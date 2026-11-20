import SwiftData
import XCTest

@testable import LabelCheck

/// Shopping lists: create, add (one row per product per list), check off,
/// clear checked, delete cascades to items. No test here touches the real
/// network; lists are on-device only.
final class ShoppingListsTests: XCTestCase {
    private let nutella = FoodProduct(
        barcode: "3017620422003",
        name: "Nutella",
        brand: "Ferrero",
        nutriScoreGrade: "e",
        novaGroup: 4,
        allergenTags: ["en:milk", "en:nuts"]
    )

    private let cola = FoodProduct(
        barcode: "5449000000996",
        name: "Coca-Cola",
        brand: "Coca-Cola",
        nutriScoreGrade: "e",
        novaGroup: 4,
        allergenTags: []
    )

    private func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: ShoppingList.self, ShoppingListItem.self, FavoriteProduct.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func listCount(in container: ModelContainer) throws -> Int {
        try ModelContext(container).fetchCount(FetchDescriptor<ShoppingList>())
    }

    private func itemCount(in container: ModelContainer) throws -> Int {
        try ModelContext(container).fetchCount(FetchDescriptor<ShoppingListItem>())
    }

    func testCreateKeepsTrimmedName() throws {
        let container = try inMemoryContainer()
        let context = ModelContext(container)
        let list = try XCTUnwrap(ShoppingList.create(name: "  Weekly shop  ", in: context))
        XCTAssertEqual(list.name, "Weekly shop")
        XCTAssertEqual(try listCount(in: container), 1)
    }

    func testCreateRejectsBlankName() throws {
        let container = try inMemoryContainer()
        let context = ModelContext(container)
        XCTAssertNil(ShoppingList.create(name: "   ", in: context))
        XCTAssertEqual(try listCount(in: container), 0)
    }

    func testAddIgnoresDuplicateBarcode() throws {
        let container = try inMemoryContainer()
        let context = ModelContext(container)
        let list = try XCTUnwrap(ShoppingList.create(name: "Weekly shop", in: context))
        XCTAssertTrue(list.add(product: nutella, in: context))
        XCTAssertFalse(list.add(product: nutella, in: context))
        XCTAssertEqual(list.items.count, 1)
        XCTAssertTrue(list.contains(barcode: nutella.barcode))
        XCTAssertFalse(list.contains(barcode: cola.barcode))
    }

    func testAddFavoriteKeepsSummaryFields() throws {
        let container = try inMemoryContainer()
        let context = ModelContext(container)
        context.insert(FavoriteProduct(product: nutella))
        let favorite = try XCTUnwrap(FavoriteProduct.fetch(barcode: nutella.barcode, in: context))
        let list = try XCTUnwrap(ShoppingList.create(name: "Weekly shop", in: context))
        XCTAssertTrue(list.add(favorite: favorite, in: context))
        let item = try XCTUnwrap(list.items.first)
        XCTAssertEqual(item.displayName, "Nutella")
        XCTAssertEqual(item.brand, "Ferrero")
        XCTAssertEqual(item.nutriScoreGrade, "e")
        XCTAssertFalse(item.isChecked)
    }

    func testToggleChecked() throws {
        let container = try inMemoryContainer()
        let context = ModelContext(container)
        let list = try XCTUnwrap(ShoppingList.create(name: "Weekly shop", in: context))
        list.add(product: nutella, in: context)
        let item = try XCTUnwrap(list.items.first)
        XCTAssertEqual(list.checkedCount, 0)
        item.toggleChecked(in: context)
        XCTAssertTrue(item.isChecked)
        XCTAssertEqual(list.checkedCount, 1)
        item.toggleChecked(in: context)
        XCTAssertFalse(item.isChecked)
    }

    func testClearCheckedRemovesOnlyChecked() throws {
        let container = try inMemoryContainer()
        let context = ModelContext(container)
        let list = try XCTUnwrap(ShoppingList.create(name: "Weekly shop", in: context))
        list.add(product: nutella, in: context)
        list.add(product: cola, in: context)
        // A relationship array has no guaranteed order, so find the item
        // by barcode instead of assuming it is first.
        let nutellaItem = try XCTUnwrap(list.items.first { $0.barcode == nutella.barcode })
        nutellaItem.toggleChecked(in: context)
        list.clearChecked(in: context)
        XCTAssertEqual(list.items.count, 1)
        XCTAssertEqual(list.items.first?.barcode, cola.barcode)
    }

    func testDeleteListCascadesToItems() throws {
        let container = try inMemoryContainer()
        let context = ModelContext(container)
        let list = try XCTUnwrap(ShoppingList.create(name: "Weekly shop", in: context))
        list.add(product: nutella, in: context)
        list.add(product: cola, in: context)
        XCTAssertEqual(try itemCount(in: container), 2)
        context.delete(list)
        try context.save()
        XCTAssertEqual(try listCount(in: container), 0)
        XCTAssertEqual(try itemCount(in: container), 0)
    }
}
