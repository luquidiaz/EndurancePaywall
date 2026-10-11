import Foundation
import Testing
@testable import EndurancePaywall

@Suite("Localization")
struct LocalizationTests {

    static let languages = [
        "en", "es", "pt-BR", "de", "fr", "it", "ja", "ko",
        "zh-Hans", "zh-Hant", "nl", "sv", "pl", "tr"
    ]
    static let keys = ["paywall.close", "paywall.unavailable.title", "paywall.unavailable.message"]

    @Test(arguments: languages)
    func everyPackageStringIsTranslated(language: String) throws {
        let path = try #require(
            Bundle.module.path(forResource: language, ofType: "lproj")
                ?? Bundle.module.path(forResource: language.replacingOccurrences(of: "-", with: "_"), ofType: "lproj"),
            "missing \(language).lproj"
        )
        let bundle = try #require(Bundle(path: path))
        for key in Self.keys {
            let value = bundle.localizedString(forKey: key, value: "__missing__", table: nil)
            #expect(value != "__missing__" && value != key, "\(language): \(key)")
        }
    }
}
