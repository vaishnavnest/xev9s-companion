## Summary
<!-- Brief description of what this PR does and why. -->

## Component
- [ ] Frontend (`frontend/xev9s_app/`)
- [ ] Backend (`backend/`)
- [ ] Simulator (`simulator/`)
- [ ] Infrastructure / DevOps (`.github/`, `infrastructure/`, `docker*`)
- [ ] Documentation (`docs/`)

**PRD / Use Case reference:** <!-- e.g. UC-01, Workflow 2 CI -->

## Type of Change
- [ ] New feature
- [ ] Bug fix
- [ ] Refactor / clean-up
- [ ] Tests
- [ ] DevOps / CI/CD / Containerization
- [ ] Documentation

---

## Verification

### Frontend (if changed)
- [ ] `flutter analyze` — 0 errors / 0 warnings
- [ ] `flutter test --coverage` — coverage >= 70%

### Backend / Simulator (if changed)
- [ ] `ruff check .` — 0 issues
- [ ] No Python file exceeds 200 lines
- [ ] `pytest --cov=app --cov-fail-under=70` — coverage >= 70%

### Manual
- [ ] Tested locally (mock server / local backend / Docker)
- [ ] Screenshots or logs attached where relevant

---

## Security
- [ ] No secrets, tokens, or credentials committed
- [ ] New dependencies are pinned and audited
- [ ] Gitleaks, Semgrep, and Trivy criteria met

---

## Pre-Merge
- [ ] Target branch is correct (`dev` for features, `main` for releases)
- [ ] PR title follows Conventional Commits (`feat:`, `fix:`, `chore:`, `ci:`, `test:`)
- [ ] All `Mandatory CI Gate` checks passed
