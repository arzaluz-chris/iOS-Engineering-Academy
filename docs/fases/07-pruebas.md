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

## Lote 2 de contenido (3 de noviembre de 2026)

| Prueba | Dónde corrió | Resultado |
| --- | --- | --- |
| `npm run validate` | Local y CI | Sin errores; 19 lecciones, 92 ejercicios, 30 recursos |
| `npm test` (Vitest) | Local y CI | 35 pruebas en 5 archivos, todas pasan |
| `npm run build` | Local y CI | Correcto |
| `swift test` | Local, contenedor `swift:6.3` (Swift 6.3.3, Linux x86_64) | 22 pruebas en 6 suites, todas pasan |
| `swift test` | GitHub Actions, macOS (Xcode 26.6, Swift 6.3.3), commit `bf42911` | 22 pruebas en 6 suites, todas pasan; los fragmentos de lecciones suman 17 casos de predicción y 97 bloques Swift |
| `npm run check-links` | Local | 30/30 enlaces responden |
| Revisión visual | Chromium headless local | Lecciones m02-l02, m02-l03, m03-l04 y m04-l05 sin errores de consola; diagramas de texto, tablas con `\|\|` y el ejercicio de predicción en pseudocódigo se ven bien |

### Pruebas nuevas

| Archivo | Qué prueba |
| --- | --- |
| `swift/Tests/LessonSnippetsTests` | Lee `content/lessons/`. Ejecuta cada ejercicio de predicción y compara su salida exacta con `output` (con `lang: pseudo`, ejecuta la traducción a Swift de la solución). En lecciones `probado`, ejecuta cada bloque Swift del texto y de las soluciones y lo compara con el bloque `output` siguiente; comprueba los errores de compilación (`no-compila`), advertencias (`advertencia`) y errores en ejecución (`falla-en-ejecucion`) que cita el texto. Verifica que las soluciones de las predicciones repiten el mismo `output`. Una prueba de cordura falla si el extractor deja de encontrar ejercicios |
| `tests/content.test.ts` | El validador exige la traducción a Swift en las predicciones en pseudocódigo; `lang` es `swift` por defecto |
| `tests/ui.test.tsx` | Una predicción en pseudocódigo se etiqueta como pseudocódigo, muestra su indicación propia y se califica automáticamente |

### Lo que las pruebas encontraron

- Una salida esperada inexacta: 36.6 °C son `97.88000000000001` °F al imprimir un `Double` (m04-l04-e5).
- Un bloque de salida que esperaba un salto de línea después de `terminator: ""` (m03-l05-e4).
- Lo impreso antes de un error en ejecución se perdía cuando la salida iba a un pipe. El ejecutor de fragmentos ahora usa salida por líneas, como una terminal o la consola de Xcode.

### Limitaciones

- Las pruebas corren con Swift 6.3.3; las lecciones declaran Swift 6.4. Ningún fragmento usa algo exclusivo de 6.4.
- Lo que el Módulo 3 describe de la interfaz de Xcode no tiene prueba automatizada.
