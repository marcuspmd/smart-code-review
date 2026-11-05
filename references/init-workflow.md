# Intelligent Agent Initialization Workflow (`/smart-code-review init`)

When the user triggers `/smart-code-review init` (or asks to "setup code review", "configure smart-code-review for this project"), the AI agent **must not merely execute a blind shell script**. Instead, the agent uses its intelligence to inspect the codebase, detect tools and linters, ask calibration questions, and generate tailored configuration, rules, and memory files.

---

## 4-Step Interactive Initialization Protocol

### Step 1: Automated Codebase Survey
Before prompting the user, the agent inspects the project root to detect:
1. **Language, Runtime & Package Manager**:
   - `composer.json` → PHP (check for Pest, PHPUnit, PHPStan, Pint)
   - `package.json` → TypeScript / Node (check for ESLint, Biome, Vitest, Jest, Prettier)
   - `pyproject.toml` / `requirements.txt` → Python (check for Ruff, Mypy, Flake8, Pytest)
   - `Cargo.toml` → Rust (Cargo test, Clippy)
   - `go.mod` → Go (go test, golangci-lint)
   - `Dockerfile` / `docker-compose.yml` → Docker / containerized environments
   - `sonar-project.properties` → SonarQube / SonarCloud presence
2. **Database & Migrations**:
   - Inspect migration folders (`database/migrations`, `prisma/migrations`, `alembic/`, `migrations/`).
3. **Existing CI/CD Workflows**:
   - Check `.github/workflows/` or `.gitlab-ci.yml` for existing test and lint scripts.

---

### Step 2: Contextualized Interview (Max 3 Direct Questions)

Present the survey findings concisely, then ask 3 targeted questions:

> *"I inspected your codebase: detected **[Framework]** with **[Test Runner]** and **[Linter/Static Analyzer]**.*
>
> *To tailor `smart-code-review` to your project, please confirm:*
> 1. **Report Language**: `pt-BR` (Português) or `en` (English)?
> 2. **Automated Tool Commands**:
>    - Test command: `[Detected test command e.g., 'npm test' or 'composer test']`?
>    - Linter command: `[Detected linter command e.g., 'npm run lint' or 'vendor/bin/phpstan']`?
> 3. **SonarQube Integration**: Is local SonarQube or SonarCloud used in this repo? (y/n)
> 4. **Git Hooks**: Would you like to install pre-commit (fast linter on staged files) and pre-push (automated test run) hooks? (y/n)"

---

### Step 3: Generate Intelligent Files

Once the user replies, the agent writes tailored files:

#### 1. `.ai/review.yml`
Customized with the actual project commands under `tools.test.commands.run` and `tools.lint.commands.run`, ignore paths based on the project layout, and the chosen language.

#### 2. `.ai/review-rules.md`
**CRITICAL**: Do NOT generate generic placeholder rules. Write rules tailored to the detected stack and conventions:
- *If Laravel*: "Ensure all database queries in Eloquent use eager loading where relationships are iterated to prevent N+1 bugs. No raw DB::statement without binding."
- *If NestJS / TypeScript*: "All DTOs must use class-validator decorators. Repositories must not be injected directly into controllers."
- *If Python / FastAPI*: "Verify all async endpoints do not call blocking synchronous I/O. Use proper dependency injection."
- *If React / Next.js*: "Ensure all interactive elements have accessible ARIA roles and keyboard event listeners. Avoid unmemoized heavy computations in render loops."

#### 3. `.ai/review-memory.md`
Pre-seed with architecture patterns, accepted conventions, and known project-specific quirks.

---

### Step 4: Hooks Setup & Next Steps

If the user agreed to Git hooks, execute:
```bash
bash scripts/install-hooks.sh
```

Conclude with a brief summary:
> *"Setup complete! Your project review profile is active. Whenever you make changes, simply say `review my changes`, `review this PR`, or use `/smart-code-review`."*
