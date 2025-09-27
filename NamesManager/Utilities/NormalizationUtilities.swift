import Foundation

enum TransliterationMode: String, CaseIterable, Identifiable {
    case none
    case latin

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Original"
        case .latin: return "Latin"
        }
    }
}

enum NamesSortOrder: String, CaseIterable, Identifiable {
    case ascending
    case descending

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .ascending: return "arrow.up"
        case .descending: return "arrow.down"
        }
    }

    var title: String {
        switch self {
        case .ascending: return "A–Z"
        case .descending: return "Z–A"
        }
    }
}

enum QuickFix: String, CaseIterable, Identifiable {
    case trimWhitespace
    case titleCase

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trimWhitespace: return "Trim Spaces"
        case .titleCase: return "Title Case"
        }
    }
}

enum NormalizationUtilities {
    static func normalize(fullName: String) -> String {
        let trimmed = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let components = lowercased.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        return components.joined(separator: " ")
    }

    static func transliterate(_ text: String, mode: TransliterationMode) -> String {
        switch mode {
        case .none:
            return text
        case .latin:
            let transform = "Any-Latin; Latin-ASCII"
            return text.applyingTransform(.init(transform), reverse: false) ?? text
        }
    }

    static func applyQuickFix(_ fix: QuickFix, to text: String) -> String {
        switch fix {
        case .trimWhitespace:
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        case .titleCase:
            let locale = Locale.current
            return text.localizedCapitalized(with: locale)
        }
    }
}

private extension String {
    func localizedCapitalized(with locale: Locale) -> String {
        let formatter = PersonNameComponentsFormatter()
        if let components = formatter.personNameComponents(from: self) {
            return formatter.string(from: components)
        }
        return self.capitalized(with: locale)
    }
}
