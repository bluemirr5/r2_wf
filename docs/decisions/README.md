# 결정 스토어 (Decision Store)

> 자동화 루프에서 발생한 **결정 사항(DECISION)**의 영속 저장소.
> `docs/PROCESS.md`의 "100줄·한줄·완료즉시삭제" 불변식과 **분리**하기 위해 존재한다.
> 프로토콜 전체는 [`../orchestration.md`](../orchestration.md) §3 참조.

## 규칙

- **append-only**: 레코드는 추가·갱신만. 삭제하지 않는다(감사 추적).
- **레코드당 1파일**: `NNN-<kebab>.md` (예: `007-security-sqli-accept.md`).
- **작성 책임**:
  - **레코드 본문 + 인덱스 한 줄**: 결정을 raise한 **emitting 에이전트**가 생성(다음 `NNN`은 인덱스의 마지막 번호+1). PROCESS.md엔 한 줄 포인터.
  - **`resolution`·`resolved-by`·`open_decisions` 관리**: **orchestrator**(자동 결정) 또는 **사람**(human 결정). notifier는 발송만.
  - doc-writer의 PROCESS.md 정리 대상에서 **제외**(wipe 금지).
- PROCESS.md에는 **한 줄 포인터만** 남긴다: `(orchestrator) DECISION-007 대기 — human 결정 필요`.

## 레코드 템플릿

```markdown
---
id: DECISION-NNN
from-agent: <에이전트명>
domain: <orchestration.md §4의 domain 키>
question: "<한 줄 질문>"
options:
  - "A: ..."
  - "B: ..."
suggest: <에이전트명 | human>
blocked-work: "<멈춘 작업>"
created: <ISO8601>
deadline: <ISO8601>
default-on-timeout: <A | B | (공란=escalate 유지)>
resolved-by:        # auto | human | (미해결시 공란)
resolution:         # 채워지면 orchestrator가 주입해 재-dispatch
---

## 맥락
<왜 이 결정이 필요한가, 어떤 옵션이 무슨 결과를 낳는가 — 사람이 읽고 판단할 수준>

## 결정 (사람/자동이 기록)
<선택한 옵션과 이유. resolution 필드와 동기화>
```

## 인덱스

<!-- orchestrator가 레코드 생성 시 한 줄씩 추가. 형식: - [DECISION-NNN](NNN-slug.md) — <상태> <한줄> -->

(아직 결정 없음)
