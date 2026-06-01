# Orchestration — 완전 자동화 프로토콜

> 이 문서는 r2_wf 자동화 레이어의 **단일 진실원천(single source of truth)**이다.
> `/orchestrate` 커맨드와 `notifier`·`e2e-tester` 에이전트가 이 규칙을 참조한다.
> 프로토콜이 바뀌면 여기를 먼저 고치고, 각 에이전트는 이 문서를 인용한다.

## 0. 왜 이 레이어가 필요한가

9개 에이전트 파이프라인(planner→spec-writer→architect→developer→test-writer→code-reviewer/security-checker→doc-writer)은 사람이 메인 세션에서 각 에이전트를 **수동 호출**하는 반자동 구조다. 완전 자동화를 막던 두 지점:

1. **실제 동작 검증 부재** — `test-writer`는 mock 기반 unit/integration만. 빌드 산출물을 실제로 띄워 엔드포인트를 때려보는 층이 없어 "테스트 통과인데 실제로 안 됨"을 사람이 매번 잡았다 → **e2e-tester**가 메움.
2. **결정 라우팅 부재** — 에이전트가 결정에 막히면 자유 텍스트로 멈춘다. 누가 판단 가능한지, 사람에게 언제 올리는지 조율이 없다 → **orchestrator(라우팅 두뇌) + notifier(사람 채널)**가 메움.

## 1. 아키텍처 제약 (설계를 규정하는 사실)

이 제약들은 협상 불가다. 모든 설계 결정이 여기서 파생된다.

| 제약 | 귀결 |
|---|---|
| **서브에이전트는 다른 서브에이전트를 호출 못 함**. 오직 메인(top-level)만 dispatch | orchestrator는 서브에이전트가 **아니라** 메인 세션이 읽는 커맨드(`.claude/commands/orchestrate.md`) |
| **서브에이전트는 stateless** — "막힌 에이전트 재개"란 없음 | 답을 컨텍스트에 주입해 **재-dispatch** → 에이전트가 파일에서 상태 재구성. **모든 상태는 파일에** |
| **PROCESS.md는 100줄·한줄·완료즉시삭제 불변식** (doc-writer가 정리) | 결정 레코드·카운터는 PROCESS.md **밖** 별도 스토어로 |
| **사람 응답의 진짜 난점은 inbound**(Slack 답→세션). 서브에이전트 모델 밖 | 폴링/cron 대신 **resume-on-relaunch** (§6) |

## 2. 상태 저장 위치 (3-스토어 분리)

| 스토어 | 소유 | 수명 | 용도 |
|---|---|---|---|
| `docs/PROCESS.md` | 전 에이전트 | 짧음(완료즉시삭제·100줄) | 현재 진행/다음/메모 + 결정 **한 줄 포인터만** |
| `docs/decisions/NNN-<kebab>.md` | orchestrator·notifier | append-only(영속) | 결정 레코드 본문·감사 추적 |
| `docs/.orch-state.json` | orchestrator 전용 | 세션 단위 | 사이클번호·dispatch카운트·예산·실패시그니처·열린결정 |

**doc-writer 경계**: `docs/decisions/`·`docs/.orch-state.json`은 append-only·orchestrator 소유 → doc-writer의 PROCESS.md 정리 대상에서 **제외**(wipe 금지).

## 3. DECISION 레코드 / Escalation 프로토콜

에이전트가 **스스로 못 푸는 결정**에 부딪히면, 자유 텍스트로 멈추지 말고 `docs/decisions/NNN-<kebab>.md`에 **구조화 레코드**를 emit하고, PROCESS.md엔 **한 줄 포인터만** 남긴다.

### 레코드 스키마 (frontmatter)

```yaml
---
id: DECISION-007
from-agent: security-checker      # 결정을 raise한 에이전트
domain: security-accept           # §4 라우팅 테이블의 domain 키
question: "A03 SQL injection 잔존 위험을 이번 릴리스에서 수용할 것인가?"
options:
  - "A: 수용(리스크 면제) — 후속 사이클에서 수정"
  - "B: 차단 — 지금 수정 후 진행"
suggest: human                    # 판단 가능 주체(에이전트명 또는 human)
blocked-work: "cycle 3 DoD 게이트 step 5"
created: 2026-06-01T10:00:00Z
deadline: 2026-06-02T10:00:00Z    # 타임아웃(무한정지 방지)
default-on-timeout: B             # 타임아웃 시 안전한 기본값(없으면 escalate 유지)
resolved-by:                      # auto | human | (미해결시 공란)
resolution:                       # 채워지면 orchestrator가 주입해 재-dispatch
---
```

### 처리 흐름

1. 에이전트가 레코드 emit + PROCESS.md 한 줄: `(orchestrator) DECISION-007 대기 — human 결정 필요`
2. orchestrator가 `domain`으로 §4 라우팅:
   - **자동 가능**(판단주체가 에이전트): 판단주체를 dispatch → 권고 수신 → 레코드 `resolution` 기록(`resolved-by: auto`) → **적용주체**를 답과 함께 재-dispatch
   - **사람 필요**(suggest=human, 또는 비가역/보안수용/비즈니스): notifier 호출 → 세션 정지(§6)
3. 재-dispatch받은 에이전트는 PROCESS.md·spec·결정레코드에서 상태를 재구성해 진행

### 안전 임계

- **auto 결정이 1파일/1모듈 영향을 넘으면 human 확인으로 격상.** 광범위 영향의 자동 결정 전파 방지.
- **보안 수용·비즈니스·비가역 결정은 절대 auto 금지** — 항상 human.
- 모든 auto 결정은 `resolved-by: auto` + 근거를 레코드에 남겨 감사 가능하게.

## 4. 라우팅 테이블 (판단주체 ≠ 적용주체)

report-only 에이전트(architect/code-reviewer/security-checker/e2e-tester)는 **권고**만 낸다. orchestrator가 권고를 받아 **적용주체**에 재-dispatch하는 **2단계**.

| domain | 판단주체 (누가 결정) | 적용주체 (누가 반영) |
|---|---|---|
| `spec-ambiguity` 스펙 모호 | spec-writer | spec-writer |
| `structure` 구조/레이어/추상화 | architect(모드2) | spec-writer 또는 developer |
| `impl-detail` 구현 기계적 결정 | developer | developer |
| `test-strategy` 테스트 전략/실패 분류 | test-writer | test-writer |
| `failure-root-cause` 빌드·런타임·테스트 실패 | debugger | developer (승인 후) |
| `security-accept` 보안 발견 **수용 여부** | **항상 human** | — (리스크 면제) |
| `security-fix` 보안 수정 방법 | security-checker(권고) | developer |
| `new-dependency` 신규 의존성 도입 | **human** | developer |
| `e2e-applicability` e2e 적용성/환경 | e2e-tester | (report) / 하니스는 사람·developer |
| `doc-drift` 문서 drift | doc-writer | doc-writer |
| `plan-scope` 플랜/범위/비범위 변경 | planner 또는 **human** | planner |
| `business` 비즈니스·우선순위·비가역 | **항상 human** | — |

**금지**: High/Critical 보안 발견의 수용 여부를 그 발견을 raise한 security-checker에게 되돌려보내지 말 것(자기 발견을 자기가 면제하는 셈) → 항상 human.

## 5. 완료 게이트 (DoD)

orchestrator는 아래를 **순서대로** 확인하고, **전부 충족 시에만** 다음 사이클로 진행한다.

1. **developer**: 모든 AC 구현 + 빌드/typecheck green
2. **test-writer**: 작성 테스트 전체 통과 (독립 실행)
3. **e2e-tester**: 통과 **또는** N/A — 실패면 §3로 분류 후 debugger. N/A(표면없음)는 §7대로 관찰 가능하게 플래그
4. **code-reviewer**: Critical 0 — "발견→수정→재검사" 루프 종료 상태(단순 1회 검사 아님)
5. **security-checker**: Critical/High 0 — 잔존 시 human 면제(`security-accept`) 없으면 미충족
6. **doc-writer**: drift 점검 통과 + PROCESS.md 정리
7. **1–6 통과 후** 작업 브랜치에 커밋 → PR 생성

### 재검증 규칙 (협상 불가)

step 4·5(리뷰·보안)는 developer 수정을 유발한다. **DoD 진행 중 코드가 바뀌면 동적 검사(1 빌드/typecheck, 2 테스트, 3 e2e)의 이전 결과가 무효화**된다 — 수정 전 버전에 대해 검증된 테스트·e2e로 커밋하면 안 된다. 따라서 **step 2~6 중 어디서든 코드 변경이 발생하면 step 1부터 다시 실행**한다. step 6(doc-writer)·정적 점검만 바뀌고 코드가 그대로면 재실행 불필요. orchestrator는 "마지막 코드 변경 이후 1~3이 모두 재통과했는가"를 커밋 전 확인한다.

### 커밋 규칙 (협상 불가)

- 리뷰/보안/테스트 에이전트는 `git diff HEAD`(**미커밋** 변경)를 본다 → **커밋은 반드시 모든 검사 통과 후**.
- **기본 브랜치(main)에 자동 커밋 금지**. 작업 브랜치에서만.
- **자동 머지 금지**. PR 생성까지만, 머지는 사람.

## 6. 비동기 사람 응답 = resume-on-relaunch

서브에이전트는 비동기 inbound(몇 시간 뒤 Slack 답)를 받을 수 없다. 그래서 "대기"가 아니라 "영속화 + 정지 + 재실행 시 재구성"으로 모델링한다.

1. orchestrator가 사람 결정 필요 도달
2. **notifier 호출** → PushNotification(+ 설정 시 Slack/Discord webhook) 발송
3. 결정 레코드 영속화 + PROCESS.md 한 줄 포인터 + `.orch-state.json`의 `open_decisions`에 id 추가
4. **orchestrator 세션 정지** (대기하지 않음)
5. 사람이 답을 **결정 레코드의 `resolution`/`resolved-by: human`에 기록** 후 `/orchestrate` 재실행
6. 재실행된 orchestrator가 `open_decisions` 확인 → 답이 채워진 결정은 해당 에이전트를 답과 함께 재-dispatch, `open_decisions`에서 제거

**MVP inbound = 사람 수동 재실행**(인프라 0). webhook→자동 재실행은 후속(§9).

## 7. e2e 적용 판정 (추론 대신 선언)

spec-writer가 스펙에 선택적 **"E2E 표면"** 필드를 표기한다(엔드포인트 경로/포트, UI URL, CLI 명령, 기동 명령). e2e-tester는 추론하지 않고 이 **선언된 사실**을 읽는다.

| 판정 | 조건 | 처리 |
|---|---|---|
| **e2e 가능** | 표면 선언 + **기동 명령** 존재 + 기동 성공 | 실제 엔드포인트/UI/CLI 테스트 |
| **N/A(표면없음)** | 표면 미선언(순수 라이브러리/내부 로직) | **결정 스토어에 한 줄 기록 + DoD에서 플래그**(아래) |
| **N/A(하니스없음)** | 표면 있으나 **기동 방법이 전혀 없음** | 사람에게 기동 명령 요청 보고 |
| **실패** | 기동 후 red | (a)프로덕션버그/(b)테스트오류/(c)환경문제 분류 → debugger |

**"기동 명령" 범위**: 외부 인프라(DB·컨테이너) 없는 단순 앱은 앱의 일반 start 명령(`npm start` 등)이 곧 기동 명령 — 별도 하니스 불필요, e2e 가능. 전용 `e2e:up`/`e2e:down`은 무거운 provisioning이 필요할 때만.

**silent N/A 방지(이 기능의 핵심)**: spec-writer가 표면 선언을 깜빡하면 엔드포인트가 있는 사이클이 검증 없이 통과되어 *바로 이 기능이 막으려던 갭으로 회귀*한다. 따라서 e2e-tester는 N/A(표면없음) 판정 시 `docs/decisions/`에 `domain: e2e-applicability`로 한 줄 기록하고, orchestrator는 DoD step 3에서 이를 **관찰 가능하게 플래그**해 doc-writer/사람이 "이 사이클에 엔드포인트가 있었는데 표면 미선언 아니었나"를 사후에 잡게 한다.

**provisioning 경계**: e2e-tester는 앱을 **띄워 테스트하는 것은 허용**(파일을 쓰지 않음)하되, **프로젝트 코드·설정·DB 스키마를 새로 작성하지 않는다**(report-only). 즉 기동 명령(`npm start` 또는 전용 `e2e:up`)을 **호출만** 하고, 그 명령·서버·하니스를 **만드는 것은 developer 몫**. 검증자가 피검증물을 만들면 이해충돌이기 때문.

## 8. 서킷브레이커 & 예산

카운터는 `docs/.orch-state.json`에 둔다(PROCESS.md 아님 — wipe 방지).

- **실패 시그니처 카운트**: 반복 횟수가 아니라 **실패 시그니처**(에러 메시지/스택 상단 프레임 해시)를 센다. 매번 다른 걸 고치면 진행이지 루프가 아니다. **같은 시그니처가 N회(기본 3) 반복 시에만 트립** → 자동 재시도 중단 → notifier→human.
- **글로벌 예산 천장**: `max_dispatches`·`max_cycles`·`wall_clock`. 핑퐁은 developer↔debugger·developer↔reviewer만이 아니므로(review→fix, e2e→debugger도) 글로벌 천장이 비용 폭주의 진짜 방어선.
- **리셋**: 시그니처 카운터는 DoD 통과 시 **사이클 단위 리셋**. 글로벌 예산은 **세션 단위**(또는 사용자 명시 리셋).

### `.orch-state.json` 스키마

```json
{
  "cycle": 3,
  "dispatches": 42,
  "started_at": "2026-06-01T09:00:00Z",
  "budget": { "max_dispatches": 200, "max_cycles": 10, "wall_clock_hours": 8 },
  "failure_signatures": { "<sha-of-error>": { "count": 2, "last_agent": "debugger" } },
  "open_decisions": ["DECISION-007"]
}
```

## 9. 알려진 한계 & 선행 설정

- **페르소나 집행은 best-effort**: 마크다운 프롬프트가 시그니처 카운터·trip-at-3·예산 천장·DoD 순서 같은 정밀 상태기계를 돌리는 것은 페르소나가 가장 약하고 Workflow 스크립트가 가장 강한 영역. 드라이런에서 페르소나가 카운터/예산/게이트를 흘리면 그 결정적 로직을 **Workflow 스크립트로 이관**하는 것이 1순위 후속.
- **선행 설정**: 서브에이전트는 `PushNotification` grant 가능(Permission Required: No, Anthropic-hosted 한정 — Bedrock/Vertex 불가). **fallback**: 서브에이전트 notifier가 PushNotification을 못 부르면 메시지 본문을 orchestrator(메인 세션)에 반환 → orchestrator가 발송(메인 세션은 항상 호출 가능). 드라이런에서 이 경로를 먼저 확인. Slack/Discord webhook curl을 쓰려면 사용자가 `.claude/settings.local.json`에 `Bash(curl ...)` allow와 webhook URL/secret을 설정해야 한다(현재 미설정 → MVP는 PushNotification만).
- **inbound 자동화(후속)**: Slack 답을 세션으로 자동 주입하려면 webhook→RemoteTrigger 또는 cron `/orchestrate`가 필요. MVP는 사람 수동 재실행.

## 10. 신뢰 경계 한눈에

- **자동(에이전트 판단)**: 스펙 모호, 구조, 구현 디테일, 테스트 전략, 실패 원인, 보안 수정 방법, 문서 drift, e2e 적용성.
- **항상 사람**: 보안 발견 수용, 신규 의존성, 플랜/범위, 비즈니스/우선순위/비가역, 그리고 영향 범위가 1모듈을 넘는 모든 auto 결정.
