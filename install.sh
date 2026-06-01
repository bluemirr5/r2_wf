#!/bin/bash
set -e

REPO_URL="https://github.com/bluemirr5/r2_wf"
# 설치할 브랜치: 인자 1 > 환경변수 R2WF_BRANCH > main
BRANCH="${1:-${R2WF_BRANCH:-main}}"
TEMP_DIR=$(mktemp -d)

echo "📦 Installing r2_wf Claude Lab template (branch: $BRANCH)..."

# git clone (지정 브랜치)
git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$TEMP_DIR" || {
    echo "❌ Error: Failed to clone repository (branch: $BRANCH)"
    echo "Make sure the repo URL / branch is correct: $REPO_URL @ $BRANCH"
    rm -rf "$TEMP_DIR"
    exit 1
}

# .claude 디렉토리 복사
if [ -d "$TEMP_DIR/.claude" ]; then
    cp -r "$TEMP_DIR/.claude" .
    echo "✅ .claude/ (agents + commands) installed"
else
    echo "❌ Error: .claude directory not found in template"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# docs/ 오케스트레이션 프로토콜 자산 복사
# (orchestrate 커맨드·에이전트가 참조하는 템플릿 자산. 모든 프로젝트가 동일하게 필요.)
# 주의: docs/PROCESS.md·docs/plans/·docs/specs/ 는 프로젝트가 생성하므로 복사하지 않는다.
mkdir -p docs/decisions
for f in docs/orchestration.md docs/orch-state.example.json docs/decisions/README.md; do
    if [ -f "$TEMP_DIR/$f" ]; then
        cp "$TEMP_DIR/$f" "$f"
        echo "✅ $f installed"
    else
        echo "⚠️  $f not found in template (skipped)"
    fi
done

echo ""
echo "Directory structure:"
ls -la .claude/
echo ""
echo "📋 Protocol: docs/orchestration.md · docs/decisions/ · docs/orch-state.example.json"
echo "▶ /orchestrate 로 전체 파이프라인을 자동 구동할 수 있습니다."

# 정리
rm -rf "$TEMP_DIR"
