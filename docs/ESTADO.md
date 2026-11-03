# Estado del proyecto

Última actualización: 3 de noviembre de 2026.

## Hecho

**Plataforma (Fase 5 completa):** navegación del currículo, lecciones, los ocho formatos de ejercicio, calificación automática y por rúbrica, retos con revelado progresivo y tres modos de práctica, simulador de entrevistas con seguimientos y resultados por categoría, proyectos con hitos, repaso espaciado FSRS, notas, marcadores, buscador global, dashboard con datos reales, exportación e importación validadas, modo claro y oscuro, diseño adaptable, despliegue a GitHub Pages.

**Contenido:**

| Tipo | Escrito | Objetivo de planificación |
| --- | --- | --- |
| Etapas | 15 (mapa completo) | 12–16 |
| Módulos | 49 (mapa con objetivos, temas y prerrequisitos) | — |
| Lecciones | 4 (M1: 3, M4: 1) | más de 100 |
| Ejercicios de lecciones | 16 (los 8 formatos) | al menos 100 |
| Retos de código | 5, con solución y pruebas Swift | al menos 100 |
| Preguntas de entrevista | 17 en 9 categorías, incluida seguridad | banco amplio |
| Proyectos | 8 especificados con hitos | 8 |
| Recursos | 20, ninguno verificado todavía | — |

**Pruebas ejecutadas en el entorno de construcción:** `npm run validate` (sin errores), `tsc --noEmit` (sin errores), `npm test` (32 pruebas, todas pasan), `vite build` (correcto), revisión visual en Chrome sin errores de consola en escritorio, móvil, claro y oscuro.

**Swift:** el workflow `swift.yml` corrió `swift test` en macOS (runner con Xcode 26.6 y Swift 6.3.3): 18 pruebas en 5 suites, todas pasan. Los cinco retos están marcados como `probado`. El runner aún no usa Xcode 27 / Swift 6.4; el código no usa nada exclusivo de 6.4.

**Publicado:** https://arzaluz-chris.github.io/iOS-Engineering-Academy/

**No ejecutado:** `check-links` (el entorno de construcción no tenía red hacia Apple ni swift.org); corre con el workflow semanal `links.yml` o a mano desde Actions.

## Criterios de aceptación que todavía no se cumplen

- Más de 100 lecciones, 100 ejercicios y 100 retos: falta la producción de contenido de los módulos 2, 3 y 5 a 49.
- Enlaces revisados: falta correr la verificación y actualizar `status` y `verifiedAt` en `resources.yaml`.
- Swift se enseña con profundidad, UIKit y SwiftUI tienen etapas completas: hoy solo existe su plan.
- Pruebas de accesibilidad automatizadas: no implementadas; se revisó manualmente estructura, foco y contraste.

## Siguiente paso

Producir contenido por lotes, un módulo a la vez, en este orden:

1. M2 Pensamiento computacional y M3 Entorno de desarrollo (completan la etapa 1).
2. M4 a M8 (etapa 2), con al menos 6 lecciones por módulo.
3. Retos de los patrones de arrays y hashing en paralelo a M7.

Para cada lote: escribir lecciones, revisar exactitud técnica, verificar prerrequisitos, ejecutar ejemplos Swift en Xcode y marcar `codeStatus` honestamente, `npm run validate && npm test`, revisar en el navegador, commit.

## Cómo continuar en otra sesión

Lee `CLAUDE.md` en la raíz, luego este archivo y `docs/CONTENIDO.md`. El esquema está en `src/content/schema.ts`; la lección `content/lessons/m04/01-print-literales-expresiones.md` es el modelo de referencia de una lección con los ocho formatos de ejercicio.
