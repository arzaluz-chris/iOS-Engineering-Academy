---
id: encode-and-decode-strings
title: Encode and Decode Strings
difficulty: medium
order: 24
patterns: [Strings, Length prefix, Serialization]
prerequisites: [m07, m15, m16-l01]
summary: Pack a list of strings into one string and get the exact list back, whatever characters the strings contain. A length prefix beats any delimiter.
solutionFile: EncodeDecodeStrings.swift
testFile: EncodeDecodeStringsTests.swift
starter: |
  func encodeStrings(_ strings: [String]) -> String {
      // Your solution
      return ""
  }

  func decodeStrings(_ encoded: String) -> [String] {
      // Your solution
      return []
  }
time: O(n) for n total bytes
space: O(n)
edgeCases:
  - An empty list versus a list with one empty string
  - Strings that contain the delimiter you'd pick, or digits
  - Emoji and accented letters, which take several UTF-8 bytes
  - Very long strings, whose length has several digits
askInterviewer:
  - Can the strings contain any character, including whatever separator I'd choose?
  - Do [] and [""] need to decode differently?
  - Is the encoded form going to be read by another program, or only by my decoder?
  - Should lengths count characters or bytes?
hints:
  - "Try joining with a comma. Which input breaks it? Is there any single character you could join with that no input will ever contain?"
  - "Instead of marking where a string ends, say up front how long it is. Then the decoder never needs to look inside a string."
  - "Write each string as its length, a separator, and the string. The separator only has to end the number, so it can't be confused with content."
followUps:
  - "Why count UTF-8 bytes instead of Characters?"
  - "How would escaping (for example, \"\\,\" for a literal comma) compare with a length prefix?"
  - How would you make the decoder reject malformed input instead of trapping?
rubric:
  - I showed why a plain delimiter fails for arbitrary strings.
  - I used a length prefix and read lengths before content.
  - "[] and [\"\"] round-trip differently."
  - I counted lengths in UTF-8 bytes and decoded by jumping, in O(n) total.
codeStatus: tested
---

A messaging app has to store a list of strings in a single text field. Write two functions: `encodeStrings` packs a list into one string, and `decodeStrings` turns that string back into **exactly** the original list. They must work for any strings: empty ones, ones with spaces, digits, punctuation, emoji, and any separator you might think of using.

```swift
let packed = encodeStrings(["hi", "", "a#b"])
decodeStrings(packed)  // ["hi", "", "a#b"]

decodeStrings(encodeStrings([]))    // []
decodeStrings(encodeStrings([""]))  // [""]
```

The encoded format is up to you; the tests only check that decoding gives back the input. (The reference solution encodes `["hi", "", "a#b"]` as `"2#hi0#3#a#b"`.)

**Constraints:** `0 ≤ strings.count ≤ 200`; each string has `0` to `200` characters, any `Character` at all. `decodeStrings` only ever receives output from `encodeStrings`.

<!-- reveal -->

## First approach

A delimiter alone can't work: whatever character you join with, some input can contain it, and the decoder can't tell content from separator. The fix is to say **how long** each string is before it starts. The decoder reads the length, then takes exactly that many bytes without looking at them.

## Naive solution

Join with a separator and split on it:

```swift
func encodeStrings(_ strings: [String]) -> String {
    strings.joined(separator: ",")
}

func decodeStrings(_ encoded: String) -> [String] {
    encoded.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
}
```

## Problems with the naive solution

It's wrong, not slow. `["a,b"]` decodes as `["a", "b"]`. And `[]` and `[""]` both encode as `""`, so one of them can't come back. Picking a rarer separator, like `"\u{1F}"`, only makes the bug rarer. Escaping the separator inside strings works, but every string has to be scanned and rewritten on both sides, and it's easy to get the escape of the escape character wrong.

## Optimized solution

Encode each string as `<length>#<content>`, where the length is the string's size in UTF-8 bytes. To decode, read digits up to the first `#`, which is always the end of a number because digits never include `#`. Then take exactly `length` bytes as the string, and repeat from the byte after it.

## Line by line

- `encoded += "\(string.utf8.count)#"`: the length in bytes, then the `#` that ends the number. The content may contain `#` or digits; it doesn't matter, because the decoder never searches inside it.
- `encoded += string`: the content, unchanged.
- `let bytes = Array(encoded.utf8)`: decoding works on bytes, so indexing is O(1) and the lengths mean the same thing as when they were written.
- `while bytes[index] != UInt8(ascii: "#")`: reads the length digit by digit. `UInt8(ascii:)` gives the byte value of an ASCII character.
- `length = length * 10 + Int(bytes[index] - UInt8(ascii: "0"))`: builds the number from its digits.
- `index += 1` skips the `#`, then `String(decoding: bytes[index..<(index + length)], as: UTF8.self)` turns exactly `length` bytes back into a string.
- `index += length` jumps to the next length prefix.
- `[]` encodes to `""` and decodes back to `[]` because the outer loop never runs; `[""]` encodes to `"0#"` and decodes to one empty string.
- Every byte is read once in each direction: **O(n) time and space** for n total bytes.

## Common mistakes

- Using `string.count` (Characters) for the length and then slicing bytes, or the reverse. `"é"` can be one `Character` and two bytes; mixing units cuts strings in the middle of a character.
- Searching for the next `#` to find the end of a string instead of using the length. That brings back the delimiter bug.
- Using a fixed-width length (say, always 3 digits) without checking the maximum. It works for this problem's limits but breaks silently on longer strings.

## Variation

**Binary framing:** network protocols use the same idea with a fixed-size binary length, such as 4 bytes, before each message. The reader never has to parse digits, and a frame's size is known before reading it. This is how many message formats tell where one message ends and the next begins.
