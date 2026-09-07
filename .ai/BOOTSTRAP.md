# Bootstrap — 템플릿을 실제 프로젝트로 초기화

<!-- 새 프로젝트를 시작할 때 한 번 수행하는 절차다. 초기화가 끝나면 이 파일을 삭제한다. -->

너는 이 프로젝트의 초기 구조를 설계하는 Software Architect이자 AI Agent Workflow Designer다.

이 저장소는 여러 개발자가 각자 AI Agent와 함께 동시에 작업하기 위한 팀 템플릿에서 생성되었다. 작업 규칙은 `AGENTS.md`에 있고, 각 문서의 작성 지침은 문서 안의 `<!-- -->` 주석에 있다. 아래 Project Description을 바탕으로 템플릿을 실제 프로젝트로 바꿔라. 이 파일이 있는 동안은 `scripts/ai-start.sh`의 `ws/*` 검사가 꺼져 있지만, 팀이라면 `scripts/ai-stream.sh open chore bootstrap --touches .` 로 스트림을 열고 PR로 남기는 편이 낫다.

## Project Description

<여기에 프로젝트 설명을 입력한다: 무엇을 만드는지, 누구를 위한 것인지, 핵심 기능, 기술 스택(정해졌다면), 저장소 구성(단일 패키지 / backend·frontend·db·infra 등), 제약, 일정, 이미 결정된 사항.>

## Procedure

1. `AGENTS.md`를 읽는다. 그 규칙은 이 절차에도 적용된다 (특히 Rule 4 Changes, 6 Scope, 9 Commits, 15 Streams).
2. Project Description을 읽는다. 부족한 정보는 **합리적인 최소 가정**으로 채우되, 모든 가정을 `.ai/HANDOFF.md`의 Unverified Assumptions에 기록한다. 스택·저장소 구성·배포 형태처럼 프로젝트 방향을 좌우하는 가정은 사용자에게 먼저 묻는다.
3. 저장소 구성과 제약 층을 정한다 — 아래 **Stack Constraints** 절차를 따른다 (Layout → Preset → AGENTS.md → PLAN T3 구체화).
4. 다음 파일의 placeholder(`<...>`)와 작성 지침 주석을 프로젝트 내용으로 교체한다.
   - `AGENTS.md` — Project, Repository Map, Commands, Rule 13의 언어별 규칙 (Stack Constraints에서 정한 대로)
   - `README.md` — 템플릿 소개를 프로젝트 소개(무엇을·왜·실행 방법)로 교체
   - `docs/PRD.md` — 요구사항 (ID 부여)
   - `docs/ARCHITECTURE.md` — 초기 구조. Module Boundaries 표의 Owner 열에 구성요소별 담당(GitHub 핸들 또는 이메일)을 적는다 — 소유권의 SSoT이며 `ai-stream.sh codeowners`가 CODEOWNERS를 만든다. 구성요소가 여럿이면 디렉터리별 책임·경계를 적는다 (미확정 부분은 "TBD (ADR-… 예정)")
   - `docs/api/openapi.yaml` — REST API가 있으면 초기 계약, 없으면 `docs/api/` 삭제 후 참조 제거
5. 스택·핵심 구조 결정을 `docs/decisions/ADR-YYYYMMDD-<slug>.md`로 기록한다 (`_template.md` 사용; 기존 ADR은 이 템플릿의 협업 구조 결정이므로 유지). 사소한 결정은 ADR로 만들지 않는다.
6. `docs/phases/01-project-setup/PLAN.md`를 프로젝트에 맞게 조정하고(Lead·Task별 Touches 포함), 전체 개발 계획을 Phase로 나눈다 — `docs/phases/NN-<name>/PLAN.md` 머리(Status·Lead·Depends on)를 채우면 `scripts/ai-stream.sh phases`가 `docs/phases/README.md` 표를 만든다. 처음 2~3개 Phase만 상세 PLAN을 쓰고 나머지는 머리만 둔다. 병렬로 진행할 Phase는 Depends on을 정확히 적는다.
7. 프로젝트 성격상 불필요한 파일은 삭제한다. 필요한 spec(DB 스키마, 이벤트 스키마, UI 스펙 등)이 있으면 `docs/` 아래에 추가하고 `AGENTS.md`의 Repository Map과 Rule 2 우선순위에 반영한다. 중복된 정보원을 만들지 않는다.
8. 아래 **Team Setup**을 수행한다. 그다음 이 파일(`.ai/BOOTSTRAP.md`)을 삭제하고, `README.md`·Phase 01 PLAN에서 BOOTSTRAP 참조를 제거한다.
9. 작업 커밋을 남긴다: `chore(ai): bootstrap project from template` (Commit Format대로 `Agent:`·`Task: 01/T1` trailer 포함 — 훅이 `Stream:`을 붙인다).
10. 스트림에서 작업했다면 `AGENTS.md`의 Session Procedure(종료)대로 끝내고 `scripts/ai-end.sh --ready`로 PR을 낸다. main에서 직접 했다면(개인 프로젝트) 커밋 후 `scripts/ai-stream.sh phases`·`announce`를 한 번 실행해 파생 파일을 맞춘다.

## Output Checklist

- [ ] `AGENTS.md`에 placeholder와 작성 지침 주석이 없다 (Stack, Repository Map, Commands, Rule 13 언어 규칙 포함)
- [ ] 저장소 구성이 실제 디렉터리·Repository Map·ARCHITECTURE Module Boundaries에서 일치한다 (루트 `src/`·`tests/`는 단일 패키지일 때만 남긴다)
- [ ] `docs/PRD.md`, `docs/ARCHITECTURE.md`가 Project Description과 모순되지 않는다
- [ ] 스택 ADR에 도구 선택 이유와 도입 금지 항목(허용 언어 목록)이 있다
- [ ] Phase 01 PLAN의 T3에 설정 파일·버전 고정·lockfile·`.gitignore` 항목이 구체적으로 적혀 있다
- [ ] 모든 가정이 `.ai/HANDOFF.md`의 Unverified Assumptions에 있다
- [ ] Phase PLAN들의 머리(Status·Lead·Depends on)가 채워졌고 `docs/phases/README.md` 표가 `scripts/ai-stream.sh phases` 출력과 같다
- [ ] `docs/ARCHITECTURE.md` Module Boundaries에 Owner 열이 있고 `.github/CODEOWNERS`가 그것과 일치한다 (GitHub 사용 시)
- [ ] Team Setup의 항목이 모두 끝났다 (또는 개인 프로젝트로 N/A 표시)
- [ ] `.ai/BOOTSTRAP.md`가 삭제되었고 남은 참조가 없다
- [ ] `scripts/ai-end.sh`(스트림) 또는 `scripts/ai-end.sh --ci`(main)가 통과했다

---

## Team Setup — 팀 저장소 설정 (리드가 한 번)

<!-- 개인 프로젝트면 이 절은 건너뛰고 Output Checklist에 N/A로 표시한다. 전략 자체는 ADR-20260907-git-strategy-and-two-audiences.md가 정하고, 여기서는 집행한다. -->

1. **저장소 설정** — `scripts/ai-stream.sh setup` 을 실행한다. `gh`가 있으면 적용하고 없으면 체크리스트를 출력한다:
   - main 보호: PR로만 변경, 상태 검사(`ai-check`, Commands) 필수, 직접 push 금지
   - 병합 방식: merge commit만 허용 (squash·rebase-merge 비활성), 병합 메시지 = "PR 제목 + 본문" (`merge_commit_title=PR_TITLE`, `merge_commit_message=PR_BODY`)
   - 병합 후 head 브랜치 자동 삭제
2. **CODEOWNERS** — `docs/ARCHITECTURE.md` Module Boundaries의 Owner 열을 채운 뒤 `scripts/ai-stream.sh codeowners` 로 `.github/CODEOWNERS`를 생성한다. `docs/`의 owner는 리드(spec 변경 PR에 항상 리뷰가 붙는다).
3. **CI** — `.github/workflows/ci.yml`의 Commands 4개를 `AGENTS.md` Commands와 같게 채운다. `ai-end.sh --ci`는 이미 연결되어 있다. flow 역할 워크플로(`flow.yml`)는 기본 꺼짐 — 조직의 Claude Code Action 설정과 API 키가 준비되면 켠다.
4. **팀원 안내** — 각자 clone 후 `scripts/ai-stream.sh setup --local` (훅 경로 · 커밋 템플릿 · `git ai-log` alias · `.ai/local/`). Agent CLI를 쓸 때 `AI_AGENT=<이름>` 환경변수를 두라고 알린다.
5. **Touches 작성 지침** — PLAN의 Task마다 `Touches:`를 경로 접두(`backend/auth/`)와 spec 조각(`docs/api/openapi.yaml#/auth`)으로 적는다. 구성요소별 분담이면 구성요소 디렉터리, 기능별 분담이면 파일 단위로 좁게. 겹침은 `ai-stream.sh open`이 경고한다.
6. **첫 공지** — 팀 전체가 알아야 할 초기 결정(스택·구성·규칙)이 있으면 `.ai/team/announcements/`에 하나 남긴다(`_template.md`).

---

## Stack Constraints — 제약 층 구성

<!-- 제약은 문서가 아니라 실행 가능한 도구로 건다. 충족해야 할 계약은 Phase 01 PLAN의 AC2·AC6·AC7이고(경고 없이 통과, 버전 고정·lockfile·설정 파일 커밋, 언어 규칙·허용 목록), 도구 선택은 자유다. 아래 프리셋은 출발점이며 프로젝트에 맞게 바꾼다. -->

### Procedure

1. **Layout** — 저장소 구성을 정한다.
   - 단일 패키지: 루트 `src/`·`tests/`를 그대로 쓴다.
   - 구성요소가 여럿(backend / frontend / db / infra 등): 루트 `src/`·`tests/`를 삭제하고 구성요소별 최상위 디렉터리를 만든다. 각 구성요소는 자기 언어의 관례(`backend/src`, `frontend/src`, `db/migrations`, `infra/terraform`)를 따르고 도구 설정을 자기 디렉터리에 둔다. `AGENTS.md` Repository Map의 `src/`·`tests/` 줄을 구성요소 목록으로 바꾸고, `docs/ARCHITECTURE.md` Module Boundaries에 디렉터리별 책임과 허용되는 의존 방향을 적는다. Commands는 Polyglot 절대로 묶는다.
2. **Preset** — 언어·런타임을 확정한다(미정이면 사용자에게 묻는다). 가장 가까운 프리셋을 고르고 프로젝트 사정(기존 코드, 팀 관행, 플랫폼)에 맞게 도구를 바꾼다. 바꾼 이유는 스택 ADR에 적는다.
3. **AGENTS.md** — Project.Stack 한 줄, Commands 표(구성요소가 여럿이면 Makefile/justfile 타깃), Rule 13 뒤에 언어별 규칙 ≤ 3줄. 도구가 잡지 못하는 것만 규칙으로 쓰고, 마지막 줄은 허용 언어 목록으로 한다 (예: "허용: Python(backend), TypeScript(frontend), HCL(infra). 그 외 도입은 ADR").
4. **PLAN T3 구체화** — 만들 설정 파일, 버전 고정 파일, lockfile, `.gitignore` 항목, 경고=실패 옵션을 Phase 01 PLAN T3에 목록으로 적는다. 실제 설치·실행·검증은 T3에서 한다. 표만 채우고 실행했다고 적지 않는다.
5. 타입 시스템이 약한 언어는 **Weak types**, 구성요소가 여럿이면 **Polyglot** 절을 적용한다.

### Presets

형식 — Commands(install / test / typecheck / lint+format / run) · 버전 고정과 lockfile · 설정(경고=실패) · `.gitignore` · Rule 13 예시.

**Python**
- Commands: `uv sync` / `uv run pytest` / `uv run mypy .` (또는 `uv run pyright`) / `uv run ruff check . && uv run ruff format --check .` / `uv run python -m <package>`
- 고정: `.python-version`, `uv.lock` (pip라면 `requirements.txt` + `pip-compile`)
- 설정: `pyproject.toml` — `[tool.mypy] strict = true`, `[tool.ruff.lint] select = ["E","F","I","B","UP"]`, `[tool.pytest.ini_options]`
- `.gitignore`: `__pycache__/`, `.venv/`, `.mypy_cache/`, `.ruff_cache/`, `.pytest_cache/`, `dist/`
- Rule 13 예시: 새 모듈은 mypy strict 통과 · 외부 입력은 pydantic 모델로 검증 · 예외는 도메인 예외로 감싼다

**TypeScript / Node**
- Commands: `npm ci` / `npm test` / `npx tsc --noEmit` / `npx eslint . && npx prettier --check .` / `npm start`
- 고정: `.nvmrc`, `package-lock.json` (pnpm이면 `pnpm-lock.yaml` + `package.json`의 `packageManager`)
- 설정: `tsconfig.json` — `"strict": true`, `"noUncheckedIndexedAccess": true`; `eslint.config.js`, `.prettierrc`
- `.gitignore`: `node_modules/`, `dist/`, `.next/`, `coverage/`
- Rule 13 예시: `any` 금지(불가피하면 `unknown` + 좁히기) · 런타임 경계는 zod로 검증 · ESM만 사용

**Go**
- Commands: `go mod download` / `go test ./...` / `go build ./... && go vet ./...` / `test -z "$(gofmt -l .)" && staticcheck ./...` (또는 `golangci-lint run`) / `go run ./cmd/<app>`
- 고정: `go.mod`의 `go`·`toolchain` 지시자, `go.sum`
- 설정: `.golangci.yml` (사용 시). 컴파일이 곧 typecheck라 별도 설정 없음
- `.gitignore`: `bin/`, `*.test`, `coverage.out`
- Rule 13 예시: 에러는 `fmt.Errorf("...: %w", err)`로 감싸 반환 · 패키지 간 순환 금지 · 구현은 `internal/` 아래에만

**Rust**
- Commands: `cargo fetch` / `cargo test` / `cargo check --all-targets` / `cargo clippy --all-targets -- -D warnings && cargo fmt --check` / `cargo run`
- 고정: `rust-toolchain.toml`, `Cargo.lock`
- 설정: `Cargo.toml` `[lints]`, `clippy.toml`, `rustfmt.toml`
- `.gitignore`: `target/`
- Rule 13 예시: `unwrap()`은 테스트에서만 · 공개 API는 `thiserror` 기반 에러 타입 · `unsafe`는 ADR 없이 금지

**Java / Kotlin (Gradle)**
- Commands: `./gradlew assemble` / `./gradlew test` / `./gradlew compileJava compileTestJava` (Kotlin: `compileKotlin compileTestKotlin`) / `./gradlew spotlessCheck checkstyleMain` (Kotlin: `ktlintCheck detekt`) / `./gradlew run`
- 고정: `gradle/wrapper/gradle-wrapper.properties`, `.tool-versions` 또는 `.sdkmanrc`(JDK), `gradle.lockfile` (`dependencyLocking`)
- 설정: `build.gradle(.kts)` — Java `options.compilerArgs += ["-Xlint:all", "-Werror"]`, Kotlin `allWarningsAsErrors = true`; `config/checkstyle/`, `detekt.yml`
- `.gitignore`: `build/`, `.gradle/`, `out/`, `*.class`
- Rule 13 예시: null 대신 Optional/nullable 타입 명시 · 계층 간 DTO 변환은 mapper에서만 · 정적 가변 상태 금지

**C# / .NET**
- Commands: `dotnet restore` / `dotnet test` / `dotnet build -warnaserror` / `dotnet format --verify-no-changes` / `dotnet run --project src/<App>`
- 고정: `global.json`(SDK), `packages.lock.json` (`RestorePackagesWithLockFile`)
- 설정: `Directory.Build.props` — `<Nullable>enable</Nullable>`, `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>`, `<EnforceCodeStyleInBuild>true</EnforceCodeStyleInBuild>`; `.editorconfig`의 분석기 규칙
- `.gitignore`: `bin/`, `obj/`, `*.user`
- Rule 13 예시: nullable 억제 연산자(`!`) 금지 · async 메서드는 `Async` 접미사 + CancellationToken · 서비스는 DI 컨테이너로만 생성

**Ruby**
- Commands: `bundle install` / `bundle exec rspec` / `bundle exec srb tc` (Sorbet 미도입 시 `N/A — Weak types 절 적용`) / `bundle exec rubocop` / `bundle exec rails server` 등
- 고정: `.ruby-version`, `Gemfile.lock`
- 설정: `.rubocop.yml`, `sorbet/config`
- `.gitignore`: `tmp/`, `log/`, `.bundle/`, `coverage/`
- Rule 13 예시: 경계 입력은 dry-schema로 검증 · `method_missing`·`define_method` 금지 · 새 파일은 `# typed: strict`

**Dart / Flutter**
- Commands: `dart pub get` (Flutter: `flutter pub get`) / `dart test` (`flutter test`) / `dart analyze --fatal-infos` / `dart format --set-exit-if-changed .` / `flutter run`
- 고정: `pubspec.lock`, `pubspec.yaml`의 `environment.sdk`, `.fvmrc`(FVM 사용 시)
- 설정: `analysis_options.yaml` — `include: package:flutter_lints/flutter.yaml`, `analyzer.language: strict-casts, strict-raw-types, strict-inference`
- `.gitignore`: `.dart_tool/`, `build/`, `.flutter-plugins*`
- Rule 13 예시: 위젯과 상태 로직 분리(상태 관리 라이브러리는 한 가지) · `dynamic` 금지 · 플랫폼 채널 코드는 `platform/` 아래에만

**DB (migrations, 구성요소)**
- Commands: install `N/A` / test `<마이그레이션 도구> upgrade head` + 롤백을 임시 DB(컨테이너)에서 실행 / typecheck `N/A — 스키마가 spec` / lint `sqlfluff lint db/` (또는 ORM의 schema validate) / run `N/A`
- 고정: 마이그레이션 도구 버전은 소속 언어의 lockfile로, DB 엔진 버전은 `docker-compose.yml`·`infra/`에 고정
- 규칙 예시: 스키마 변경은 마이그레이션 파일로만(수동 DDL 금지) · 마이그레이션은 되돌릴 수 있어야 함 · `docs/`의 스키마 문서(있다면)와 같은 커밋에서 갱신

**Infra (Terraform / Kubernetes, 구성요소)**
- Commands: `terraform init -backend=false` / `terraform validate` (+ 가능하면 `terraform plan` 을 CI에서) / typecheck `N/A` / `terraform fmt -check -recursive && tflint` (k8s: `kubeconform -strict`) / run `N/A`
- 고정: `required_version`, `.terraform.lock.hcl`, provider 버전 고정
- 규칙 예시: 상태 파일·시크릿 커밋 금지 · 리소스 변경은 `plan` 출력을 HANDOFF에 요약 · 수동 콘솔 변경 금지(드리프트는 코드로 수정)

### Weak types — 타입 시스템이 약한 언어

typecheck 칸이 비면 Rule 2의 executable spec이 테스트뿐이라 제약이 헐거워진다. 가능한 것을 적용하고 ADR에 적는다.
- 새 코드에 한해 typechecker를 strict로 켠다 (mypy는 모듈 단위 점진 적용, Sorbet `# typed: strict`, JS는 `// @ts-check` + JSDoc 또는 TS 전환).
- 시스템 경계(API 입력, 설정, 외부 응답)에서 스키마 검증을 강제한다 (pydantic, zod, dry-schema, JSON Schema).
- Rule 13 줄에 "테스트 없는 코드 변경은 커밋하지 않는다"를 넣어 Rule 8을 강화한다.

### Polyglot — 구성요소가 여럿

- Commands 표를 언어별로 늘리지 않는다. 루트 `Makefile` 또는 `justfile`에 `install / test / typecheck / lint / run` 타깃을 두고 하위 구성요소 명령을 묶는다 (예: `test: test-backend test-frontend test-db`). Agent에게는 인터페이스 하나만 보인다.
- 구성요소별 도구 설정·버전 고정·lockfile은 각 디렉터리에 둔다. 루트에는 `.editorconfig`, Makefile, `.gitignore`(구성요소 항목 합침)만 둔다.
- `AGENTS.md` Repository Map에 구성요소와 책임을 한 줄씩 적고, `docs/ARCHITECTURE.md` Module Boundaries에 구성요소 간 허용 의존(예: `frontend → backend API만`, `backend → db 마이그레이션 소유`)을 적는다.
- Rule 13의 마지막 줄을 허용 목록으로 쓴다: "허용: Python(backend), TypeScript(frontend), SQL(db), HCL(infra). 그 외 도입은 ADR".
- Phase를 나눌 때 구성요소를 섞지 않는 편이 검증이 쉽다. 섞어야 하면 PLAN의 Scope에 구성요소별로 적는다.
