import Foundation
import OSLog
import SQLiteData
extension BoardManager {
  private enum BoardStatusMutationError: Error {
    case statusNotFound
    case statusBoardMismatch
    case cannotDeleteLastStatus
  }

  func createBoardStatus(boardID: UUID, label: String, at requestedColumnIndex: Int? = nil) {
    let normalizedLabel = normalizeStatusLabel(label)

    guard !normalizedLabel.isEmpty else {
      errorMessage = "Column name cannot be empty."
      return
    }

    do {
      try database.write { database in
        var orderedStatuses =
          try BoardStatus
          .where { $0.boardID.eq(boardID) }
          .order { $0.columnIndex.asc() }
          .fetchAll(database)

        let insertionIndex = min(max(requestedColumnIndex ?? orderedStatuses.count, 0), orderedStatuses.count)

        for index in insertionIndex..<orderedStatuses.count {
          var status = orderedStatuses[index]
          status.columnIndex += 1
          orderedStatuses[index] = status

          try BoardStatus.upsert {
            status
          }
          .execute(database)
        }

        try BoardStatus.insert {
          BoardStatus(label: normalizedLabel, columnIndex: insertionIndex, boardID: boardID)
        }
        .execute(database)
      }

      errorMessage = nil
    } catch {
      errorMessage = "Failed to create column."
      Logger.databaseLogger.error("Failed creating board status: \(String(describing: error), privacy: .public)")
    }
  }

  func updateBoardStatus(_ input: BoardStatus) {
    let normalizedLabel = normalizeStatusLabel(input.label)

    guard !normalizedLabel.isEmpty else {
      errorMessage = "Column name cannot be empty."
      return
    }

    do {
      try database.write { database in
        let existingStatus =
          try BoardStatus
          .where { $0.id.eq(input.id) }
          .fetchOne(database)

        guard let existingStatus else {
          throw BoardStatusMutationError.statusNotFound
        }

        try BoardStatus.upsert {
          BoardStatus(
            id: existingStatus.id,
            createdDate: existingStatus.createdDate,
            label: normalizedLabel,
            columnIndex: existingStatus.columnIndex,
            boardID: existingStatus.boardID
          )
        }
        .execute(database)
      }

      errorMessage = nil
    } catch {
      switch error {
      case BoardStatusMutationError.statusNotFound:
        errorMessage = "That column no longer exists."
      default:
        errorMessage = "Failed to update column."
      }

      Logger.databaseLogger.error("Failed updating board status: \(String(describing: error), privacy: .public)")
    }
  }

  func deleteBoardStatus(_ input: BoardStatus) {
    do {
      try database.write { database in
        let orderedStatuses =
          try BoardStatus
          .where { $0.boardID.eq(input.boardID) }
          .order { $0.columnIndex.asc() }
          .fetchAll(database)

        guard orderedStatuses.count > 1 else {
          throw BoardStatusMutationError.cannotDeleteLastStatus
        }

        guard orderedStatuses.contains(where: { $0.id == input.id }) else {
          throw BoardStatusMutationError.statusNotFound
        }

        guard let sourceIndex = orderedStatuses.firstIndex(where: { $0.id == input.id }) else {
          throw BoardStatusMutationError.statusNotFound
        }

        let destinationStatus = destinationStatus(for: sourceIndex, in: orderedStatuses)

        let sourceItems =
          try BoardItem
          .where { $0.boardID.eq(input.boardID) && $0.statusID.eq(input.id) }
          .order { $0.rowIndex.asc() }
          .fetchAll(database)

        let destinationItems =
          try BoardItem
          .where { $0.boardID.eq(input.boardID) && $0.statusID.eq(destinationStatus.id) }
          .order { $0.rowIndex.asc() }
          .fetchAll(database)

        if !sourceItems.isEmpty {
          try persistItems(destinationItems + sourceItems, statusID: destinationStatus.id, in: database)
        }

        try BoardStatus
          .where { $0.id.eq(input.id) }
          .delete()
          .execute(database)

        try compactStatusColumnIndices(boardID: input.boardID, in: database)
      }

      errorMessage = nil
    } catch {
      switch error {
      case BoardStatusMutationError.cannotDeleteLastStatus:
        errorMessage = "A board must have at least one column."
      case BoardStatusMutationError.statusNotFound:
        errorMessage = "That column no longer exists."
      default:
        errorMessage = "Failed to delete column."
      }

      Logger.databaseLogger.error("Failed deleting board status: \(String(describing: error), privacy: .public)")
    }
  }

  func moveBoardStatus(statusID: UUID, destinationColumnIndex: Int) {
    do {
      try database.write { database in
        let movingStatusCandidate =
          try BoardStatus
          .where { $0.id.eq(statusID) }
          .fetchOne(database)

        guard let movingStatus = movingStatusCandidate else {
          throw BoardStatusMutationError.statusNotFound
        }

        var orderedStatuses =
          try BoardStatus
          .where { $0.boardID.eq(movingStatus.boardID) }
          .order { $0.columnIndex.asc() }
          .fetchAll(database)

        guard let sourceIndex = orderedStatuses.firstIndex(where: { $0.id == movingStatus.id }) else {
          throw BoardStatusMutationError.statusNotFound
        }

        let removedStatus = orderedStatuses.remove(at: sourceIndex)
        let clampedDestination = min(max(destinationColumnIndex, 0), orderedStatuses.count)

        if clampedDestination == sourceIndex {
          return
        }

        orderedStatuses.insert(removedStatus, at: clampedDestination)

        for (index, var status) in orderedStatuses.enumerated() where status.columnIndex != index {
          guard status.boardID == movingStatus.boardID else {
            throw BoardStatusMutationError.statusBoardMismatch
          }

          status.columnIndex = index
          try BoardStatus.upsert {
            status
          }
          .execute(database)
        }
      }

      errorMessage = nil
    } catch {
      switch error {
      case BoardStatusMutationError.statusNotFound:
        errorMessage = "That column no longer exists."
      case BoardStatusMutationError.statusBoardMismatch:
        errorMessage = "Cannot move a column to another board."
      default:
        errorMessage = "Failed to reorder columns."
      }

      Logger.databaseLogger.error("Failed moving board status: \(String(describing: error), privacy: .public)")
    }
  }

  private func normalizeStatusLabel(_ label: String) -> String {
    label.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func destinationStatus(for sourceIndex: Int, in orderedStatuses: [BoardStatus]) -> BoardStatus {
    if sourceIndex < orderedStatuses.count - 1 {
      return orderedStatuses[sourceIndex + 1]
    }
    return orderedStatuses[sourceIndex - 1]
  }

  private func persistItems(_ orderedItems: [BoardItem], statusID: UUID, in database: Database) throws {
    for var item in orderedItems {
      item.statusID = nil
      try BoardItem.upsert {
        item
      }
      .execute(database)
    }

    for (index, var item) in orderedItems.enumerated() {
      item.statusID = statusID
      item.rowIndex = index

      try BoardItem.upsert {
        item
      }
      .execute(database)
    }
  }

  private func compactStatusColumnIndices(boardID: UUID, in database: Database) throws {
    let remainingStatuses =
      try BoardStatus
      .where { $0.boardID.eq(boardID) }
      .order { $0.columnIndex.asc() }
      .fetchAll(database)

    for (index, var status) in remainingStatuses.enumerated() where status.columnIndex != index {
      status.columnIndex = index
      try BoardStatus.upsert {
        status
      }
      .execute(database)
    }
  }
}
