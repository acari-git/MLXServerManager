import Foundation

enum ShellArgumentParserError: LocalizedError, Equatable {
    case unterminatedSingleQuote
    case unterminatedDoubleQuote
    case trailingEscape

    var errorDescription: String? {
        switch self {
        case .unterminatedSingleQuote:
            return "Raw extra arguments contain an unterminated single quote."
        case .unterminatedDoubleQuote:
            return "Raw extra arguments contain an unterminated double quote."
        case .trailingEscape:
            return "Raw extra arguments end with an incomplete escape sequence."
        }
    }
}

enum ShellArgumentParser {
    nonisolated static func parse(_ input: String) throws -> [String] {
        enum QuoteMode {
            case none
            case single
            case double
        }

        var arguments: [String] = []
        var current = ""
        var quoteMode: QuoteMode = .none
        var isEscaping = false
        var tokenStarted = false

        func finishToken() {
            guard tokenStarted else { return }
            arguments.append(current)
            current = ""
            tokenStarted = false
        }

        for character in input {
            if isEscaping {
                current.append(character)
                tokenStarted = true
                isEscaping = false
                continue
            }

            switch quoteMode {
            case .single:
                if character == "'" {
                    quoteMode = .none
                } else {
                    current.append(character)
                }
                tokenStarted = true

            case .double:
                if character == "\"" {
                    quoteMode = .none
                } else if character == "\\" {
                    isEscaping = true
                } else {
                    current.append(character)
                }
                tokenStarted = true

            case .none:
                if character.isWhitespace {
                    finishToken()
                } else if character == "'" {
                    quoteMode = .single
                    tokenStarted = true
                } else if character == "\"" {
                    quoteMode = .double
                    tokenStarted = true
                } else if character == "\\" {
                    isEscaping = true
                    tokenStarted = true
                } else {
                    current.append(character)
                    tokenStarted = true
                }
            }
        }

        if isEscaping {
            throw ShellArgumentParserError.trailingEscape
        }
        switch quoteMode {
        case .single:
            throw ShellArgumentParserError.unterminatedSingleQuote
        case .double:
            throw ShellArgumentParserError.unterminatedDoubleQuote
        case .none:
            break
        }

        finishToken()
        return arguments
    }
}
