# Fase 8. Auditoría del estado actual

Fecha: 3 de noviembre de 2026. Esta auditoría corresponde al cierre del primer incremento, no al proyecto terminado.

## Verificaciones

| Punto | Resultado |
| --- | --- |
| Las rutas funcionan | Sí; rutas inexistentes muestran una página que lo explica |
| Los enlaces funcionan | 20/20 recursos |
| Ejercicios con instrucciones completas | Sí, los 16 |
| Soluciones corresponden a sus enunciados | Revisadas; las de retos, además, probadas |
| Código coherente con la versión de Swift declarada | Sí; nada exclusivo de Swift 6.4 |
| El progreso se actualiza | Sí (pruebas de persistencia) |
| Funciona sin servicios externos | Sí; fuentes y contenido empaquetados |
| Interfaz accesible y legible | Revisión manual: estructura de encabezados, etiquetas, foco visible, contraste, Reduce Motion. Sin auditoría automatizada |
| Sin páginas vacías | Los módulos sin lecciones muestran su plan y lo dicen explícitamente |
| Sin botones decorativos | Sí |
| Sin errores de consola | Sí, en las páginas revisadas |
| Progresión pedagógica razonable | Sí en el mapa; el contenido escrito cubre solo el inicio |

## Criterios de aceptación de la especificación

| Criterio | Estado |
| --- | --- |
| Currículo completo y navegable | Mapa completo; contenido parcial |
| Formación desde cero | Sí, en las lecciones escritas |
| Swift, UIKit y SwiftUI con profundidad | **No todavía**: solo planificados |
| Algoritmos prácticos con soluciones verificables | Parcial: 5 retos probados |
| Proyectos progresivos | Sí, 8 especificados |
| Lecciones con objetivos y evaluaciones | Sí |
| Enlaces revisados; sin videos | Sí |
| Sin módulos principales vacíos | **No**: 47 de 49 módulos sin lecciones |
| Navegación, búsqueda, dashboard, progreso, notas, repaso, respaldo, responsive, temas, sin backend | Sí |
| Compila, pruebas pasan, validaciones automáticas, documentación | Sí |
| Calidad pedagógica (prerrequisitos, soluciones, casos límite, complejidad, razonamiento verbal) | Sí en lo escrito |

**Veredicto:** la plataforma cumple los criterios de producto y de calidad técnica. El curso no está terminado: faltan más de 96 lecciones, más de 84 ejercicios y más de 95 retos para llegar a los objetivos de planificación. El plan de producción está en `docs/ESTADO.md`.

## Actualización: lote 2 de contenido (3 de noviembre de 2026)

| Punto | Resultado |
| --- | --- |
| Los enlaces funcionan | 30/30 (`npm run check-links`); 10 recursos nuevos siguen con `status: no-verificado` hasta que los confirme el workflow semanal |
| Ejercicios con instrucciones completas | Sí, los 92 |
| Soluciones corresponden a sus enunciados | Revisadas; las salidas de las 17 predicciones y el código de las soluciones de lecciones `probado` se ejecutaron |
| Código coherente con la versión de Swift declarada | Sí; ejecutado con Swift 6.3.3 en Linux y macOS, nada exclusivo de 6.4 |
| `codeStatus` honesto | 17 lecciones `probado` (verificadas por `LessonSnippetsTests`), 2 `sin-codigo`, ninguna `revisado` |
| Versiones de Xcode | La lección m03-l01 usa las versiones de `02-investigacion.md`, enseña a comprobar la propia con `xcodebuild -version` y remite a la tabla oficial; no afirma cuál está instalada |
| Progresión pedagógica | Etapa 1 completa (M1–M3) y M4 completo. Las referencias hacia adelante (`if`, `for`, opcionales, ternario) se anuncian como tales y se explican lo justo |
| Sin errores de consola | Sí, en las páginas revisadas |

| Criterio | Estado |
| --- | --- |
| Formación desde cero | Sí: fundamentos, pensamiento computacional, entorno y primeros programas |
| Sin módulos principales vacíos | **No**: 45 de 49 módulos sin lecciones |
| Swift, UIKit y SwiftUI con profundidad | **No todavía** |
| Algoritmos con soluciones verificables | Parcial: 5 retos |

**Veredicto:** las lecciones escritas cumplen los criterios de calidad y todo su código está ejecutado. Faltan más de 81 lecciones y más de 95 retos para los objetivos de planificación. El siguiente paso está en `docs/ESTADO.md`.
