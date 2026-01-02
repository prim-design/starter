# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**TT Template** is a monorepo fullstack template for Cloudflare Workers with:
- **tt-server**: Hono API on Cloudflare Workers with Prisma + D1 database
- **tt-client**: Vite React SPA deployed as a Cloudflare Worker (Assets)
- **tt-shared**: Shared TypeScript types between client and server

The client proxies `/api/*` requests to the server via a Cloudflare service binding (no CORS in production).

## Documentation References

- **Hono**: https://hono.dev/llms.txt
- **BetterAuth**: https://www.better-auth.com/llms.txt
- **TanStack Router**: See `tt-client/TANSTACK_ROUTER_API.md` for comprehensive API documentation
- **shadcn/ui**: https://ui.shadcn.com/docs
- **Stripe**: https://docs.stripe.com/llms.txt

## Common Commands

### Development

```bash
# Install dependencies (run from workspace root)
pnpm -w install

# Server development (runs on http://localhost:8787)
pnpm --filter tt-server dev

# Client development (runs on http://localhost:3000)
cd tt-client && VITE_API_BASE=http://localhost:8787 pnpm dev

# Alternative: Client Worker dev (build + run as Worker)
pnpm --filter tt-client run build && pnpm --filter tt-client exec wrangler dev
```

### Database (Prisma + D1)

All database commands run from `tt-server`:

```bash
# Create migration file
pnpm --filter tt-server run db:migrate:create <migration_name>

# Generate SQL from Prisma schema
pnpm --filter tt-server run db:migrate:diff > migrations/000X_<migration_name>.sql

# Apply migrations locally
pnpm --filter tt-server run db:migrate:local

# Apply migrations to production
pnpm --filter tt-server run db:migrate:remote

# Generate Prisma Client types
pnpm --filter tt-server run db:generate
```

**Important**: After editing `tt-server/prisma/schema.prisma`, run `db:generate` to regenerate types, then create and apply migrations.

### Build & Deploy

```bash
# Build client
pnpm --filter tt-client run build

# Deploy server
pnpm --filter tt-server exec wrangler deploy

# Deploy client
pnpm --filter tt-client run build && pnpm --filter tt-client exec wrangler deploy
```

### Production Deployment with Custom Domain

When deploying to production with a custom domain (e.g., `yourdomain.com`), follow these steps:

**1. Create D1 Database**
```bash
wrangler d1 create your-app-database
# Copy the database_id to tt-server/wrangler.jsonc
```

**2. Set Required Secrets**
```bash
# Generate a secret: openssl rand -base64 32
wrangler secret put BETTER_AUTH_SECRET --config tt-server/wrangler.jsonc

# Set your domain (without protocol, e.g., "yourdomain.com")
wrangler secret put APP_DOMAIN --config tt-server/wrangler.jsonc

# Set the API base URL (e.g., "https://api.yourdomain.com")
wrangler secret put BETTER_AUTH_URL --config tt-server/wrangler.jsonc

# OAuth providers
wrangler secret put GOOGLE_CLIENT_ID --config tt-server/wrangler.jsonc
wrangler secret put GOOGLE_CLIENT_SECRET --config tt-server/wrangler.jsonc

# Stripe (if using)
wrangler secret put STRIPE_SECRET_KEY --config tt-server/wrangler.jsonc
wrangler secret put STRIPE_WEBHOOK_SECRET --config tt-server/wrangler.jsonc
```

**3. Configure Custom Domains in wrangler.jsonc**

In `tt-server/wrangler.jsonc`, add:
```jsonc
"routes": [
  { "pattern": "api.yourdomain.com", "custom_domain": true }
]
```

In `tt-client/wrangler.jsonc`, add:
```jsonc
"routes": [
  { "pattern": "yourdomain.com", "custom_domain": true },
  { "pattern": "www.yourdomain.com", "custom_domain": true }
]
```

**4. Update OAuth Redirect URIs**

In your OAuth provider dashboards, add the production callback URLs:
- `https://api.yourdomain.com/auth/callback/google`
- `https://api.yourdomain.com/auth/callback/discord`
- etc.

**5. Deploy**
```bash
# Apply migrations to production
pnpm --filter tt-server run db:migrate:remote

# Deploy server first
pnpm --filter tt-server exec wrangler deploy

# Build and deploy client
pnpm --filter tt-client run build && pnpm --filter tt-client exec wrangler deploy
```

**Key Environment Variables**:
| Variable | Description | Example |
|----------|-------------|---------|
| `BETTER_AUTH_URL` | Full API URL with protocol | `https://api.yourdomain.com` |
| `BETTER_AUTH_SECRET` | Random secret for auth | `openssl rand -base64 32` |
| `APP_DOMAIN` | Your domain without protocol (custom domains only) | `yourdomain.com` |

**Deployment modes:**

1. **Workers.dev (no custom domain)**: Just set `BETTER_AUTH_URL` to your server worker URL
   ```bash
   wrangler secret put BETTER_AUTH_URL  # e.g., https://my-server.account.workers.dev
   wrangler secret put BETTER_AUTH_SECRET
   ```
   CORS and trusted origins are automatically derived (assumes `*-server` / `*-client` naming).

2. **Custom domain**: Set both `BETTER_AUTH_URL` and `APP_DOMAIN`
   ```bash
   wrangler secret put BETTER_AUTH_URL  # e.g., https://api.yourdomain.com
   wrangler secret put APP_DOMAIN       # e.g., yourdomain.com
   wrangler secret put BETTER_AUTH_SECRET
   ```
   This also enables cross-subdomain cookies for `api.` + `www.` subdomains.

### Testing

```bash
# Run client tests
pnpm --filter tt-client test
```

### shadcn/ui Components

All commands run from `tt-client`:

```bash
# Add a new component (uses shadcn@canary for React 19 + Tailwind v4)
cd tt-client && npx shadcn@canary add <component-name>

# Example: Add button component
cd tt-client && npx shadcn@canary add button

# Add multiple components at once
cd tt-client && npx shadcn@canary add button card dialog

# Add from custom registries (e.g., JollyUI)
cd tt-client && npx shadcn@canary add https://jollyui.dev/r/button
```

**Component Configuration**:
- Components install to `tt-client/src/components/ui/`
- Utils helper at `tt-client/src/lib/utils.ts`
- CSS variables defined in `tt-client/src/styles.css`
- TypeScript paths configured for `@/*` imports
- Configuration file at `tt-client/components.json`

**Usage Example**:
```tsx
import { Button } from "@/components/ui/button"

export function MyComponent() {
  return <Button variant="default">Click me</Button>
}
```

## Architecture

### Monorepo Structure

- **pnpm workspace** with 3 packages: `tt-server`, `tt-client`, `tt-shared`
- `tt-shared` exports shared types at `tt-shared/types`
- Both server and client import from `tt-shared`

### Service Binding (Client → Server)

The client Worker (`tt-client/src/worker.ts`) proxies `/api/*` requests to the server:

1. Client strips `/api` prefix from incoming requests
2. Forwards to `env.TT_SERVER` service binding (configured in `tt-client/wrangler.jsonc`)
3. Server receives requests at root paths (e.g., `/` for health check, `/auth/**` for auth routes)

**Configuration**:
- `tt-client/wrangler.jsonc` → `services[0].service: "tt-server"`
- No CORS needed in production (same-worker communication)

### Client Architecture

- **TanStack Router**: File-based routing in `src/routes/`
- **TanStack Query**: Data fetching and caching
- **Vite**: Build tool and dev server
- **Tailwind CSS v4**: Styling via `@tailwindcss/vite`
- **API Base**: `src/lib/api.ts` sets API base to `/api` in prod, `http://localhost:8787` in dev (override via `VITE_API_BASE`)

**Worker Deployment**: The client Worker serves static assets from `./dist` (via Workers Assets) and proxies API requests to the server.

### Server Architecture

- **Hono**: Web framework with type-safe routing
- **Prisma**: Type-safe ORM with D1 adapter (`@prisma/adapter-d1`)
- **D1 Database**: SQLite database on Cloudflare
- **BetterAuth**: Authentication with Google and Discord OAuth providers

**Auth Routes**: All auth endpoints are at `/api/auth/**` (handled by BetterAuth in `tt-server/src/app.ts:29-32`).

### Authentication (BetterAuth)

- **Framework**: BetterAuth (NOT NextAuth)
- **Database adapter**: Kysely + D1 dialect (`kysely-d1`)
- **OAuth providers**: Google and Discord
- **Schema generation**: Use `pnpm --filter tt-server auth:generate` to generate Prisma schema from BetterAuth config

**Setup**:
1. Create `tt-server/.dev.vars` with OAuth credentials (see `AUTH_SETUP.md`)
2. For production, use `wrangler secret put VARIABLE_NAME`
3. Run `pnpm --filter tt-server auth:generate` to sync schema
4. Generate Prisma client and apply migrations

**Important**: Always reference BetterAuth documentation for APIs (not NextAuth). The server uses Kysely to connect BetterAuth to D1.

### Prisma + D1 Integration

- **Datasource**: `sqlite` (D1 is SQLite-based)
- **Adapter**: `@prisma/adapter-d1` in `tt-server/src/lib/prisma.ts`
- **Client output**: `../../node_modules/.prisma/client` (shared across workspace)
- **Driver adapters**: Enabled via `previewFeatures = ["driverAdapters"]`

**Migration workflow**:
1. Edit `schema.prisma`
2. Run `db:migrate:diff` to generate SQL
3. Save SQL to `migrations/` directory
4. Apply with `db:migrate:local` or `db:migrate:remote`

### Cloudflare Bindings

**Server bindings** (`tt-server/wrangler.jsonc`):
- `DB`: D1 database binding
- Auth variables: `BETTER_AUTH_SECRET`, `BETTER_AUTH_URL`, `APP_DOMAIN`
- OAuth variables: `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `DISCORD_CLIENT_ID`, `DISCORD_CLIENT_SECRET`
- Stripe variables: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`

**Client bindings** (`tt-client/wrangler.jsonc`):
- `TT_SERVER`: Service binding to `tt-server` Worker
- `ASSETS`: Workers Assets binding for static files

## Important Configuration Details

### Worker Names

When creating a new project from this template:
1. Set unique worker names in `wrangler.jsonc` files (`name` field)
2. Update `tt-client/wrangler.jsonc` → `services[0].service` to match server worker name

### CORS

- **Development**: CORS enabled for `http://localhost:3000` and `http://localhost:8787`
- **Production**: CORS automatically configured via `APP_DOMAIN` env var
- **Trusted origins**: Dynamically configured in `tt-server/src/lib/auth.ts` based on `APP_DOMAIN`

When `APP_DOMAIN` is set (e.g., `yourdomain.com`), CORS and trusted origins automatically include:
- `https://yourdomain.com`
- `https://www.yourdomain.com`
- `https://api.yourdomain.com`

### Environment Variables

- **Development**: Use `.dev.vars` files (not committed)
- **Production**: Use `wrangler secret put` to set secrets
- **Client**: Use `.env` files with `VITE_` prefix for Vite environment variables

## CI/CD

GitHub Actions workflows automatically deploy on push to `main`:
- `.github/workflows/deploy-server.yml`: Runs migrations and deploys server
- `.github/workflows/deploy-client.yml`: Builds and deploys client

## File Locations

- Client routes: `tt-client/src/routes/` (TanStack Router file-based routing)
- Server routes: `tt-server/src/app.ts` (Hono routes)
- Auth config: `tt-server/src/lib/auth.ts` (BetterAuth with Kysely)
- Database schema: `tt-server/prisma/schema.prisma`
- Migrations: `tt-server/migrations/`
- Shared types: `tt-shared/src/types.ts`
