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
        
        // Ranges to process (initially the whole string)
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        var globalRangesOfInterest = [fullRange]
        
        // 1. Extract Code Blocks
        // Pattern: ```(optional language)\n(content)``` or ```(content)```
        // We look for parts that are code, and we remove them from the "interest" list
        
        // Regex explanation:
        // ```             : Start with triple backticks
        // (?:             : Start non-capturing group for language info
        //   ([^\n]*?)     : Capture Group 1: Language identifier (anything not newline, lazy)
        //   \n            : Literal newline (required if language is present)
        // )?              : End optional group
        // ([\s\S]*?)      : Capture Group 2: Content (anything including newlines, lazy)
        // ```             : End triple backticks
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
                if !langStr.isEmpty {
                    language = langStr
                }
            }
            
            if contentRange.location != NSNotFound, let range = Range(contentRange, in: text) {
                let content = String(text[range])
                // Create the part
                codeMatches.append((match.range, ContentPart(text: content, type: .code(language: language))))
            }
        }
        
        // 2. Extract Math (Block and Inline)
        // We only search for math in the ranges that are NOT code matches.
        
        // Helper to check if a range overlaps with any code match
        func isInsideCode(_ range: NSRange) -> Bool {
            for code in codeMatches {
                if NSIntersectionRange(range, code.range).length > 0 {
                    return true
                }
            }
            return false
        }
        
        var mathMatches: [(range: NSRange, part: ContentPart)] = []
        
        // Block Math: $$content$$
        let blockMathRegex = try! NSRegularExpression(pattern: "\\$\\$([\\s\\S]*?)\\$\\$", options: [])
        blockMathRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            guard let match = match, !isInsideCode(match.range) else { return }
            
            if let contentRange = Range(match.range(at: 1), in: text) {
                let content = String(text[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                mathMatches.append((match.range, ContentPart(text: content, type: .blockMath)))
            }
        }
        
        // Inline Math: $content$
        // Pattern: $(?!\s)( (?: [^$\n] | \\. )*? )(?<!\s)$
        // Avoids matching currency like $5, and supports escaped dollars like \$ inside math.
        let inlineMathPattern = "\\$(?!\\s)((?:[^$\\n]|\\\\.)*?)(?<!\\s)\\$"
        let inlineMathRegex = try! NSRegularExpression(pattern: inlineMathPattern, options: [])
        
        inlineMathRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            // Check overlaps with code OR block math
            guard let match = match, !isInsideCode(match.range) else { return }
            
            // Also need to check overlap with already found block math
            let overlapsBlock = mathMatches.contains { block in
                NSIntersectionRange(match.range, block.range).length > 0
            }
            if overlapsBlock { return }
            
            if let contentRange = Range(match.range(at: 1), in: text) {
                let content = String(text[contentRange])
                mathMatches.append((match.range, ContentPart(text: content, type: .inlineMath)))
            }
        }
        
        // 3. Assemble and fill gaps with Text
        
        var allSpecialParts = codeMatches + mathMatches
        // Sort by location
        allSpecialParts.sort { $0.range.location < $1.range.location }
        
        var currentIndex = 0
        let nsText = text as NSString
        
        for part in allSpecialParts {
            // Check for gap before this part
            if part.range.location > currentIndex {
                let gapRange = NSRange(location: currentIndex, length: part.range.location - currentIndex)
                let gapText = nsText.substring(with: gapRange)
                if !gapText.isEmpty {
                    parts.append(ContentPart(text: formatText(gapText), type: .text))
                }
            }
            
            // Add the special part
            parts.append(part.part)
            
            // Advance index
            currentIndex = part.range.location + part.range.length
        }
        
        // Check for remaining text at the end
        if currentIndex < nsText.length {
            let remainingRange = NSRange(location: currentIndex, length: nsText.length - currentIndex)
            let remainingText = nsText.substring(with: remainingRange)
            parts.append(ContentPart(text: formatText(remainingText), type: .text))
        }
        
        return parts
    }
    
    private func formatText(_ text: String) -> String {
        // Replace asterisk list markers "* " with bullet points "• "
        // Pattern: Start of line (^), optional whitespace (\s*), asterisk (\*), required whitespace (\s+)
        // We use anchorsMatchLines so ^ matches line starts
        
        let pattern = "^(\\s*)\\*(\\s+)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) else {
            return text
        }
        
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "$1•$2")
    }
}
