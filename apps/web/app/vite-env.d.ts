/**
 * Declares the VITE_ variables this app reads, so `import.meta.env` is typed.
 * This is Vite's documented way to extend its ImportMetaEnv interface; the base
 * interface comes from the "vite/client" entry in tsconfig.json's `types`.
 * Keep it in step with ClientEnv in app/config/env-types.ts.
 */
interface ImportMetaEnv {
  readonly VITE_PUBLIC_API_BASE_URL?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
