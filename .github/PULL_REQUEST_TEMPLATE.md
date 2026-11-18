<!-- ======================================================================= -->
<!-- XEV 9S Companion Application - Pull Request Template                    -->
<!-- Required under PRD Section 4.2 (Workflow 1: Repository & Branch Mgmt)   -->
<!-- ======================================================================= -->

## 📋 Summary
<!-- Provide a clear, concise overview of what this PR does and why it is needed. -->

## 🎯 PRD Reference & Scope
- **Component(s) Modified:**
  - [ ] Frontend (`frontend/xev9s_app/`)
  - [ ] Backend (`backend/`)
  - [ ] Simulator (`simulator/`)
  - [ ] Infrastructure & DevOps (`.github/`, `infrastructure/`, `docker*`)
  - [ ] Documentation (`docs/`)
- **Use Case / Section Reference:** 
  <!-- e.g., UC-01 Auth & Vehicle Association, UC-02 Dashboard, Workflow 2 CI, etc. -->

## 🏷️ Type of Change
- [ ] 🚀 New Feature (non-breaking change adding functionality)
- [ ] 🐛 Bug Fix (non-breaking fix to existing functionality)
- [ ] ♻️ Refactoring / Clean-up (no behavior changes)
- [ ] 🧪 Tests (adding or updating unit, integration, or widget tests)
- [ ] ⚙️ DevOps / CI/CD / Containerization
- [ ] 📝 Documentation

---

## 🧪 Local Quality & Test Verification
> **All checks below must pass before requesting review / merging to `dev`.**

### Flutter Frontend (if applicable)
- [ ] `flutter analyze` completed with 0 errors / 0 warnings
- [ ] `flutter test --coverage` executed
- [ ] Line coverage meets or exceeds **70.0%** threshold

### Python Backend / Simulator (if applicable)
- [ ] `ruff check .` passed with 0 linting issues
- [ ] Maximum 200 lines per Python file rule respected
- [ ] `pytest tests --cov=app --cov-fail-under=70` executed
- [ ] Test coverage meets or exceeds **70.0%** threshold

### Integration & Manual Verification
- [ ] Tested locally (e.g. against mock server / local backend / Docker environment)
- [ ] Relevant screenshots, terminal outputs, or API responses attached (if applicable)

---

## 🛡️ Security & DevSecOps Compliance
- [ ] **No Secrets:** Verified that no tokens, credentials, API keys, or passwords are committed.
- [ ] **Dependencies:** Any newly introduced dependencies are audited and pinned.
- [ ] **Security Scans:** Changes adhere to Gitleaks, Semgrep SAST, and Trivy criteria.

---

## 🔍 Pre-Merge Checklist (Reviewer & Author)
- [ ] Targeted branch is correct (`dev` for feature branches; `main` for release branches).
- [ ] Pull Request title follows Conventional Commits format (e.g., `feat:`, `fix:`, `chore:`, `test:`).
- [ ] All automated GitHub Actions status checks (**`Mandatory CI Gate`**) passed successfully.
