---
id: valid-parentheses
title: Valid Parentheses
difficulty: facil
order: 5
patterns: [Stack]
prerequisites: [m07, m15]
summary: Verificar que paréntesis, corchetes y llaves se cierren en orden. El problema que enseña para qué sirve una pila.
solutionFile: ValidParentheses.swift
testFile: ValidParenthesesTests.swift
starter: |
  func isValidParentheses(_ s: String) -> Bool {
      // Tu solución
      return false
  }
time: O(n)
space: O(n)
edgeCases:
  - Cadena vacía
  - Solo aperturas, como "(("
  - Un cierre sin apertura, como ")"
  - Cierres en el orden equivocado, como "([)]"
askInterviewer:
  - ¿Qué caracteres puede contener la cadena? ¿Ignoro los demás o la invalidan?
  - ¿La cadena vacía cuenta como válida?
hints:
  - Contar aperturas y cierres no basta. ¿Por qué "([)]" tiene los mismos conteos que "([])" y no es válida?
  - Cada cierre debe corresponder a la apertura más reciente que siga abierta. ¿Qué estructura te da «lo más reciente» en O(1)?
followUps:
  - ¿Cómo lo resolverías si solo existieran paréntesis redondos, con O(1) de memoria?
  - "¿Cómo encuentras la longitud de la subcadena válida más larga? (Longest Valid Parentheses.)"
  - ¿Dónde aparece este patrón en una app real? (Validar plantillas, analizar expresiones, deshacer operaciones.)
rubric:
  - Usé una pila para emparejar cada cierre con la apertura más reciente.
  - Rechacé un cierre cuando la pila está vacía.
  - Verifiqué que la pila quede vacía al final.
  - Di complejidad O(n) de tiempo y de espacio.
codeStatus: revisado
---

Dada una cadena formada por `(`, `)`, `[`, `]`, `{` y `}`, devuelve `true` si es válida:

1. Cada apertura se cierra con su mismo tipo.
2. Las aperturas se cierran en el orden correcto.
3. Cada cierre tiene una apertura previa de su tipo.

Cualquier otro carácter hace que la cadena sea inválida. La cadena vacía es válida.

```swift
isValidParentheses("()[]{}")  // true
isValidParentheses("([)]")    // false
isValidParentheses("{[]}")    // true
```

**Restricciones:** `0 ≤ s.count ≤ 10^4`.

<!-- revelar -->

## Enfoque inicial

La apertura que debe cerrarse primero es la última que se abrió. «Lo último que entró es lo primero que sale» es exactamente el comportamiento de una **pila** (stack).

## Solución ingenua

Borrar repetidamente los pares adyacentes `()`, `[]` y `{}` hasta que no quede ninguno:

```swift
func isValidParentheses(_ s: String) -> Bool {
    var current = s
    while true {
        let reduced = current
            .replacingOccurrences(of: "()", with: "")
            .replacingOccurrences(of: "[]", with: "")
            .replacingOccurrences(of: "{}", with: "")
        if reduced == current { return current.isEmpty }
        current = reduced
    }
}
```

`replacingOccurrences` pertenece a Foundation; este fragmento necesita `import Foundation`.

## Problemas de la solución ingenua

Cada pasada recorre la cadena y puede quitar un solo nivel de anidación. Con `"((((…))))"` de profundidad n/2 hacen falta n/2 pasadas: **O(n²)**. Además crea una cadena nueva en cada reemplazo.

## Solución optimizada

Recorre la cadena una vez. Apila cada apertura. Ante un cierre, saca el último elemento de la pila y verifica que sea la apertura correspondiente. Al final, la pila debe quedar vacía.

## Explicación línea por línea

- `openerFor`: diccionario de cada cierre a su apertura. Evita una cadena de `if`.
- `openers`: conjunto de aperturas para preguntar en O(1).
- `stack.append(character)`: la apertura queda pendiente.
- `guard stack.popLast() == expectedOpener`: `popLast()` devuelve un optional, `nil` si la pila está vacía. Comparar el optional con la apertura esperada cubre dos fallas en una línea: cierre sin apertura y cierre del tipo equivocado.
- `else { return false }`: cualquier otro carácter invalida la cadena, como dice el enunciado.
- `return stack.isEmpty`: si quedan aperturas sin cerrar, como en `"(("`, no es válida.

## Errores frecuentes

- Contar aperturas y cierres de cada tipo: `"([)]"` tiene conteos correctos y es inválida.
- Llamar `removeLast()` sin revisar si la pila está vacía: detiene el programa con `")"`.
- Olvidar revisar la pila al final.

## Variante

Si solo hay paréntesis redondos, basta un contador: suma 1 por apertura, resta 1 por cierre, falla si baja de 0 y exige 0 al final. O(1) de memoria.
