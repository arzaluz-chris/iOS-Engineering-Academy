---
id: two-sum
title: Two Sum
difficulty: facil
order: 3
patterns: [Hash map, Complemento]
prerequisites: [m07, m08, m15]
summary: Encontrar dos posiciones cuya suma es un objetivo. El ejemplo canónico de cambiar memoria por tiempo con un diccionario.
solutionFile: TwoSum.swift
testFile: TwoSumTests.swift
starter: |
  func twoSum(_ nums: [Int], _ target: Int) -> [Int]? {
      // Tu solución
      return nil
  }
time: O(n) en promedio
space: O(n)
edgeCases:
  - Dos valores iguales que suman el objetivo, como [3, 3] con 6
  - Un valor que es la mitad del objetivo pero aparece una sola vez
  - Negativos y cero
  - Sin solución
askInterviewer:
  - ¿Siempre existe exactamente una solución, o debo manejar ninguna o varias?
  - ¿Devuelvo índices o valores?
  - ¿La lista está ordenada?
  - ¿Puede haber valores repetidos?
hints:
  - Para cada número `x`, ¿qué número necesitas encontrar? Escríbelo en función de `target` y `x`.
  - Si guardaras los números que ya recorriste junto con su índice, ¿cuánto costaría preguntar si ya viste el que necesitas?
  - Busca el complemento antes de guardar el número actual. ¿Por qué importa ese orden?
followUps:
  - Si la lista estuviera ordenada, ¿cómo lo resolverías con O(1) de memoria? (Two pointers.)
  - ¿Y si hay que devolver todas las parejas distintas?
  - ¿Qué riesgo tiene calcular target - x con valores cercanos a Int.max?
rubric:
  - Expliqué la solución O(n²) y por qué no escala.
  - Usé un diccionario de valor a índice para buscar el complemento en O(1) promedio.
  - Busqué el complemento antes de insertar el valor actual, para no usar el mismo índice dos veces.
  - Manejé el caso sin solución.
codeStatus: revisado
---

Dada una lista de enteros `nums` y un entero `target`, devuelve los índices `[i, j]` de dos elementos **distintos** (`i ≠ j`) cuya suma es `target`, con `i < j`. Si no existen, devuelve `nil`.

```swift
twoSum([2, 7, 11, 15], 9)  // [0, 1]  porque 2 + 7 = 9
twoSum([3, 2, 4], 6)       // [1, 2]  porque 2 + 4 = 6
twoSum([3, 3], 6)          // [0, 1]
twoSum([1, 2, 3], 100)     // nil
```

**Restricciones:** `0 ≤ nums.count ≤ 10^4`; `-10^9 ≤ nums[i], target ≤ 10^9`. Si hay varias soluciones, devuelve la primera cuyo segundo índice es menor.

<!-- revelar -->

## Enfoque inicial

Para cada número `x`, el número que lo completa es `target - x`. El problema se reduce a preguntar, rápido, «¿ya vi `target - x`, y en qué posición?».

## Solución ingenua

Probar todas las parejas `(i, j)` con `i < j`:

```swift
func twoSum(_ nums: [Int], _ target: Int) -> [Int]? {
    for i in nums.indices {
        for j in (i + 1)..<nums.count where nums[i] + nums[j] == target {
            return [i, j]
        }
    }
    return nil
}
```

## Problemas de la solución ingenua

Es **O(n²)** en tiempo. Con 10^4 elementos son cerca de 5·10^7 sumas: funciona, pero en entrevista el siguiente paso esperado es mejorarla. Su ventaja es que usa O(1) de memoria; menciónalo, porque es un trade-off real.

## Solución optimizada

Recorre una vez. Para cada valor, busca su complemento en un diccionario `[valor: índice]` con lo ya recorrido; si está, terminaste. Si no, guarda el valor actual y sigue.

## Explicación línea por línea

- `var indexByValue: [Int: Int] = [:]`: para cada valor ya visto, su índice.
- `for (index, value) in nums.enumerated()`: recorre con posición y valor a la vez.
- `if let complementIndex = indexByValue[target - value]`: leer un diccionario devuelve un optional, porque la clave puede no existir. `if let` lo desempaqueta solo si existe.
- `return [complementIndex, index]`: el complemento se vio antes, así que su índice es menor.
- `indexByValue[value] = index`: se guarda **después** de buscar. Si se guardara antes, con `[3, 5]` y objetivo 6, el 3 encontraría a sí mismo como complemento.
- Si hay valores repetidos, la última asignación sobrescribe el índice anterior; no afecta, porque cualquier pareja válida se detecta al llegar a su segundo elemento.

## Errores frecuentes

- Insertar antes de buscar y emparejar un elemento consigo mismo.
- Ordenar la lista para usar two pointers y perder los índices originales.
- Usar `firstIndex(of:)` dentro del ciclo: parece O(n), pero es O(n²), porque `firstIndex` recorre la lista.

## Variante

**Two Sum II** (lista ordenada): un índice al inicio y otro al final. Si la suma es menor que el objetivo, avanza el izquierdo; si es mayor, retrocede el derecho. O(n) de tiempo y O(1) de memoria.
