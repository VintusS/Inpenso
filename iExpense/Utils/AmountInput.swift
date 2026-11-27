import Foundation

struct AmountInput {
    let fractionDigits: Int
    let locale: Locale

    private var decimalSeparator: String { locale.decimalSeparator ?? "." }
    private var groupingSeparator: String { locale.groupingSeparator ?? "," }

    var placeholder: String {
        display(fractionDigits == 0 ? "0" : "0." + String(repeating: "0", count: fractionDigits))
    }

    func bindingText(for value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? ""
    }

    func value(of text: String) -> Double? {
        guard let value = Double(text), value.isFinite, value >= 0 else { return nil }
        return value
    }

    func display(_ text: String) -> String {
        let parts = text.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        let whole = parts[0].dropFirst(text.hasPrefix("-") ? 1 : 0)
        let grouped = whole.enumerated().map { index, digit in
            index > 0 && (whole.count - index).isMultiple(of: 3)
                ? groupingSeparator + String(digit) : String(digit)
        }.joined()
        let sign = text.hasPrefix("-") ? "-" : ""
        return sign + grouped + (parts.count == 2 ? decimalSeparator + parts[1] : "")
    }

    func updating(_ text: String, with editedDisplay: String) -> String {
        let previous = Array(display(text))
        let edited = Array(editedDisplay)
        if previous == edited { return text }

        // Strip grouping from the unchanged text. A newly typed "." or "," can
        // then act as a decimal even when it matches the locale's grouping mark.
        let prefixCount = zip(previous, edited).prefix { $0 == $1 }.count
        let suffixCount = zip(previous.dropFirst(prefixCount).reversed(), edited.dropFirst(prefixCount).reversed())
            .prefix { $0 == $1 }.count
        let insertion = String(edited.dropFirst(prefixCount).dropLast(suffixCount))

        if insertion.count > 1 {
            let pastedText = canonicalPaste(editedDisplay)
            if insertion.contains(where: { $0.isLetter || $0.isCurrencySymbol })
                || isGroupedNumber(editedDisplay) {
                return normalize(pastedText)
            }
            return normalize(
                canonicalDisplay(String(edited.prefix(prefixCount))) +
                canonicalPaste(insertion) +
                canonicalDisplay(String(edited.suffix(suffixCount)))
            )
        }

        let isDecimal = insertion == "." || insertion == "," || insertion == decimalSeparator
        return normalize(
            canonicalDisplay(String(edited.prefix(prefixCount))) +
            (isDecimal ? "." : insertion) +
            canonicalDisplay(String(edited.suffix(suffixCount)))
        )
    }

    private func isGroupedNumber(_ text: String) -> Bool {
        [groupingSeparator, ".", ","].contains { separator in
            guard fractionDigits == 0 || separator != decimalSeparator else { return false }
            let groups = text.components(separatedBy: separator)
            guard groups.count > 1, (1...3).contains(groups[0].count) else { return false }
            return groups[0].allSatisfy { digitValue($0) != nil } && groups.dropFirst().allSatisfy {
                $0.count == 3 && $0.allSatisfy { digitValue($0) != nil }
            }
        }
    }

    private func canonicalDisplay(_ text: String) -> String {
        text.replacingOccurrences(of: groupingSeparator, with: "")
            .replacingOccurrences(of: decimalSeparator, with: ".")
    }

    private func canonicalPaste(_ text: String) -> String {
        // Preserve an ambiguous decimal mark from the current locale for
        // fractional currencies. A foreign mark with a full group is grouping.
        let separators = Set([".", ",", decimalSeparator, groupingSeparator])
        let cleaned = text.filter { digitValue($0) != nil || $0 == "-" || separators.contains(String($0)) }
        let punctuation = cleaned.indices.filter {
            let mark = String(cleaned[$0])
            return mark == "." || mark == "," || mark == decimalSeparator
                || (mark == groupingSeparator && !cleaned[$0].isWhitespace)
        }
        guard let last = punctuation.last else { return cleaned }
        let mark = String(cleaned[last])
        let trailingDigits = cleaned[cleaned.index(after: last)...].compactMap(digitValue).count
        let mixedSeparators = punctuation.contains { cleaned[$0] != cleaned[last] }
        let isGrouping = !mixedSeparators && trailingDigits == 3 && (
            fractionDigits == 0 || mark != decimalSeparator || punctuation.count > 1
        )

        return cleaned.indices.map { index in
            let character = cleaned[index]
            if digitValue(character) != nil || character == "-" { return String(character) }
            return index == last && !isGrouping ? "." : ""
        }.joined()
    }

    private func normalize(_ text: String) -> String {
        let parts = text.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        var whole = parts[0].compactMap(digitValue).joined()
        // "05000000" -> "5000000"; a lone "0" stays so "0.5" can be typed.
        while whole.count > 1 && whole.hasPrefix("0") { whole.removeFirst() }
        let sign = text.hasPrefix("-") ? "-" : ""
        guard parts.count == 2, fractionDigits > 0 else { return sign + whole }
        let fraction = parts[1].prefix { $0 != "." }.compactMap(digitValue).prefix(fractionDigits)
        return sign + (whole.isEmpty ? "0" : whole) + "." + fraction.joined()
    }

    private func digitValue(_ character: Character) -> String? {
        guard let digit = character.wholeNumberValue, (0...9).contains(digit) else { return nil }
        return String(digit)
    }
}
