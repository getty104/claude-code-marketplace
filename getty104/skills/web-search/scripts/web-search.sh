#!/bin/bash

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <search-query>"
    echo "Example: $0 \"Next.js 15の新機能について教えて\""
    exit 1
fi

SEARCH_QUERY="$1"

gemini -p "WebSearch: ${SEARCH_QUERY}" --yolo
