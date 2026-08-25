import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['apps/electron/src/renderer/test/setup.ts'],
  },
});
