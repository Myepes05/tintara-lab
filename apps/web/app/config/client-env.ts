import type { ClientEnv } from "./env-types";

/**
 * The only module in this app that touches `import.meta.env`.
 *
 * Vite replaces `import.meta.env.VITE_*` with literal strings at build time, so
 * everything reachable from here is public. Isolating that read in one file has
 * two consequences that matter:
 *
 *  - No component ever reads an environment variable directly (D-020), so the
 *    logic that interprets these values can be unit-tested with plain objects.
 *  - Jest runs tests as CommonJS, and TypeScript will not compile
 *    `import.meta` to CommonJS, so Jest only has to replace this one module
 *    (see jest.config.js).
 */
export const clientEnv: ClientEnv = {
  // Each variable is read by its full name: Vite replaces the expression
  // `import.meta.env.VITE_PUBLIC_API_BASE_URL` with a string literal, and
  // naming it here keeps exactly this value, and nothing else, in the bundle.
  VITE_PUBLIC_API_BASE_URL: import.meta.env.VITE_PUBLIC_API_BASE_URL,
};
