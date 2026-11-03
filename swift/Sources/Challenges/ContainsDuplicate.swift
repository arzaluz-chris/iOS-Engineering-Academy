/// Indica si algún valor aparece al menos dos veces en `nums`.
///
/// Recorre la lista una vez y guarda lo visto en un `Set`.
/// `insert` devuelve `inserted == false` cuando el valor ya estaba.
/// Tiempo O(n) en promedio, espacio O(n).
public func containsDuplicate(_ nums: [Int]) -> Bool {
    var seen = Set<Int>()
    seen.reserveCapacity(nums.count)
    for value in nums {
        if !seen.insert(value).inserted {
            return true
        }
    }
    return false
}

/// Alternativa sin memoria extra proporcional a n (además de la copia ordenada):
/// ordenar y comparar vecinos. Tiempo O(n log n).
public func containsDuplicateBySorting(_ nums: [Int]) -> Bool {
    let sorted = nums.sorted()
    for i in sorted.indices.dropFirst() where sorted[i] == sorted[i - 1] {
        return true
    }
    return false
}
