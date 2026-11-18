import SwiftUI

/// OCR result: text recognised on-device from a label photo, plus the
/// allergens the on-device matcher found in it. The user confirms the
/// matches — OCR can misread, so extracted allergens are never presented
/// as fact.
struct OCRResultView: View {
    let text: String

    @Environment(\.dismiss) private var dismiss

    private var foundAllergens: [String] {
        OCRService.allergensInText(text)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Allergens found in this label")
                            .font(.headline)
                        if foundAllergens.isEmpty {
                            Text("No listed allergens recognised in this text. OCR can miss things — always check the physical label.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(foundAllergens, id: \.self) { allergen in
                                Label(allergen, systemImage: "exclamationmark.triangle.fill")
                                    .font(.subheadline)
                            }
                            Text("Please confirm these against the physical label. This is a reading aid, not an allergy safety guarantee.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("ocr-allergens")
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recognised text")
                            .font(.headline)
                        Text(text.isEmpty ? "No text recognised. Try again with the label flat and well lit." : text)
                            .font(.subheadline)
                    }
                    .accessibilityIdentifier("ocr-text")
                }
                .padding()
            }
            .navigationTitle("Label photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
