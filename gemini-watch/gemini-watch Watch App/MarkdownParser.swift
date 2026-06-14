import Foundation

enum PartType: Equatable, Hashable {
    case text
    case code(language: String?)
    case blockMath
    case inlineMath
}

struct ContentPart: Equatable, Hashable, Codable {
    let text: String
    let type: PartType
}

// Codable support for PartType
extension PartType: Codable {
    private enum CodingKeys: String, CodingKey {
        case base, language
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let base = try container.decode(String.self, forKey: .base)
        switch base {
        case "text": self = .text
        case "code":
            let lang = try container.decodeIfPresent(String.self, forKey: .language)
            self = .code(language: lang)
        case "blockMath": self = .blockMath
        case "inlineMath": self = .inlineMath
        default: throw DecodingError.dataCorruptedError(forKey: .base, in: container, debugDescription: "Unknown type")
        }
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text: try container.encode("text", forKey: .base)
        case .code(let lang):
            try container.encode("code", forKey: .base)
            try container.encode(lang, forKey: .language)
        case .blockMath: try container.encode("blockMath", forKey: .base)
        case .inlineMath: try container.encode("inlineMath", forKey: .base)
        }
    }
}

class MarkdownParser {
    static let shared = MarkdownParser()

    // MARK: - Pre-compiled Regexes
    private let codeRegex: NSRegularExpression
    private let blockMathRegex: NSRegularExpression
    private let inlineMathRegex: NSRegularExpression
    private let listMarkerRegex: NSRegularExpression
    private let whitespaceRegex: NSRegularExpression

    // Math-formatting regexes
    private let fracRegex: NSRegularExpression
    private let sqrtNRegex: NSRegularExpression
    private let sqrtRegex: NSRegularExpression
    private let leftBracketRegex: NSRegularExpression
    private let rightBracketRegex: NSRegularExpression
    private let supRegex: NSRegularExpression
    private let subRegex: NSRegularExpression
    private let textCmdRegex: NSRegularExpression
    private let mathCmdRegex: NSRegularExpression
    private let unknownCmdRegex: NSRegularExpression
    private let multiSpaceRegex: NSRegularExpression

    // MARK: - Parse result cache
    private var cache: [String: [ContentPart]] = [:]
    private var cacheKeys: [String] = []
    private let cacheLimit = 100

    private init() {
        func make(_ pattern: String, _ opts: NSRegularExpression.Options = []) -> NSRegularExpression {
            return try! NSRegularExpression(pattern: pattern, options: opts)
        }
        codeRegex        = make("```(?:([^\\n]*?)\\n)?([\\s\\S]*?)```")
        blockMathRegex   = make("\\$\\$([\\s\\S]*?)\\$\\$")
        inlineMathRegex  = make("\\$(?!\\s)((?:[^$\\n]|\\\\.)*?)(?<!\\s)\\$")
        listMarkerRegex  = make("^(\\s*)\\*(\\s+)", .anchorsMatchLines)
        whitespaceRegex  = make("[ \\t]+")
        fracRegex        = make("\\\\frac\\{([^}]*)\\}\\{([^}]*)\\}")
        sqrtNRegex       = make("\\\\sqrt\\[([^\\]]*)\\]\\{([^}]*)\\}")
        sqrtRegex        = make("\\\\sqrt\\{([^}]*)\\}")
        leftBracketRegex = make("\\\\left\\s*([\\(\\)\\[\\]\\{\\}|])")
        rightBracketRegex = make("\\\\right\\s*([\\(\\)\\[\\]\\{\\}|])")
        supRegex         = make("\\^\\{([^}]*)\\}")
        subRegex         = make("_\\{([^}]*)\\}")
        textCmdRegex     = make("\\\\text\\{([^}]*)\\}")
        mathCmdRegex     = make("\\\\math[a-z]+\\{([^}]*)\\}")
        unknownCmdRegex  = make("\\\\[a-zA-Z]+")
        multiSpaceRegex  = make("[ \\t]+")
    }

    func parse(_ text: String, isStreaming: Bool = false) -> [ContentPart] {
        if let cached = cache[text] {
            if let index = cacheKeys.firstIndex(of: text) {
                cacheKeys.remove(at: index)
                cacheKeys.append(text)
            }
            return cached
        }
        
        // During streaming, try to find the longest cached prefix to optimize parsing
        if isStreaming {
            let sortedKeys = cacheKeys.sorted { $0.count > $1.count }
            if let prefix = sortedKeys.first(where: { text.hasPrefix($0) }),
               let prefixParts = cache[prefix] {
                
                let remaining = String(text.dropFirst(prefix.count))
                if !remaining.isEmpty {
                    // For safety in markdown, if the prefix ends inside a block, we can't trivially append.
                    // But for streaming UX, we can parse the delta and append if the prefix ends cleanly.
                    if !prefix.contains("```") && !prefix.contains("$$") && !prefix.contains("$") {
                        let deltaParts = doParse(remaining)
                        let combined = prefixParts + deltaParts
                        return combined
                    }
                }
            }
        }
        
        let result = doParse(text)
        
        // Cache management: Skip heavy caching for every tiny streaming chunk to avoid churn,
        // but cache significant milestones (every 50 chars) or final results.
        if isStreaming && text.count % 50 != 0 {
            return result
        }
        
        if cacheKeys.count >= cacheLimit {
            let oldest = cacheKeys.removeFirst()
            cache[oldest] = nil
        }
        cacheKeys.append(text)
        cache[text] = result
        return result
    }

    private func doParse(_ text: String) -> [ContentPart] {
        var parts: [ContentPart] = []
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)

        var codeMatches: [(range: NSRange, part: ContentPart)] = []
        codeRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            guard let match = match, match.range.location != NSNotFound else { return }
            let languageRange = match.range(at: 1)
            let contentRange  = match.range(at: 2)
            var language: String? = nil
            if languageRange.location != NSNotFound, let r = Range(languageRange, in: text) {
                let lang = String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !lang.isEmpty { language = lang }
            }
            if contentRange.location != NSNotFound, let r = Range(contentRange, in: text) {
                codeMatches.append((match.range, ContentPart(text: String(text[r]), type: .code(language: language))))
            }
        }

        func isInsideCode(_ range: NSRange) -> Bool {
            codeMatches.contains { NSIntersectionRange(range, $0.range).length > 0 }
        }

        var mathMatches: [(range: NSRange, part: ContentPart)] = []
        blockMathRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            guard let match = match, !isInsideCode(match.range) else { return }
            if let r = Range(match.range(at: 1), in: text) {
                let content = String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
                mathMatches.append((match.range, ContentPart(text: formatMath(content), type: .blockMath)))
            }
        }

        inlineMathRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            guard let match = match, !isInsideCode(match.range) else { return }
            let overlaps = mathMatches.contains { NSIntersectionRange(match.range, $0.range).length > 0 }
            if overlaps { return }
            if let r = Range(match.range(at: 1), in: text) {
                mathMatches.append((match.range, ContentPart(text: formatMath(String(text[r])), type: .inlineMath)))
            }
        }

        var allSpecial = codeMatches + mathMatches
        allSpecial.sort { $0.range.location < $1.range.location }

        var current = 0
        let nsText = text as NSString

        for part in allSpecial {
            if part.range.location > current {
                let gap = nsText.substring(with: NSRange(location: current, length: part.range.location - current))
                if !gap.isEmpty { parts.append(ContentPart(text: formatText(gap), type: .text)) }
            }
            parts.append(part.part)
            current = part.range.location + part.range.length
        }
        if current < nsText.length {
            let tail = nsText.substring(with: NSRange(location: current, length: nsText.length - current))
            if !tail.isEmpty { parts.append(ContentPart(text: formatText(tail), type: .text)) }
        }

        return parts
    }

    private func formatMath(_ latex: String) -> String {
        var s = latex
        s = apply(fracRegex,         to: s, template: "($1)/($2)")
        s = apply(sqrtNRegex,        to: s, template: "$1√($2)")
        s = apply(sqrtRegex,         to: s, template: "√($1)")
        s = apply(leftBracketRegex,  to: s, template: "$1")
        s = apply(rightBracketRegex, to: s, template: "$1")
        s = apply(supRegex,          to: s, template: "^($1)")
        s = apply(subRegex,          to: s, template: "_($1)")
        s = apply(textCmdRegex,      to: s, template: "$1")
        s = apply(mathCmdRegex,      to: s, template: "$1")
        s = s.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")

        let greek: [(String, String)] = [
            ("\\alpha","α"),("\\beta","β"),("\\gamma","γ"),("\\delta","δ"),
            ("\\epsilon","ε"),("\\varepsilon","ε"),("\\zeta","ζ"),("\\eta","η"),
            ("\\theta","θ"),("\\vartheta","ϑ"),("\\iota","ι"),("\\kappa","κ"),
            ("\\lambda","λ"),("\\mu","μ"),("\\nu","ν"),("\\xi","ξ"),
            ("\\pi","π"),("\\varpi","ϖ"),("\\rho","ρ"),("\\varrho","ϱ"),
            ("\\sigma","σ"),("\\varsigma","ς"),("\\tau","τ"),("\\upsilon","υ"),
            ("\\phi","φ"),("\\varphi","φ"),("\\chi","χ"),("\\psi","ψ"),("\\omega","ω"),
            ("\\Gamma","Γ"),("\\Delta","Δ"),("\\Theta","Θ"),("\\Lambda","Λ"),
            ("\\Xi","Ξ"),("\\Pi","Π"),("\\Sigma","Σ"),("\\Upsilon","Υ"),
            ("\\Phi","Φ"),("\\Psi","Ψ"),("\\Omega","Ω"),
        ]
        for (cmd, sym) in greek { s = s.replacingOccurrences(of: cmd, with: sym) }

        let operators: [(String, String)] = [
            ("\\times","×"),("\\div","÷"),("\\pm","±"),("\\mp","∓"),
            ("\\cdot","·"),("\\cdots","⋯"),("\\ldots","…"),("\\vdots","⋮"),
            ("\\leq","≤"),("\\geq","≥"),("\\neq","≠"),("\\approx","≈"),
            ("\\equiv","≡"),("\\sim","∼"),("\\propto","∝"),
            ("\\infty","∞"),("\\partial","∂"),("\\nabla","∇"),
            ("\\sum","Σ"),("\\prod","Π"),("\\int","∫"),("\\oint","∮"),
            ("\\forall","∀"),("\\exists","∃"),("\\in","∈"),("\\notin","∉"),
            ("\\subset","⊂"),("\\supset","⊃"),("\\cup","∪"),("\\cap","∩"),
            ("\\emptyset","∅"),("\\varnothing","∅"),
            ("\\rightarrow","→"),("\\leftarrow","←"),("\\Rightarrow","⇒"),
            ("\\Leftarrow","⇐"),("\\leftrightarrow","↔"),("\\Leftrightarrow","⟺"),
            ("\\to","→"),("\\gets","←"),
            ("\\langle","⟨"),("\\rangle","⟩"),
            ("\\\\ ","‖"),("\\,","  "),("\\;"," "),("\\:"," "),("\\!",""),
            ("\\quad","  "),("\\qquad","    "),
            ("\\ln","ln"),("\\log","log"),("\\exp","exp"),
            ("\\sin","sin"),("\\cos","cos"),("\\tan","tan"),
            ("\\arcsin","arcsin"),("\\arccos","arccos"),("\\arctan","arctan"),
            ("\\lim","lim"),("\\max","max"),("\\min","min"),
        ]
        for (cmd, sym) in operators { s = s.replacingOccurrences(of: cmd, with: sym) }

        s = apply(unknownCmdRegex, to: s, template: "")
        s = apply(multiSpaceRegex, to: s, template: " ")
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func apply(_ regex: NSRegularExpression, to input: String, template: String) -> String {
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        return regex.stringByReplacingMatches(in: input, options: [], range: range, withTemplate: template)
    }

    private func formatText(_ text: String) -> String {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return listMarkerRegex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "$1•$2")
    }
}
