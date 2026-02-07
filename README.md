# TT Template

A production-ready fullstack template for Cloudflare Workers with authentication.

**Stack:**
- **Server**: Hono API on Cloudflare Workers with Prisma + D1 database + BetterAuth
- **Client**: Vite + React + TanStack Router deployed as Cloudflare Worker (Assets)
- **UI**: shadcn/ui components with Tailwind CSS v4
- **Auth**: BetterAuth with Google & Discord OAuth (extensible)
- **Payments**: Stripe integration with subscription management (via Better Auth plugin)

The client proxies `/api/*` to the server via service binding (no CORS in production).

---

## Quick Start (New Project from Template)

### 1. Clone and Rename

```bash
git clone https://github.com/noah-wardlow/starter my-project
cd my-project

# Automated rename (recommended)
./rename-project.sh my-project

# This will rename:
#   tt-client → my-project-client
#   tt-server → my-project-server
#   tt-shared → my-project-shared
# And update all references in configs, imports, and docs
```

**Or rename manually:**
- Rename directories: `tt-client`, `tt-server`, `tt-shared`
- Update `package.json` workspace names
- Update `wrangler.jsonc` names and service bindings
- Update imports in code

### 2. Install Dependencies

```bash
pnpm install
```

### 3. Create D1 Database

```bash
cd my-project-server
pnpm exec wrangler d1 create my-project-database

# Copy the database_id from the output and update my-project-server/wrangler.jsonc
```

Example output:
```
[[d1_databases]]
binding = "DB"
database_name = "my-project-database"
database_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### 4. Set Up Database Schema

```bash
cd my-project-server

# Generate Prisma client
pnpm run db:generate

# Apply existing migrations to local DB
pnpm run db:migrate:local

# Apply migrations to production DB (after deploying)
pnpm run db:migrate:remote
```

### 5. Configure Environment Variables & Secrets

**Generate a secure auth secret:**
```bash
node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"
```

**For local development:**

Create `my-project-server/.dev.vars`:
```bash
BETTER_AUTH_SECRET="<generated-secret>"

# Add OAuth provider credentials (based on enabled providers in my-project-shared/src/oauth-config.ts)
# Format: {PROVIDER}_CLIENT_ID and {PROVIDER}_CLIENT_SECRET
GOOGLE_CLIENT_ID="your-client-id"
GOOGLE_CLIENT_SECRET="your-client-secret"

# Optional: Stripe (see STRIPE_SETUP.md for full guide)
STRIPE_SECRET_KEY="sk_test_..."
STRIPE_WEBHOOK_SECRET="whsec_..."
STRIPE_CONNECT_WEBHOOK_SECRET="whsec_..."
```

**For production:**

Deploy all secrets from `.dev.vars` to production:
```bash
cd my-project-server

# For each variable in .dev.vars, run:
pnpm exec wrangler secret put VARIABLE_NAME
# You'll be prompted to paste the value

# Example:
pnpm exec wrangler secret put BETTER_AUTH_SECRET
pnpm exec wrangler secret put GOOGLE_CLIENT_ID
pnpm exec wrangler secret put GOOGLE_CLIENT_SECRET
```

> **Important**: Every environment variable in `.dev.vars` must also be set as a Wrangler secret for production.

**OAuth provider setup:**
- Configure which providers to enable in `my-project-shared/src/oauth-config.ts`
- Get credentials from each provider's developer console
- Add `{PROVIDER}_CLIENT_ID` and `{PROVIDER}_CLIENT_SECRET` to `.dev.vars` and production secrets

#### Google OAuth Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Navigate to **APIs & Services** → **Credentials**
4. Click **Create Credentials** → **OAuth client ID**
5. Select **Web application** as the application type
6. Configure the following:

   **Authorized JavaScript origins:**
   ```
   http://localhost
   https://my-project-client.YOUR_SUBDOMAIN.workers.dev
   ```

   **Authorized redirect URIs:**
   ```
   http://localhost
   http://localhost:8787/auth/callback/google
   ```

7. Click **Create** and copy your **Client ID** and **Client Secret**
8. Add them to `my-project-server/.dev.vars`:
   ```
   GOOGLE_CLIENT_ID="your-client-id"
   GOOGLE_CLIENT_SECRET="your-client-secret"
   ```

### 6. Local Development

**Terminal 1 - Server:**
```bash
pnpm --filter my-project-server dev
# Runs on http://localhost:8787
```

**Terminal 2 - Client:**
```bash
cd my-project-client
VITE_API_BASE=http://localhost:8787 pnpm dev
# Runs on http://localhost:3000
```

Visit `http://localhost:3000` - you should see the app with authentication working!

### 7. Deploy to Production

```bash
# Deploy server (includes migrations)
pnpm --filter my-project-server exec wrangler deploy

# Build and deploy client
pnpm --filter my-project-client run build
pnpm --filter my-project-client exec wrangler deploy
```

Your app is now live at `https://my-project-client.YOUR_SUBDOMAIN.workers.dev`!

---

## Project Structure

```
my-project/
├── my-project-server/      # Hono API server
│   ├── src/
│   │   ├── app.ts          # Main Hono app with routes
│   │   └── lib/
│   │       ├── auth.ts     # BetterAuth configuration
│   │       └── prisma.ts   # Prisma client
│   ├── prisma/
│   │   └── schema.prisma   # Database schema
│   ├── migrations/         # D1 migrations
│   └── wrangler.jsonc      # Server Worker config
│
├── my-project-client/      # React SPA
│   ├── src/
│   │   ├── routes/         # TanStack Router file-based routes
│   │   ├── components/     # React components + shadcn/ui
│   │   ├── lib/
│   │   │   ├── auth.ts         # BetterAuth client
│   │   │   └── auth-context.tsx # Auth context provider
│   │   ├── worker.ts       # Cloudflare Worker (proxies /api/*)
│   │   └── main.tsx        # React app entry
│   └── wrangler.jsonc      # Client Worker config
│
├── my-project-shared/      # Shared types
│   └── src/types.ts
│
└── CLAUDE.md               # Developer documentation
```

---

## Authentication

**Pre-configured with BetterAuth:**
- Session-based authentication with cookies
- OAuth providers: Google, Discord (add more easily)
- Protected routes via TanStack Router
- Server-side session validation

**Routes:**
- `/login` - Login page with OAuth buttons
- `/dashboard` - Protected route (example)
- `/` - Public home page

**Usage:**
```tsx
import { useAuth } from "@/lib/auth-context";

function MyComponent() {
  const { session, isAuthenticated, isPending } = useAuth();

  if (isPending) return <div>Loading...</div>;
  if (!isAuthenticated) return <div>Please log in</div>;

  return <div>Welcome {session?.user?.name}!</div>;
}
```

---

## UI Components (shadcn/ui)

Pre-configured with shadcn/ui + Tailwind CSS v4.

**Add components:**
```bash
cd my-project-client
npx shadcn@canary add button card dialog
```

**Add from custom registries:**
```bash
npx shadcn@canary add https://jollyui.dev/r/button
```

See [shadcn/ui docs](https://ui.shadcn.com/docs) for available components.

---

## Available Scripts

### Server (tt-server)

```bash
pnpm --filter tt-server dev              # Start dev server
pnpm --filter tt-server deploy           # Deploy to production

# Database
pnpm --filter tt-server run db:generate         # Generate Prisma client
pnpm --filter tt-server run db:migrate:create   # Create migration file
pnpm --filter tt-server run db:migrate:diff     # Generate SQL from schema
pnpm --filter tt-server run db:migrate:local    # Apply migrations locally
pnpm --filter tt-server run db:migrate:remote   # Apply to production

# Auth
pnpm --filter tt-server run auth:generate       # Generate auth schema

# Types
pnpm --filter tt-server run cf-typegen          # Generate Cloudflare types
```

### Client (tt-client)

```bash
pnpm --filter tt-client dev      # Start Vite dev server
pnpm --filter tt-client build    # Build for production
pnpm --filter tt-client deploy   # Deploy to Cloudflare
pnpm --filter tt-client test     # Run tests
```

---

## Database Management

### Creating Migrations

1. Edit `tt-server/prisma/schema.prisma`
2. Generate Prisma client: `pnpm --filter tt-server run db:generate`
3. Create migration file: `pnpm --filter tt-server run db:migrate:create add_users_table`
4. Generate SQL: `pnpm --filter tt-server run db:migrate:diff > migrations/0002_add_users_table.sql`
5. Apply locally: `pnpm --filter tt-server run db:migrate:local`
6. Apply to production: `pnpm --filter tt-server run db:migrate:remote`

### Example: Adding a New Table

```prisma
// tt-server/prisma/schema.prisma
model Post {
  id        String   @id @default(cuid())
  title     String
  content   String
  authorId  String
  author    User     @relation(fields: [authorId], references: [id])
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}
```

Then run the migration commands above.

---

## API Routes

### Server Routes (tt-server/src/app.ts)

- `GET /` - Health check
- `GET /api/auth/*` - BetterAuth endpoints (session, OAuth, etc.)
- `GET /users` - Example: List all users
- `POST /users` - Example: Create user

### Adding New Routes

```typescript
// tt-server/src/app.ts
app.get('/posts', async (c) => {
  const prisma = getPrisma(c.env.DB);
  const posts = await prisma.post.findMany();
  return c.json(posts);
});
```

---

## Protected Routes

Use the `_authenticated` layout for protected routes:

```tsx
// tt-client/src/routes/_authenticated/profile.tsx
import { createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/_authenticated/profile")({
  component: Profile,
});

function Profile() {
  const { auth } = Route.useRouteContext();
  return <div>Welcome {auth.session?.user?.name}</div>;
}
```

The `_authenticated` layout automatically redirects unauthenticated users to `/login`.

---

## Deployment

### GitHub Actions (Auto-deploy)

CI/CD workflows are pre-configured in `.github/workflows/`:

- `deploy-server.yml` - Deploys server on push to `main`
- `deploy-client.yml` - Deploys client on push to `main`

**Setup:**

1. **Create a Cloudflare API Token:**
   - Go to https://dash.cloudflare.com/profile/api-tokens
   - Click **Create Token**
   - Use **Create Custom Token** with these permissions:

   | Scope | Resource | Permission |
   |-------|----------|------------|
   | Account | Workers Scripts | Edit |
   | Account | D1 | Edit |

   - Click **Continue to summary** → **Create Token**
   - Copy the token (you won't see it again)

2. **Add GitHub Secrets** (Settings → Secrets and variables → Actions):
   - `CLOUDFLARE_API_TOKEN` = the token you just created
   - `CLOUDFLARE_ACCOUNT_ID` = your account ID (found in Workers dashboard URL or sidebar)

3. Push to `main` branch - auto-deploys!

### Manual Deploy

```bash
# Deploy everything
pnpm --filter tt-server exec wrangler deploy
pnpm --filter tt-client run build && pnpm --filter tt-client exec wrangler deploy
```

---

## Key Features

- **Monorepo** - pnpm workspace with shared types
- **Type-safe** - Full TypeScript with Prisma
- **Authentication** - BetterAuth with OAuth
- **Payments** - Stripe subscriptions with Better Auth plugin
- **Protected Routes** - TanStack Router auth guards
- **UI Components** - shadcn/ui + Tailwind v4
- **Database** - Prisma + Cloudflare D1
- **Service Bindings** - No CORS in production
- **CI/CD** - Auto-deploy via GitHub Actions

---

## Documentation

- [CLAUDE.md](./CLAUDE.md) - Detailed developer docs
- [STRIPE_SETUP.md](./STRIPE_SETUP.md) - Stripe integration & subscription management guide
- [Hono](https://hono.dev/llms.txt) - Server framework
- [BetterAuth](https://www.better-auth.com/docs) - Authentication
- [TanStack Router](https://tanstack.com/router) - Client routing
- [shadcn/ui](https://ui.shadcn.com/docs) - UI components
- [Cloudflare Workers](https://developers.cloudflare.com/workers) - Platform docs

---

## Troubleshooting

**Auth not working (500 errors)?**
- Ensure `nodejs_compat` flag is in `tt-server/wrangler.jsonc` (required for BetterAuth)
- Check `BETTER_AUTH_SECRET` is set in `.dev.vars` and production secrets
- Verify OAuth credentials are correct
- Check `trustedOrigins` in `tt-server/src/lib/auth.ts` includes your domains

**Database errors?**
- Run `pnpm --filter tt-server run db:generate` after schema changes
- Apply migrations: `pnpm --filter tt-server run db:migrate:local`

**Build errors?**
- Run `pnpm install` from workspace root
- Check `pnpm exec tsc --noEmit` for type errors

**Service binding not working?**
- Verify worker names match in both `wrangler.jsonc` files
- Check `tt-client/wrangler.jsonc` service binding points to server name

---

## License

MIT
