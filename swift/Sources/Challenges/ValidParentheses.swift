/// Indica si los paréntesis `()`, corchetes `[]` y llaves `{}` de `s` están bien balanceados
/// y anidados. Cualquier otro carácter hace que la cadena sea inválida.
///
/// Cada apertura se apila; cada cierre debe coincidir con la última apertura pendiente.
/// Tiempo O(n), espacio O(n) en el peor caso (solo aperturas).
public func isValidParentheses(_ s: String) -> Bool {
    let openerFor: [Character: Character] = [")": "(", "]": "[", "}": "{"]
    let openers: Set<Character> = ["(", "[", "{"]
    var stack: [Character] = []

    for character in s {
        if openers.contains(character) {
            stack.append(character)
        } else if let expectedOpener = openerFor[character] {
            guard stack.popLast() == expectedOpener else { return false }
        } else {
            return false
        }
    }
    return stack.isEmpty
}
