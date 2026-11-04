/// Encodes a list of strings as a single string that `decodeStrings` turns back into the same
/// list. Works for any strings, including empty ones and ones containing digits, `#` or emoji.
///
/// Each string is written as its length in UTF-8 bytes, a `#`, and then its bytes. The decoder
/// never has to look inside a string for a delimiter: it reads the length and jumps.
/// O(n) time and space for n total bytes.
public func encodeStrings(_ strings: [String]) -> String {
    var encoded = ""
    for string in strings {
        encoded += "\(string.utf8.count)#"
        encoded += string
    }
    return encoded
}

/// Decodes a string produced by `encodeStrings`. O(n) time and space for n bytes.
public func decodeStrings(_ encoded: String) -> [String] {
    let bytes = Array(encoded.utf8)
    var strings: [String] = []
    var index = 0
    while index < bytes.count {
        var length = 0
        while bytes[index] != UInt8(ascii: "#") {
            length = length * 10 + Int(bytes[index] - UInt8(ascii: "0"))
            index += 1
        }
        index += 1
        strings.append(String(decoding: bytes[index..<(index + length)], as: UTF8.self))
        index += length
    }
    return strings
}
