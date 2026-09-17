// ESLint flat configuration (the only format ESLint 10 reads).
//
// Layers, applied in order:
//  1. @eslint/js recommended: core JavaScript mistakes.
//  2. typescript-eslint recommended: TypeScript-aware versions of those rules,
//     and it switches off core rules that TypeScript already enforces.
//  3. react-hooks recommended: the Rules of Hooks, which no type checker catches.
//  4. eslint-config-prettier, last: turns off every rule that only concerns
//     formatting, so ESLint and Prettier can never disagree. Formatting is
//     Prettier's job alone (`pnpm format:check`).
import js from "@eslint/js";
import prettier from "eslint-config-prettier";
import reactHooks from "eslint-plugin-react-hooks";
import { defineConfig, globalIgnores } from "eslint/config";
import tseslint from "typescript-eslint";

export default defineConfig([
  // Generated or installed output, never linted.
  globalIgnores(["build/", ".react-router/", "coverage/", "node_modules/"]),

  js.configs.recommended,
  tseslint.configs.recommended,
  reactHooks.configs.flat.recommended,
  prettier,
]);
