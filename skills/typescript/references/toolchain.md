# TypeScript Toolchain Reference

> Load when: user asks about tsconfig, ESLint, Vitest, Vite, pnpm, or build setup.

## ESLint 9 Flat Config

```javascript
// eslint.config.js
import eslint from "@eslint/js";
import tseslint from "typescript-eslint";

export default tseslint.config(
  eslint.configs.recommended,
  ...tseslint.configs.strictTypeChecked,
  {
    languageOptions: {
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      "@typescript-eslint/no-explicit-any": "error",
      "@typescript-eslint/no-unnecessary-condition": "error",
      "@typescript-eslint/prefer-nullish-coalescing": "warn",
    },
  }
);
```

## Vitest Setup

```typescript
// vitest.config.ts
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    globals: true,
    environment: "node",      // or "jsdom" for React
    coverage: {
      provider: "v8",
      reporter: ["text", "lcov"],
    },
  },
});
```

```typescript
// example test
import { describe, it, expect, vi } from "vitest";

describe("parseUser", () => {
  it("returns ok for valid input", () => {
    const result = parseUser({ name: "Alice", email: "a@b.com" });
    expect(result.success).toBe(true);
  });

  it("returns error for invalid email", () => {
    const result = parseUser({ name: "Alice", email: "not-an-email" });
    expect(result.success).toBe(false);
  });
});
```

## Vite Config (SPA)

```typescript
// vite.config.ts
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import path from "path";

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
      "@shared": path.resolve(__dirname, "./src/shared"),
    },
  },
});
```

## pnpm Workspaces (monorepo)

```yaml
# pnpm-workspace.yaml
packages:
  - "packages/*"
  - "apps/*"
```

```json
// Root package.json
{
  "scripts": {
    "build": "tsc --build",
    "typecheck": "tsc --build --noEmit",
    "test": "vitest run",
    "lint": "eslint ."
  }
}
```

## tsconfig for Node.js CLI/tooling (no bundler)

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "Node16",
    "moduleResolution": "Node16",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "esModuleInterop": true,
    "outDir": "./dist",
    "rootDir": "./src",
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true
  }
}
```

Note: Use `module: "Node16"` + `.js` extensions in imports for native ESM Node.
Use `tsx` or `ts-node --esm` for running TS directly in dev.

## tsconfig for React SPA (Vite)

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "jsx": "react-jsx",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "skipLibCheck": true,
    "noEmit": true
  }
}
```
