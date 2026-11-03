import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'

// base './' + hash routing: el sitio funciona en cualquier subruta de GitHub Pages
// (arzaluz-chris.github.io/<repo>/) y también al abrir dist/ con `vite preview`.
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
