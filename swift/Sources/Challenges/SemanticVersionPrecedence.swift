/// Compares two valid Semantic Versioning 2.0.0 strings, `MAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]`,
/// by precedence. Returns -1 if `lhs` comes first, 1 if `rhs` does, and 0 if they have the same
/// precedence (build metadata is ignored, so `1.0.0+a` and `1.0.0+b` compare equal).
///
/// Major, minor and patch compare as numbers. With those equal, a version with a pre-release comes
/// before the same version without one. Pre-releases compare identifier by identifier: numbers
/// as numbers, other identifiers by their ASCII bytes, and a numeric identifier before an
/// alphanumeric one. If one list runs out first and everything so far was equal, it comes first.
/// Numbers are compared as digit strings (length first, then digits), which is safe because valid
/// versions have no leading zeros, and never overflows.
/// O(n) time and O(n) space for the split parts, where n is the total length of both strings.
public func compareSemanticVersions(_ lhs: String, _ rhs: String) -> Int {
    let left = semverPrecedenceParts(of: lhs)
    let right = semverPrecedenceParts(of: rhs)
    for (a, b) in zip(left.core, right.core) {
        let order = semverCompareDigitStrings(a, b)
        if order != 0 { return order }
    }
    switch (left.preRelease.isEmpty, right.preRelease.isEmpty) {
    case (true, true): return 0
    case (true, false): return 1       // 1.0.0 comes after 1.0.0-anything
    case (false, true): return -1
    case (false, false): break
    }
    for (a, b) in zip(left.preRelease, right.preRelease) {
        let order = semverComparePreReleaseIdentifiers(a, b)
        if order != 0 { return order }
    }
    return semverCompareInts(left.preRelease.count, right.preRelease.count)
}

/// Splits off build metadata (after the first `+`) and the pre-release (after the first `-`),
/// then splits each remaining part on dots.
private func semverPrecedenceParts(of version: String) -> (core: [Substring], preRelease: [Substring]) {
    let withoutBuild = version.split(separator: "+", maxSplits: 1, omittingEmptySubsequences: false)[0]
    let pieces = withoutBuild.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
    let core = pieces[0].split(separator: ".", omittingEmptySubsequences: false)
    let preRelease = pieces.count > 1 ? pieces[1].split(separator: ".", omittingEmptySubsequences: false) : []
    return (core, preRelease)
}

private func semverComparePreReleaseIdentifiers(_ a: Substring, _ b: Substring) -> Int {
    switch (semverIsNumericIdentifier(a), semverIsNumericIdentifier(b)) {
    case (true, true): return semverCompareDigitStrings(a, b)
    case (true, false): return -1      // numeric identifiers come first
    case (false, true): return 1
    case (false, false):
        if a == b { return 0 }
        return a.utf8.lexicographicallyPrecedes(b.utf8) ? -1 : 1
    }
}

private func semverIsNumericIdentifier(_ identifier: Substring) -> Bool {
    !identifier.isEmpty && identifier.utf8.allSatisfy { $0 >= UInt8(ascii: "0") && $0 <= UInt8(ascii: "9") }
}

/// Compares two numbers written without leading zeros: the longer one is bigger, and equal lengths
/// compare digit by digit.
private func semverCompareDigitStrings(_ a: Substring, _ b: Substring) -> Int {
    if a.utf8.count != b.utf8.count { return semverCompareInts(a.utf8.count, b.utf8.count) }
    if a == b { return 0 }
    return a.utf8.lexicographicallyPrecedes(b.utf8) ? -1 : 1
}

private func semverCompareInts(_ a: Int, _ b: Int) -> Int {
    a < b ? -1 : (a > b ? 1 : 0)
}
