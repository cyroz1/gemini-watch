import Foundation

enum PartType: Equatable, Hashable {
    case text
    case code(language: String?)
    case blockMath
    case inlineMath
}

struct ContentPart: Equatable, Hashable {
    let text: String
    let type: PartType
}

class MarkdownParser {
    static let shared = MarkdownParser()

    // MARK: - Pre-compiled Regexes (compiled once at init)
    private let codeRegex: NSRegularExpression
    private let blockMathRegex: NSRegularExpression
    private let inlineMathRegex: NSRegularExpression
    private let listMarkerRegex: NSRegularExpression
    private let whitespaceRegex: NSRegularExpression

    // Math-formatting regexes (also pre-compiled)
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

    // MARK: - Parse result cache (keyed by message text)
    private var cache: [String: [ContentPart]] = [:]
    private let cacheLimit = 100

    private init() {
        func make(_ pattern: String, _ opts: NSRegularExpression.Options = []) -> NSRegularExpression {
            // Patterns are compile-time constants — safe to force-unwrap
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

    func parse(_ text: String) -> [ContentPart] {
        if let cached = cache[text] { return cached }
        let result = doParse(text)
        if cache.count >= cacheLimit { cache.removeAll() } // simple eviction
        cache[text] = result
        return result
    }

    private func doParse(_ text: String) -> [ContentPart] {
        var parts: [ContentPart] = []
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)

        // 1. Extract Code Blocks
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

        // 2. Extract Math
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

        // 3. Assemble parts
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

    // MARK: - LaTeX → Readable Unicode

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

    // MARK: - Plain Text Formatting

    private func formatText(_ text: String) -> String {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return listMarkerRegex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "$1•$2")
    }
}
