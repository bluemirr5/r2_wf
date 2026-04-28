# r2_wf - Claude Lab Template

회사의 Claude Lab 기본 템플릿입니다.

## 빠른 설치

새로운 프로젝트에서 다음을 실행하세요:

```bash
curl -fsSL https://raw.githubusercontent.com/bluemirr5/r2_wf/main/install.sh | bash
```

## 설치되는 것

- `agents/` - 커스텀 agents (code-reviewer, architect, debugger 등)
- `commands/` - 커스텀 commands (md2html, review-loop 등)
- `settings.local.json` - 로컬 설정

## 구조

```
.claude/
├── agents/          # 커스텀 에이전트들
│   ├── architect.md
│   ├── code-reviewer.md
│   ├── debugger.md
│   ├── developer.md
│   ├── doc-writer.md
│   ├── planner.md
│   ├── security-checker.md
│   ├── spec-writer.md
│   └── test-writer.md
├── commands/        # 커스텀 명령어들
│   ├── md2html.md
│   └── review-loop.md
└── settings.local.json
```

## 사용법

설치 후 Claude Code 또는 Claude API를 사용할 때 이 템플릿의 agents와 commands를 활용할 수 있습니다.

## 업데이트

`.claude` 디렉토리를 최신 버전으로 업데이트하려면:

```bash
rm -rf .claude
curl -fsSL https://raw.githubusercontent.com/bluemirr5/r2_wf/main/install.sh | bash
```

## 버전 히스토리

- v1.0 - Initial template release
