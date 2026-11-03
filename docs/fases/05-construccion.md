# Fase 5. Construcción incremental

Versión funcional mínima pedida por la especificación y su estado:

| Requisito | Estado | Dónde |
| --- | --- | --- |
| Navegación del currículo | Hecho | `src/pages/Curriculum.tsx` |
| Una lección completa | Hecho (4 lecciones) | `content/lessons/` |
| Un ejercicio de cada formato | Hecho (A–H en `m04-l01`) | `src/exercises/ExerciseBlock.tsx` |
| Evaluación | Hecho: automática A–D, rúbrica E–H, retos y entrevistas | `src/exercises/grade.ts`, `src/components/ui.tsx` |
| Progreso persistente | Hecho | `src/db/` |
| Búsqueda | Hecho | `src/search/`, `src/pages/Search.tsx` |
| Notas y marcadores | Hecho | `src/components/ui.tsx`, `src/pages/Notes.tsx` |
| Dashboard con datos reales | Hecho; el tiempo de estudio no se mide, y se dice | `src/pages/Dashboard.tsx` |
| Diseño adaptable, modo claro y oscuro | Hecho | `src/styles.css` |
| Retos con revelado progresivo y modos de práctica | Hecho | `src/pages/Challenges.tsx` |
| Simulador de entrevistas | Hecho | `src/pages/Interview.tsx` |
| Repaso espaciado | Hecho | `src/srs/`, `src/pages/Review.tsx` |
| Exportación e importación | Hecho | `src/db/backup.ts`, `src/pages/Settings.tsx` |
| Despliegue | Hecho | `.github/workflows/deploy.yml` |

## Diseño visual

Concepto: cuaderno técnico de ingeniería. IBM Plex Sans en la interfaz, Source Serif 4 en la prosa de las lecciones, IBM Plex Mono en código. Paleta fría (fondo gris azulado, acento azul petróleo) con colores de estado para correcto, advertencia y error. El único gesto visual fuerte son los errores frecuentes, presentados como diagnósticos de compilador. El currículo se presenta como una ruta numerada porque es una secuencia real. Fuentes empaquetadas para funcionar sin conexión.

## Historial

| Commit | Contenido |
| --- | --- |
| `b22ac10` | Plataforma base, contenido inicial, CI |
| `446dde8` | Retos marcados como probados tras `swift test` en macOS |
| `08e49a5` | Recursos marcados como verificados tras `links.yml` |
