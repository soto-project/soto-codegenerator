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

extension String {
    public func toSwiftLabelCase() -> String {
        let snakeCase = self.replacingOccurrences(of: "-", with: "_")
        if snakeCase.allLetterIsSnakeUppercased() {
            return snakeCase.lowercased().camelCased(capitalize: false)
        }
        return snakeCase.camelCased(capitalize: false)
    }

    public func toSwiftVariableCase() -> String {
        return self.toSwiftLabelCase().reservedwordEscaped()
    }

    public func toSwiftClassCase() -> String {
        return self.replacingOccurrences(of: "-", with: "_")
            .camelCased(capitalize: true)
            .reservedwordEscaped()
    }

    // for some reason the Region and Partition enum are not camel cased
    public func toSwiftRegionEnumCase() -> String {
        return self.replacingOccurrences(of: "-", with: "")
    }

    public func toSwiftEnumCase() -> String {
        return self.toSwiftLabelCase().reservedwordEscaped()
    }

    public func tagStriped() -> String {
        return self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
    }

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

    func camelCased(capitalize: Bool) -> String {
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

    func reservedwordEscaped() -> String {
        if swiftReservedWords.contains(self) {
            return "`\(self)`"
        }
        return self
    }

    private static let backslashEncodeMap: [String.Element: String] = [
        "\"": "\\\"",
        "\\": "\\\\",
        "\n": "\\n",
        "\t": "\\t",
        "\r": "\\r",
    ]

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

    fileprivate func capitalizingFirstLetter() -> String {
        return prefix(1).capitalized + dropFirst()
    }

    fileprivate mutating func capitalizeFirstLetter() {
        self = self.capitalizingFirstLetter()
    }

    mutating func trimCharacters(in characterset: CharacterSet) {
        self = self.trimmingCharacters(in: characterset)
    }
}

extension StringProtocol {
    func allLetterIsNumeric() -> Bool {
        for c in self {
            if !c.isNumber {
                return false
            }
        }
        return true
    }
    
    fileprivate func lowerFirst() -> String {
        return String(self[startIndex]).lowercased() + self[index(after: startIndex)...]
    }

    fileprivate func upperFirst() -> String {
        return String(self[self.startIndex]).uppercased() + self[index(after: startIndex)...]
    }

    /// Lowercase first letter, or if first word is an uppercase acronym then lowercase the whole of the acronym
    fileprivate func lowerFirstWord() -> String {
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

    fileprivate func allLetterIsSnakeUppercased() -> Bool {
        for c in self {
            if !c.isSnakeUppercase() {
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

fileprivate let swiftReservedWords: Set<String> = [
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
    "Protocol",
    "public",
    "repeat",
    "return",
    "self",
    "Self",
    "static",
    "struct",
    "switch",
    "true",
    "try",
    "Type",
    "where",
    "while",
]
