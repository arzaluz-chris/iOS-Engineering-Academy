import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'

// base './' + hash routing: the site works under any GitHub Pages subpath
// (arzaluz-chris.github.io/<repo>/) and also when serving dist/ with `vite preview`.
export default defineConfig({
  base: './',
  plugins: [react()],
  build: { chunkSizeWarningLimit: 1000 },
  server: { fs: { allow: ['.'] } },
  test: {
    environment: 'jsdom',
    setupFiles: ['./tests/setup.ts'],
    include: ['tests/**/*.test.ts', 'tests/**/*.test.tsx'],
  },
})
