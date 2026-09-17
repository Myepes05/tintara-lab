/**
 * The shapes of the two environments this app reads from. Keeping them in their
 * own module lets the server-only and client-visible configuration modules
 * share types without importing each other's code.
 */

/**
 * The values Vite inlines into the browser bundle. Vite only exposes project
 * variables whose names start with VITE_, plus a few built-in ones such as DEV,
 * which is the reason every value here is public by definition: it ends up in a
 * file anyone can download.
 */
export interface ClientEnv {
  /** Vite's built-in flag: true under `pnpm dev`, false in a production build. */
  DEV: boolean;
  VITE_PUBLIC_API_BASE_URL?: string;
}

/**
 * A process environment, as a server-only module sees it. `process.env` is
 * assignable to this type.
 */
export type ServerEnv = Record<string, string | undefined>;
