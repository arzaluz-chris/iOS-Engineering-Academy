---
id: p02
number: 2
title: Biblioteca de algoritmos con pruebas
summary: Tu propio paquete Swift con las soluciones de los retos, cada una con pruebas. Aprendes a estructurar problemas y a comprobar soluciones de forma automática.
prerequisites: [m14, m16]
objectives:
  - Organizar soluciones por patrón en un Swift Package.
  - Escribir pruebas parametrizadas con casos límite.
  - Comparar dos soluciones del mismo problema con pruebas de equivalencia.
requirements:
  - Un paquete con un target por patrón o un archivo por problema.
  - Cada solución tiene al menos una prueba por caso límite listado en su reto.
  - Cada archivo documenta complejidad temporal y espacial.
acceptance:
  - "`swift test` pasa en tu Mac."
  - Al menos 10 retos resueltos sin consultar la solución de referencia.
  - Cada reto tiene una prueba que compara la solución optimizada con una ingenua.
milestones:
  - id: p02-h1
    title: Estructura del paquete
    tasks: ["Crea el paquete con un target de biblioteca y uno de pruebas.", "Agrega un workflow de CI que ejecute `swift test`."]
    concepts: [Swift Package Manager, CI]
  - id: p02-h2
    title: Patrones de hashing y two pointers
    tasks: ["Resuelve Two Sum, Contains Duplicate, Valid Palindrome y Valid Anagram con pruebas."]
    concepts: [Hash map, Two pointers]
  - id: p02-h3
    title: Pilas, ventanas y búsqueda binaria
    tasks: ["Resuelve Valid Parentheses, Best Time to Buy and Sell Stock y Binary Search con pruebas."]
    concepts: [Stack, Sliding window, Búsqueda binaria]
  - id: p02-h4
    title: Pruebas de equivalencia
    tasks: ["Para cada reto, prueba que la solución ingenua y la optimizada coinciden en casos generados."]
    concepts: [Pruebas parametrizadas]
---

## Relación con este repositorio

El directorio `swift/` del repositorio de la academia es un ejemplo de esta estructura: soluciones en `Sources/Challenges` y pruebas en `Tests/ChallengesTests`. Tu biblioteca es independiente; consulta la de referencia solo después de intentar cada reto.
