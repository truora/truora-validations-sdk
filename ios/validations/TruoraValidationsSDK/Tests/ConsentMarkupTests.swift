//
//  ConsentMarkupTests.swift
//  TruoraValidationsSDKTests
//

import XCTest
@testable import TruoraValidationsSDK

final class ConsentMarkupTests: XCTestCase {
    // MARK: - Real production copy

    /// Verbatim `_default_basic` / `ALL` / `es` from the consents seed. The whole
    /// point of ``ConsentMarkup``: none of this markup may reach the screen.
    func testRendersRealBasicTermsCopy() {
        let markup = """
        Autorizo el uso de mis <a href="https://www.truora.com/assets/auth.pdf" \
        target="_blank" rel="noopener noreferrer">datos biométricos</a> para verificar mi identidad.
        """

        let rendered = ConsentMarkup.render(markup)

        XCTAssertEqual(rendered.text, "Autorizo el uso de mis datos biométricos para verificar mi identidad.")
        XCTAssertEqual(rendered.linkText, "datos biométricos")
        XCTAssertEqual(rendered.linkURL, URL(string: "https://www.truora.com/assets/auth.pdf"))
        XCTAssertFalse(rendered.text.contains("<"), "No markup may survive to the view")
    }

    /// Verbatim shape of `_default_items` / `ALL` / `en`: bold numbering plus a
    /// trailing policy link, and a `{{.company}}` token the service leaves
    /// unparsed when the company params are omitted.
    func testRendersRealItemsTermsCopyKeepingUnparsedTemplates() {
        let markup = """
        I accept and authorize {{.company}} to validate my identity. I declare that: \
        <b>1.</b> I freely grant authorization. <b>2.</b> Fingerprints are sensitive data. \
        See the <a href="https://www.truora.com/en/integral-privacy-notice">Privacy Policy.</a>
        """

        let rendered = ConsentMarkup.render(markup)

        XCTAssertFalse(rendered.text.contains("<b>"))
        XCTAssertTrue(rendered.text.contains("1. I freely grant authorization."))
        XCTAssertTrue(
            rendered.text.contains("{{.company}}"),
            "An unparsed template is a valid 200 response and must flow through untouched"
        )
        XCTAssertEqual(rendered.linkText, "Privacy Policy.")
        XCTAssertEqual(rendered.linkURL, URL(string: "https://www.truora.com/en/integral-privacy-notice"))
    }

    // MARK: - Line breaks

    func testLineBreaksBecomeNewlines() {
        XCTAssertEqual(ConsentMarkup.render("a<br>b").text, "a\nb")
        XCTAssertEqual(ConsentMarkup.render("a<br/>b").text, "a\nb")
        XCTAssertEqual(ConsentMarkup.render("a<br />b").text, "a\nb")
        XCTAssertEqual(ConsentMarkup.render("a<BR>b").text, "a\nb")
    }

    /// ``AuthorizationHydration`` joins the face and credit-bureau copy with the
    /// web's literal `<br><br>`; it has to land as a paragraph break.
    func testFaceCreditBureauSeparatorBecomesBlankLine() {
        XCTAssertEqual(ConsentMarkup.render("Face copy<br><br>Bureau copy").text, "Face copy\n\nBureau copy")
    }

    // MARK: - Link extraction

    func testLinkTextIsAlwaysASubstringOfTheRenderedText() throws {
        let rendered = ConsentMarkup.render(#"Ver <a href="https://acme.co/t"><b>términos</b></a> aquí."#)

        XCTAssertEqual(rendered.text, "Ver términos aquí.")

        let linkText = try XCTUnwrap(rendered.linkText, "Tags inside the label are stripped too")
        XCTAssertEqual(linkText, "términos")
        XCTAssertNotNil(rendered.text.range(of: linkText), "The view locates the link with range(of:)")
    }

    func testOnlyTheFirstAnchorBecomesTheLink() {
        let rendered = ConsentMarkup.render(
            #"<a href="https://a.co">first</a> and <a href="https://b.co">second</a>"#
        )

        XCTAssertEqual(rendered.text, "first and second", "Later anchors keep their label, lose their markup")
        XCTAssertEqual(rendered.linkText, "first")
        XCTAssertEqual(rendered.linkURL, URL(string: "https://a.co"))
    }

    func testSingleQuotedAndAttributeOrderVariantsStillParse() {
        let rendered = ConsentMarkup.render("Ver <a target='_blank' href='https://acme.co/t'>términos</a>.")

        XCTAssertEqual(rendered.linkText, "términos")
        XCTAssertEqual(rendered.linkURL, URL(string: "https://acme.co/t"))
    }

    func testAnchorWithEmptyLabelYieldsNoLinkText() {
        let rendered = ConsentMarkup.render(#"Texto <a href="https://acme.co"></a>final"#)

        XCTAssertEqual(rendered.text, "Texto final")
        XCTAssertNil(rendered.linkText)
    }

    // MARK: - Bare URLs (the web's updateLinksInText)

    func testBareHTTPSURLBecomesTheLinkWhenThereIsNoAnchor() {
        let rendered = ConsentMarkup.render("Consulta https://acme.co/policy para más detalle.")

        XCTAssertEqual(rendered.text, "Consulta https://acme.co/policy para más detalle.")
        XCTAssertEqual(rendered.linkText, "https://acme.co/policy")
        XCTAssertEqual(rendered.linkURL, URL(string: "https://acme.co/policy"))
    }

    /// The web sets `url.search = ''` before linking. The visible text keeps the
    /// query (it must stay a substring); only the tap target drops it.
    func testBareURLQueryIsStrippedFromTheTapTargetOnly() {
        let rendered = ConsentMarkup.render("Ver https://acme.co/p?utm_source=mail ahora.")

        XCTAssertEqual(rendered.linkText, "https://acme.co/p?utm_source=mail")
        XCTAssertEqual(rendered.linkURL, URL(string: "https://acme.co/p"))
    }

    func testBareHTTPURLIsNotLinked() {
        let rendered = ConsentMarkup.render("Ver http://acme.co/policy ahora.")

        XCTAssertNil(rendered.linkText, "The web's regex matches https only")
        XCTAssertNil(rendered.linkURL)
    }

    func testAnchorWinsOverABareURL() {
        let rendered = ConsentMarkup.render(#"https://bare.co y <a href="https://anchor.co">aquí</a>"#)

        XCTAssertEqual(rendered.linkText, "aquí")
        XCTAssertEqual(rendered.linkURL, URL(string: "https://anchor.co"))
    }

    // MARK: - Entities and stray markup

    func testNamedEntitiesAreDecoded() {
        let rendered = ConsentMarkup.render("Datos &amp; biometría &lt;ok&gt; &quot;sí&quot; &#39;no&#39;")

        XCTAssertEqual(rendered.text, "Datos & biometría <ok> \"sí\" 'no'")
    }

    /// `&amp;` is decoded last so an escaped entity does not decode twice.
    func testEscapedEntitiesDoNotDoubleDecode() {
        XCTAssertEqual(ConsentMarkup.render("&amp;lt;b&amp;gt;").text, "&lt;b&gt;")
    }

    func testUnknownTagsAreDroppedKeepingTheirContent() {
        XCTAssertEqual(ConsentMarkup.render("<p><span class='x'>Texto</span></p>").text, "Texto")
    }

    func testEdgesAreTrimmed() {
        XCTAssertEqual(ConsentMarkup.render("<br>  Texto  <br>").text, "Texto")
    }

    func testMarkupOnlyCopyRendersEmpty() {
        XCTAssertEqual(ConsentMarkup.render("<br><br>").text, "")
    }

    func testPlainCopyIsUntouched() {
        let plain = "Autorizo el tratamiento de mis datos personales."

        XCTAssertEqual(ConsentMarkup.render(plain), ConsentMarkup.Rendered(
            text: plain, linkText: nil, linkURL: nil
        ))
    }
}
