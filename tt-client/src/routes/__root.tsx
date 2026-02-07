import { Outlet, createRootRouteWithContext } from "@tanstack/react-router";
import { lazy } from "react";

import type { RouterContext } from "@/main";
import { sessionQueryOptions } from "@/lib/auth";

// Lazy load devtools only in development
const TanStackDevtools = import.meta.env.DEV
  ? lazy(() =>
      import("@tanstack/react-devtools").then((mod) => ({
        default: mod.TanStackDevtools,
      }))
    )
  : () => null;

const TanStackRouterDevtoolsPanel = import.meta.env.DEV
  ? lazy(() =>
      import("@tanstack/react-router-devtools").then((mod) => ({
        default: mod.TanStackRouterDevtoolsPanel,
      }))
    )
  : () => null;

export const Route = createRootRouteWithContext<RouterContext>()({
  beforeLoad: async ({ context }) => {
    // Prefetch session so it's ready before any route renders
    // Use try-catch to allow UI to render even if backend is unreachable
    try {
      await context.queryClient.ensureQueryData(sessionQueryOptions);
    } catch (error) {
      console.error("Failed to prefetch session:", error);
    }
  },
  component: () => (
    <>
      <Outlet />
      {import.meta.env.DEV && (
        <TanStackDevtools
          config={{
            position: "bottom-right",
          }}
          plugins={[
            {
              name: "Tanstack Router",
              render: <TanStackRouterDevtoolsPanel />,
            },
          ]}
        />
      )}
    </>
  ),
});
