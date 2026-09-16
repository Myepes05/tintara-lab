import type { ClientEnv } from "~/config/env-types";

/**
 * Stands in for app/config/client-env.ts inside Jest.
 *
 * The real module's only job is to hand over `import.meta.env`, which ts-jest
 * cannot compile to CommonJS. Tests never assert against this object: they call
 * readPublicConfig() with an explicit environment instead, which is exactly the
 * testability D-020 asks for.
 */
export const clientEnv: ClientEnv = {};
