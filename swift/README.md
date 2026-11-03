# Soluciones de los retos y fragmentos de las lecciones

Swift Package con una solución y sus pruebas (Swift Testing) por cada reto de `content/challenges/`. La web muestra estos mismos archivos.

```bash
swift test                          # todas las pruebas
swift test --filter TwoSumTests     # un reto
```

Requiere Swift 6 (Xcode 16 o posterior). Para practicar con tu propia solución, sustituye el archivo del reto en `Sources/Challenges/` en una rama aparte y corre sus pruebas.

## Fragmentos de las lecciones

`Tests/LessonSnippetsTests` compila y ejecuta los fragmentos de `content/lessons/` (ejercicios de predicción y, en lecciones `probado`, cada bloque Swift) y compara su salida con la que afirma la lección. Las reglas están en `docs/CONTENIDO.md`. Necesita `swiftc` en el `PATH`.

```bash
swift test --filter LessonSnippetsTests
```
