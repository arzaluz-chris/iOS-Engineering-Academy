# Estado del proyecto

Última actualización: 3 de noviembre de 2026.

## Hecho

**Plataforma (Fase 5 completa):** navegación del currículo, lecciones, los ocho formatos de ejercicio, calificación automática y por rúbrica, retos con revelado progresivo y tres modos de práctica, simulador de entrevistas con seguimientos y resultados por categoría, proyectos con hitos, repaso espaciado FSRS, notas, marcadores, buscador global, dashboard con datos reales, exportación e importación validadas, modo claro y oscuro, diseño adaptable, despliegue a GitHub Pages.

**Contenido:**

| Tipo | Escrito | Objetivo de planificación |
| --- | --- | --- |
| Etapas | 15 (mapa completo) | 12–16 |
| Módulos | 49 en el mapa; 4 con lecciones (M1 a M4) | — |
| Lecciones | 19 (M1: 3, M2: 5, M3: 5, M4: 6) | más de 100 |
| Ejercicios de lecciones | 92 (comprensión 27, predicción 17, resolver 16, explicar 8, errores 8, completar 7, diseño 5, refactorizar 4) | al menos 100 |
| Tarjetas de repaso | 74 | — |
| Retos de código | 5, con solución y pruebas Swift | al menos 100 |
| Preguntas de entrevista | 17 en 9 categorías, incluida seguridad | banco amplio |
| Proyectos | 8 especificados con hitos | 8 |
| Recursos | 30; 20 verificados y 10 nuevos con `status: no-verificado` (los 30 respondieron 200 a `npm run check-links` el 3 nov 2026) | — |

Las etapas 1 (M1–M3) y el Módulo 4 completo de la etapa 2 están escritos.

**Código de las lecciones:** 17 de 19 lecciones tienen `codeStatus: probado`; las otras dos (m01-l01 y m01-l03) son `sin-codigo`. Ninguna lección queda en `revisado`. «Probado» significa que el target `swift/Tests/LessonSnippetsTests` compila y ejecuta cada bloque Swift de la lección y de las soluciones de sus ejercicios, y compara la salida con la que afirma el texto. Cada ejercicio de predicción, de cualquier lección, se ejecuta y su `output` se compara exactamente; en las predicciones en pseudocódigo (`lang: pseudo`, Módulo 2) se ejecuta su traducción a Swift. También se comprueban los mensajes de error de compilación (`swift no-compila`), las advertencias (`swift advertencia`) y los errores en ejecución (`swift falla-en-ejecucion`) que citan las lecciones. Lo que no se ejecuta: los bloques marcados `swift ilustrativo` (el manifiesto `Package.swift`, la plantilla `@main` de un paquete y la declaración de `print` en m03; la solución con `@main` de m03-l03-e4), los comandos de terminal y lo que se describe de la interfaz de Xcode, que se tomó de la documentación de Apple y no se pudo comprobar en Xcode desde el entorno de construcción.

**Pruebas ejecutadas en el entorno de construcción:** `npm run validate` (sin errores), `npm test` (35 pruebas, todas pasan), `npm run build` (correcto), `swift test` en el contenedor `swift:6.3` (Swift 6.3.3, Linux), revisión visual en Chromium sin errores de consola.

**Swift en CI:** el workflow `swift.yml` corre `swift test` en macOS (Xcode 26.6, Swift 6.3.3) en cada push que toca `swift/` o `content/lessons/`. Pasó con cada lote de este incremento. El runner aún no usa Xcode 27 / Swift 6.4; el código no usa nada exclusivo de 6.4.

**Publicado:** https://arzaluz-chris.github.io/iOS-Engineering-Academy/

**Enlaces:** el workflow `links.yml` comprueba existencia (para la documentación de Apple consulta su JSON de datos). Comprueba que el enlace responde, no que el contenido corresponda al tema; eso se revisó al escribir cada recurso.

## Cambios en la plataforma de este incremento

- Ejercicios de predicción con `lang: pseudo` (esquema, componente y validador, con pruebas en `tests/content.test.ts` y `tests/ui.test.tsx`): se muestran como pseudocódigo y el validador exige una traducción a Swift en la solución.
- Target Swift `LessonSnippetsTests` y modificadores de bloque `no-compila`, `advertencia`, `falla-en-ejecucion` e `ilustrativo`, documentados en `docs/CONTENIDO.md`.

## Criterios de aceptación que todavía no se cumplen

- Más de 100 lecciones, 100 ejercicios y 100 retos: faltan los módulos 5 a 49 y casi todos los retos.
- Swift se enseña con profundidad, UIKit y SwiftUI tienen etapas completas: hoy solo existe su plan.
- Pruebas de accesibilidad automatizadas: no implementadas.
- Las instrucciones de interfaz de Xcode del Módulo 3 (menús, atajos, *Settings › Components*, depurador) no se comprobaron en un Xcode real.

## Siguiente paso

1. Módulo 5, Control del flujo (`if`, `switch`, `guard` en su forma básica, `for-in`, `while`, `repeat-while`, `break`, `continue`), con al menos 6 lecciones. Retoma lo anunciado en M4: el operador ternario, `if` para elegir «año» o «años», el ciclo de la solución de bisiestos.
2. Módulos 6 a 8 (funciones, colecciones, opcionales), cerrando la etapa 2.
3. Retos de arrays y hashing en paralelo a M7.
4. Revisar en Xcode 27 las instrucciones de interfaz del Módulo 3 y, si coinciden, anotarlo aquí.
5. Si se confirman los 10 recursos nuevos con el workflow de enlaces, cambiar su `status` a `verificado` con fecha.

Para cada lote: escribir lecciones, ejecutar `cd swift && swift test` (o el contenedor `swift:6.3`), marcar `codeStatus` según lo que ejecutaron las pruebas, `npm run validate && npm test && npm run build`, revisar en el navegador, commit y push, y comprobar el workflow de Swift.

## Cómo continuar en otra sesión

Lee `CLAUDE.md` en la raíz, luego este archivo y `docs/CONTENIDO.md`. El esquema está en `src/content/schema.ts`; la lección `content/lessons/m04/01-print-literales-expresiones.md` es el modelo de referencia de una lección con los ocho formatos de ejercicio. Para ejecutar Swift sin Xcode: `docker run --rm -v "$PWD":/w -w /w/swift swift:6.3 swift test` (si el daemon de Docker no está corriendo, arráncalo con `dockerd`).
