# Fase 6. Producción de contenido

## Lote 1 (3 de noviembre de 2026)

| Pieza | Cantidad | Detalle |
| --- | --- | --- |
| Lecciones | 4 | M1: qué es programar; del código fuente al programa; Swift, Xcode e iOS. M4: print, comentarios, literales y expresiones |
| Ejercicios | 16 | Los ocho formatos; los siete de `m04-l01` cubren B a G |
| Tarjetas de repaso | 13 | En el frontmatter de cada lección |
| Retos | 5 | FizzBuzz, Contains Duplicate, Two Sum, Valid Palindrome, Valid Parentheses |
| Preguntas de entrevista | 17 | Swift (4), memoria (1), concurrencia (2), UIKit (2), SwiftUI (1), arquitectura (2), seguridad (3), testing (1), system design (1) |
| Proyectos | 8 | Especificados con requisitos, criterios de aceptación e hitos |
| Recursos | 20 | Verificados el 3 nov 2026 |

## Checklist del lote

| Paso | Resultado |
| --- | --- |
| 1. Escribir lecciones | Hecho |
| 2. Revisar exactitud técnica | Revisión estática. Salidas de predicción calculadas a mano y revisadas; comportamiento de `print`, división entera, precedencia, comentarios anidados y mensajes de error del compilador contrastados con la documentación de Swift |
| 3. Comprobar prerrequisitos | Validador sin errores |
| 4. Verificar ejemplos | Ejemplos de lecciones: **revisados, no ejecutados** (`codeStatus: revisado` o `ilustrativo`). Código de retos: ejecutado en CI |
| 5. Comprobar soluciones | `swift test`: 18 pruebas en 5 suites pasan |
| 6. Verificar enlaces | 20/20 |
| 7. Pruebas y rúbricas | Todas las piezas con rúbrica o calificación automática |
| 8. Validaciones automáticas | `npm run validate` sin errores |
| 9. Corregir errores | Se corrigieron 9 errores de YAML detectados por el validador (valores con «: » sin comillas) |

## Pendiente para el siguiente lote

Resuelto en el lote 2: las predicciones de `m04-l01` y `m01-l02` se verificaron ejecutándolas y ambas lecciones son `probado`.

## Lote 2 (3 de noviembre de 2026)

| Pieza | Cantidad | Detalle |
| --- | --- | --- |
| Lecciones | 15 nuevas (19 en total) | M2: descomposición, patrones y abstracción; pseudocódigo; diagramas de flujo; tablas de seguimiento; casos límite y método de diseño. M3: instalar Xcode y comprobar versiones; proyecto, ventana y simulador; Swift desde la terminal y Swift Packages; errores, advertencias y errores en ejecución; breakpoints y documentación. M4: constantes y variables; tipos e inferencia; anotaciones y conversión; comparación y lógicos; interpolación |
| Ejercicios | 76 nuevos (92 en total) | Cada lección tiene al menos 4, con al menos una predicción y un ejercicio de resolver |
| Tarjetas de repaso | 61 nuevas (74 en total) | |
| Recursos | 10 nuevos (30 en total) | Control Flow, Functions y Strings and Characters del libro de Swift; cuatro páginas de documentación de Xcode (componentes, crear proyecto, breakpoints, depuración paso a paso); documentación de SwiftPM; guía de swift.org para herramientas de línea de comandos; tutorial de LLDB. Con `status: no-verificado`; respondieron 200 a `npm run check-links` |

### Checklist del lote

| Paso | Resultado |
| --- | --- |
| 1. Verificar las predicciones pendientes de m01-l02 y m04-l01 | Coinciden con la ejecución real. Ambas lecciones pasaron a `probado` |
| 2. Escribir lecciones | Hecho, M2 y M3 completos, M4 completo (lecciones 1 a 6) |
| 3. Revisar exactitud técnica | Versiones de Xcode y Swift tomadas de `02-investigacion.md`; la lección m03-l01 enseña a comprobarlas y remite a la tabla oficial, sin suponer la versión instalada. Menús de Xcode, Components, breakpoints y comandos `v`/`p`/`po` contrastados con la documentación de Apple (JSON de developer.apple.com). Salidas de `swift package init`, `swift run` y `swift test` obtenidas ejecutándolos con Swift 6.3.3 |
| 4. Comprobar prerrequisitos | Validador sin errores |
| 5. Verificar ejemplos | Todo bloque Swift de las 17 lecciones con código se ejecuta en `LessonSnippetsTests` (salvo los `ilustrativo`, listados en `docs/ESTADO.md`) |
| 6. Corregir lo que la ejecución reveló | 36.6 °C da `97.88000000000001` °F, no `97.88` (m04-l04-e5, ahora explica la precisión de `Double`). Un bloque con `terminator: ""` seguido de una salida esperada con salto final (m03-l05). Un enunciado que afirmaba que el compilador señalaba la línea 3 cuando señala el final de la línea 2 (m03-l04-e3). Además, el validador detectó un error de YAML en una tarjeta (m04-l03) |
| 7. Verificar enlaces | 30/30 con `npm run check-links` |
| 8. Validaciones automáticas | `npm run validate`, `npm test`, `npm run build` y `swift test` sin errores |

### Decisiones

- **Predicciones en pseudocódigo.** El Módulo 2 se cursa antes de aprender Swift, pero toda predicción debe quedar verificada. Se agregó `lang: pseudo` a los ejercicios de predicción: el código se muestra como pseudocódigo y la solución incluye su traducción a Swift, que es lo que ejecutan las pruebas.
- **Mensajes del compilador.** Las lecciones citan mensajes de Swift 6.3 y lo dicen. Las pruebas comprueban que el texto citado sigue apareciendo, así que un cambio de redacción en una versión futura hará fallar la prueba en lugar de dejar la lección desactualizada.
