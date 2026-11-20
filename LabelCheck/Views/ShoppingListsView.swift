import SwiftData
import SwiftUI

/// Shopping lists pane, shown under the Favorites tab next to Favorites:
/// the weekly shop, built from favorites or from a product card. Free for
/// every user, on-device only. A list is a named group of products; items
/// check off while shopping and tap through to the full product card.
struct ShoppingListsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ShoppingList.createdAt)
    private var lists: [ShoppingList]

    /// Bound to the Favorites tab's product destination, so a list item
    /// tap pushes the same full card as a favorite tap (one destination
    /// for FoodProduct per stack, not two).
    @Binding var selectedProduct: FoodProduct?

    @State private var selectedList: ShoppingList?
    @State private var showingNewList = false
    @State private var newListName = ""

    var body: some View {
        Group {
            if lists.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(lists) { list in
                        Button {
                            selectedList = list
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(list.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(listSummary(list))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true) // Decorative; the row is labelled by the list name.
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("shopping-list-\(list.name)")
                    }
                    .onDelete(perform: delete)
                }
                // The iOS 26 floating tab bar overlays scroll content;
                // a bottom content margin lets the last row scroll fully
                // above the pill.
                .contentMargins(.bottom, 110, for: .scrollContent)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newListName = ""
                    showingNewList = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New shopping list")
                .accessibilityIdentifier("new-list-button")
            }
        }
        .alert("New shopping list", isPresented: $showingNewList) {
            TextField("List name", text: $newListName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                selectedList = ShoppingList.create(name: newListName, in: modelContext)
            }
        } message: {
            Text("Name the list, then add products from Favorites or a product card.")
        }
        .navigationDestination(item: $selectedList) { list in
            ShoppingListDetailView(list: list, selectedProduct: $selectedProduct)
        }
    }

    private func listSummary(_ list: ShoppingList) -> String {
        let total = list.items.count
        let checked = list.checkedCount
        if total == 0 {
            return "No items yet"
        }
        if checked == 0 {
            return "\(total) item\(total == 1 ? "" : "s")"
        }
        return "\(checked) of \(total) checked"
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "cart")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true) // Decorative; the "No lists yet" heading follows.
            Text("No lists yet")
                .font(.title3.bold())
            Text("Make a list for the weekly shop, then add products from Favorites or a product card. Lists stay on this phone.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("New shopping list") {
                newListName = ""
                showingNewList = true
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("new-list-empty-button")
        }
        .padding()
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(lists[index])
        }
        try? modelContext.save()
    }
}

/// One list's items: tap the circle to check an item off while shopping,
/// tap the row to open the full product card, swipe to remove an item.
struct ShoppingListDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let list: ShoppingList

    @Binding var selectedProduct: FoodProduct?

    @State private var showingFavoritesPicker = false

    private var sortedItems: [ShoppingListItem] {
        list.items.sorted { $0.addedAt < $1.addedAt }
    }

    var body: some View {
        Group {
            if list.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "cart")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true) // Decorative; the "No items yet" heading follows.
                    Text("No items yet")
                        .font(.title3.bold())
                    Text("Add products from your favorites to start this list.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Add from favorites") {
                        showingFavoritesPicker = true
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("add-from-favorites-button")
                }
                .padding()
            } else {
                List {
                    ForEach(sortedItems) { item in
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
                                Button {
                                    item.toggleChecked(in: modelContext)
                                } label: {
                                    Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(item.isChecked ? .green : .secondary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(item.isChecked ? "Uncheck \(item.displayName)" : "Check off \(item.displayName)")
                                .accessibilityIdentifier("check-item-\(item.barcode)")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.displayName)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                        .strikethrough(item.isChecked)
                                    if let brand = item.brand {
                                        Text(brand)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .strikethrough(item.isChecked)
                                    }
                                }
                                Spacer()
                                NutriScoreBadge(grade: item.nutriScoreGrade, size: 32, font: .headline.bold())
                                    .opacity(item.isChecked ? 0.5 : 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: delete)
                }
                .contentMargins(.bottom, 110, for: .scrollContent)
            }
        }
        .navigationTitle(list.name)
        .toolbar {
            if !list.items.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        showingFavoritesPicker = true
                    }
                    .accessibilityIdentifier("add-from-favorites-button")
                }
            }
            if list.checkedCount > 0 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear checked") {
                        list.clearChecked(in: modelContext)
                    }
                    .accessibilityIdentifier("clear-checked-button")
                }
            }
        }
        .sheet(isPresented: $showingFavoritesPicker) {
            FavoritesPickerSheet(list: list)
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let item = sortedItems[index]
            list.items.removeAll { $0 == item }
            modelContext.delete(item)
        }
        try? modelContext.save()
    }
}

/// Picks favorites to add to a list. Rows already on the list show a
/// checkmark and do nothing on tap; the sheet stays open so several
/// products can be added in one go.
struct FavoritesPickerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let list: ShoppingList

    @Query(sort: \FavoriteProduct.favoritedAt, order: .reverse)
    private var favorites: [FavoriteProduct]

    var body: some View {
        NavigationStack {
            Group {
                if favorites.isEmpty {
                    VStack(spacing: 12) {
                        Text("No favorites yet")
                            .font(.title3.bold())
                        Text("Tap the heart on any product card to save it as a favorite first.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List(favorites) { favorite in
                        let alreadyAdded = list.contains(barcode: favorite.barcode)
                        Button {
                            if !alreadyAdded {
                                list.add(favorite: favorite, in: modelContext)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(favorite.displayName)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    if let brand = favorite.brand {
                                        Text(brand)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if alreadyAdded {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.secondary)
                                        .accessibilityHidden(true) // Decorative; the row label says the product.
                                }
                                NutriScoreBadge(grade: favorite.nutriScoreGrade, size: 32, font: .headline.bold())
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("pick-favorite-\(favorite.barcode)")
                    }
                }
            }
            .navigationTitle("Add from favorites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// Adds the product on a product card to one of the user's lists. Tapping
/// a list adds the product (one row per product per list); a checkmark
/// shows lists it is already on. The sheet stays open so the product can
/// go on several lists, and offers a new list inline.
struct AddToListSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let product: FoodProduct

    @Query(sort: \ShoppingList.createdAt)
    private var lists: [ShoppingList]

    @State private var showingNewList = false
    @State private var newListName = ""

    var body: some View {
        NavigationStack {
            Group {
                if lists.isEmpty {
                    VStack(spacing: 12) {
                        Text("No lists yet")
                            .font(.title3.bold())
                        Text("Make a list first, then add this product to it.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("New shopping list") {
                            newListName = ""
                            showingNewList = true
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("new-list-empty-button")
                    }
                    .padding()
                } else {
                    List(lists) { list in
                        let alreadyAdded = list.contains(barcode: product.barcode)
                        Button {
                            if !alreadyAdded {
                                list.add(product: product, in: modelContext)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(list.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text("\(list.items.count) item\(list.items.count == 1 ? "" : "s")")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if alreadyAdded {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.secondary)
                                        .accessibilityHidden(true) // Decorative; the row label says the list.
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("add-to-list-\(list.name)")
                    }
                }
            }
            .navigationTitle("Add to a list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        newListName = ""
                        showingNewList = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New shopping list")
                    .accessibilityIdentifier("new-list-button")
                }
            }
            .alert("New shopping list", isPresented: $showingNewList) {
                TextField("List name", text: $newListName)
                Button("Cancel", role: .cancel) {}
                Button("Create") {
                    if let list = ShoppingList.create(name: newListName, in: modelContext) {
                        list.add(product: product, in: modelContext)
                    }
                }
            } message: {
                Text("Name the list. This product is added to it right away.")
            }
        }
    }
}
