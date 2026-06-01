# CLAUDE.md

## 프로젝트 개요

**r2_wf**는 회사 "Claude Lab"의 기본 템플릿 저장소다. 애플리케이션이 아니라,
새 프로젝트에 `.claude/` 디렉토리(커스텀 서브에이전트 + 커맨드)를 심어주는 **배포용 템플릿**이다.

설치는 원커맨드: `curl -fsSL .../install.sh | bash` → repo를 clone해 `.claude/`만 현재 폴더로 복사.

## 구조

```
r2_wf/
├── install.sh           # .claude/만 현재 폴더로 복사하는 설치 스크립트
├── README.md            # 설치/구조/업데이트 안내
├── workflow.html        # 에이전트 워크플로우를 시각화한 단일 HTML 문서
└── docs/
    ├── PROCESS.md       # 모든 에이전트가 공유하는 "살아있는 작업판" (100줄 상한)
    ├── orchestration.md # ★ 자동화 프로토콜 단일 진실원천 (DECISION·라우팅·DoD·서킷브레이커)
    ├── decisions/       # append-only 결정 스토어 (orchestrator 소유, doc-writer 정리 제외)
    ├── orch-state.example.json # orchestrator 상태 스키마 (런타임: docs/.orch-state.json)
    ├── plans/           # 마스터 플랜
    └── specs/           # 사이클별 스펙
.claude/
├── agents/   # 11개 서브에이전트 (.md)
└── commands/ # md2html, review-loop, orchestrate
```

## 에이전트 파이프라인 (한 사이클)

planner → spec-writer → architect → developer → test-writer → **e2e-tester** → code-reviewer / security-checker → doc-writer

| 에이전트 | 모델 | 역할 | 쓰기 권한 |
|---|---|---|---|
| planner | opus | 마스터 플랜 수립 + CEO/CTO 자체검증, PROCESS.md 초기화 | plan 문서 |
| spec-writer | opus | 사이클별 기능 명세(계약서) 작성, E2E 표면 선언 | spec 문서 |
| architect | opus | 스펙↔플랜 정합성 리뷰 / 구현 결정 가이드 | PROCESS.md만 |
| developer | sonnet | 스펙 기반 실제 코드 구현 | 코드 |
| test-writer | sonnet | 변경 코드 테스트 작성·실행 (mock 기반) | 테스트 파일만 |
| e2e-tester | sonnet | 실제 엔드포인트·UI·CLI end-to-end 검증 (report-only) | PROCESS.md·decisions만 |
| code-reviewer | sonnet | 코드 품질·로직 리뷰 (제안만) | PROCESS.md만 |
| debugger | opus | 실패 원인 추적, **승인 후에만** 수정 | 승인 후 코드 |
| security-checker | opus | OWASP 심층 보안검사 (보고만) | PROCESS.md만 |
| doc-writer | haiku | 문서↔코드 drift 점검, PROCESS.md 정리 1차 책임 | 문서(.md) |
| notifier | haiku | 사람 채널 어댑터 — 결정사항 push/Slack 발송 (outbound 전용) | PROCESS.md·decisions만 |

## 자동화 레이어 (orchestrator)

`/orchestrate` 커맨드(메인 세션 페르소나)가 위 11개 에이전트를 **사람 개입 없이 순차 구동**한다. 서브에이전트는 다른 서브에이전트를 호출할 수 없으므로 dispatch 권한은 메인 세션에만 있다 → orchestrator는 에이전트가 아니라 커맨드.

- **결정 라우팅**: 에이전트가 못 푸는 결정은 구조화 DECISION 레코드로 emit → orchestrator가 도메인별로 판단 가능한 에이전트에 라우팅, 불가하면 notifier로 사람에게 escalation.
- **완료 게이트(DoD)**: AC + 테스트 + e2e + 리뷰 + 보안 + doc 통과 후에만 커밋·다음 사이클.
- **서킷브레이커·예산**: 동일 실패 반복/예산 초과 시 정지.
- **비동기 사람 응답**: 대기하지 않고 영속화 후 정지, 사람이 답 기록 후 `/orchestrate` 재실행(resume-on-relaunch).
- 프로토콜 전체: `docs/orchestration.md`.

## 핵심 원칙

- **권한 경계 엄격 분리**: 각 에이전트는 자기 영역만 수정한다. architect/code-reviewer/security-checker는 코드를 건드리지 않고 제안만 한다. debugger는 사용자 승인 없이 코드를 수정하지 않는다.
- **PROCESS.md = 공유 작업판**: 모든 에이전트가 시작·종료마다 읽고 갱신. **완료 항목은 즉시 삭제**(이력화 X), 100줄 상한. 길어지면 spec/플랜으로 이관.
- **스펙=계약, 플랜=WHY**: 중복 금지. 스펙은 WHAT(파일·타입·AC)만, WHY·아키텍처는 마스터 플랜이 소유한다.
- **마스터 플랜 분할 규칙**: 단일 파일이 400줄 / 10k 토큰을 초과하면 인덱스(`docs/plans/README.md`) + 주제별 파일로 분할. 서브에이전트의 단일 read 토큰 제한 대응.

## 컨벤션

- **언어**: 모든 응답·문서는 한국어. 단, 코드 식별자·파일 경로·라이브러리명·커밋 메시지는 영문.
- **에이전트 파일 포맷**: frontmatter(`name`, `description`, `tools`, `model`) + 본문(역할/철학 → 권한 경계 → 작업 순서 → 체크리스트 → 출력 형식 → 금지사항 → 연계).
- 에이전트 간 참조는 `[[agent-name]]` 형식.
- 문서 경로 관례: 플랜 `docs/plans/`, 스펙 `docs/specs/<NNN>-<kebab>.md`, 결정 `docs/decisions/<NNN>-<kebab>.md`.
