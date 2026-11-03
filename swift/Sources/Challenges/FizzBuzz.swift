/// Devuelve las líneas de FizzBuzz del 1 al `n`, ambos incluidos.
/// - Múltiplos de 3 y de 5: "FizzBuzz"
/// - Solo de 3: "Fizz"
/// - Solo de 5: "Buzz"
/// - Los demás: el número como texto.
/// Para `n < 1` devuelve una lista vacía.
///
/// Tiempo O(n), espacio O(n) por el resultado.
public func fizzBuzz(_ n: Int) -> [String] {
    guard n >= 1 else { return [] }
    var result: [String] = []
    result.reserveCapacity(n)
    for i in 1...n {
        let divisibleBy3 = i % 3 == 0
        let divisibleBy5 = i % 5 == 0
        switch (divisibleBy3, divisibleBy5) {
        case (true, true):
            result.append("FizzBuzz")
        case (true, false):
            result.append("Fizz")
        case (false, true):
            result.append("Buzz")
        case (false, false):
            result.append(String(i))
        }
    }
    return result
}
