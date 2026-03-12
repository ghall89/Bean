import Foundation
import OSLog
import SQLiteData
import SwiftUI
extension BoardManager {
  private struct DestinationPlacement {
    let statusID: UUID
    let rowIndex: Int
  }

  private enum BoardItemMutationError: Error {
    case itemNotFound
    case statusNotFound
    case statusBoardMismatch
    case itemStatusNotFound
  }

  func createBoardItem(_ input: BoardItem) {
    let normalizedTitle = normalizeItemTitle(input.title)

    guard !normalizedTitle.isEmpty else {
      errorMessage = "Item title cannot be empty."
      return
    }

    guard let inputStatusID = input.statusID else {
      errorMessage = "Cannot create an item without a column."
      return
    }

    do {
      try database.write { database in
        try insertBoardItem(
          input: input,
          statusID: inputStatusID,
          normalizedTitle: normalizedTitle,
          in: database
        )
      }

      errorMessage = nil
    } catch {
      handleCreateBoardItemError(error)
    }
  }

  func updateBoardItem(_ input: BoardItem) {
    let normalizedTitle = normalizeItemTitle(input.title)

    guard !normalizedTitle.isEmpty else {
      errorMessage = "Item title cannot be empty."
      return
    }

    do {
      try database.write { database in
        let existing =
          try BoardItem
          .where { $0.id.eq(input.id) }
          .fetchOne(database)

        guard let existing else {
          throw BoardItemMutationError.itemNotFound
        }

        let updated = BoardItem(
          id: existing.id,
          createdDate: existing.createdDate,
          title: normalizedTitle,
          description: input.description,
          rowIndex: existing.rowIndex,
          boardID: existing.boardID,
          statusID: existing.statusID
        )

        try BoardItem.upsert {
          updated
        }
        .execute(database)
      }

      errorMessage = nil
    } catch {
      switch error {
      case BoardItemMutationError.itemNotFound:
        errorMessage = "That item no longer exists."
      default:
        errorMessage = "Failed to update item."
      }
      Logger.databaseLogger.error("Failed updating board item: \(String(describing: error), privacy: .public)")
    }
  }

  func deleteBoardItem(_ input: BoardItem) {
    do {
      try database.write { database in
        let statusID = input.statusID

        try BoardItem
          .where { $0.id.eq(input.id) }
          .delete()
          .execute(database)

        guard let statusID else {
          return
        }

        let remainingItems =
          try BoardItem
          .where { $0.boardID.eq(input.boardID) && $0.statusID.eq(statusID) }
          .order { $0.rowIndex.asc() }
          .fetchAll(database)

        for (index, var item) in remainingItems.enumerated() where item.rowIndex != index {
          item.rowIndex = index
          try BoardItem.upsert {
            item
          }
          .execute(database)
        }
      }

      errorMessage = nil
    } catch {
      errorMessage = "Failed to delete item."
      Logger.databaseLogger.error("Failed deleting board item: \(String(describing: error), privacy: .public)")
    }
  }

  func reorderBoardItems(
    boardID: UUID,
    statusID: UUID,
    fromOffsets: IndexSet,
    toOffset: Int
  ) {
    guard !fromOffsets.isEmpty else {
      return
    }

    do {
      try database.write { database in
        var orderedItems =
          try BoardItem
          .where { $0.boardID.eq(boardID) && $0.statusID.eq(statusID) }
          .order { $0.rowIndex.asc() }
          .fetchAll(database)

        orderedItems.move(fromOffsets: fromOffsets, toOffset: toOffset)
        try persistOrderedItems(orderedItems, statusID: statusID, in: database)
      }

      errorMessage = nil
    } catch {
      errorMessage = "Failed to reorder items."
      Logger.databaseLogger.error(
        "Failed reordering board items: \(String(describing: error), privacy: .public)")
    }
  }

  func moveBoardItem(
    itemID: UUID,
    destinationStatusID: UUID,
    destinationRowIndex: Int
  ) {
    do {
      try database.write { database in
        try moveBoardItemInDatabase(
          itemID: itemID,
          destinationStatusID: destinationStatusID,
          destinationRowIndex: destinationRowIndex,
          in: database
        )
      }

      errorMessage = nil
    } catch {
      handleMoveBoardItemError(error)
    }
  }

  private func normalizeItemTitle(_ title: String) -> String {
    title.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func insertBoardItem(
    input: BoardItem,
    statusID: UUID,
    normalizedTitle: String,
    in database: Database
  ) throws {
    let status = try BoardStatus.where { $0.id.eq(statusID) }.fetchOne(database)
    guard let status else {
      throw BoardItemMutationError.statusNotFound
    }

    guard status.boardID == input.boardID else {
      throw BoardItemMutationError.statusBoardMismatch
    }

    let existingItems =
      try BoardItem
      .where { $0.boardID.eq(input.boardID) && $0.statusID.eq(statusID) }
      .order { $0.rowIndex.asc() }
      .fetchAll(database)

    try persistOrderedItems(
      existingItems,
      statusID: statusID,
      in: database,
      startingRowIndex: 1
    )

    try BoardItem.insert {
      BoardItem(
        id: input.id,
        createdDate: input.createdDate,
        title: normalizedTitle,
        description: input.description,
        rowIndex: 0,
        boardID: input.boardID,
        statusID: statusID
      )
    }
    .execute(database)
  }

  private func persistOrderedItems(
    _ orderedItems: [BoardItem],
    statusID: UUID,
    in database: Database,
    startingRowIndex: Int = 0
  ) throws {
    for var item in orderedItems {
      item.statusID = nil
      try BoardItem.upsert {
        item
      }
      .execute(database)
    }

    for (index, var item) in orderedItems.enumerated() {
      item.statusID = statusID
      item.rowIndex = startingRowIndex + index
      try BoardItem.upsert {
        item
      }
      .execute(database)
    }
  }

  private func moveBoardItemInDatabase(
    itemID: UUID,
    destinationStatusID: UUID,
    destinationRowIndex: Int,
    in database: Database
  ) throws {
    let destinationStatus = try BoardStatus.where { $0.id.eq(destinationStatusID) }.fetchOne(database)
    guard let destinationStatus else {
      throw BoardItemMutationError.statusNotFound
    }

		guard let movingItem = try BoardItem.where({ $0.id.eq(itemID) }).fetchOne(database) else {
      throw BoardItemMutationError.itemNotFound
    }

    guard movingItem.boardID == destinationStatus.boardID else {
      throw BoardItemMutationError.statusBoardMismatch
    }

    guard let sourceStatusID = movingItem.statusID else {
      throw BoardItemMutationError.itemStatusNotFound
    }

    var sourceItems =
      try BoardItem
      .where { $0.boardID.eq(movingItem.boardID) && $0.statusID.eq(sourceStatusID) }
      .order { $0.rowIndex.asc() }
      .fetchAll(database)

    guard let sourceIndex = sourceItems.firstIndex(where: { $0.id == movingItem.id }) else {
      throw BoardItemMutationError.itemNotFound
    }

    sourceItems.remove(at: sourceIndex)

    if sourceStatusID == destinationStatusID {
      try moveItemWithinStatus(
        movingItem: movingItem,
        sourceItems: sourceItems,
        sourceIndex: sourceIndex,
        destination: DestinationPlacement(
          statusID: destinationStatusID,
          rowIndex: destinationRowIndex
        ),
        in: database
      )
      return
    }

    try moveItemAcrossStatuses(
      movingItem: movingItem,
      sourceItems: sourceItems,
      sourceStatusID: sourceStatusID,
      destination: DestinationPlacement(
        statusID: destinationStatusID,
        rowIndex: destinationRowIndex
      ),
      in: database
    )
  }

  private func moveItemWithinStatus(
    movingItem: BoardItem,
    sourceItems: [BoardItem],
    sourceIndex: Int,
    destination: DestinationPlacement,
    in database: Database
  ) throws {
    let clampedRowIndex = min(max(destination.rowIndex, 0), sourceItems.count + 1)
    let effectiveDestinationIndex = sourceIndex < clampedRowIndex
      ? clampedRowIndex - 1
      : clampedRowIndex

    if effectiveDestinationIndex == sourceIndex {
      return
    }

    var updatedItem = movingItem
    updatedItem.statusID = destination.statusID

    var reorderedItems = sourceItems
    reorderedItems.insert(updatedItem, at: effectiveDestinationIndex)
    try persistOrderedItems(reorderedItems, statusID: destination.statusID, in: database)
  }

  private func moveItemAcrossStatuses(
    movingItem: BoardItem,
    sourceItems: [BoardItem],
    sourceStatusID: UUID,
    destination: DestinationPlacement,
    in database: Database
  ) throws {
    var destinationItems =
      try BoardItem
      .where { $0.boardID.eq(movingItem.boardID) && $0.statusID.eq(destination.statusID) }
      .order { $0.rowIndex.asc() }
      .fetchAll(database)

    var detachedMovingItem = movingItem
    detachedMovingItem.statusID = nil
    try BoardItem.upsert {
      detachedMovingItem
    }
    .execute(database)

    let clampedRowIndex = min(max(destination.rowIndex, 0), destinationItems.count)
    var updatedItem = movingItem
    updatedItem.statusID = destination.statusID
    destinationItems.insert(updatedItem, at: clampedRowIndex)

    try persistOrderedItems(sourceItems, statusID: sourceStatusID, in: database)
    try persistOrderedItems(destinationItems, statusID: destination.statusID, in: database)
  }

  private func handleCreateBoardItemError(_ error: any Error) {
    switch error {
    case BoardItemMutationError.statusNotFound:
      errorMessage = "That status no longer exists."
    case BoardItemMutationError.statusBoardMismatch:
      errorMessage = "Cannot create an item in a status from another board."
    case BoardItemMutationError.itemStatusNotFound:
      errorMessage = "That item is not assigned to a valid column."
    default:
      errorMessage = "Failed to create item."
    }
    Logger.databaseLogger.error("Failed creating board item: \(String(describing: error), privacy: .public)")
  }

  private func handleMoveBoardItemError(_ error: any Error) {
    switch error {
    case BoardItemMutationError.itemNotFound:
      errorMessage = "That item no longer exists."
    case BoardItemMutationError.statusNotFound:
      errorMessage = "That status no longer exists."
    case BoardItemMutationError.statusBoardMismatch:
      errorMessage = "Cannot move an item to a status from another board."
    case BoardItemMutationError.itemStatusNotFound:
      errorMessage = "That item is not assigned to a valid column."
    default:
      errorMessage = "Failed to move item."
    }
    Logger.databaseLogger.error("Failed moving board item: \(String(describing: error), privacy: .public)")
  }
}
