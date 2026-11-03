---
id: fizzbuzz
title: FizzBuzz
difficulty: facil
order: 1
patterns: [Recorrido lineal, Condicionales]
prerequisites: [m05, m07]
summary: El clásico filtro de entrevistas. Fácil de resolver y fácil de resolver mal si no cuidas el orden de las condiciones.
solutionFile: FizzBuzz.swift
testFile: FizzBuzzTests.swift
starter: |
  func fizzBuzz(_ n: Int) -> [String] {
      // Tu solución
      return []
  }
time: O(n)
space: O(n) por la lista resultado
edgeCases:
  - n igual a 1
  - n igual a 0 o negativo
  - Números múltiplos de 15
askInterviewer:
  - ¿Devuelvo una lista o imprimo cada línea?
  - ¿Qué espero si n es 0 o negativo?
  - ¿El rango incluye a n?
hints:
  - Un número múltiplo de 15 es múltiplo de 3 y de 5. ¿Qué pasa si revisas «múltiplo de 3» primero?
  - "`i % 3 == 0` significa que `i` es múltiplo de 3."
followUps:
  - ¿Cómo lo extenderías para que las reglas (3 → Fizz, 5 → Buzz, 7 → Bazz) se configuren sin modificar la función?
  - ¿Qué cambia si n puede ser mil millones? Piensa en memoria y en devolver los valores de forma perezosa.
  - ¿Cómo lo probarías sin escribir los 100 valores esperados?
rubric:
  - Los múltiplos de 15 producen FizzBuzz y no solo Fizz.
  - Manejé n menor que 1 sin fallar.
  - Mencioné la complejidad O(n).
codeStatus: probado
---

Escribe una función que, dado un entero `n`, devuelva una lista de textos para cada número del 1 al `n`, ambos incluidos:

- Si el número es múltiplo de 3 y de 5: `"FizzBuzz"`.
- Si solo es múltiplo de 3: `"Fizz"`.
- Si solo es múltiplo de 5: `"Buzz"`.
- En otro caso: el número como texto, por ejemplo `"7"`.

Si `n` es menor que 1, devuelve una lista vacía.

```swift
fizzBuzz(5)  // ["1", "2", "Fizz", "4", "Buzz"]
```

**Restricciones:** `-10^4 ≤ n ≤ 10^4`.

<!-- revelar -->

## Enfoque inicial

Recorre del 1 al `n` y decide qué agregar en cada vuelta. La única dificultad real es el **orden de las condiciones**: el caso de 15 cumple dos reglas a la vez y debe revisarse antes que cada una por separado.

## Solución ingenua

```swift
func fizzBuzz(_ n: Int) -> [String] {
    var result: [String] = []
    for i in 1...n {
        if i % 3 == 0 {
            result.append("Fizz")
        } else if i % 5 == 0 {
            result.append("Buzz")
        } else if i % 15 == 0 {
            result.append("FizzBuzz")
        } else {
            result.append(String(i))
        }
    }
    return result
}
```

## Problemas de la solución ingenua

- **El caso FizzBuzz nunca ocurre.** Para 15, la primera condición (`i % 3 == 0`) ya es verdadera y se agrega `"Fizz"`. El `else if` de 15 es código muerto.
- **Falla con n menor que 1.** `1...n` con `n = 0` es un rango inválido: Swift detiene el programa en ejecución, porque el límite inferior no puede ser mayor que el superior.

## Solución optimizada

Revisa primero el caso combinado, o mejor, evalúa ambas condiciones una vez y decide con un `switch` sobre la pareja. Así el compilador comprueba que cubriste las cuatro combinaciones.

## Explicación línea por línea

- `guard n >= 1 else { return [] }`: protege el rango `1...n`, que no admite `n < 1`.
- `reserveCapacity(n)`: reserva memoria una sola vez. No cambia la complejidad, pero evita realojamientos; es un detalle que vale la pena mencionar en voz alta.
- `let divisibleBy3 = i % 3 == 0`: calcula cada condición una vez y le da nombre.
- `switch (divisibleBy3, divisibleBy5)`: un `switch` sobre una tupla de dos `Bool`. Las cuatro combinaciones están escritas y Swift exige que el `switch` sea exhaustivo, así que olvidar un caso es un error de compilación.
- `String(i)`: convierte el entero a texto.

## Errores frecuentes

- Revisar «múltiplo de 3» antes que «múltiplo de 15».
- Usar `0...n` y producir una línea de más para el 0.
- Olvidar que `1...n` con `n` menor que 1 detiene el programa.

## Variante

Generaliza las reglas: recibe una lista de parejas `(divisor, palabra)` y concatena las palabras de todos los divisores que se cumplan. Con `[(3, "Fizz"), (5, "Buzz")]` obtienes el FizzBuzz clásico; con `(7, "Bazz")` agregas una regla sin tocar la función.
