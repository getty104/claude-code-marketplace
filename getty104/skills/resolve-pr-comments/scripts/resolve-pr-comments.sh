OWNER_REPO="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
OWNER="$(echo $OWNER_REPO | cut -d'/' -f1)"
REPO="$(echo $OWNER_REPO | cut -d'/' -f2)"
PR_NUMBER="$(gh pr view --json number --jq '.number')"

fetch_all_review_threads() {
  local cursor="null"
  local has_next_page=true
  local temp_dir=$(mktemp -d)
  local page_num=0

  while [ "$has_next_page" = "true" ]; do
    gh api graphql -f query="
query(\$cursor: String) {
  repository(owner: \"${OWNER}\", name: \"${REPO}\") {
    pullRequest(number: ${PR_NUMBER}) {
      number
      title
      url
      state
      author {
        login
      }
      reviewRequests(first: 100) {
        nodes {
          requestedReviewer {
            ... on User {
              login
            }
          }
        }
      }
      reviewThreads(first: 100, after: \$cursor) {
        pageInfo {
          hasNextPage
          endCursor
        }
        edges {
          node {
            id
            isResolved
            isOutdated
            path
            line
            comments(last: 100) {
              nodes {
                author {
                  login
                }
                body
                url
                createdAt
              }
            }
          }
        }
      }
    }
  }
}" -f cursor="$cursor" > "${temp_dir}/page_${page_num}.json"

    has_next_page=$(jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.hasNextPage' "${temp_dir}/page_${page_num}.json")
    cursor=$(jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.endCursor' "${temp_dir}/page_${page_num}.json")
    page_num=$((page_num + 1))
  done

  jq -s '
    .[0].data.repository.pullRequest as $first_pr |
    {
      pr_number: $first_pr.number,
      title: $first_pr.title,
      url: $first_pr.url,
      state: $first_pr.state,
      author: $first_pr.author.login,
      requested_reviewers: [$first_pr.reviewRequests.nodes[].requestedReviewer.login],
      unresolved_threads: [
        .[].data.repository.pullRequest.reviewThreads.edges[] |
        select(.node.isResolved == false) |
        {
          thread_id: .node.id,
          path: .node.path,
          line: .node.line,
          is_outdated: .node.isOutdated,
          comments: [
            .node.comments.nodes[] |
            {
              author: .author.login,
              body: .body,
              url: .url,
              created_at: .createdAt
            }
          ]
        }
      ]
    }
  ' "${temp_dir}"/page_*.json

  rm -rf "$temp_dir"
}

REVIEW_DATA=$(fetch_all_review_threads)

echo "$REVIEW_DATA" | jq -r '.unresolved_threads[].thread_id' | while read -r thread_id; do
  if [ -n "$thread_id" ] && [ "$thread_id" != "null" ]; then
    echo "Resolving thread: $thread_id"
    gh api graphql -f query="
mutation {
  resolveReviewThread(input: {threadId: \"$thread_id\"}) {
    thread {
      id
      isResolved
    }
  }
}" && echo "✓ Resolved thread: $thread_id" || echo "✗ Failed to resolve thread: $thread_id"
  fi
done

echo "All unresolved threads have been processed."
