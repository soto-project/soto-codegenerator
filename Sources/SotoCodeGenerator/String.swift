//===----------------------------------------------------------------------===//
//
// This source file is part of the Soto for AWS open source project
//
// Copyright (c) 2017-2020 the Soto project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Soto project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation

let swiftReservedWords: Set<String> = [
    "as",
    "async",
    "await",
    "break",
    "case",
    "catch",
    "class",
    "continue",
    "default",
    "defer",
    "do",
    "else",
    "enum",
    "extension",
    "false",
    "for",
    "func",
    "if",
    "import",
    "in",
    "internal",
    "is",
    "nil",
    "operator",
    "private",
    "protocol",
    "public",
    "repeat",
    "return",
    "self",
    "static",
    "struct",
    "switch",
    "true",
    "try",
    "where",
]

extension String {
    public func toSwiftLabelCase() -> String {
        if self.allLetterIsSnakeUppercased() {
            return self.replacingOccurrences(of: "-", with: "_").lowercased().camelCased(capitalize: false)
        }
        return self.replacingOccurrences(of: "-", with: "_").camelCased(capitalize: false)
    }

    public func reservedwordEscaped() -> String {
        if swiftReservedWords.contains(self.lowercased()) {
            return "`\(self)`"
        }
        return self
    }

    public func toSwiftVariableCase() -> String {
        return self.toSwiftLabelCase().reservedwordEscaped()
    }

    public func toSwiftClassCase() -> String {
        if self == "Type" {
            return "`\(self)`"
        }

        return self.replacingOccurrences(of: "-", with: "_")
            .camelCased(capitalize: true)
    }

    // for some reason the Region and Partition enum are not camel cased
    public func toSwiftRegionEnumCase() -> String {
        return self.replacingOccurrences(of: "-", with: "")
    }

    public func camelCased(capitalize: Bool) -> String {
        let items = self.split(separator: "_")
        let firstWord = items.first!
        let firstWordProcessed: String
        if capitalize {
            firstWordProcessed = firstWord.upperFirst()
        } else {
            firstWordProcessed = firstWord.lowerFirstWord()
        }
        let remainingItems = items.dropFirst().map { word -> String in
            if word.allLetterIsSnakeUppercased() {
                return String(word)
            }
            return word.capitalized
        }
        return firstWordProcessed + remainingItems.joined()
    }

    public func toSwiftEnumCase() -> String {
        return self.toSwiftLabelCase().reservedwordEscaped()
    }

   public func tagStriped() -> String {
        return self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
    }

    private static let backslashEncodeMap: [String.Element: String] = [
        "\"": "\\\"",
        "\\": "\\\\",
        "\n": "\\n",
        "\t": "\\t",
        "\r": "\\r",
    ]

    /// back slash encode special characters
    public func addingBackslashEncoding() -> String {
        var newString = ""
        for c in self {
            if let replacement = String.backslashEncodeMap[c] {
                newString.append(contentsOf: replacement)
            } else {
                newString.append(c)
            }
        }
        return newString
    }

    func deletingPrefix(_ prefix: String) -> String {
        guard self.hasPrefix(prefix) else { return self }
        return String(self.dropFirst(prefix.count))
    }

    mutating func deletePrefix(_ prefix: String) {
        self = self.deletingPrefix(prefix)
    }

    func deletingSuffix(_ suffix: String) -> String {
        guard self.hasSuffix(suffix) else { return self }
        return String(self.dropLast(suffix.count))
    }

    mutating func deleteSuffix(_ suffix: String) {
        self = self.deletingSuffix(suffix)
    }

    func removingWhitespaces() -> String {
        return components(separatedBy: .whitespaces).joined()
    }

    mutating func removeWhitespaces() {
        self = self.removingWhitespaces()
    }

    func removingCharacterSet(in characterset: CharacterSet) -> String {
        return components(separatedBy: characterset).joined()
    }

    mutating func removeCharacterSet(in characterset: CharacterSet) {
        self = self.removingCharacterSet(in: characterset)
    }

    func capitalizingFirstLetter() -> String {
        return prefix(1).capitalized + dropFirst()
    }

    mutating func capitalizeFirstLetter() {
        self = self.capitalizingFirstLetter()
    }

    mutating func trimCharacters(in characterset: CharacterSet) {
        self = self.trimmingCharacters(in: characterset)
    }
}

extension StringProtocol {
    public func lowerFirst() -> String {
        return String(self[startIndex]).lowercased() + self[index(after: startIndex)...]
    }

    public func upperFirst() -> String {
        return String(self[self.startIndex]).uppercased() + self[index(after: startIndex)...]
    }

    /// Lowercase first letter, or if first word is an uppercase acronym then lowercase the whole of the acronym
    public func lowerFirstWord() -> String {
        var firstLowercase = self.startIndex
        var lastUppercaseOptional: Self.Index? = nil
        // get last uppercase character, first lowercase character
        while firstLowercase != self.endIndex, self[firstLowercase].isSnakeUppercase() {
            lastUppercaseOptional = firstLowercase
            firstLowercase = self.index(after: firstLowercase)
        }
        // if first character was never set first character must be lowercase
        guard let lastUppercase = lastUppercaseOptional else {
            return String(self)
        }
        if firstLowercase == self.endIndex {
            // if first lowercase letter is the end index then whole word is uppercase and
            // should be wholly lowercased
            return self.lowercased()
        } else if lastUppercase == self.startIndex {
            // if last uppercase letter is the first letter then only lower that character
            return self.lowerFirst()
        } else {
            // We have an acronym at the start, lowercase the whole of it
            return self[startIndex..<lastUppercase].lowercased() + self[lastUppercase...]
        }
    }

    func allLetterIsSnakeUppercased() -> Bool {
        for c in self {
            if !c.isSnakeUppercase() {
                return false
            }
        }
        return true
    }

    func allLetterIsNumeric() -> Bool {
        for c in self {
            if !c.isNumber {
                return false
            }
        }
        return true
    }
}

extension Character {
    fileprivate func isSnakeUppercase() -> Bool {
        return self.isNumber || ("A"..."Z").contains(self) || self == "_"
    }
}
