import type { ClientEnv } from "./env-types";

/**
 * The only module in this app that reads `import.meta.env`. (The type
 * declaration in app/vite-env.d.ts names it too, but reads nothing.)
 *
 * Vite replaces `import.meta.env.*` with literal values at build time, so
 * everything reachable from here is public. Isolating that read in one file has
 * two consequences that matter:
 *
 *  - No component ever reads an environment value directly (D-020); components
 *    such as root.tsx's ErrorBoundary import `clientEnv` instead, so tests can
 *    replace a value, and the logic that interprets these values can be
 *    unit-tested with plain objects.
 *  - Jest runs tests as CommonJS, and TypeScript will not compile
 *    `import.meta` to CommonJS, so Jest only has to replace this one module
 *    (see jest.config.js).
 */
export const clientEnv: ClientEnv = {
  // Each value is read by its full name: Vite replaces an expression such as
  // `import.meta.env.VITE_PUBLIC_API_BASE_URL` with a literal, and naming it
  // here keeps exactly that value, and nothing else, in the bundle. Reading
  // `import.meta.env` as a whole object would instead inline every VITE_
  // variable, including a wrongly prefixed secret that no code references.
  DEV: import.meta.env.DEV,
  VITE_PUBLIC_API_BASE_URL: import.meta.env.VITE_PUBLIC_API_BASE_URL,
};
