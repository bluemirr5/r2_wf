#!/bin/bash
set -e

REPO_URL="https://github.com/bluemirr5/r2_wf"
TEMP_DIR=$(mktemp -d)

echo "📦 Installing r2_wf Claude Lab template..."

# git clone
git clone --depth 1 "$REPO_URL" "$TEMP_DIR" || {
    echo "❌ Error: Failed to clone repository"
    echo "Make sure the repository URL is correct: $REPO_URL"
    rm -rf "$TEMP_DIR"
    exit 1
}

# .claude 디렉토리 복사
if [ -d "$TEMP_DIR/.claude" ]; then
    cp -r "$TEMP_DIR/.claude" .
    echo "✅ Success! Claude Lab installed"
    echo ""
    echo "Directory structure:"
    ls -la .claude/
else
    echo "❌ Error: .claude directory not found in template"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# 정리
rm -rf "$TEMP_DIR"
