/// Devuelve los índices `[i, j]` (con `i < j`) de dos elementos distintos cuya suma es `target`,
/// o `nil` si no existen. Si hay varias parejas, devuelve la primera cuyo segundo índice es menor.
///
/// Un diccionario guarda, para cada valor ya visto, su índice. Para cada elemento se busca
/// su complemento `target - value` antes de registrarlo, así un elemento no se empareja consigo mismo.
/// Tiempo O(n) en promedio, espacio O(n).
///
/// Supone valores en un rango donde `target - value` no desborda `Int`
/// (en el enunciado: valores y objetivo entre -10^9 y 10^9).
public func twoSum(_ nums: [Int], _ target: Int) -> [Int]? {
    var indexByValue: [Int: Int] = [:]
    for (index, value) in nums.enumerated() {
        if let complementIndex = indexByValue[target - value] {
            return [complementIndex, index]
        }
        indexByValue[value] = index
    }
    return nil
}

/// Solución ingenua: probar todas las parejas. Tiempo O(n²), espacio O(1).
public func twoSumBruteForce(_ nums: [Int], _ target: Int) -> [Int]? {
    for i in nums.indices {
        for j in (i + 1)..<nums.count where nums[i] + nums[j] == target {
            return [i, j]
        }
    }
    return nil
}
