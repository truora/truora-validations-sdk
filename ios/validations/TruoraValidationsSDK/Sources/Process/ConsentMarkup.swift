//
//  ConsentMarkup.swift
//  TruoraValidationsSDK
//

import Foundation

/// Renders the HTML fragment the consent-terms service returns into the plain
/// string ``DataAuthorizationView`` displays, plus the single inline link
/// ``AuthorizationConsent`` models.
///
/// The stored copy is authored for the web process-runner, which renders it with
/// `v-html` (`DefaultAuthorizationMessage.vue`). Real production terms therefore
/// carry markup — every `default-basic` / `default-items` variant in the consents
/// seed contains an `<a href>`, and the `default-items` variants add `<b>`:
///
/// ```
/// Autorizo el uso de mis <a href="https://…pdf" target="_blank">datos biométricos</a> para…
/// ```
///
/// SwiftUI's `Text` and `AttributedString(_:)` do **not** parse markup, so handing
/// that string to the view untouched shows the user raw tags on a legally-binding
/// screen. This type is the translation step.
///
/// Only the subset the service actually emits is interpreted:
/// - `<br>` (any spelling) becomes a newline. This is also how
///   ``AuthorizationHydration``'s `<br><br>` face/credit-bureau separator — kept
///   verbatim for web parity — reaches the screen as a paragraph break.
/// - The first `<a href="…">label</a>` becomes ``Rendered/linkText`` +
///   ``Rendered/linkURL`` so the view can style and tap it. Every variant in the
///   terms table carries at most one anchor, which is exactly what
///   ``AuthorizationConsent`` models.
/// - Any other tag is dropped, keeping its content.
/// - The named entities the copy could contain are decoded.
///
/// Copy that carries no anchor but does carry a bare `https://` URL gets that URL
/// as its link, mirroring the web's `updateLinksInText` — which is applied to the
/// client-authored `client_authorization` description, the one consent whose text
/// is not markup written by the terms service.
///
/// Rendering never fails: anything unparseable degrades to the input string.
enum ConsentMarkup {
    /// Display-ready copy plus its single optional inline link.
    ///
    /// ``linkText`` is always a literal substring of ``text`` — ``AuthorizationLinkText``
    /// locates it with `range(of:)` to apply the link styling.
    struct Rendered: Equatable {
        let text: String
        let linkText: String?
        let linkURL: URL?
    }

    /// Turns one consent-terms fragment into display-ready copy.
    static func render(_ markup: String) -> Rendered {
        let withBreaks = replacingMatches(of: lineBreak, in: markup, with: "\n")
        let text = plainText(from: withBreaks)

        guard let anchor = firstAnchor(in: withBreaks) else {
            return linkifyingBareURL(in: text)
        }

        let label = plainText(from: anchor.label)

        return Rendered(
            text: text,
            linkText: label.isEmpty ? nil : label,
            linkURL: URL(string: anchor.href)
        )
    }

    // MARK: - Patterns

    // Compiled once (Swift statics are lazy). A pattern that somehow fails to
    // compile leaves the corresponding step a no-op rather than trapping.
    private static let lineBreak = compile(#"<br\s*/?>"#)
    private static let anchor = compile(#"<a\b[^>]*href\s*=\s*["']([^"']*)["'][^>]*>([\s\S]*?)</a\s*>"#)
    private static let anyTag = compile(#"</?[a-zA-Z][^>]*>"#)
    /// The web's `updateLinksInText` regex: `https` only, no bare `http`.
    private static let bareURL = compile(#"https://[\w_-]+(?:\.[\w_-]+)+[\w.,@?^=%&:/~+#-]*[\w@?^=%&/~+#-]"#)

    /// Decoded last-to-first so `&amp;lt;` does not turn into `<`.
    private static let entities: [(escaped: String, decoded: String)] = [
        ("&lt;", "<"),
        ("&gt;", ">"),
        ("&quot;", "\""),
        ("&#39;", "'"),
        ("&apos;", "'"),
        ("&nbsp;", "\u{00A0}"),
        ("&amp;", "&")
    ]

    private static func compile(_ pattern: String) -> NSRegularExpression? {
        try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }

    // MARK: - Steps

    /// Drops every tag, decodes entities and trims the edges. Applied to both the
    /// whole fragment and the anchor's label so the label stays a substring of the
    /// rendered text.
    private static func plainText(from markup: String) -> String {
        let stripped = replacingMatches(of: anyTag, in: markup, with: "")
        let decoded = entities.reduce(stripped) { partial, entity in
            partial.replacingOccurrences(of: entity.escaped, with: entity.decoded, options: .caseInsensitive)
        }

        return decoded.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func firstAnchor(in markup: String) -> (href: String, label: String)? {
        guard
            let anchor,
            let match = anchor.firstMatch(in: markup, range: NSRange(markup.startIndex..., in: markup)),
            match.numberOfRanges == 3,
            let hrefRange = Range(match.range(at: 1), in: markup),
            let labelRange = Range(match.range(at: 2), in: markup) else {
            return nil
        }

        return (String(markup[hrefRange]), String(markup[labelRange]))
    }

    /// Links the first bare `https://` URL. The visible text stays exactly as
    /// authored (it has to remain a substring of `text`); only the tap target
    /// drops the query string, matching the web's `url.search = ''`.
    private static func linkifyingBareURL(in text: String) -> Rendered {
        guard
            let bareURL,
            let match = bareURL.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
            let range = Range(match.range, in: text) else {
            return Rendered(text: text, linkText: nil, linkURL: nil)
        }

        let urlString = String(text[range])

        guard
            var components = URLComponents(string: urlString),
            components.query != nil || components.fragment != nil else {
            return Rendered(text: text, linkText: urlString, linkURL: URL(string: urlString))
        }

        components.query = nil
        components.fragment = nil

        return Rendered(text: text, linkText: urlString, linkURL: components.url)
    }

    private static func replacingMatches(
        of regex: NSRegularExpression?,
        in text: String,
        with template: String
    ) -> String {
        guard let regex else {
            return text
        }

        return regex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: template
        )
    }
}
