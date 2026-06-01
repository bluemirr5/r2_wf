# r2_wf - Claude Lab Template

회사의 Claude Lab 기본 템플릿입니다.

## 빠른 설치

새로운 프로젝트에서 다음을 실행하세요:

```bash
curl -fsSL https://raw.githubusercontent.com/bluemirr5/r2_wf/main/install.sh | bash
```

## 설치되는 것

- `.claude/agents/` - 커스텀 agents (11개: planner, spec-writer, architect, developer, test-writer, e2e-tester, code-reviewer, security-checker, debugger, doc-writer, notifier)
- `.claude/commands/` - 커스텀 commands (md2html, review-loop, orchestrate)
- `.claude/settings.local.json` - 로컬 설정
- `docs/orchestration.md` - 자동화 프로토콜 (SoT)
- `docs/decisions/`, `docs/orch-state.example.json` - 오케스트레이션 스토어·상태 스키마

> 프로젝트가 생성하는 `docs/PROCESS.md`·`docs/plans/`·`docs/specs/` 는 설치 대상이 아닙니다.

### 특정 브랜치에서 설치 (테스트용)

```bash
curl -fsSL https://raw.githubusercontent.com/bluemirr5/r2_wf/<branch>/install.sh | R2WF_BRANCH=<branch> bash
```

## 구조

```
.claude/
├── agents/          # 커스텀 에이전트들 (11개)
│   ├── architect.md
│   ├── code-reviewer.md
│   ├── debugger.md
│   ├── developer.md
│   ├── doc-writer.md
│   ├── e2e-tester.md
│   ├── notifier.md
│   ├── planner.md
│   ├── security-checker.md
│   ├── spec-writer.md
│   └── test-writer.md
├── commands/        # 커스텀 명령어들
│   ├── md2html.md
│   ├── orchestrate.md
│   └── review-loop.md
└── settings.local.json
```

자동화 프로토콜은 `docs/orchestration.md`를 참조하세요. `/orchestrate`로 전체 파이프라인을 자동 구동합니다.

## 사용법

설치 후 Claude Code 또는 Claude API를 사용할 때 이 템플릿의 agents와 commands를 활용할 수 있습니다.

## 업데이트

`.claude` 디렉토리와 프로토콜 문서를 최신 버전으로 업데이트하려면:

```bash
rm -rf .claude docs/orchestration.md docs/orch-state.example.json docs/decisions/README.md
curl -fsSL https://raw.githubusercontent.com/bluemirr5/r2_wf/main/install.sh | bash
```

> 재설치는 프로토콜 문서를 덮어쓰지만, 프로젝트가 만든 `docs/PROCESS.md`·`plans/`·`specs/`·`decisions/<NNN>.md` 레코드는 건드리지 않습니다.

## 버전 히스토리

- v1.0 - Initial template release
