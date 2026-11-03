# Arquitectura

## Restricciones que la definen

- Se publica en **GitHub Pages**: sitio 100 % estático, sin servidor ni reescritura de rutas.
- Un solo usuario; sin cuentas ni backend. El progreso vive en el navegador.
- El navegador **no puede compilar Swift** (ver `INVESTIGACION.md`): el código se escribe aquí y se ejecuta en Xcode o con `swift test`.
- El contenido debe poder crecer sin tocar la aplicación.

## Stack

| Pieza | Elección | Por qué |
| --- | --- | --- |
| Compilación | Vite 8 | Sitio estático, `import.meta.glob` para cargar el contenido como texto en compilación. |
| UI | React 19 + TypeScript estricto | Componentes reutilizables y tipado de punta a punta. |
| Rutas | Enrutador propio por hash (`src/router.ts`, ~40 líneas) | GitHub Pages no reescribe rutas; con `#/...` ninguna recarga da 404. Evita una dependencia. |
| Esquema de contenido | Zod 4 | Un solo esquema para navegador, script de validación y pruebas. |
| Contenido | Markdown con frontmatter YAML; ejercicios en bloques ````` ````exercise ````` | Se escribe como texto, se revisa en diffs, no requiere CMS. |
| Markdown | marked + highlight.js (Swift, bash, JSON) | Renderizado en cliente con resaltado y avisos propios (`> [!error]`). |
| Editor | CodeMirror 6 con el modo Swift de `@codemirror/legacy-modes`, cargado bajo demanda | Ligero y accesible; solo se descarga en páginas con editor. |
| Persistencia | IndexedDB con Dexie 4; `localStorage` solo para el tema | Volumen de intentos y borradores; consultas indexadas; transacciones para importar. |
| Búsqueda | MiniSearch, índice en memoria creado al primer uso | Búsqueda por prefijo, difusa y sin acentos sobre todo el contenido. |
| Repaso espaciado | ts-fsrs 6, modelo **FSRS-7** fijado explícitamente | Más preciso que SM-2; se guarda el historial completo (`revlog`) para poder reprogramar si se cambia de modelo. |
| Tipografía | IBM Plex Sans, IBM Plex Mono y Source Serif 4, empaquetadas | Funciona sin conexión; serif para lectura larga. |
| Pruebas | Vitest + Testing Library + fake-indexeddb; Swift Testing para los retos | Ver «Pruebas». |

Next.js y Astro se descartaron: sus ventajas (SSR, páginas por ruta) no aportan aquí y la interactividad es casi toda del lado del cliente.

## Organización de archivos

```
content/                 Curso (datos, sin código de interfaz)
  curriculum.yaml        Etapas y módulos con objetivos, temas y prerrequisitos
  resources.yaml         Registro de enlaces externos con estado de verificación
  lessons/mNN/*.md       Lecciones; cada una con sus ejercicios embebidos
  challenges/*.md        Retos; código en swift/
  interview/*.yaml       Preguntas de entrevista por categoría
  projects/*.md          Proyectos con hitos
swift/                   Swift Package con soluciones y pruebas de los retos
src/
  content/               schema.ts, parse.ts (puro), validate.ts (puro), index.ts (carga en navegador)
  db/                    db.ts (Dexie), actions.ts, backup.ts, stats.ts
  srs/                   scheduler.ts (FSRS)
  search/                índice de búsqueda
  exercises/             calificación (grade.ts) y componente de ejercicios
  components/            Markdown, editor, UI común
  pages/                 una página por sección
scripts/                 validate-content.ts, check-links.ts, load-content.ts
tests/                   pruebas Vitest
```

`parse.ts` y `validate.ts` no dependen del navegador ni de Node: el navegador les pasa el contenido con `import.meta.glob` y los scripts y pruebas con `fs` (`scripts/load-content.ts`). Así la validación que corre en CI es exactamente la lógica que usa la app.

## Modelo de datos

Contenido (solo lectura, ver `src/content/schema.ts`): `Stage`, `Module`, `Lesson` (con `segments` de Markdown y ejercicios, `cards` de repaso), `Exercise` (unión discriminada por `type`), `Challenge`, `InterviewQuestion`, `Project`, `Resource`. Los IDs son kebab-case y únicos en todo el curso, porque el progreso se guarda por ID.

Progreso (IndexedDB, `src/db/db.ts`):

| Tabla | Contenido |
| --- | --- |
| `lessons` | estado por lección (`en-curso`, `completada`) y última sección vista |
| `attempts` | cada intento de ejercicio, reto o pregunta, con resultado, puntaje y si fue calificación automática o autoevaluación |
| `drafts` | borradores de código por ejercicio o reto |
| `notes`, `bookmarks` | notas y marcadores vinculados a lecciones, ejercicios, retos, preguntas, proyectos o recursos |
| `challenges`, `questions`, `projects` | estado de retos, preguntas y hitos de proyectos |
| `cards`, `revlog` | tarjetas FSRS y su historial completo |
| `activity` | registro para «Actividad reciente» |

Reglas de dominio:

- Abrir una lección la marca **en curso**, nunca completada.
- Para completar una lección hay que **intentar** todos sus ejercicios. Al completarla, sus conceptos entran al repaso.
- Una lección está **dominada** si está completada y el último intento de cada ejercicio es correcto.
- Todo intento no correcto agrega el elemento al repaso (o lo vuelve a poner pendiente hoy).
- El repaso prioriza temas marcados como difíciles, luego fallos, luego vencimiento.
- El tiempo de estudio **no** se registra: no hay forma fiable de medirlo.

## Respaldo

`src/db/backup.ts` exporta todas las tablas a un JSON con `format` y `version`. La importación valida el archivo completo con Zod antes de tocar la base y reemplaza todo dentro de una transacción. Un archivo inválido no modifica nada. GitHub Pages comparte el origen `arzaluz-chris.github.io` entre repositorios; la base usa el nombre `iea:ios-engineering-academy` para no chocar con otros proyectos.

## Ejercicios y ejecución de Swift

- Tipos A a D (comprensión, predicción, completar, encontrar errores): respuesta estructurada, **calificación automática**.
- Tipos E a H (resolver, explicar, refactorizar, diseñar): editor y **rúbrica de autoevaluación**. La interfaz lo indica en cada ejercicio.
- Las soluciones se ocultan hasta que el estudiante las pide; si no hay intento previo, se pide confirmación.
- Las soluciones de los retos se muestran desde los mismos archivos de `swift/` que CI compila y prueba, así lo publicado coincide con lo probado.

## Pruebas

- `npm run validate`: esquema e integridad (IDs duplicados, prerrequisitos inexistentes o fuera de orden, recursos inexistentes, ejercicios sin solución, huecos sin respuesta, opción única con varias correctas, bloques de código sin cerrar, enlaces a videos, URLs duplicadas, retos sin archivos Swift o sin `@Test`).
- `npm test`: contenido real, validador con casos negativos, calificación, persistencia, repaso, respaldo e importación inválida, búsqueda, enrutador, dominio de lecciones y componentes.
- `swift test`: soluciones de referencia.
- `npm run check-links`: enlaces de recursos (en CI semanal).

## Decisiones registradas

1. **Sin backend.** El único motivo para uno sería ejecutar Swift en servidor, con costo y riesgo de seguridad desproporcionados para un uso personal.
2. **Hash routing** en lugar de un `404.html` de respaldo: más simple y sin parpadeos.
3. **Contenido en Markdown + YAML** en lugar de TypeScript: el código Swift dentro de lecciones no necesita escaparse.
4. **FSRS-7 fijado** y `revlog` completo para migraciones futuras.
5. **Concurrencia antes de networking.** El orden de etapas pone «Concurrencia y memoria» (8) antes de «Datos, arquitectura y testing» (9) porque networking con `async/await` la necesita. La especificación original listaba networking primero; se priorizó la progresión pedagógica.
