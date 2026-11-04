/// Lays out `words` in lines of exactly `width` characters, as a fully justified label would.
/// Each line takes as many words as fit with at least one space between them. The spaces are then
/// spread over the gaps as evenly as possible, with the extra ones going to the leftmost gaps.
/// A line with a single word, and the last line, are left-aligned: one space between words,
/// padded with spaces on the right. Every word must be non-empty, contain no spaces and fit in
/// `width`. Lengths are counted in `Character`s.
///
/// Greedy packing, then one division per line: with `spaces` to share over `gaps`, every gap gets
/// `spaces / gaps` and the first `spaces % gaps` gaps get one more.
/// O(c + l · width) time and space for c characters in the words and l lines of output.
public func justifyText(_ words: [String], width: Int) -> [String] {
    var lines: [String] = []
    var start = 0
    while start < words.count {
        var end = start + 1
        var letters = words[start].count
        // Adding words[end] needs one more space per word already on the line.
        while end < words.count && letters + words[end].count + (end - start) <= width {
            letters += words[end].count
            end += 1
        }
        let gaps = end - start - 1
        if gaps == 0 || end == words.count {
            let line = words[start..<end].joined(separator: " ")
            lines.append(line + String(repeating: " ", count: width - line.count))
        } else {
            let spaces = width - letters
            let spacesPerGap = spaces / gaps
            let gapsWithExtraSpace = spaces % gaps
            var line = ""
            for gap in 0..<gaps {
                line += words[start + gap]
                line += String(repeating: " ", count: spacesPerGap + (gap < gapsWithExtraSpace ? 1 : 0))
            }
            line += words[end - 1]
            lines.append(line)
        }
        start = end
    }
    return lines
}

/// Naive solution: same packing, but each line starts with single spaces and grows by inserting one
/// space at a time, cycling through the gaps from the left. Each insertion scans for the gap and
/// shifts the rest of the line: O(width²) per line.
public func justifyTextBySpaceInsertion(_ words: [String], width: Int) -> [String] {
    var lines: [String] = []
    var start = 0
    while start < words.count {
        var end = start
        var length = -1
        while end < words.count && length + 1 + words[end].count <= width {
            length += 1 + words[end].count
            end += 1
        }
        var line = Array(words[start..<end].joined(separator: " "))
        let gaps = end - start - 1
        if gaps == 0 || end == words.count {
            line += Array(repeating: " ", count: width - line.count)
        } else {
            var gap = 0
            while line.count < width {
                // Find where gap number `gap` starts: the first space after word number `gap`.
                var wordsPassed = 0
                var index = 0
                while true {
                    if line[index] == " " && line[index - 1] != " " {
                        if wordsPassed == gap { break }
                        wordsPassed += 1
                    }
                    index += 1
                }
                line.insert(" ", at: index)
                gap = (gap + 1) % gaps
            }
        }
        lines.append(String(line))
        start = end
    }
    return lines
}
