-- ============================================================
-- KMS Project — PostgreSQL Database Schema
-- Generated: 2026-05-18
-- Django apps: users, clients, devices, requests,
--              certificates, logs, otp, tokens
-- ============================================================

-- Enable UUID extension (agar kerak bo'lsa)
-- CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- Django built-in auth tables (auth app)
-- ============================================================

CREATE TABLE IF NOT EXISTS auth_permission (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(255)  NOT NULL,
    content_type_id INTEGER   NOT NULL,
    codename    VARCHAR(100)  NOT NULL,
    UNIQUE (content_type_id, codename)
);

CREATE TABLE IF NOT EXISTS auth_group (
    id   SERIAL PRIMARY KEY,
    name VARCHAR(150) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS auth_group_permissions (
    id            BIGSERIAL PRIMARY KEY,
    group_id      INTEGER NOT NULL REFERENCES auth_group(id)      ON DELETE CASCADE,
    permission_id INTEGER NOT NULL REFERENCES auth_permission(id) ON DELETE CASCADE,
    UNIQUE (group_id, permission_id)
);

-- ============================================================
-- users app
-- ============================================================

CREATE TABLE IF NOT EXISTS user_users (
    id                      BIGSERIAL    PRIMARY KEY,
    password                VARCHAR(128) NOT NULL,
    last_login              TIMESTAMPTZ,
    is_superuser            BOOLEAN      NOT NULL DEFAULT FALSE,
    username                VARCHAR(150) NOT NULL UNIQUE,
    first_name              VARCHAR(150) NOT NULL DEFAULT '',
    last_name               VARCHAR(150) NOT NULL DEFAULT '',
    email                   VARCHAR(254) NOT NULL DEFAULT '',
    is_staff                BOOLEAN      NOT NULL DEFAULT FALSE,
    is_active               BOOLEAN      NOT NULL DEFAULT TRUE,
    date_joined             TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

    -- custom fields
    role                    VARCHAR(32)  NOT NULL DEFAULT 'user'
                                CHECK (role IN ('admin', 'limited_admin', 'user', 'operator')),
    mfo                     VARCHAR(128) NOT NULL DEFAULT '',
    failed_login_attempts   SMALLINT     NOT NULL DEFAULT 0 CHECK (failed_login_attempts >= 0),
    locked_until            TIMESTAMPTZ,

    -- added in migration 0004
    branch                  VARCHAR(255) NOT NULL DEFAULT '',
    count                   SMALLINT     NOT NULL DEFAULT 3  CHECK (count >= 0),
    crobs                   BOOLEAN,
    iabs                    BOOLEAN      NOT NULL DEFAULT FALSE,
    ibank                   BOOLEAN      NOT NULL DEFAULT FALSE,
    joyda                   BOOLEAN,
    mbank                   BOOLEAN      NOT NULL DEFAULT FALSE,
    metin                   VARCHAR(255),
    parent_id               INTEGER      NOT NULL DEFAULT 0,
    status                  SMALLINT     NOT NULL DEFAULT 0
                                CHECK (status IN (0, 1)),   -- 0=Inactive, 1=Active
    token_count             INTEGER      NOT NULL DEFAULT 0,
    verified_token_count    INTEGER      NOT NULL DEFAULT 0,

    -- added in migration 0006
    avatar                  VARCHAR(255)                         -- ImageField -> file path
);

-- M2M: user <-> group
CREATE TABLE IF NOT EXISTS user_users_groups (
    id       BIGSERIAL PRIMARY KEY,
    user_id  BIGINT  NOT NULL REFERENCES user_users(id)  ON DELETE CASCADE,
    group_id INTEGER NOT NULL REFERENCES auth_group(id)  ON DELETE CASCADE,
    UNIQUE (user_id, group_id)
);

-- M2M: user <-> permission
CREATE TABLE IF NOT EXISTS user_users_user_permissions (
    id            BIGSERIAL PRIMARY KEY,
    user_id       BIGINT  NOT NULL REFERENCES user_users(id)     ON DELETE CASCADE,
    permission_id INTEGER NOT NULL REFERENCES auth_permission(id) ON DELETE CASCADE,
    UNIQUE (user_id, permission_id)
);

-- JWT / session tokens (users app — NOT the hardware tokens app)
CREATE TABLE IF NOT EXISTS user_tokens (
    id          BIGSERIAL    PRIMARY KEY,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    key         VARCHAR(500) NOT NULL UNIQUE,
    refresh     VARCHAR(500) NOT NULL UNIQUE,
    is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
    expires_at  TIMESTAMPTZ  NOT NULL,
    user_id     BIGINT       NOT NULL REFERENCES user_users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS user_tokens_user_id_idx ON user_tokens (user_id);

-- ============================================================
-- clients app
-- ============================================================

CREATE TABLE IF NOT EXISTS clients (
    id              BIGSERIAL    PRIMARY KEY,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    cname           VARCHAR(64)  NOT NULL,
    sname           VARCHAR(128) NOT NULL DEFAULT '',
    location        VARCHAR(64)  NOT NULL,
    state           VARCHAR(64)  NOT NULL,
    country         VARCHAR(3)   NOT NULL DEFAULT 'UZB',
    address         VARCHAR(128) NOT NULL,
    email           VARCHAR(128) NOT NULL,
    organisation    VARCHAR(128) NOT NULL,
    org_unit        VARCHAR(128) NOT NULL,
    status          INTEGER      NOT NULL DEFAULT 1
                        CHECK (status IN (0, 1)),       -- 0=Inactive, 1=Active
    inn             VARCHAR(12),
    pinfl           VARCHAR(14),
    phone           VARCHAR(16),
    password        VARCHAR(128) NOT NULL,
    fix             BOOLEAN      NOT NULL DEFAULT FALSE,
    comment         VARCHAR(256) NOT NULL DEFAULT '',
    fido_user_id    BIGINT       NOT NULL DEFAULT 0,
    fido_user_type_id BIGINT     NOT NULL DEFAULT 0,
    login           VARCHAR(255) NOT NULL DEFAULT '',
    branch_user_id  BIGINT       NOT NULL REFERENCES user_users(id) ON DELETE RESTRICT,
    operator_id     BIGINT            REFERENCES user_users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS clients_branch_user_id_idx ON clients (branch_user_id);
CREATE INDEX IF NOT EXISTS clients_operator_id_idx    ON clients (operator_id);

-- ============================================================
-- devices app
-- ============================================================

CREATE TABLE IF NOT EXISTS devices (
    id              BIGSERIAL    PRIMARY KEY,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    type            VARCHAR(128) NOT NULL DEFAULT 'epass/ikey'
                        CHECK (type IN ('epass/ikey', 'mobile', 'smartcard', 'virtual')),
    platform        VARCHAR(32)  NOT NULL DEFAULT 'windows'
                        CHECK (platform IN ('android', 'ios', 'windows')),
    device_id_type  VARCHAR(128) NOT NULL DEFAULT 'serial_number'
                        CHECK (device_id_type IN ('serial_number', 'guid', 'unid')),
    device_id_number VARCHAR(128) NOT NULL,
    is_primary      BOOLEAN      NOT NULL DEFAULT FALSE,
    status          INTEGER      NOT NULL DEFAULT 1
                        CHECK (status IN (0, 1)),       -- 0=Inactive, 1=Active
    os_version      VARCHAR(20)  NOT NULL DEFAULT '',
    model           VARCHAR(255) NOT NULL DEFAULT '',
    firebase_token  VARCHAR(255) NOT NULL DEFAULT '',
    user_id         BIGINT       NOT NULL REFERENCES clients(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS devices_user_id_idx ON devices (user_id);

-- ============================================================
-- requests app
-- ============================================================

CREATE TABLE IF NOT EXISTS requests (
    id                  BIGSERIAL    PRIMARY KEY,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    request             TEXT         NOT NULL,
    container           VARCHAR(32),
    type                SMALLINT     NOT NULL,
    file_name           VARCHAR(128) NOT NULL,
    password            VARCHAR(64),
    cng                 SMALLINT,
    status              SMALLINT     NOT NULL DEFAULT 0,
    -- migration 0003: device and user become nullable (SET_NULL)
    device_id           BIGINT           REFERENCES devices(id)  ON DELETE SET NULL,
    user_id             BIGINT           REFERENCES clients(id)  ON DELETE SET NULL,
    branch_user_id      BIGINT       NOT NULL REFERENCES user_users(id) ON DELETE RESTRICT,
    new_branch_user_id  BIGINT           REFERENCES user_users(id) ON DELETE SET NULL,
    operator_id         BIGINT           REFERENCES user_users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS requests_branch_user_id_idx     ON requests (branch_user_id);
CREATE INDEX IF NOT EXISTS requests_user_id_idx            ON requests (user_id);
CREATE INDEX IF NOT EXISTS requests_device_id_idx          ON requests (device_id);

-- ============================================================
-- certificates app
-- ============================================================

CREATE TABLE IF NOT EXISTS certificates (
    id                BIGSERIAL    PRIMARY KEY,
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    issuer            VARCHAR(128),
    cert_sn           VARCHAR(64)  NOT NULL UNIQUE,
    cert_thumb        VARCHAR(64),
    cert_from         DATE         NOT NULL,
    cert_to           DATE         NOT NULL,
    base64            TEXT         NOT NULL,
    pfx               TEXT,
    -- 0=Revoked, 1=Ready to write in token, 2=Ready to install pfx, 3=Updated, 4=Imported
    status            INTEGER      NOT NULL DEFAULT 1
                          CHECK (status IN (0, 1, 2, 3, 4)),
    rev_reason        VARCHAR(255),
    -- 0=Not pending, 1=Branch revoke request pending
    branch_rev_status INTEGER      DEFAULT 0
                          CHECK (branch_rev_status IN (0, 1)),
    file_name         VARCHAR(128),
    sync              INTEGER      NOT NULL DEFAULT 0,
    last_login        VARCHAR(64),
    revoke_date       TIMESTAMPTZ,
    request_id        BIGINT       NOT NULL REFERENCES requests(id)   ON DELETE RESTRICT,
    user_id           BIGINT       NOT NULL REFERENCES clients(id)    ON DELETE RESTRICT,
    operator_id       BIGINT           REFERENCES user_users(id)      ON DELETE SET NULL,
    branch_user_id    BIGINT       NOT NULL REFERENCES user_users(id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS certificates_request_id_idx     ON certificates (request_id);
CREATE INDEX IF NOT EXISTS certificates_user_id_idx        ON certificates (user_id);
CREATE INDEX IF NOT EXISTS certificates_branch_user_id_idx ON certificates (branch_user_id);
CREATE INDEX IF NOT EXISTS certificates_status_idx         ON certificates (status);

-- ============================================================
-- logs app
-- ============================================================

CREATE TABLE IF NOT EXISTS logs (
    id          BIGSERIAL     PRIMARY KEY,
    created_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    username    VARCHAR(128)  NOT NULL DEFAULT '',
    action      VARCHAR(128)  NOT NULL,
    comment     VARCHAR(512)  NOT NULL DEFAULT '',
    context     JSONB         NOT NULL DEFAULT '{}',
    ip_address  INET,
    actor_id    BIGINT            REFERENCES user_users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS logs_actor_id_idx   ON logs (actor_id);
CREATE INDEX IF NOT EXISTS logs_created_at_idx ON logs (created_at);

-- ============================================================
-- otp app
-- ============================================================

CREATE TABLE IF NOT EXISTS user_otp (
    id          BIGSERIAL    PRIMARY KEY,
    otp         VARCHAR(5)   NOT NULL,
    inn         VARCHAR(9),
    pinfl       VARCHAR(14),
    phone       VARCHAR(16)  NOT NULL,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ============================================================
-- tokens app  (hardware tokens — eToken, iKey, etc.)
-- ============================================================

CREATE TABLE IF NOT EXISTS tokens (
    id              BIGSERIAL    PRIMARY KEY,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    seria_number    VARCHAR(50)  NOT NULL UNIQUE,
    is_used         INTEGER      NOT NULL DEFAULT 0,
    is_attached     BOOLEAN      NOT NULL DEFAULT FALSE,
    attached_at     TIMESTAMPTZ,
    branch_user_id  BIGINT           REFERENCES user_users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS tokens_branch_user_id_idx ON tokens (branch_user_id);
CREATE INDEX IF NOT EXISTS tokens_is_used_idx        ON tokens (is_used);

-- ============================================================
-- Django system tables (migrate qilganda o'zi yaratiladi,
-- lekin to'liq standalone uchun qo'shilgan)
-- ============================================================

CREATE TABLE IF NOT EXISTS django_content_type (
    id        SERIAL       PRIMARY KEY,
    app_label VARCHAR(100) NOT NULL,
    model     VARCHAR(100) NOT NULL,
    UNIQUE (app_label, model)
);

ALTER TABLE auth_permission
    ADD CONSTRAINT IF NOT EXISTS auth_permission_content_type_id_fk
    FOREIGN KEY (content_type_id) REFERENCES django_content_type(id) ON DELETE CASCADE;

CREATE TABLE IF NOT EXISTS django_migrations (
    id      BIGSERIAL    PRIMARY KEY,
    app     VARCHAR(255) NOT NULL,
    name    VARCHAR(255) NOT NULL,
    applied TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS django_session (
    session_key  VARCHAR(40) PRIMARY KEY,
    session_data TEXT        NOT NULL,
    expire_date  TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS django_session_expire_date_idx ON django_session (expire_date);

-- ============================================================
-- END OF SCHEMA
-- ============================================================
