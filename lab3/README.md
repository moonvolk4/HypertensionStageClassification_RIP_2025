# Lab 3 Backend (Go + Gin)

Concise project overview for frontend migration (React/Vite) and lab defense.

## Stack
- Go (Gin, GORM, Logrus)
- PostgreSQL (via GORM)
- Redis (JWT blacklist on logout)
- MinIO (object storage for images) behind Nginx (ports 9000/9001)
- Swagger UI at `/swagger` (static OpenAPI JSON at `/api/swagger.json`)

## Run Locally
- Start dependencies (Postgres, Adminer, Redis, MinIO+Nginx):
  - `docker compose up -d postgres adminer redis minio1 minio2 minio3 minio4 nginx`
- Prepare backend environment (zsh):
  - `export DB_HOST=127.0.0.1 DB_PORT=5432 DB_USER=myuser DB_PASS=mypassword DB_NAME=stagesdb`
  - Optional image URL config for templates: `export MINIO_PUBLIC_BASE=http://localhost:9000 MINIO_BUCKET=images`
- Run the server:
  - `go run ./cmd/lab2`
  - Server reads optional config from `config/config.toml` (JWT, Redis, cookie name).

## Swagger
- UI: `http://localhost:8080/swagger/index.html`
- Spec: `GET /api/swagger.json` (served from `resources/swagger/openapi.json`).
- Authorize in Swagger via Bearer token or cookie `access_token`.

## Auth & Roles
- Login issues a JWT (HS256) and sets `access_token` cookie.
- Provide auth via header `Authorization: Bearer <token>` or Cookie `access_token=<token>`.
- Logout blacklists token JTI in Redis and clears cookie.
- Roles:
  - User: can manage drafts and own records only.
  - Moderator: can manage stages and resolve any formed record.

## Database Schema (as used by the code)

### `users`
- `id` serial PK
- `login` text unique not null
- `password` text not null (bcrypt hash)
- `is_moderator` boolean not null default false

### `stages`
- `id` serial PK
- `title` text
- `description` text
- `risk_class` text not null default ''
- `image_key` text not null default ''
- `code` text (optional, used by views)
- `icon` text (optional, used by views)
- `pressure` text (optional, used by views)
- `sys_from` int not null default 0
- `sys_to` int not null default 0
- `dia_from` int not null default 0
- `dia_to` int not null default 0
- `is_deleted` boolean not null default false (soft delete)

### `records` (applications/requests)
- `id` serial PK
- `status` varchar(20) not null
  - values: `черновик`, `сформирована`, `завершена`, `отклонена`, `удалён`
- `creator_id` int not null (FK → `users.id`)
- `created_at` timestamp
- `formed_at` timestamp null
- `finished_at` timestamp null
- `moderator_id` int null (FK → `users.id`)
- `result_stage` text null (calculated stage title on approve)
- `result_map` numeric(5,2) null (calculated MAP on approve)
- Flags:
  - `flag_lv_hypertrophy` boolean not null default false
  - `flag_renal_damage` boolean not null default false
  - `flag_arterial_stiffness` boolean not null default false
- `comment` text null
- Partial unique index: one draft per user (`status='черновик'`).

### `records_stages` (m:n link between records and stages)
- `id` serial PK
- `application_id` int not null
- `order_id` int not null (stage id)
- Unique pair (`application_id`, `order_id`)
- `quantity` int not null default 1
- `doctor_comment` text null

## API Overview

Base URL: `http://localhost:8080`

### Auth
- `POST /api/users/register` → body: `{ username|login, password, is_moderator }` → 201
- `POST /api/users/login` → body: `{ username|login, password }` → 200 `{ token, user }` + cookie `access_token`
- `POST /api/users/logout` (auth) → 200
- `GET /api/users/me` (auth) → 200 `{ id, username, is_moderator }`
- `PUT /api/users/me` (auth) → body: `{ username? }` → 200

### Stages (catalog)
- `GET /api/stages` → 200 `Stage[]` (optional `?query=...`)
- `GET /api/stages/:id` → 200 `Stage`
- `POST /api/stages` (moderator) → body: `{ title, description?, risk_class?, image_key?, sys_from?, sys_to?, dia_from?, dia_to? }` → 201
- `PUT /api/stages/:id` (moderator) → body: partial update `{ title?, description? }` → 200
- `DELETE /api/stages/:id` (moderator) → soft delete (`is_deleted=true`, clears `image_key`) → 200
- `POST /api/stages/:id/image` (moderator) → body: `{ image_key }` → 200
- `POST /api/stages/:id/draft-add` (auth) → body: `{ quantity?, doctor_comment? }` → 201

### Records (applications)
- `GET /api/records` (auth)
  - User: own records; Moderator: all; filters: `?status=...&formed_from=YYYY-MM-DD&formed_to=YYYY-MM-DD`
  - Returns: `Application[]` with `items_count`
- `GET /api/records/:id` (auth)
  - Owner or moderator. Returns `{ application, items }`
- `PUT /api/records/:id` (auth)
  - Owner or moderator. Body: `{ comment?, flag_lv_hypertrophy?, flag_renal_damage?, flag_arterial_stiffness? }`
- `PUT /api/records/:id/submit` (auth)
  - Owner only, from draft → formed (non-empty items required)
- `PUT /api/records/:id/resolve` (moderator)
  - Body: `{ action: "approve"|"reject" }`; on approve sets `result_stage`, `result_map`, `finished_at`, `moderator_id`
- `DELETE /api/records/:id` (auth)
  - Owner or moderator; marks as `удалён`

### Draft helpers (current user)
- `GET /api/records/draft/icon` (auth) → `{ record_id: number|null, items_count: number }`
- `POST /api/records/draft/items` (auth) → body: `{ stage_id, quantity?, doctor_comment? }` → 201
- `PUT /api/records/:id/items` (auth) → body: `{ stage_id, quantity?, doctor_comment? }` → 200
- `DELETE /api/records/:id/items?stage_id=...` (auth) → 200

## MinIO Notes
- Public URL in templates is built as: `${MINIO_PUBLIC_BASE}/${MINIO_BUCKET}/${image_key}`
- Defaults: `MINIO_PUBLIC_BASE=http://localhost:9000`, `MINIO_BUCKET=images`
- Use MinIO Console at `http://localhost:9001` to create bucket `images` and upload assets.

## Security Details
- JWT HS256 secret: `config/config.toml` → `JWTSecret` (default: dev secret).
- TTL: `JWTTTLMinutes` (default 60). Token stored also in cookie `CookieName` (default `access_token`).
- Redis address: `RedisAddr` (default `127.0.0.1:6379`) used for blacklist on logout.

## Example cURL
```sh
# Register
curl -s http://localhost:8080/api/users/register \
  -H 'Content-Type: application/json' \
  -d '{"username":"user1","password":"pass1"}'

# Login (capture token and cookie)
LOGIN_JSON=$(curl -i -s http://localhost:8080/api/users/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"user1","password":"pass1"}')
TOKEN=$(echo "$LOGIN_JSON" | sed -n 's/.*\{"token":"\([^"]*\)".*/\1/p')
COOKIE=$(echo "$LOGIN_JSON" | grep -i '^Set-Cookie:' | sed -n 's/Set-Cookie: \([^;]*\).*/\1/p')

# Authorized request via Bearer
curl -s 'http://localhost:8080/api/records' -H "Authorization: Bearer $TOKEN"

# Or via Cookie
curl -s 'http://localhost:8080/api/records' -H "Cookie: $COOKIE"
```

## Frontend Integration Tips (React/Vite)
- Use `/api/users/login` to get the token and rely on cookie for subsequent calls, or store token in memory and use Bearer.
- Build list/detail views around:
  - Catalog: `GET /api/stages` (+ search via `?query=`)
  - Draft: `GET /api/records/draft/icon` + `POST /api/records/draft/items`
  - Records: `GET /api/records`, detail `GET /api/records/:id`
- For images use `minioURL(image_key)` rule from backend: `${MINIO_PUBLIC_BASE}/${MINIO_BUCKET}/${image_key}`.
## Inspect JWT + Redis blacklist (demo)

There is a helper script `scripts/demo_jwt_redis.sh` that:
- logs in as `user1` (body `{ "username":"user1","password":"pass1" }`),
- calls `GET /api/records` using `Authorization: Bearer <token>`,
- logs out (POST `/api/users/logout`) which blacklists the token's `jti` in Redis,
- inspects Redis for key `jwt:blacklist:<jti>` and prints the value and TTL.

Run it from repo root (zsh):
```zsh
chmod +x ./scripts/demo_jwt_redis.sh
./scripts/demo_jwt_redis.sh
```

The script will use `docker compose exec redis redis-cli` if `docker-compose.yml` exists, otherwise `redis-cli` on localhost:6379.

---
This README reflects the current codepaths in `internal/app` and `internal/api`. If you need a full OpenAPI for all endpoints, we can expand `resources/swagger/openapi.json` accordingly.
