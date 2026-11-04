/// Returns an array where position `i` holds the product of every element of `nums`
/// except `nums[i]`, without using division.
///
/// A first pass stores, at each position, the product of everything to its left.
/// A second pass, from the right, multiplies in the product of everything to its right,
/// carried in a single variable. O(n) time, O(1) extra space besides the result.
///
/// Assumes every product fits in `Int`, as the problem statement guarantees.
public func productsExceptSelf(_ nums: [Int]) -> [Int] {
    var result = Array(repeating: 1, count: nums.count)
    var leftProduct = 1
    for index in nums.indices {
        result[index] = leftProduct
        leftProduct *= nums[index]
    }
    var rightProduct = 1
    for index in nums.indices.reversed() {
        result[index] *= rightProduct
        rightProduct *= nums[index]
    }
    return result
}

/// Naive solution: for each position, multiply every other element. O(n²) time.
public func productsExceptSelfBruteForce(_ nums: [Int]) -> [Int] {
    nums.indices.map { skipped in
        var product = 1
        for index in nums.indices where index != skipped {
            product *= nums[index]
        }
        return product
    }
}
