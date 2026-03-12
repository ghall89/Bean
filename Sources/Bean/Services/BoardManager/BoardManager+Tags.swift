import Foundation
import OSLog
import SQLiteData
extension BoardManager {
  private enum BoardTagMutationError: Error {
    case tagNotFound
    case itemNotFound
    case boardMismatch
    case assignmentExists
    case duplicateName
  }

  func createBoardTag(boardID: UUID, name: String, colorName: String? = nil) {
    let normalizedName = normalizeTagName(name)
    let resolvedColorName = colorName ?? BoardTagColor.allCases.randomElement()?.rawValue

    guard !normalizedName.isEmpty else {
      errorMessage = "Tag name cannot be empty."
      return
    }

    do {
      try database.write { database in
        let duplicateCount =
          try BoardTag
          .where { $0.boardID.eq(boardID) && $0.name.eq(normalizedName) }
          .count()
          .fetchOne(database) ?? 0

        guard duplicateCount == 0 else {
          throw BoardTagMutationError.duplicateName
        }

        try BoardTag.insert {
          BoardTag(name: normalizedName, colorName: resolvedColorName, boardID: boardID)
        }
        .execute(database)
      }

      errorMessage = nil
    } catch {
      switch error {
      case BoardTagMutationError.duplicateName:
        errorMessage = "That tag already exists on this board."
      default:
        if isDuplicateTagConstraint(error) {
          errorMessage = "That tag already exists on this board."
        } else {
          errorMessage = "Failed to create tag."
        }
      }

      Logger.databaseLogger.error("Failed creating board tag: \(String(describing: error), privacy: .public)")
    }
  }

  func deleteBoardTag(_ input: BoardTag) {
    do {
      try database.write { database in
        try BoardTag
          .where { $0.id.eq(input.id) }
          .delete()
          .execute(database)
      }

      errorMessage = nil
    } catch {
      errorMessage = "Failed to delete tag."
      Logger.databaseLogger.error("Failed deleting board tag: \(String(describing: error), privacy: .public)")
    }
  }

  func updateBoardTag(_ input: BoardTag) {
    let normalizedName = normalizeTagName(input.name)

    guard !normalizedName.isEmpty else {
      errorMessage = "Tag name cannot be empty."
      return
    }

    do {
      try database.write { database in
        try updateBoardTag(input, normalizedName: normalizedName, in: database)
      }

      errorMessage = nil
    } catch {
      handleUpdateTagError(error)
    }
  }

  func attachTag(tagID: UUID, toItemID itemID: UUID) {
    do {
      try database.write { database in
        try attachTag(tagID: tagID, toItemID: itemID, in: database)
      }

      errorMessage = nil
    } catch {
      switch error {
      case BoardTagMutationError.tagNotFound:
        errorMessage = "That tag no longer exists."
      case BoardTagMutationError.itemNotFound:
        errorMessage = "That item no longer exists."
      case BoardTagMutationError.boardMismatch:
        errorMessage = "Cannot assign a tag from another board."
      case BoardTagMutationError.assignmentExists:
        errorMessage = nil
      default:
        if isDuplicateItemTagConstraint(error) {
          errorMessage = nil
        } else {
          errorMessage = "Failed to add tag to item."
        }
      }

      Logger.databaseLogger.error("Failed attaching tag to item: \(String(describing: error), privacy: .public)")
    }
  }

  func detachTag(tagID: UUID, fromItemID itemID: UUID) {
    do {
      try database.write { database in
        try BoardItemTagAssignment
          .where { $0.itemID.eq(itemID) && $0.tagID.eq(tagID) }
          .delete()
          .execute(database)
      }

      errorMessage = nil
    } catch {
      errorMessage = "Failed to remove tag from item."
      Logger.databaseLogger.error("Failed detaching tag from item: \(String(describing: error), privacy: .public)")
    }
  }

  func toggleTag(tagID: UUID, forItemID itemID: UUID) {
    do {
      let hasAssignment = try database.read { database in
        let count =
          try BoardItemTagAssignment
          .where { $0.itemID.eq(itemID) && $0.tagID.eq(tagID) }
          .count()
          .fetchOne(database) ?? 0
        return count > 0
      }

      if hasAssignment {
        detachTag(tagID: tagID, fromItemID: itemID)
      } else {
        attachTag(tagID: tagID, toItemID: itemID)
      }
    } catch {
      errorMessage = "Failed to update item tag."
      Logger.databaseLogger.error("Failed toggling item tag: \(String(describing: error), privacy: .public)")
    }
  }

  private func normalizeTagName(_ name: String) -> String {
    name.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func updateBoardTag(_ input: BoardTag, normalizedName: String, in database: Database) throws {
    let existing = try BoardTag.where { $0.id.eq(input.id) }.fetchOne(database)
    guard let existing else {
      throw BoardTagMutationError.tagNotFound
    }

    let duplicateCount =
      try BoardTag
      .where { $0.boardID.eq(existing.boardID) && $0.name.eq(normalizedName) && $0.id.neq(existing.id) }
      .count()
      .fetchOne(database) ?? 0

    guard duplicateCount == 0 else {
      throw BoardTagMutationError.duplicateName
    }

    try BoardTag.upsert {
      BoardTag(
        id: existing.id,
        createdDate: existing.createdDate,
        name: normalizedName,
        colorName: input.colorName,
        boardID: existing.boardID
      )
    }
    .execute(database)
  }

  private func handleUpdateTagError(_ error: any Error) {
    switch error {
    case BoardTagMutationError.tagNotFound:
      errorMessage = "That tag no longer exists."
    case BoardTagMutationError.duplicateName:
      errorMessage = "That tag already exists on this board."
    default:
      if isDuplicateTagConstraint(error) {
        errorMessage = "That tag already exists on this board."
      } else {
        errorMessage = "Failed to update tag."
      }
    }

    Logger.databaseLogger.error("Failed updating board tag: \(String(describing: error), privacy: .public)")
  }

  private func attachTag(tagID: UUID, toItemID itemID: UUID, in database: Database) throws {
    let tagCandidate = try BoardTag.where { $0.id.eq(tagID) }.fetchOne(database)
    let itemCandidate = try BoardItem.where { $0.id.eq(itemID) }.fetchOne(database)

    guard let tag = tagCandidate else {
      throw BoardTagMutationError.tagNotFound
    }

    guard let item = itemCandidate else {
      throw BoardTagMutationError.itemNotFound
    }

    guard tag.boardID == item.boardID else {
      throw BoardTagMutationError.boardMismatch
    }

    let assignmentCount =
      try BoardItemTagAssignment
      .where { $0.itemID.eq(itemID) && $0.tagID.eq(tagID) }
      .count()
      .fetchOne(database) ?? 0

    guard assignmentCount == 0 else {
      throw BoardTagMutationError.assignmentExists
    }

    try BoardItemTagAssignment.insert {
      BoardItemTagAssignment(boardID: item.boardID, itemID: itemID, tagID: tagID)
    }
    .execute(database)
  }

  private func isDuplicateTagConstraint(_ error: any Error) -> Bool {
    String(describing: error)
      .localizedCaseInsensitiveContains("UNIQUE constraint failed: board_tag.boardID, board_tag.name")
  }

  private func isDuplicateItemTagConstraint(_ error: any Error) -> Bool {
    String(describing: error)
      .localizedCaseInsensitiveContains("UNIQUE constraint failed: board_item_tag.itemID, board_item_tag.tagID")
  }
}
