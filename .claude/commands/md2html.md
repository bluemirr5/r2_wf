---
name: md2html
description: 마크다운 파일을 개발자 리뷰용 HTML로 변환
---

# md2html

`specs/` 폴더 또는 임의 경로의 마크다운 파일을 읽어서 개발자 리뷰 목적의 HTML로 변환합니다.

## 사용법

```
/md2html <파일1> [파일2] [파일3] ...
```

파일을 하나만 지정하거나, 공백으로 구분해 여러 파일을 한번에 지정할 수 있습니다.
글로브 패턴(`specs/*.md`)도 지원합니다.

**예시:**

- `/md2html specs/SPEC-003-selection-move-delete.md` — 단일 파일
- `/md2html specs/SPEC-003-foo.md specs/SPEC-004-bar.md` — 여러 파일
- `/md2html specs/*.md` — 글로브 패턴으로 폴더 내 전체 변환
- `/md2html README.md docs/architecture.md specs/SPEC-005-foo.md` — 혼합

---

## 작업 프로세스

파일이 여러 개인 경우 아래 흐름을 각 파일마다 순서대로 반복합니다.

1. 지정한 마크다운 파일 목록 확정 (글로브이면 먼저 파일 목록 전개)
2. 각 파일을 순서대로 읽기 (경로는 현재 작업 디렉토리 기준 상대 경로 또는 절대 경로 모두 허용)
3. 파일의 구조·내용 분석
4. HTML로 변환
5. 출력 경로 결정 후 저장:
   - 입력이 `specs/SPEC-{번호}-{슬러그}.md` 패턴이면 → `docs/SPEC-{번호}-{슬러그}.html`
   - 그 외 경로이면 → 동일 디렉토리에 `.md`를 `.html`로 대체한 경로에 저장
6. 모든 파일 처리 완료 후 결과 요약 출력

---

## 변환 규칙

### 구조 분석

- `#` 섹션은 문서 제목 및 목차 생성에 사용
- `##` 서브섹션은 `section.card`로 감싸기
- 각 section에 순번 뱃지(1, 2, 3...) 부여

### 스타일 적용

- 전체 CSS 변수: `--primary`, `--card`, `--border`, `--bg`, `--text`, `--muted` 등
- 코드 블록: `<pre><code>` 신택스 강조 (`--code-keyword`, `--code-string` 등)
- 표: 기본 테이블 스타일 (th, td 보더, 번갈아 배경)
- 호출상자: `.callout`, `.callout.warn`, `.callout.danger`, `.callout.ok`
- 배지: `.badge.draft`, `.badge.ok`, `.badge.info`

### 헤더 섹션

```html
<header class="hero">
  <h1>{문서 제목}</h1>
  <p>{부제 또는 description 앞부분}</p>
  <div class="meta">
    <span><strong>상태</strong><span class="badge draft">Draft</span></span>
    <span><strong>기준일</strong>{오늘 날짜}</span>
    <!-- 마크다운에 메타 정보가 있으면 추가 표시 -->
  </div>
</header>
```

- 마크다운 frontmatter(`---`)가 있으면 메타 정보로 파싱하여 헤더에 반영
- frontmatter가 없으면 `#` 제목을 문서 제목으로 사용

### 목차 생성

- 모든 `##` 레벨 섹션 수집
- 각 섹션에 `id="s1"`, `id="s2"` 부여
- 섹션이 4개 이상이면 2단 컬럼 레이아웃, 미만이면 1단

### 코드 블록 강조

- `<span class="kw">` — 키워드 (const, return, if 등)
- `<span class="str">` — 문자열 ('...')
- `<span class="cmt">` — 주석 (// ...)
- `<span class="ty">` — 타입 (MyType, Promise<T> 등)
- `<span class="fn">` — 함수명

### 특수 요소

- 마크다운 리스트 → `<ul>` / `<ol>` (시나리오 성격이면 `.scenario-box`로 감싸기)
- 표 → `<table>` (th, td 스타일 적용)
- 인라인 코드: `<code>` (배경색 #f1f5f9)
- 인용문(`>`): `.callout` 박스로 변환

### 다이어그램 (Mermaid)

- 마크다운의 ` ```mermaid ` 코드 블록은 신택스 강조 대상이 아니라 **다이어그램으로 렌더링**한다.
  내용을 이스케이프하지 말고 그대로 `<pre class="mermaid">...</pre>`로 출력하고, "필수 사항"의
  mermaid.js 초기화 스크립트를 포함한다.
- ASCII/유니코드 박스 드로잉(`┌ ─ │ ▼ ◀ └ ┘ ▶` 등)으로 그린 텍스트 다이어그램은 의미를 해석해
  **동등한 Mermaid `flowchart`로 변환**한 뒤 위와 동일하게 렌더링한다. 노드 라벨·엣지 라벨·
  화살표 방향을 보존하고, DB·스토리지성 노드는 원통형(`[( )]`)으로, 폴링·비동기성 엣지는
  점선(`-.->`)으로 표현한다.
  - 원문 `.md`는 수정하지 않고 **HTML 출력에서만** 변환하는 것이 기본. 원문 `.md`의 ASCII를
    `mermaid` 블록으로 함께 치환하려면 사용자가 명시적으로 요청할 때만 수행한다.
- Mermaid 테마는 문서 CSS 변수와 맞춘다: `theme: "base"` + `themeVariables`
  (primaryColor=`--primary-soft`, primaryBorderColor=`--primary`, primaryTextColor=`--text`,
  lineColor=`--muted`, fontFamily=본문 폰트).

---

## 출력 경로 규칙

| 입력 경로 | 출력 경로 |
|---|---|
| `specs/SPEC-003-foo.md` | `docs/SPEC-003-foo.html` |
| `specs/phase-2-design.md` | `docs/phase-2-design.html` |
| `docs/architecture.md` | `docs/architecture.html` |
| `README.md` | `README.html` |
| `/absolute/path/doc.md` | `/absolute/path/doc.html` |

---

## 필수 사항

- UTF-8 인코딩
- DOCTYPE, meta viewport 포함
- 반응형 (max-width: 720px에서 컬럼 1개)
- 푸터: 원본 파일 경로 표시 (`원본: <code>{입력 파일 경로}</code>`)
- `mermaid` 블록(또는 ASCII→Mermaid로 변환된 다이어그램)이 하나라도 있으면 `</body>` 직전에
  mermaid.js ESM 모듈을 포함하고 `mermaid.initialize({ startOnLoad: true, securityLevel: "loose",
  theme: "base", themeVariables: {...} })`를 호출한다.
  CDN: `https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs`.
  (폐쇄망/오프라인 리뷰가 필요하면 CDN 대신 로컬에 vendoring.)

---

## 작업 완료 후

파일이 하나이면:
1. 생성된 HTML 파일 경로 표시
2. (선택) 브라우저에서 열어 미리보기 확인 제안

파일이 여러 개이면:
1. 처리 결과를 표 형태로 요약 출력

| 입력 파일 | 출력 파일 | 결과 |
|---|---|---|
| `specs/SPEC-003-foo.md` | `docs/SPEC-003-foo.html` | ✓ |
| `specs/SPEC-004-bar.md` | `docs/SPEC-004-bar.html` | ✓ |

2. 실패한 파일이 있으면 이유와 함께 별도 표시
