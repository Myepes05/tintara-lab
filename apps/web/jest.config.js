/**
 * Jest configuration.
 *
 * This project builds with Vite (through React Router's framework mode) but
 * tests with Jest (D-020). The two do not share a module pipeline, so every
 * Vite-specific behaviour the app relies on has to be reproduced here:
 *
 *  - Vite compiles TypeScript and JSX; Jest needs an explicit transform, so
 *    ts-jest compiles each test and each module it pulls in.
 *  - Vite resolves the `~/*` alias from tsconfig.json; Jest resolves modules
 *    itself, so the alias is repeated in moduleNameMapper.
 *  - Vite can import CSS and SVG files as modules; Node cannot, so those
 *    imports are mapped to inert stubs.
 *  - Vite replaces `import.meta.env` at build time. ts-jest compiles to
 *    CommonJS, and TypeScript refuses to compile `import.meta` for CommonJS
 *    (error TS1343), so the single module that reads it is mapped to a stub. Everything that interprets those
 *    values lives in plain modules that tests can call directly.
 *
 * @type {import('jest').Config}
 */
export default {
  testEnvironment: "jsdom",
  roots: ["<rootDir>/app"],
  setupFilesAfterEnv: ["<rootDir>/test/setup-jest.ts"],

  // Order matters: the first pattern that matches wins, so the specific
  // client-env mapping has to come before the general `~/*` alias.
  moduleNameMapper: {
    "^~/config/client-env$": "<rootDir>/test/stubs/client-env.ts",
    "^~/(.*)$": "<rootDir>/app/$1",
    "\\.css$": "<rootDir>/test/stubs/style.ts",
    "\\.(svg|png|jpe?g|gif|webp|avif|ico)$": "<rootDir>/test/stubs/asset.ts",
  },

  transform: {
    "^.+\\.tsx?$": ["ts-jest", { tsconfig: "<rootDir>/tsconfig.jest.json" }],
  },
};
