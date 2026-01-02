import { betterAuth } from "better-auth";
import { Kysely } from "kysely";
import { D1Dialect } from "kysely-d1";
import { getEnabledProviders } from "tt-shared/oauth-config";
import {
  getClientIdEnvVar,
  getClientSecretEnvVar,
  profileMappers,
} from "./oauth-utils";
import { stripe } from "@better-auth/stripe";
import Stripe from "stripe";

type AuthEnv = {
  GOOGLE_CLIENT_ID?: string;
  GOOGLE_CLIENT_SECRET?: string;
  DISCORD_CLIENT_ID?: string;
  DISCORD_CLIENT_SECRET?: string;
  TWITCH_CLIENT_ID?: string;
  TWITCH_CLIENT_SECRET?: string;
  BETTER_AUTH_SECRET?: string;
  STRIPE_SECRET_KEY?: string;
  STRIPE_WEBHOOK_SECRET?: string;
  // Production deployment config
  BETTER_AUTH_URL?: string; // e.g., https://api.example.com
  APP_DOMAIN?: string; // e.g., example.com (without protocol)
};

// Cache auth instance per DB to avoid recreating on every request
const authCache = new WeakMap();

export function getAuth(db: D1Database, env: AuthEnv) {
  // Return cached instance if available
  if (authCache.has(db)) {
    return authCache.get(db);
  }

  // Create Kysely instance with D1 dialect
  const kysely = new Kysely<any>({
    dialect: new D1Dialect({ database: db }),
  });

  // Build social providers config dynamically from enabled providers
  const enabledProviders = getEnabledProviders();
  const socialProviders: Record<string, any> = {};

  for (const provider of enabledProviders) {
    socialProviders[provider] = {
      clientId: env[getClientIdEnvVar(provider)] || "",
      clientSecret: env[getClientSecretEnvVar(provider)] || "",
      mapProfileToUser: profileMappers[provider],
    };
  }

  // Create Stripe client if configured
  const stripeClient = env.STRIPE_SECRET_KEY
    ? new Stripe(env.STRIPE_SECRET_KEY, {
        apiVersion: "2025-02-24.acacia",
      })
    : undefined;

  // Build trusted origins dynamically
  const trustedOrigins = [
    "http://localhost:3000",
    "http://localhost:8787",
  ];

  // Add production origins if APP_DOMAIN is configured (custom domain)
  if (env.APP_DOMAIN) {
    trustedOrigins.push(
      `https://${env.APP_DOMAIN}`,
      `https://www.${env.APP_DOMAIN}`,
      `https://api.${env.APP_DOMAIN}`
    );
  } else if (env.BETTER_AUTH_URL) {
    // For workers.dev deployment: derive origins from BETTER_AUTH_URL
    // e.g., https://my-server.account.workers.dev -> trust that + client equivalent
    trustedOrigins.push(env.BETTER_AUTH_URL);
    // Also trust the client worker (assumes naming convention: *-server -> *-client)
    const clientUrl = env.BETTER_AUTH_URL.replace("-server", "-client");
    if (clientUrl !== env.BETTER_AUTH_URL) {
      trustedOrigins.push(clientUrl);
    }
  }

  // Determine if we're in production (custom domain configured)
  const isProduction = !!env.APP_DOMAIN;

  const auth = betterAuth({
    database: {
      db: kysely,
      type: "sqlite",
    },
    baseURL: env.BETTER_AUTH_URL,
    basePath: "/auth",
    secret: env.BETTER_AUTH_SECRET || "default-secret-change-me",
    emailAndPassword: {
      enabled: false,
    },
    // Enable cross-subdomain cookies in production (e.g., app.example.com + api.example.com)
    ...(isProduction && {
      advanced: {
        crossSubDomainCookies: {
          enabled: true,
          domain: `.${env.APP_DOMAIN}`,
        },
      },
    }),
    user: {
      additionalFields: {
        username: {
          type: "string",
          required: false,
        },
      },
    },
    account: {
      accountLinking: {
        enabled: true,
        trustedProviders: enabledProviders,
        updateUserInfoOnLink: true,
      },
    },
    socialProviders,
    trustedOrigins,
    plugins: [
      ...(stripeClient && env.STRIPE_WEBHOOK_SECRET
        ? [
            stripe({
              stripeClient,
              stripeWebhookSecret: env.STRIPE_WEBHOOK_SECRET,
              createCustomerOnSignUp: true,
            }),
          ]
        : []),
    ],
  });

  authCache.set(db, auth);
  return auth;
}
