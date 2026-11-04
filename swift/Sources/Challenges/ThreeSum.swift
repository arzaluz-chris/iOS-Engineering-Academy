/// Returns every distinct triple of values from `nums`, taken from three different positions,
/// that adds up to 0. Each triple is in ascending order, and the list of triples is sorted.
///
/// Sorts a copy, fixes the smallest value of the triple, and finds the other two with
/// converging pointers over the rest. Equal values are skipped at all three positions so no
/// triple is reported twice. O(n²) time, O(n) space for the sorted copy (O(1) besides it and
/// the output).
public func threeSum(_ nums: [Int]) -> [[Int]] {
    let sorted = nums.sorted()
    var triples: [[Int]] = []
    for first in sorted.indices {
        if first > 0 && sorted[first] == sorted[first - 1] { continue }
        if sorted[first] > 0 { break }
        var left = first + 1
        var right = sorted.count - 1
        while left < right {
            let sum = sorted[first] + sorted[left] + sorted[right]
            if sum < 0 {
                left += 1
            } else if sum > 0 {
                right -= 1
            } else {
                triples.append([sorted[first], sorted[left], sorted[right]])
                left += 1
                right -= 1
                while left < right && sorted[left] == sorted[left - 1] {
                    left += 1
                }
            }
        }
    }
    return triples
}

/// Naive solution: try every triple of positions and keep the distinct sorted triples in a Set.
/// O(n³) time, O(t) space for t distinct triples.
public func threeSumBruteForce(_ nums: [Int]) -> [[Int]] {
    var found = Set<[Int]>()
    for i in nums.indices {
        for j in (i + 1)..<nums.count {
            for k in (j + 1)..<nums.count where nums[i] + nums[j] + nums[k] == 0 {
                found.insert([nums[i], nums[j], nums[k]].sorted())
            }
        }
    }
    return found.sorted { $0.lexicographicallyPrecedes($1) }
}
