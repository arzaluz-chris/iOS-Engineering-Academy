---
id: contains-duplicate
title: Contains Duplicate
difficulty: facil
order: 2
patterns: [Hash set, Ordenamiento]
prerequisites: [m07, m15]
summary: ¿Algún valor se repite? El primer encuentro con el trade-off entre tiempo y memoria.
solutionFile: ContainsDuplicate.swift
testFile: ContainsDuplicateTests.swift
starter: |
  func containsDuplicate(_ nums: [Int]) -> Bool {
      // Tu solución
      return false
  }
time: O(n) en promedio
space: O(n)
edgeCases:
  - Lista vacía
  - Un solo elemento
  - Negativos y valores extremos como Int.max
  - El duplicado está al final
askInterviewer:
  - ¿Qué tamaño puede tener la lista?
  - ¿Puedo modificar la lista de entrada, por ejemplo ordenarla en su lugar?
  - ¿Importa la memoria adicional?
hints:
  - Comparar cada pareja funciona, pero ¿cuántas parejas hay en una lista de n elementos?
  - ¿Qué estructura responde en tiempo constante «¿ya vi este valor?»?
followUps:
  - Si no puedes usar memoria adicional proporcional a n, ¿qué haces y qué cuesta?
  - "¿Qué cambia si la pregunta es «¿hay dos valores iguales a distancia máxima k?»? (Contains Duplicate II: ventana deslizante con Set.)"
  - ¿Por qué decimos «O(n) en promedio» y no «O(n)» a secas para un Set?
rubric:
  - Propuse primero la solución de fuerza bruta y expliqué su costo O(n²).
  - Llegué a la solución con Set en O(n) tiempo y O(n) espacio.
  - Mencioné la alternativa de ordenar, O(n log n), y cuándo conviene.
codeStatus: revisado
---

Dada una lista de enteros `nums`, devuelve `true` si algún valor aparece al menos dos veces, y `false` si todos son distintos.

```swift
containsDuplicate([1, 2, 3, 1])  // true
containsDuplicate([1, 2, 3, 4])  // false
```

**Restricciones:** `0 ≤ nums.count ≤ 10^5`; los valores caben en `Int`.

<!-- revelar -->

## Enfoque inicial

Hay que comparar cada valor con los demás. La pregunta es cuánto cuesta esa comparación y si se puede recordar lo ya visto para no repetirla.

## Solución ingenua

```swift
func containsDuplicate(_ nums: [Int]) -> Bool {
    for i in nums.indices {
        for j in (i + 1)..<nums.count where nums[i] == nums[j] {
            return true
        }
    }
    return false
}
```

## Problemas de la solución ingenua

Compara todas las parejas: n·(n−1)/2 comparaciones, es decir **O(n²)**. Con 10^5 elementos son unos 5·10^9 comparaciones, demasiado para una respuesta interactiva. Usa O(1) de memoria, que es su única ventaja.

## Solución optimizada

Recorre la lista una vez y guarda cada valor en un `Set`. Si al insertar descubres que ya estaba, hay un duplicado. Cada inserción y búsqueda en un `Set` cuesta O(1) en promedio, así que el total es O(n) de tiempo a cambio de O(n) de memoria.

## Explicación línea por línea

- `var seen = Set<Int>()`: los valores vistos hasta ahora.
- `seen.reserveCapacity(nums.count)`: evita que el `Set` crezca varias veces.
- `seen.insert(value)` devuelve una tupla; su campo `inserted` es `false` si el valor ya existía. Así se busca e inserta en una sola operación.
- `return true` en cuanto aparece el primer duplicado: no hace falta terminar el recorrido.
- La alternativa `containsDuplicateBySorting` ordena una copia (O(n log n)) y compara vecinos: si hay duplicados, quedan juntos.

## Errores frecuentes

- Construir `Set(nums)` y comparar `count`: funciona y es O(n), pero siempre recorre toda la lista aunque el duplicado esté en las dos primeras posiciones. Es válido mencionarlo como alternativa concisa.
- Ordenar la lista de entrada sin preguntar si se puede modificar.
- Decir «O(1)» sin matizar: las tablas hash tienen costo constante **promedio**, no garantizado.

## Variante

**Contains Duplicate II:** devuelve `true` si existen `i ≠ j` con `nums[i] == nums[j]` y `|i − j| ≤ k`. Mantén un `Set` con como máximo los últimos `k` valores: es una ventana deslizante.
