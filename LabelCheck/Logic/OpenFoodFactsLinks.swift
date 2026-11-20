import Foundation

/// Deep links into the Open Food Facts website for contributing data.
///
/// LabelCheck never writes to Open Food Facts itself. The write API
/// needs an account password (a global app account would mean a
/// password embedded in the shipped app, which the no-secrets rule
/// forbids), so the user contributes in their own browser instead:
/// tapping one of these links opens Safari, where they sign in to
/// their own free Open Food Facts account to add or correct a product.
/// No new network call from the app; the barcode travels only in the
/// link the user chooses to open. Verified 2026-11-19: the add form
/// URL resolves to Open Food Facts sign-in, and an existing product
/// page carries "Edit the page" in its main body.
enum OpenFoodFactsLinks {
    /// The web add-product form for a barcode the database does not
    /// have yet. Open Food Facts asks the user to sign in first; the
    /// barcode is in the link. Prefill after sign-in is not verified
    /// (it needs an account to check), so no copy promises it.
    static func addProductURL(barcode: String) -> URL? {
        var components = URLComponents(string: "https://world.openfoodfacts.org/cgi/product.pl")
        components?.queryItems = [
            URLQueryItem(name: "type", value: "add"),
            URLQueryItem(name: "code", value: barcode),
        ]
        return components?.url
    }

    /// The public product page, where "Edit the page" corrects data.
    static func productPageURL(barcode: String) -> URL? {
        URL(string: "https://world.openfoodfacts.org/product/\(barcode)")
    }
}
