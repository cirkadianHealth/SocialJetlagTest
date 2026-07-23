# CIRKADIAN 부스 설문 · 실시간 랭킹 보드

두 개의 정적 페이지로 구성됩니다.

- `cirkadian_jetlag_test.html` — 방문자가 QR로 스캔해 들어가는 설문 페이지 (폰에서 실행)
- `cirkadian_globe.html` — 부스 대형 모니터에 띄우는 실시간 지구본 랭킹 보드 (운영 노트북에서 실행)

설문 제출 → Supabase(DB) 저장(완전 익명) → 모니터가 실시간 구독해서 즉시 반영, 구조입니다.
서버 코드는 따로 없고, Supabase가 백엔드 역할을 합니다.

## 1. Supabase 프로젝트 만들기

1. https://supabase.com 에서 무료 프로젝트 생성
2. 왼쪽 메뉴 **SQL Editor** → New query → [`supabase/schema.sql`](supabase/schema.sql) 내용 붙여넣고 실행
   - `research_responses`: 설문 원본 + 계산값 저장 (연구용, 익명, insert만 가능 — 조회는 Supabase 대시보드/서비스 키로만)
   - `board_events`: 모니터에 뿌릴 도시/시차값만 저장 (공개 읽기 + 실시간 구독)
3. **Database → Replication** 메뉴에서 `board_events` 테이블이 `supabase_realtime` publication에 포함돼 있는지 확인 (스키마의 마지막 줄이 자동으로 추가하지만, UI에서 토글이 꺼져 있으면 켜주세요)
4. **Project Settings → API** 에서 `Project URL`과 `anon public` key를 복사

## 2. 페이지에 키 채워 넣기

- `cirkadian_jetlag_test.html` 상단 스크립트의 `SUPABASE_URL`, `SUPABASE_ANON_KEY`
- `cirkadian_globe.html` 상단 스크립트의 `SUPABASE_URL`, `SUPABASE_ANON_KEY`, 그리고 `SURVEY_URL`(3번에서 배포한 설문 페이지의 실제 URL)

두 파일 모두 같은 Supabase 프로젝트의 URL/키를 넣으면 됩니다.

## 3. 정적 페이지 배포 (인터넷 어디서든 접속 가능하게)

가장 쉬운 방법: [Vercel](https://vercel.com) 또는 [Netlify](https://app.netlify.com/drop) 에 이 폴더를 그대로 드래그&드롭 배포 (별도 빌드 설정 필요 없음, 정적 HTML이라 바로 서빙됨).

배포 후 두 개의 URL이 생깁니다.
- `https://your-domain/cirkadian_jetlag_test.html` → 이 URL을 `SURVEY_URL`에 넣고, QR로 인쇄/전시
- `https://your-domain/cirkadian_globe.html` → 부스 모니터 브라우저에서 이 URL을 전체화면으로 열기

## 4. 당일 운영

- 모니터 페이지(`cirkadian_globe.html`)를 열면 화면 우측 하단에 설문 페이지로 연결되는 QR이 자동으로 뜹니다. 이 QR을 방문자가 스캔하면 됩니다. (원하면 이 QR을 따로 캡처해서 배너/스탠드에 인쇄해도 됩니다)
- 방문자가 설문을 마치면 몇 초 안에 모니터의 지구본에 핀이 찍히고 랭킹이 갱신됩니다.
- 테스트가 필요하면 모니터 URL 뒤에 `?demo=1`을 붙이면 가짜 데이터로 자동 채워지는 테스트 버튼/타이머가 나타납니다. **실제 행사 중에는 `?demo=1` 없이** 여세요 (없으면 실제 데이터만 표시됩니다).

## 5. 익명성 / 연구 데이터

- 이름, 연락처, 기기 정보는 어떤 테이블에도 저장하지 않습니다.
- `research_responses`에는 취침/기상 시각(분 단위), 6개 설문 응답, 계산된 사회적 시차·크로노타입·수면 점수만 저장됩니다.
- 이 테이블은 anon 키로는 insert만 가능하고 조회는 불가능합니다. 나중에 연구용으로 데이터를 내려받을 때는 Supabase 대시보드(Table Editor) 또는 `service_role` 키로 접근하세요. `service_role` 키는 절대 프론트엔드 코드에 넣지 마세요.
- `board_events`는 모니터 표시용으로 도시값·시차값만 공개돼 있어 개인 식별이 불가능합니다.

## 로컬 테스트 (Supabase 연결 없이)

두 파일을 그냥 로컬에서 열면(`SUPABASE_URL`을 채우지 않은 상태) `supa`가 `null`이 되어 저장은 스킵되고, 같은 브라우저 내에서는 기존 `BroadcastChannel` 방식으로 설문 결과가 모니터 탭에 반영됩니다 (개발용, 다른 기기 간에는 동작하지 않음).
