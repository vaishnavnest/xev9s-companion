# XEV 9S Companion Backend --- Requirements and Implementation Record

**Document:** `requirement.md`\
**Project:** XEV 9S Companion\
**Scope covered:** Backend foundation, MongoDB Atlas integration, and
user authentication/session management\
**Last updated:** 17 November 2026

------------------------------------------------------------------------

## 1. Purpose

This document records the backend requirements addressed and the
implementation work completed so far for the XEV 9S Companion project.
It distinguishes implemented and tested functionality from features that
are still planned.

The backend is being developed in Python with FastAPI. MongoDB Atlas is
the selected cloud database, accessed through PyMongo. The vehicle
simulator is a separate Python component and will be integrated with the
backend as the project progresses.

## 2. Backend architecture and technology requirements

### 2.1 Current architecture

The intended application flow is:

1.  The Flutter client sends HTTP requests to the FastAPI backend.
2.  FastAPI validates request data and executes application logic.
3.  The backend reads and writes application data in MongoDB Atlas
    through PyMongo.
4.  The backend returns structured JSON responses to the client.

The simulator is a separate Python application. Its complete integration
and messaging arrangement remain future work and must be coordinated
with the infrastructure owner.

### 2.2 Technology choices

  Area                          Selected technology
  ----------------------------- ------------------------------
  Backend language              Python
  API framework                 FastAPI
  ASGI server                   Uvicorn
  Database                      MongoDB Atlas
  MongoDB driver                PyMongo
  Request/response validation   Pydantic
  Password hashing              Argon2 through `pwdlib`
  Access-token format           JWT using HS256
  Automated tests               pytest
  Test HTTP client support      HTTPX / Starlette TestClient

### 2.3 Code and configuration constraints

-   Every application source-code file must contain no more than 200
    lines unless a documented technical justification is approved.
-   Secrets and credentials must be supplied through environment
    configuration. They must not be hardcoded or committed.
-   The root `.gitignore`, repository-wide documentation, CI/CD,
    infrastructure and deployment configuration are owned by the DevOps
    teammate. Backend changes must not take ownership of those files
    without coordination.
-   Feature work is organized in separate Git branches and should be
    committed in focused, reviewable changes.
-   Only relevant file paths should be staged for a commit; avoid
    `git add .`.

## 3. Database requirements and setup completed

### 3.1 MongoDB Atlas

MongoDB Atlas was selected as the cloud database.

The following setup has been completed:

-   Atlas cluster created for the project.
-   Application database created with the name `Xev9s_db`.
-   Collections created:
    -   `users`
    -   `sessions`
-   A dedicated backend database user was configured with `readWrite`
    access scoped to `Xev9s_db`.
-   A network access entry was configured for the development
    environment.
-   The backend connection is configured through environment variables.
-   The backend successfully connected to Atlas, and the database health
    check returned:

``` json
{
  "database": "connected"
}
```

### 3.2 Database security and indexes

-   Database credentials and the MongoDB connection URI must remain
    outside source control.
-   The application creates a unique ascending index on `users.email`,
    named `uq_users_email`.
-   The application creates a unique ascending index on
    `sessions.refresh_token_hash`, named `uq_sessions_refresh_token`.
-   Email addresses are normalized by trimming whitespace and converting
    to lowercase before storage and lookup.

## 4. Backend foundation completed

The initial FastAPI application foundation was created and locally run
using Uvicorn.

The application health endpoint was tested and returned:

``` json
{
  "status": "healthy"
}
```

The application lifespan manages database initialization and shutdown:

-   Connect to MongoDB Atlas when the application starts.
-   Ensure required database indexes exist.
-   Close the database connection when the application shuts down.

The database health check was also verified against the live Atlas
connection.

## 5. User authentication and session management requirements

The first backend feature is user authentication and session management.

### 5.1 User registration

**Endpoint:** `POST /auth/register`

Requirements and implemented behavior:

-   Accept a user's full name, email, password and password
    confirmation.
-   Validate the full name length (2--80 characters).
-   Validate the email using Pydantic `EmailStr`.
-   Enforce password length of 8--128 characters.
-   Reject registration if the password and confirmation do not match.
-   Normalize the email address before checking or storing it.
-   Reject an email address that already belongs to an account.
-   Hash the password using Argon2 before persistence.
-   Store the user record in MongoDB; never store the plaintext
    password.
-   Return public user information without returning the password hash.

The stored user document includes:

-   MongoDB document ID
-   Normalized email
-   Full name
-   Argon2 password hash
-   Account active status
-   Creation timestamp
-   Update timestamp

**Verification completed:** A test account was successfully registered
through the FastAPI Swagger interface, and its user document was
observed in the Atlas `users` collection.

### 5.2 User login

**Endpoint:** `POST /auth/login`

Requirements and implemented behavior:

-   Accept email and password credentials.
-   Find the account using the normalized email address.
-   Verify the submitted password against the stored Argon2 hash.
-   Reject invalid credentials with a generic authentication error.
-   Reject inactive accounts.
-   On successful login, issue a short-lived access token and a refresh
    token.
-   Persist only the hash of the refresh token in the database.

### 5.3 Access-token requirements

-   Access tokens are JWTs signed using HS256.
-   The JWT secret is loaded from environment configuration.
-   The configured secret must be present and at least 32 characters
    long.
-   Access tokens contain the subject (`sub`), issued-at (`iat`), expiry
    (`exp`) and token type (`type`) claims.
-   The token type must be `access`.
-   The configured access-token lifetime defaults to 15 minutes.
-   Invalid, expired, tampered or wrong-type tokens must be rejected.

### 5.4 Refresh-token requirements

-   Refresh tokens are generated using a cryptographically secure random
    generator.
-   Refresh tokens are opaque tokens, not JWTs.
-   Only a SHA-256 hash of a refresh token is stored in MongoDB.
-   The default refresh-session lifetime is seven days and is
    configurable through environment settings.
-   A valid refresh token can be exchanged for a new access token and a
    new refresh token.
-   Refresh-token rotation is performed atomically against the session
    record.
-   When a token is rotated, its hash is retained in
    `rotated_token_hashes`.
-   A previously rotated token must not be accepted again.
-   Reuse of an old refresh token triggers revocation of the associated
    session.
-   Once the session is revoked, its current refresh token must also be
    rejected.
-   Expired, unknown and revoked refresh tokens must be rejected.

### 5.5 Session persistence

The `sessions` collection stores session information including:

-   User ID
-   Current refresh-token hash
-   Previously rotated refresh-token hashes
-   Session creation timestamp
-   Expiration timestamp
-   Revocation timestamp, or `null` while active

The session repository supports creating sessions, looking up
refresh-token hashes, finding active sessions, rotating refresh tokens
and revoking sessions.

### 5.6 Logout

**Endpoint:** `POST /auth/logout`

Requirements and implemented behavior:

-   Accept the refresh token associated with the session.
-   Hash the supplied token before database lookup.
-   Revoke the matching active session.
-   Return success only when a session is actually revoked.
-   Reject invalid, expired or already-revoked sessions.

**Live verification completed:** Logout succeeded through the API. The
corresponding Atlas session document showed a non-null `revoked_at`
timestamp. Reusing that revoked refresh token returned HTTP 401.

### 5.7 Current-user profile

**Endpoint:** `GET /auth/me`

Requirements and implemented behavior:

-   Require a bearer access token.
-   Decode and validate the access token.
-   Load the user record from MongoDB using the token subject.
-   Reject missing, invalid or expired tokens.
-   Reject users who do not exist or are inactive.
-   Return public user information only.

### 5.8 Authentication endpoints summary

  -----------------------------------------------------------------------
  Method                  Endpoint                Purpose
  ----------------------- ----------------------- -----------------------
  POST                    `/auth/register`        Register a new user

  POST                    `/auth/login`           Authenticate and issue
                                                  tokens

  POST                    `/auth/refresh`         Rotate refresh token
                                                  and issue a new access
                                                  token

  POST                    `/auth/logout`          Revoke the active
                                                  session

  GET                     `/auth/me`              Retrieve the
                                                  authenticated user's
                                                  profile
  -----------------------------------------------------------------------

## 6. Input and response schemas

Pydantic schemas have been implemented for:

-   User registration
-   User login
-   Public user response
-   Token response
-   Refresh-token request

The schemas validate request data and define the public response shape.
Password hashes and raw database credentials must not be exposed in API
responses.

## 7. Automated testing completed

Tests are implemented under `backend/tests/`.

  -----------------------------------------------------------------------
  Test file                           Coverage
  ----------------------------------- -----------------------------------
  `test_auth.py`                      Registration, password mismatch,
                                      login, incorrect credentials,
                                      refresh, logout and profile
                                      behavior

  `test_auth_dependency.py`           Valid JWT, missing JWT, invalid JWT
                                      and inactive-user authentication

  `test_refresh_security.py`          Successful refresh, refresh-token
                                      replay detection, concurrent
                                      refresh failure, expired token and
                                      revoked session
  -----------------------------------------------------------------------

**Latest test command:**

``` powershell
python -m pytest backend\tests -v
```

**Latest recorded result:**

``` text
16 passed in 0.58s
```

The automated tests use mocks for database-dependent behavior; they do
not represent 16 independent live Atlas integration tests.

### 7.1 Live behavior verified against MongoDB Atlas

The following behavior was also checked manually through the running API
and Atlas:

-   Database connection succeeded.
-   User registration created a user document.
-   Login issued access and refresh tokens.
-   Logout updated the session's `revoked_at` field.
-   A revoked refresh token was rejected with HTTP 401.
-   Refresh-token rotation updated the current token hash and recorded
    the old token hash.
-   Replaying the old refresh token was rejected.
-   The replay caused the session's `revoked_at` field to become
    non-null.
-   The new refresh token from that same session was then rejected with
    HTTP 401 and the message `Session has been revoked`.

Do not include real passwords, access tokens, refresh tokens, token
hashes, database passwords or full connection strings in reports, source
control or screenshots.

## 8. Code quality and Git status

### 8.1 Source-file length

A PowerShell check was run over Python files under `backend/app`. It
produced no output for files exceeding 200 lines. Therefore, all
application Python files checked at that point met the 200-line limit.

### 8.2 Authentication feature commit

Authentication work was committed on:

`feature/user-authentication`

Commit:

``` text
27adabd Implement user authentication and session management
```

The commit contains 15 authentication-related files, including
application code and tests.

The root `.gitignore` had a separate uncommitted modification at the
time of the commit. It was deliberately not staged because
repository-wide ignore configuration is owned by the DevOps teammate.

## 9. Project functionality not yet implemented

The following areas are part of the wider backend/simulator scope but
are not claimed as completed by this document:

1.  Vehicle association and retrieval.
2.  Canonical simulator vehicle state and valid state transitions.
3.  Telemetry generation and ingestion.
4.  Latest vehicle state and telemetry history.
5.  Online/offline connectivity monitoring.
6.  Remote vehicle command processing and command lifecycle.
7.  Charging preferences, schedules and charging-session lifecycle.
8.  Vehicle location management.
9.  Trip detection, recording and completion.
10. Driving and energy analytics.
11. Vehicle events and notification management.
12. Historical vehicle data retrieval.
13. Report generation and retrieval.
14. Demonstration scenario management.
15. End-to-end integration with the Flutter client and simulator.
16. Full integration, performance, security and deployment verification.

These features must be implemented and tested in their planned feature
branches before they can be marked complete.

## 10. Acceptance criteria for the completed authentication feature

The authentication feature is considered implemented and verified
against the current scope because:

-   [x] Registration validates input and password confirmation.
-   [x] Duplicate email registration is rejected.
-   [x] Passwords are stored as Argon2 hashes.
-   [x] Login validates credentials and account status.
-   [x] Access JWTs are signed and validated.
-   [x] Refresh tokens are generated securely and stored as hashes.
-   [x] Refresh-token rotation works.
-   [x] Reuse of a rotated refresh token revokes its session.
-   [x] A revoked session's current refresh token is rejected.
-   [x] Logout revokes the active session.
-   [x] Authenticated profile retrieval validates the bearer token.
-   [x] The automated authentication test suite passes (16 tests).
-   [x] The checked application Python files satisfy the 200-line limit.
-   [x] Authentication implementation is committed to its feature
    branch.

## 11. Operational and security notes

-   Keep `.env` files out of Git.
-   Use separate, strong secrets for each environment.
-   Never paste credentials or bearer/refresh tokens into issue
    trackers, documentation or chat.
-   If a token or password is exposed, revoke the affected session and
    rotate the credential as appropriate.
-   Restrict Atlas network access to approved development or deployment
    sources.
-   Coordinate database access, MQTT decisions, infrastructure, CI/CD
    and deployment with the DevOps teammate.
-   Do not claim deployment readiness based solely on local API and
    database tests.

------------------------------------------------------------------------

**Document status:** Records the backend foundation, Atlas connection
and authentication/session-management work completed and verified as of
17 November 2026. It is an implementation record and current-scope
requirements document, not a claim that the full XEV 9S backend is
complete.
