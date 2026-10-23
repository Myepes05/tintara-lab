import { clientEnv } from "~/config/client-env";
import type { ClientEnv } from "./env-types";

/**
 * Where the browser reaches the Rails API in development. Production overrides
 * it with the API subdomain of D-039, supplied as VITE_PUBLIC_API_BASE_URL.
 */
export const DEFAULT_PUBLIC_API_BASE_URL = "http://localhost:3000";

export interface PublicConfig {
  /** Base URL the browser uses for its own API calls, with no trailing path. */
  apiBaseUrl: string;
}

/**
 * Interprets a client environment. Exported separately from `publicConfig` so
 * tests can pass an environment in rather than mutate a global one (D-020).
 *
 * A missing value is not an error here: this one is public and has a sensible
 * development default. Server-only values behave the opposite way; see
 * server-config.server.ts.
 *
 * It accepts only the variable it interprets, so a test does not have to invent
 * the rest of the client environment.
 */
export function readPublicConfig(
  env: Pick<ClientEnv, "VITE_PUBLIC_API_BASE_URL">,
): PublicConfig {
  const configured = env.VITE_PUBLIC_API_BASE_URL?.trim();

  return {
    apiBaseUrl:
      configured && configured.length > 0
        ? configured
        : DEFAULT_PUBLIC_API_BASE_URL,
  };
}

/** The configuration of the running app. Safe to import from any module. */
export const publicConfig = readPublicConfig(clientEnv);
