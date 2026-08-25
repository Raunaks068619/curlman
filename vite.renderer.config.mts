import path from 'node:path';
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';

export default defineConfig({
  plugins: [react()],
  root: 'apps/electron/src/renderer',
  build: {
    outDir: path.resolve('.vite/renderer/main_window'),
  },
});
