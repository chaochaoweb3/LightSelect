import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  base: './',
  plugins: [react(), tailwindcss()],
  build: {
    outDir: '../Resources/Web',
    emptyOutDir: true,
    rollupOptions: {
      input: {
        action: new URL('./src/action/index.html', import.meta.url).pathname,
        settings: new URL('./src/settings/index.html', import.meta.url).pathname,
        toolbar: new URL('./src/toolbar/index.html', import.meta.url).pathname
      }
    }
  }
})
