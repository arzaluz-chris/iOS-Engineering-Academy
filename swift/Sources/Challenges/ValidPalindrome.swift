/// Indica si `s` es un palíndromo considerando solo letras y dígitos, sin distinguir mayúsculas.
///
/// Dos índices avanzan desde los extremos hacia el centro, saltando lo que no es letra ni dígito.
/// Tiempo O(n); espacio O(n) por la copia en `Array` (indexar `String` directamente
/// por posición entera no es O(1) en Swift).
public func isPalindrome(_ s: String) -> Bool {
    let characters = Array(s.lowercased())
    var left = 0
    var right = characters.count - 1
    while left < right {
        if !isAlphanumeric(characters[left]) {
            left += 1
            continue
        }
        if !isAlphanumeric(characters[right]) {
            right -= 1
            continue
        }
        if characters[left] != characters[right] {
            return false
        }
        left += 1
        right -= 1
    }
    return true
}

private func isAlphanumeric(_ c: Character) -> Bool {
    c.isLetter || c.isNumber
}
