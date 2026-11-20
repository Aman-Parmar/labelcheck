import Foundation

/// Plain-language additive explainer.
///
/// Every product card shows what each additive on the label is and what
/// it does, in plain English. The data is a curated on-device list: each
/// entry is an E-number, its common name, and one line about the job it
/// does in food. Names and purposes are from the public E-number list
/// (Wikipedia, "E number", checked 2026-11-19): the EU functional class
/// for each code, nothing more. No safety claim, no risk claim, no
/// verdict: the section says what an additive does, never whether it is
/// good or bad for you. That is the whole point of the feature: Trash
/// Panda's pitch is flags linked to studies, Yuka is criticised for
/// flagging without explaining. This explains without flagging.
///
/// Free for every user: the additives come from the product payload the
/// app already fetched, so no new network call and no new data leaves
/// the phone. Unknown codes (not in the list yet) still show their code
/// with a "no note yet" line, so the section never hides an additive
/// the label lists.
enum AdditiveExplainer {
    /// One additive's plain-language note.
    struct AdditiveNote: Equatable {
        /// Lowercase code without a language prefix, e.g. "e322".
        let code: String
        let name: String
        /// One plain sentence about the job it does. Function only.
        let explanation: String
    }

    /// One row on the product card: the code as listed, plus its note
    /// when the list covers it.
    struct AdditiveRow: Equatable {
        /// Uppercase code as listed, e.g. "E322".
        let code: String
        let note: AdditiveNote?
    }

    /// Curated notes, keyed by lowercase code. Subtypes (E322i, E500ii)
    /// are not listed separately: lookup falls back to the base code.
    static let notes: [String: AdditiveNote] = [
        // Colours (E100-199). Wikipedia gives the colour each one gives.
        "e100": AdditiveNote(code: "e100", name: "Curcumin", explanation: "A colour. It gives food a yellow-orange colour."),
        "e102": AdditiveNote(code: "e102", name: "Tartrazine", explanation: "A colour. It gives food a yellow colour."),
        "e110": AdditiveNote(code: "e110", name: "Sunset Yellow", explanation: "A colour. It gives food an orange colour."),
        "e120": AdditiveNote(code: "e120", name: "Cochineal", explanation: "A colour. It gives food a red colour."),
        "e124": AdditiveNote(code: "e124", name: "Ponceau 4R", explanation: "A colour. It gives food a red colour."),
        "e133": AdditiveNote(code: "e133", name: "Brilliant Blue", explanation: "A colour. It gives food a blue colour."),
        "e150a": AdditiveNote(code: "e150a", name: "Plain caramel", explanation: "A colour. It gives food a brown colour."),
        "e150d": AdditiveNote(code: "e150d", name: "Sulphite ammonia caramel", explanation: "A colour. It gives food a brown colour."),
        "e160a": AdditiveNote(code: "e160a", name: "Carotenes", explanation: "A colour. It gives food a red to brown colour."),
        "e162": AdditiveNote(code: "e162", name: "Beetroot Red", explanation: "A colour. It gives food a red colour."),
        "e163": AdditiveNote(code: "e163", name: "Anthocyanins", explanation: "A colour. It gives food a purple-red colour."),
        // Preservatives (E200-299).
        "e202": AdditiveNote(code: "e202", name: "Potassium sorbate", explanation: "A preservative. It slows mould and bacteria so the food keeps longer."),
        "e211": AdditiveNote(code: "e211", name: "Sodium benzoate", explanation: "A preservative. It slows mould and bacteria so the food keeps longer."),
        "e220": AdditiveNote(code: "e220", name: "Sulphur dioxide", explanation: "A preservative. It slows mould and bacteria so the food keeps longer."),
        "e250": AdditiveNote(code: "e250", name: "Sodium nitrite", explanation: "A preservative. It keeps cured meat from spoiling."),
        "e260": AdditiveNote(code: "e260", name: "Acetic acid", explanation: "An acidity regulator. It sets how sour or sharp the food tastes."),
        "e270": AdditiveNote(code: "e270", name: "Lactic acid", explanation: "A preservative and antioxidant. It slows mould and bacteria and damage from air."),
        "e280": AdditiveNote(code: "e280", name: "Propionic acid", explanation: "A preservative. It slows mould and bacteria so the food keeps longer."),
        "e296": AdditiveNote(code: "e296", name: "Malic acid", explanation: "An acidity regulator. It sets how sour or sharp the food tastes."),
        // Antioxidants and acidity regulators (E300-399).
        "e300": AdditiveNote(code: "e300", name: "Ascorbic acid", explanation: "An antioxidant. It slows damage from air so the food keeps its colour and flavour longer. It is vitamin C."),
        "e301": AdditiveNote(code: "e301", name: "Sodium ascorbate", explanation: "An antioxidant. It slows damage from air so the food keeps its colour and flavour longer."),
        "e307": AdditiveNote(code: "e307", name: "Alpha-tocopherol", explanation: "An antioxidant. It slows damage from air so the food keeps its colour and flavour longer. It is vitamin E."),
        "e322": AdditiveNote(code: "e322", name: "Lecithins", explanation: "An emulsifier. It keeps oil and water mixed so the food stays smooth."),
        "e330": AdditiveNote(code: "e330", name: "Citric acid", explanation: "An acidity regulator. It sets how sour or sharp the food tastes."),
        "e331": AdditiveNote(code: "e331", name: "Sodium citrates", explanation: "An acidity regulator. It sets how sour or sharp the food tastes."),
        "e338": AdditiveNote(code: "e338", name: "Phosphoric acid", explanation: "An acidity regulator. It sets how sour or sharp the food tastes."),
        // Thickeners, stabilisers and emulsifiers (E400-499).
        "e407": AdditiveNote(code: "e407", name: "Carrageenan", explanation: "A thickener and stabiliser. It thickens the food and keeps the texture even."),
        "e412": AdditiveNote(code: "e412", name: "Guar gum", explanation: "A thickener and stabiliser. It thickens the food and keeps the texture even."),
        "e415": AdditiveNote(code: "e415", name: "Xanthan gum", explanation: "A thickener and stabiliser. It thickens the food and keeps the texture even."),
        "e422": AdditiveNote(code: "e422", name: "Glycerol", explanation: "An emulsifier. It keeps oil and water mixed so the food stays smooth."),
        "e440": AdditiveNote(code: "e440", name: "Pectins", explanation: "An emulsifier. It keeps oil and water mixed so the food stays smooth."),
        "e450": AdditiveNote(code: "e450", name: "Diphosphates", explanation: "An emulsifier. It keeps oil and water mixed so the food stays smooth."),
        "e466": AdditiveNote(code: "e466", name: "Carboxymethyl cellulose", explanation: "An emulsifier. It keeps oil and water mixed so the food stays smooth."),
        "e471": AdditiveNote(code: "e471", name: "Mono- and diglycerides of fatty acids", explanation: "An emulsifier. It keeps oil and water mixed so the food stays smooth."),
        "e476": AdditiveNote(code: "e476", name: "Polyglycerol polyricinoleate", explanation: "An emulsifier. It keeps oil and water mixed so the food stays smooth."),
        // pH regulators (E500-599).
        "e500": AdditiveNote(code: "e500", name: "Sodium carbonates", explanation: "A raising agent. It helps dough and batter rise, and sets the acidity."),
        "e503": AdditiveNote(code: "e503", name: "Ammonium carbonates", explanation: "An acidity regulator. It sets how sour or sharp the food tastes."),
        // Flavour enhancers (E600-699).
        "e621": AdditiveNote(code: "e621", name: "Monosodium glutamate", explanation: "A flavour enhancer. It boosts the savoury flavour of the food."),
        // Sweeteners (E900-999).
        "e950": AdditiveNote(code: "e950", name: "Acesulfame K", explanation: "A sweetener. It adds sweetness without sugar."),
        "e951": AdditiveNote(code: "e951", name: "Aspartame", explanation: "A sweetener. It adds sweetness without sugar."),
        "e955": AdditiveNote(code: "e955", name: "Sucralose", explanation: "A sweetener. It adds sweetness without sugar."),
        "e960": AdditiveNote(code: "e960", name: "Steviol glycosides", explanation: "A sweetener. It adds sweetness without sugar."),
    ]

    /// Rows for a product card, in the order Open Food Facts lists the
    /// additives, deduped: E322 and E322i are the same note, so the card
    /// shows Lecithins once. Empty when the product lists no additives.
    static func rows(for product: FoodProduct) -> [AdditiveRow] {
        var seen: Set<String> = []
        var rows: [AdditiveRow] = []
        for tag in product.additivesTags {
            let note = note(forTag: tag)
            // Dedupe by the note's base code when covered: E322 and
            // E322i are the same note, so the card shows Lecithins
            // once. Unknown codes dedupe by the code as listed.
            let key = note?.code ?? displayCode(forTag: tag)
            guard seen.insert(key).inserted else { continue }
            rows.append(AdditiveRow(code: displayCode(forTag: tag), note: note))
        }
        return rows
    }

    /// The note for one Open Food Facts tag (e.g. "en:e322i"), or nil
    /// when the list does not cover it yet.
    static func note(forTag tag: String) -> AdditiveNote? {
        let code = normalisedCode(forTag: tag)
        if let note = notes[code] { return note }
        // Subtype fallback: E322i, E500ii and E960a share the base
        // code's note. Strip the trailing letters after the digits.
        let base = code.prefix(while: { $0.isNumber || $0 == "e" })
        guard base != code else { return nil }
        return notes[String(base)]
    }

    /// "en:e322i" -> "E322i". The code as listed, uppercased.
    static func displayCode(forTag tag: String) -> String {
        normalisedCode(forTag: tag).uppercased()
    }

    /// "en:e322i" -> "e322i". Strips the language prefix, lowercases.
    static func normalisedCode(forTag tag: String) -> String {
        let withoutPrefix = tag.split(separator: ":").last.map(String.init) ?? tag
        return withoutPrefix.trimmed.lowercased()
    }
}
