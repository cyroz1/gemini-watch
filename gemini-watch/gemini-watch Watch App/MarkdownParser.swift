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
    
    private init() {}
    
    func parse(_ text: String) -> [ContentPart] {
        var parts: [ContentPart] = []
        
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        
        // 1. Extract Code Blocks
        let codePattern = "```(?:([^\\n]*?)\\n)?([\\s\\S]*?)```"
        let codeRegex = try! NSRegularExpression(pattern: codePattern, options: [])
        var codeMatches: [(range: NSRange, part: ContentPart)] = []
        
        codeRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            guard let match = match, match.range.location != NSNotFound else { return }
            
            let languageRange = match.range(at: 1)
            let contentRange = match.range(at: 2)
            
            var language: String? = nil
            if languageRange.location != NSNotFound, let range = Range(languageRange, in: text) {
                let langStr = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !langStr.isEmpty { language = langStr }
            }
            
            if contentRange.location != NSNotFound, let range = Range(contentRange, in: text) {
                let content = String(text[range])
                codeMatches.append((match.range, ContentPart(text: content, type: .code(language: language))))
            }
        }
        
        // 2. Extract Math (Block and Inline)
        func isInsideCode(_ range: NSRange) -> Bool {
            codeMatches.contains { NSIntersectionRange(range, $0.range).length > 0 }
        }
        
        var mathMatches: [(range: NSRange, part: ContentPart)] = []
        
        // Block Math: $$content$$
        let blockMathRegex = try! NSRegularExpression(pattern: "\\$\\$([\\s\\S]*?)\\$\\$", options: [])
        blockMathRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            guard let match = match, !isInsideCode(match.range) else { return }
            if let contentRange = Range(match.range(at: 1), in: text) {
                let content = String(text[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                mathMatches.append((match.range, ContentPart(text: formatMath(content), type: .blockMath)))
            }
        }
        
        // Inline Math: $content$
        let inlineMathPattern = "\\$(?!\\s)((?:[^$\\n]|\\\\.)*?)(?<!\\s)\\$"
        let inlineMathRegex = try! NSRegularExpression(pattern: inlineMathPattern, options: [])
        inlineMathRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            guard let match = match, !isInsideCode(match.range) else { return }
            let overlapsBlock = mathMatches.contains { NSIntersectionRange(match.range, $0.range).length > 0 }
            if overlapsBlock { return }
            if let contentRange = Range(match.range(at: 1), in: text) {
                let content = String(text[contentRange])
                mathMatches.append((match.range, ContentPart(text: formatMath(content), type: .inlineMath)))
            }
        }
        
        // 3. Assemble parts, filling gaps with plain text
        var allSpecialParts = codeMatches + mathMatches
        allSpecialParts.sort { $0.range.location < $1.range.location }
        
        var currentIndex = 0
        let nsText = text as NSString
        
        for part in allSpecialParts {
            if part.range.location > currentIndex {
                let gapRange = NSRange(location: currentIndex, length: part.range.location - currentIndex)
                let gapText = nsText.substring(with: gapRange)
                if !gapText.isEmpty {
                    parts.append(ContentPart(text: formatText(gapText), type: .text))
                }
            }
            parts.append(part.part)
            currentIndex = part.range.location + part.range.length
        }
        
        if currentIndex < nsText.length {
            let remainingRange = NSRange(location: currentIndex, length: nsText.length - currentIndex)
            let remainingText = nsText.substring(with: remainingRange)
            parts.append(ContentPart(text: formatText(remainingText), type: .text))
        }
        
        return parts
    }
    
    // MARK: - LaTeX → Readable Unicode
    
    /// Converts LaTeX math source into a human-readable Unicode approximation.
    private func formatMath(_ latex: String) -> String {
        var s = latex
        
        // \frac{a}{b} → (a)/(b)
        s = applyRegex(s, pattern: "\\\\frac\\{([^}]*)\\}\\{([^}]*)\\}", template: "($1)/($2)")
        
        // \sqrt[n]{x} → n√(x)  (must come before plain \sqrt)
        s = applyRegex(s, pattern: "\\\\sqrt\\[([^\\]]*)\\]\\{([^}]*)\\}", template: "$1√($2)")
        // \sqrt{x} → √(x)
        s = applyRegex(s, pattern: "\\\\sqrt\\{([^}]*)\\}", template: "√($1)")
        
        // \left( \right) etc. → just the bracket
        s = applyRegex(s, pattern: "\\\\left\\s*([\\(\\)\\[\\]\\{\\}|])", template: "$1")
        s = applyRegex(s, pattern: "\\\\right\\s*([\\(\\)\\[\\]\\{\\}|])", template: "$1")
        
        // Superscripts/subscripts with braces
        s = applyRegex(s, pattern: "\\^\\{([^}]*)\\}", template: "^($1)")
        s = applyRegex(s, pattern: "_\\{([^}]*)\\}", template: "_($1)")
        
        // \text{...}, \mathrm{...}, \mathbf{...}, etc.
        s = applyRegex(s, pattern: "\\\\text\\{([^}]*)\\}", template: "$1")
        s = applyRegex(s, pattern: "\\\\math[a-z]+\\{([^}]*)\\}", template: "$1")
        
        // Strip remaining grouping braces
        s = s.replacingOccurrences(of: "{", with: "")
        s = s.replacingOccurrences(of: "}", with: "")
        
        // Greek letters
        let greek: [(String, String)] = [
            ("\\alpha", "α"), ("\\beta", "β"), ("\\gamma", "γ"), ("\\delta", "δ"),
            ("\\epsilon", "ε"), ("\\varepsilon", "ε"), ("\\zeta", "ζ"), ("\\eta", "η"),
            ("\\theta", "θ"), ("\\vartheta", "ϑ"), ("\\iota", "ι"), ("\\kappa", "κ"),
            ("\\lambda", "λ"), ("\\mu", "μ"), ("\\nu", "ν"), ("\\xi", "ξ"),
            ("\\pi", "π"), ("\\varpi", "ϖ"), ("\\rho", "ρ"), ("\\varrho", "ϱ"),
            ("\\sigma", "σ"), ("\\varsigma", "ς"), ("\\tau", "τ"), ("\\upsilon", "υ"),
            ("\\phi", "φ"), ("\\varphi", "φ"), ("\\chi", "χ"), ("\\psi", "ψ"),
            ("\\omega", "ω"),
            ("\\Gamma", "Γ"), ("\\Delta", "Δ"), ("\\Theta", "Θ"), ("\\Lambda", "Λ"),
            ("\\Xi", "Ξ"), ("\\Pi", "Π"), ("\\Sigma", "Σ"), ("\\Upsilon", "Υ"),
            ("\\Phi", "Φ"), ("\\Psi", "Ψ"), ("\\Omega", "Ω"),
        ]
        for (cmd, sym) in greek { s = s.replacingOccurrences(of: cmd, with: sym) }
        
        // Operators and symbols
        let operators: [(String, String)] = [
            ("\\times", "×"), ("\\div", "÷"), ("\\pm", "±"), ("\\mp", "∓"),
            ("\\cdot", "·"), ("\\cdots", "⋯"), ("\\ldots", "…"), ("\\vdots", "⋮"),
            ("\\leq", "≤"), ("\\geq", "≥"), ("\\neq", "≠"), ("\\approx", "≈"),
            ("\\equiv", "≡"), ("\\sim", "∼"), ("\\propto", "∝"),
            ("\\infty", "∞"), ("\\partial", "∂"), ("\\nabla", "∇"),
            ("\\sum", "Σ"), ("\\prod", "Π"), ("\\int", "∫"), ("\\oint", "∮"),
            ("\\forall", "∀"), ("\\exists", "∃"), ("\\in", "∈"), ("\\notin", "∉"),
            ("\\subset", "⊂"), ("\\supset", "⊃"), ("\\cup", "∪"), ("\\cap", "∩"),
            ("\\emptyset", "∅"), ("\\varnothing", "∅"),
            ("\\rightarrow", "→"), ("\\leftarrow", "←"), ("\\Rightarrow", "⇒"),
            ("\\Leftarrow", "⇐"), ("\\leftrightarrow", "↔"), ("\\Leftrightarrow", "⟺"),
            ("\\to", "→"), ("\\gets", "←"),
            ("\\langle", "⟨"), ("\\rangle", "⟩"),
            ("\\|", "‖"), ("\\,", " "), ("\\;", " "), ("\\:", " "), ("\\!", ""),
            ("\\quad", "  "), ("\\qquad", "    "),
            ("\\ln", "ln"), ("\\log", "log"), ("\\exp", "exp"),
            ("\\sin", "sin"), ("\\cos", "cos"), ("\\tan", "tan"),
            ("\\arcsin", "arcsin"), ("\\arccos", "arccos"), ("\\arctan", "arctan"),
            ("\\lim", "lim"), ("\\max", "max"), ("\\min", "min"),
        ]
        for (cmd, sym) in operators { s = s.replacingOccurrences(of: cmd, with: sym) }
        
        // Strip any remaining unknown \commands
        s = applyRegex(s, pattern: "\\\\[a-zA-Z]+", template: "")
        
        // Clean up extra whitespace
        s = applyRegex(s, pattern: "[ \\t]+", template: " ")
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return s
    }
    
    private func applyRegex(_ input: String, pattern: String, template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return input }
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        return regex.stringByReplacingMatches(in: input, options: [], range: range, withTemplate: template)
    }
    
    // MARK: - Plain Text Formatting
    
    private func formatText(_ text: String) -> String {
        // Replace "* " list markers with "• "
        let pattern = "^(\\s*)\\*(\\s+)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "$1•$2")
    }
}
