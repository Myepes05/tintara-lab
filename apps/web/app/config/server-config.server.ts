import type { ServerEnv } from "./env-types";

/**
 * Server-only configuration.
 *
 * The `.server` in this file name is not decoration: React Router's Vite plugin
 * fails the build if anything in the client module graph reaches a `.server`
 * file. That turns "do not leak the internal token to the browser" from a rule
 * people have to remember into a rule the build enforces (D-039, D-045).
 *
 * Nothing calls the API yet, so no module imports this one at runtime. The
 * guarantee is verified in `handoff/learning/03-web-skeleton.md`, which shows
 * the build failing when a client module imports it on purpose.
 */

export interface ServerConfig {
  /** Where server-side loaders call Rails (D-018, D-046). */
  apiInternalUrl: string;
  /** The X-Internal-Token value that exempts SSR calls from the public
   *  per-IP rate limit (D-045). A secret: never expose it to the browser. */
  apiInternalToken: string;
}

const REQUIRED_VARIABLES = ["API_INTERNAL_URL", "API_INTERNAL_TOKEN"] as const;

/**
 * Reads and validates the server-only environment.
 *
 * Every required variable must be present and non-blank. A missing one throws
 * immediately and names every variable that is missing, because the alternative
 * — an undefined value travelling into a fetch call — surfaces much later as an
 * unrelated error. `env` is a parameter so tests never have to mutate
 * `process.env`.
 */
export function readServerConfig(env: ServerEnv = process.env): ServerConfig {
  const missing = REQUIRED_VARIABLES.filter(
    (name) => (env[name] ?? "").trim().length === 0,
  );

  if (missing.length > 0) {
    throw new Error(
      `Missing required server environment ${
        missing.length === 1 ? "variable" : "variables"
      }: ${missing.join(", ")}. ` +
        `See apps/web/.env.example. These values are server-only and must never ` +
        `be given a VITE_ prefix.`,
    );
  }

  return {
    apiInternalUrl: (env.API_INTERNAL_URL as string).trim(),
    apiInternalToken: (env.API_INTERNAL_TOKEN as string).trim(),
  };
}

let cached: ServerConfig | undefined;

/**
 * The configuration of the running server, read once.
 *
 * Deliberately a function rather than a module-level constant: a constant would
 * be evaluated when the module is first imported, which would make the server
 * refuse to start — and `pnpm test` refuse to import this file — in every
 * environment that has not set the variables yet.
 */
export function getServerConfig(): ServerConfig {
  cached ??= readServerConfig();
  return cached;
}
