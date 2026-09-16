/**
 * The shapes of the two environments this app reads from. Keeping them in their
 * own module lets the server-only and client-visible configuration modules
 * share types without importing each other's code.
 */

/**
 * The variables Vite inlines into the browser bundle. Vite only exposes names
 * that start with VITE_, which is the reason every value here is public by
 * definition: it ends up in a file anyone can download.
 */
export interface ClientEnv {
  VITE_PUBLIC_API_BASE_URL?: string;
}

/**
 * A process environment, as a server-only module sees it. `process.env` is
 * assignable to this type.
 */
export type ServerEnv = Record<string, string | undefined>;
