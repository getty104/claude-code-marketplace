#!/usr/bin/env bash
set -euo pipefail

DAYS="${1:-1}"

OWNER_REPO="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
OWNER="$(echo "$OWNER_REPO" | cut -d'/' -f1)"
REPO="$(echo "$OWNER_REPO" | cut -d'/' -f2)"

if date -v-1d >/dev/null 2>&1; then
  SINCE_DATE="$(date -v-"${DAYS}"d +%Y-%m-%d)"
  SINCE_ISO="$(date -u -v-"${DAYS}"d +%Y-%m-%dT%H:%M:%SZ)"
else
  SINCE_DATE="$(date -d "${DAYS} days ago" +%Y-%m-%d)"
  SINCE_ISO="$(date -u -d "${DAYS} days ago" +%Y-%m-%dT%H:%M:%SZ)"
fi

PR_NUMBERS=$(gh pr list --state all --search "updated:>=${SINCE_DATE}" --json number --jq '.[].number' --limit 100)

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

if [ -z "$PR_NUMBERS" ]; then
  jq -n --arg since "$SINCE_ISO" --arg repo "$OWNER_REPO" \
    '{period_since:$since, repo:$repo, pr_count:0, prs:[]}'
  exit 0
fi

fetch_pr() {
  local pr="$1"
  local out_file="$2"
  local since="$3"
  local owner="$4"
  local repo="$5"

  gh api graphql \
    -f query='query($owner:String!,$repo:String!,$pr:Int!) {
      repository(owner:$owner, name:$repo) {
        pullRequest(number:$pr) {
          number title url author { login }
          reviewThreads(first: 100) {
            nodes {
              isResolved isOutdated path line
              comments(first: 50) {
                nodes { author { login } body url createdAt }
              }
            }
          }
          comments(first: 100) {
            nodes { author { login } body url createdAt isMinimized }
          }
        }
      }
    }' \
    -F owner="$owner" -F repo="$repo" -F pr="$pr" \
    | jq --arg since "$since" '
        .data.repository.pullRequest as $pr | {
          pr_number: $pr.number,
          pr_title: $pr.title,
          pr_url: $pr.url,
          pr_author: ($pr.author.login // "unknown"),
          review_comments: [
            $pr.reviewThreads.nodes[] | . as $t |
            $t.comments.nodes[] | select(.createdAt >= $since) |
            {
              path: $t.path, line: $t.line,
              is_resolved: $t.isResolved, is_outdated: $t.isOutdated,
              author: (.author.login // "unknown"),
              body: .body, url: .url, created_at: .createdAt
            }
          ],
          conversation_comments: [
            $pr.comments.nodes[] | select(.createdAt >= $since) | select(.isMinimized == false) |
            { author: (.author.login // "unknown"), body: .body, url: .url, created_at: .createdAt }
          ]
        }
      ' > "$out_file"
}

for PR in $PR_NUMBERS; do
  fetch_pr "$PR" "$TEMP_DIR/pr_${PR}.json" "$SINCE_ISO" "$OWNER" "$REPO" &
done
wait

jq -s --arg since "$SINCE_ISO" --arg repo "$OWNER_REPO" '
  map(select(
    (.review_comments | length > 0) or (.conversation_comments | length > 0)
  )) as $non_empty |
  {
    period_since: $since,
    repo: $repo,
    pr_count: ($non_empty | length),
    prs: $non_empty
  }
' "$TEMP_DIR"/pr_*.json
