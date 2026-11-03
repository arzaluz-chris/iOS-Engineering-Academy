# Fase 4. Diseño técnico

El documento completo es `docs/ARQUITECTURA.md`. Aquí se registran las decisiones de esta fase y su justificación.

| Tema | Decisión |
| --- | --- |
| Stack | Vite 8, React 19, TypeScript estricto (`noUncheckedIndexedAccess`) |
| Arquitectura | Contenido como datos (`content/`), parser y validador puros (`src/content/`), capa de progreso (`src/db/`), páginas por sección (`src/pages/`) |
| Componentes | Markdown con avisos y copia de código, editor CodeMirror diferido, ejercicios por tipo, rúbricas, notas, marcadores |
| Modelo de datos | Unión discriminada de ejercicios en Zod; IDs kebab-case globales; 11 tablas en IndexedDB |
| Persistencia | Dexie 4; `localStorage` solo para el tema; respaldo JSON validado y transaccional |
| Navegación | Hash routing propio, compatible con GitHub Pages y con `base: './'` |
| Búsqueda | MiniSearch en memoria, sin acentos, prefijo y difusa |
| Ejercicios | A–D automáticos, E–H por rúbrica; Swift se ejecuta fuera del navegador |
| Repaso | ts-fsrs 6, FSRS-7 fijado, historial completo |
| Pruebas | Vitest (jsdom, fake-indexeddb, Testing Library), validador de contenido, Swift Testing en macOS, verificación de enlaces |
| CI/CD | `deploy.yml` (Linux), `swift.yml` (macOS), `links.yml` (semanal), Dependabot mensual |

## Alternativas descartadas

| Alternativa | Por qué no |
| --- | --- |
| Backend propio para ejecutar Swift | Costo, mantenimiento y riesgo de seguridad desproporcionados para un uso personal |
| Next.js | Sus ventajas (SSR, rutas de servidor) no aplican a un sitio estático en Pages |
| Astro (recomendado en la investigación) | Versión mayor más reciente que la investigada; casi toda la app es interactiva |
| react-router | Un enrutador por hash de unas 40 líneas basta |
| Contenido en TypeScript | Exigiría escapar los bloques de código Swift |
| SM-2 | Menos preciso que FSRS |
| Compilar Swift a Wasm en el navegador | No existe una opción mantenida que compile código del usuario en el cliente |

## Riesgos técnicos

- **Tamaño del bundle principal** (alrededor de 920 kB sin comprimir, 285 kB gzip). Mitigado con carga diferida del editor. Se puede dividir más por página si crece el contenido.
- **Origen compartido en GitHub Pages:** base de datos con nombre propio.
- **Versión de Swift en CI:** el runner usa la versión de Xcode que GitHub preinstala; puede ir atrás de la última publicada.
