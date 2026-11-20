import SwiftData
import SwiftUI

/// Favorites: products the user saved with the heart on the product card.
/// Free for every user, on-device only, independent of History: a favorite
/// survives the free 10-scan history cap and clearing history. Tapping a
/// row opens the full product card from the LC-2 offline cache when one
/// exists, so it works with no signal.
struct FavoritesView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \FavoriteProduct.favoritedAt, order: .reverse)
    private var favorites: [FavoriteProduct]

    @State private var selectedProduct: FoodProduct?

    var body: some View {
        NavigationStack {
            Group {
                if favorites.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(favorites) { item in
                            Button {
                                Task {
                                    selectedProduct = await fullProduct(
                                        barcode: item.barcode,
                                        name: item.name,
                                        brand: item.brand,
                                        nutriScoreGrade: item.nutriScoreGrade,
                                        novaGroup: nil,
                                        allergenTags: [],
                                        in: modelContext.container
                                    )
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.displayName)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        if let brand = item.brand {
                                            Text(brand)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                        Text(item.favoritedAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    NutriScoreBadge(grade: item.nutriScoreGrade, size: 32, font: .headline.bold())
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: delete)
                    }
                    // The iOS 26 floating tab bar overlays scroll content;
                    // a bottom content margin lets the last row scroll fully
                    // above the pill.
                    .contentMargins(.bottom, 110, for: .scrollContent)
                }
            }
            .navigationTitle("Favorites")
            .navigationDestination(item: $selectedProduct) { product in
                ProductView(product: product)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true) // Decorative; the "No favorites yet" heading follows.
            Text("No favorites yet")
                .font(.title3.bold())
            Text("Tap the heart on any product card to save it here, on this phone only.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(favorites[index])
        }
        try? modelContext.save()
    }
}
