import { Hono } from "hono";
import { cors } from "hono/cors";
import { getPrisma } from "./lib/prisma";
import { getAuth } from "./lib/auth";
import stripeConnectWebhook from "./routes/stripe-connect-webhook";
import {
  createAuthContextMiddleware,
  requireAuth,
  type AppVariables,
} from "./middleware";

type Bindings = {
  DB: D1Database;
  GOOGLE_CLIENT_ID?: string;
  GOOGLE_CLIENT_SECRET?: string;
  DISCORD_CLIENT_ID?: string;
  DISCORD_CLIENT_SECRET?: string;
  TWITCH_CLIENT_ID?: string;
  TWITCH_CLIENT_SECRET?: string;
  BETTER_AUTH_SECRET?: string;
  STRIPE_SECRET_KEY?: string;
  STRIPE_WEBHOOK_SECRET?: string;
  STRIPE_CONNECT_WEBHOOK_SECRET?: string;
  // Production deployment config
  BETTER_AUTH_URL?: string;
  APP_DOMAIN?: string;
};

declare global {
  interface CloudflareBindings extends Bindings {}
}

const app = new Hono<{ Bindings: Bindings; Variables: AppVariables }>();

// Build allowed origins based on APP_DOMAIN or BETTER_AUTH_URL env vars
function getAllowedOrigins(appDomain?: string, betterAuthUrl?: string): string[] {
  const origins = [
    "http://localhost:3000",
    "http://localhost:8787",
  ];
  if (appDomain) {
    // Custom domain deployment
    origins.push(
      `https://${appDomain}`,
      `https://www.${appDomain}`,
      `https://api.${appDomain}`
    );
  } else if (betterAuthUrl) {
    // Workers.dev deployment: derive origins from BETTER_AUTH_URL
    origins.push(betterAuthUrl);
    // Also allow client worker (assumes *-server -> *-client naming)
    const clientUrl = betterAuthUrl.replace("-server", "-client");
    if (clientUrl !== betterAuthUrl) {
      origins.push(clientUrl);
    }
  }
  return origins;
}

// Enable CORS - works with both service bindings and direct API calls
// In production with custom domains, CORS is needed for cross-origin requests
app.use("*", async (c, next) => {
  const allowedOrigins = getAllowedOrigins(c.env.APP_DOMAIN, c.env.BETTER_AUTH_URL);
  const corsMiddleware = cors({
    origin: (origin) => {
      return allowedOrigins.includes(origin)
        ? origin
        : allowedOrigins[0];
    },
    allowMethods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowHeaders: ["Content-Type", "Authorization"],
    exposeHeaders: ["Content-Length"],
    maxAge: 600,
    credentials: true,
  });
  return corsMiddleware(c, next);
});

// Health check
app.get("/", (c) => c.json({ ok: true }));

// Populate user/session on every request
app.use("*", createAuthContextMiddleware());

// BetterAuth routes - handle all auth endpoints
// In production: client strips /api/ prefix, so server receives /auth/*
// In development: client calls server directly at /api/auth/*
app.on(["GET", "POST"], "/auth/*", async (c) => {
  try {
    const auth = getAuth(c.env.DB, c.env);
    return await auth.handler(c.req.raw);
  } catch (error) {
    return c.json(
      {
        error: "Authentication error",
        details: error instanceof Error ? error.message : String(error),
      },
      500,
    );
  }
});

// Session/user echo route using middleware context
app.get("/session", (c) => {
  const session = c.get("session");
  const user = c.get("user");
  if (!user) return c.body(null, 401);
  return c.json({ session, user });
});

// Stripe Connect webhook (separate from Better Auth's standard Stripe webhooks)
app.route("/stripe", stripeConnectWebhook);

// Example Prisma route - get all users
app.get("/users", requireAuth(), async (c) => {
  const prisma = getPrisma(c.env.DB);
  const users = await prisma.user.findMany();
  return c.json(users);
});

export default app;
