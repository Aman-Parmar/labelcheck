import SwiftData
import SwiftUI

/// Allergen profiles: named sets of allergens matched on-device against every
/// product card. Multiple profiles is a Pro feature; the first profile is free.
/// A match is a warning to check the physical label, never a safety guarantee.
struct AllergenProfilesView: View {
    @EnvironmentObject private var store: StoreManager
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \AllergenProfile.createdAt)
    private var profiles: [AllergenProfile]

    @State private var showingAdd = false
    @State private var showingPaywall = false

    var body: some View {
        NavigationStack {
            Group {
                if profiles.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(profiles) { profile in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(profile.name)
                                        .font(.headline)
                                    Spacer()
                                    Toggle("", isOn: Binding(
                                        get: { profile.isActive },
                                        set: { profile.isActive = $0 }
                                    ))
                                    .labelsHidden()
                                    .accessibilityIdentifier("profile-toggle-\(profile.name)")
                                }
                                Text(profile.allergenList.compactMap(AllergenMatcher.label(forKey:)).commaJoined)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                    // The iOS 26 floating tab bar overlays scroll content;
                    // a bottom content margin lets the last row scroll fully
                    // above the pill.
                    .contentMargins(.bottom, 110, for: .scrollContent)
                }
            }
            .navigationTitle("Allergens")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if profiles.isEmpty || store.isPro {
                            showingAdd = true
                        } else {
                            showingPaywall = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add allergen profile")
                    .accessibilityIdentifier("add-profile-button")
                }
            }
            // The add-profile form is a navigation push, not a sheet. This
            // view used to carry two .sheet modifiers (add + paywall) on
            // the same view, the identical latent bug as ScanView's OCR
            // sheet: only one sheet reliably presents, so the add form
            // could silently fail to appear. A push uses the same
            // mechanism as the product card, which test02 proves works.
            // The paywall stays as this view's single sheet.
            .navigationDestination(isPresented: $showingAdd) {
                AddProfileView()
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.shield")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true) // Decorative; the heading below says the same thing.
            Text("No allergen profiles yet")
                .font(.title3.bold())
            Text("Add a profile, for example milk and peanut, and every product card will flag matches. Matching happens on this phone.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Add a profile") {
                showingAdd = true
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("add-profile-empty-button")
        }
        .padding()
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(profiles[index])
        }
        try? modelContext.save()
    }
}

private struct AddProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var selected: Set<String> = []

    var body: some View {
        // No inner NavigationStack: this view is pushed onto the
        // AllergenProfilesView stack, which supplies the navigation bar.
        Form {
            Section("Name") {
                TextField("Whose profile is this?", text: $name)
                    .accessibilityIdentifier("profile-name-field")
            }
            Section("Allergens to watch for") {
                ForEach(AllergenMatcher.allLabels, id: \.self) { label in
                    Button {
                        if selected.contains(label) {
                            selected.remove(label)
                        } else {
                            selected.insert(label)
                        }
                    } label: {
                        HStack {
                            Text(label)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selected.contains(label) {
                                Image(systemName: "checkmark")
                                    .accessibilityHidden(true) // Meaning is in the accessibilityValue below.
                            }
                        }
                    }
                    .accessibilityValue(selected.contains(label) ? "Selected" : "Not selected")
                    .accessibilityIdentifier("allergen-option-\(label)")
                }
            }
            Section {
                Text("Matches are warnings to check the physical label. This is not an allergy safety guarantee.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("New profile")
        .navigationBarTitleDisplayMode(.inline)
        // Pushed detail screen: hide the floating tab bar, like the
        // product card and OCR result.
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let keys = selected.compactMap(AllergenMatcher.key(forLabel:))
                    modelContext.insert(AllergenProfile(
                        name: name.isBlank ? "My profile" : name,
                        allergens: keys
                    ))
                    try? modelContext.save()
                    dismiss()
                }
                .disabled(selected.isEmpty)
                .accessibilityIdentifier("save-profile-button")
            }
        }
    }
}
