# Fase 7. Pruebas

Ejecutadas el 3 de noviembre de 2026.

| Prueba | Dónde corrió | Resultado |
| --- | --- | --- |
| `npm run validate` | Local y CI | Sin errores; 47 avisos de módulos sin lecciones |
| `tsc --noEmit` | Local y CI | Sin errores |
| `npm test` (Vitest) | Local y CI | 32 pruebas en 5 archivos, todas pasan |
| `vite build` | Local y CI | Correcto |
| `swift test` | GitHub Actions, macOS (Xcode 26.6, Swift 6.3.3) | 18 pruebas en 5 suites, todas pasan |
| `check-links` | GitHub Actions, Linux | 20/20 enlaces responden |
| Revisión visual | Chrome headless local | Sin errores de consola en dashboard, currículo, lecciones, retos, entrevistas y repaso; escritorio 1440 px y móvil 390 px; claro y oscuro |
| Despliegue | GitHub Pages | Publicado en https://arzaluz-chris.github.io/iOS-Engineering-Academy/ |

## Cobertura de las pruebas web

| Archivo | Qué prueba |
| --- | --- |
| `tests/content.test.ts` | Contenido real sin errores; 12–16 etapas; módulo de seguridad; lecciones con objetivos, ejercicios y soluciones; retos con código y pruebas Swift; sin videos. Validador con casos negativos: prerrequisitos inexistentes, IDs duplicados, huecos sin respuesta, opción única con dos correctas, frontmatter inválido |
| `tests/grade.test.ts` | Opción única y múltiple, predicción (espacios, CRLF, alternativas), huecos, separación de huecos |
| `tests/persistence.test.ts` | Abrir no completa; completar agrega tarjetas; fallos al repaso; FSRS reprograma y registra historial; prioridad del repaso; exportar, borrar e importar sin pérdida; rechazo de respaldos inválidos; importación inválida no toca datos |
| `tests/search-router.test.ts` | Búsqueda sin acentos, por patrón y en preguntas; rutas con hash; dominio de lección según último intento |
| `tests/ui.test.tsx` | Ejercicio de comprensión registra intento automático; la solución no se muestra antes de pedirla; dashboard vacío sin métricas inventadas; currículo con todas las etapas |

## No cubierto todavía

- Pruebas automatizadas de accesibilidad (por ejemplo, axe) y de navegación de extremo a extremo en navegador real dentro de CI.
- Persistencia tras recargar en un navegador real (probada con fake-indexeddb, no con recarga real en CI).
