---
id: valid-palindrome
title: Valid Palindrome
difficulty: facil
order: 4
patterns: [Two pointers, Cadenas]
prerequisites: [m07, m15]
summary: ¿Se lee igual al derecho y al revés? Dos índices que convergen y una trampa de rendimiento propia de Swift.
solutionFile: ValidPalindrome.swift
testFile: ValidPalindromeTests.swift
starter: |
  func isPalindrome(_ s: String) -> Bool {
      // Tu solución
      return false
  }
time: O(n)
space: O(n) por la copia en Array
edgeCases:
  - Cadena vacía
  - Cadena solo con espacios o signos de puntuación
  - Mezcla de letras y dígitos, como "0P"
  - Un solo carácter
askInterviewer:
  - ¿Qué caracteres cuentan? ¿Solo letras y dígitos?
  - ¿Distingo mayúsculas de minúsculas?
  - ¿La entrada puede tener caracteres fuera de ASCII, como acentos o emoji?
hints:
  - Primero resuélvelo limpiando la cadena y comparándola con su reverso. Luego busca cómo evitar la copia limpia.
  - Dos índices, uno en cada extremo. ¿Qué haces cuando uno de ellos apunta a un espacio?
  - "En Swift, `s[i]` con un entero no compila: los índices de String no son enteros. ¿Qué conversión te permite indexar en O(1)?"
followUps:
  - "Valid Palindrome II: ¿y si puedes borrar como máximo un carácter?"
  - ¿Por qué Swift no permite indexar String con enteros?
  - ¿Cómo cambia tu solución si la entrada tiene emoji o acentos combinados?
rubric:
  - Aclaré qué caracteres cuentan y si importa la capitalización.
  - Usé dos índices que convergen sin construir otra cadena limpia, o expliqué ese trade-off.
  - La cadena vacía devuelve true.
  - Expliqué por qué convertí a Array para indexar.
codeStatus: probado
---

Una frase es palíndromo si, después de pasar todo a minúsculas y quitar lo que no sea letra ni dígito, se lee igual al derecho y al revés.

Escribe `isPalindrome(_ s: String) -> Bool`.

```swift
isPalindrome("A man, a plan, a canal: Panama")  // true
isPalindrome("race a car")                      // false
isPalindrome(" ")                               // true: queda vacía
```

**Restricciones:** `0 ≤ s.count ≤ 2·10^5`.

<!-- revelar -->

## Enfoque inicial

Hay dos tareas: decidir qué caracteres cuentan y comparar de afuera hacia adentro. Se pueden hacer juntas con dos índices.

## Solución ingenua

```swift
func isPalindrome(_ s: String) -> Bool {
    let cleaned = s.lowercased().filter { $0.isLetter || $0.isNumber }
    return cleaned == String(cleaned.reversed())
}
```

## Problemas de la solución ingenua

Es correcta y O(n), y en Swift es una respuesta legítima. Su costo está en la memoria: construye la cadena limpia y su reverso, dos copias extra. En entrevista suelen pedir el siguiente paso: comparar sin construir la cadena limpia.

## Solución optimizada

Convierte la cadena a un `Array` de `Character` para indexar por posición en O(1). Usa `left` desde el inicio y `right` desde el final. Salta lo que no cuente; si los dos caracteres válidos difieren, no es palíndromo. Si los índices se cruzan sin diferencias, sí lo es.

## Explicación línea por línea

- `Array(s.lowercased())`: en Swift, `String` no se indexa con enteros porque un `Character` puede ocupar varios bytes (por ejemplo, un emoji o una letra con acento combinado). Pedir «el carácter 5000» exigiría recorrer desde el inicio. El `Array` da acceso O(1) a cambio de O(n) memoria.
- `var right = characters.count - 1`: con la cadena vacía vale −1 y el ciclo no se ejecuta; la respuesta es `true`.
- `while left < right`: cuando se cruzan, ya se comparó todo.
- Los dos `continue` saltan caracteres que no cuentan sin mover el otro índice.
- `characters[left] != characters[right]`: la primera diferencia basta para responder `false`.

## Errores frecuentes

- Intentar `s[i]` con un `Int`: no compila en Swift.
- Usar `s.index(s.startIndex, offsetBy: i)` dentro del ciclo: compila, pero cada llamada es O(i) y el total se vuelve O(n²).
- Olvidar convertir a minúsculas y decir que «Aa» no es palíndromo.

## Variante

**Valid Palindrome II:** se permite borrar como máximo un carácter. Al encontrar la primera diferencia, prueba si `[left+1...right]` o `[left...right-1]` es palíndromo. Sigue siendo O(n).
