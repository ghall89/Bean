import Foundation
import OSLog
import SQLiteData
extension BoardManager {
  func createInitialBoardIfNeeded() {
    do {
      let boardCount = try database.read { database in
        try Board
          .count()
          .fetchOne(database)
      }

      guard (boardCount ?? 0) == 0 else {
        return
      }

      createBoard(
        Board(
          title: "Untitled",
          icon: "square.grid.2x2"
        )
      )
    } catch {
      errorMessage = "Failed to check initial boards."
      Logger.databaseLogger.error(
        "Failed checking initial boards: \(String(describing: error), privacy: .public)")
    }
  }

  func createBoard(_ input: Board) {
    let normalizedTitle = normalizeTitle(input.title)

    guard !normalizedTitle.isEmpty else {
      errorMessage = "Board title cannot be empty."
      return
    }

    guard !hasDuplicateTitle(normalizedTitle) else {
      errorMessage = "A board with that title already exists."
      return
    }

    do {
      let board = Board(
        id: input.id, createdDate: input.createdDate, title: normalizedTitle, icon: input.icon)
      try database.write { database in
        try Board.insert {
          board
        }
        .execute(database)
        try insertDefaultStatusesAndSeedItem(for: board, in: database)
      }
      errorMessage = nil
      selectedBoardID = board.id
    } catch {
      if isDuplicateTitleConstraint(error) {
        errorMessage = "A board with that title already exists."
      } else {
        errorMessage = "Failed to create board."
      }
      Logger.databaseLogger.error("Failed creating board: \(String(describing: error), privacy: .public)")
    }
  }

  func ensureDefaultStatuses(for boardID: UUID) {
    do {
      try database.write { database in
        let statusCount =
          try BoardStatus
          .where { $0.boardID.eq(boardID) }
          .count()
          .fetchOne(database) ?? 0

        guard statusCount == 0 else {
          return
        }

        for (columnIndex, label) in defaultStatusLabels.enumerated() {
          try BoardStatus.insert {
            BoardStatus(label: label, columnIndex: columnIndex, boardID: boardID)
          }
          .execute(database)
        }
      }

      errorMessage = nil
    } catch {
      errorMessage = "Failed to initialize board columns."
      Logger.databaseLogger.error(
        "Failed creating default statuses for board: \(boardID.uuidString, privacy: .public), error: \(String(describing: error), privacy: .public)"
      )
    }
  }

  func deleteBoard(_ input: Board) {
    do {
      try database.write { database in
        try Board
          .where { $0.id.eq(input.id) }
          .delete()
          .execute(database)
      }
      if selectedBoardID == input.id {
        selectedBoardID = nil
      }
      errorMessage = nil
    } catch {
      errorMessage = "Failed to delete board."
      Logger.databaseLogger.error("Failed deleting board: \(String(describing: error), privacy: .public)")
    }
  }

  func updateBoard(_ input: Board) {
    let normalizedTitle = normalizeTitle(input.title)

    guard !normalizedTitle.isEmpty else {
      errorMessage = "Board title cannot be empty."
      return
    }

    guard !hasDuplicateTitle(normalizedTitle, excluding: input.id) else {
      errorMessage = "A board with that title already exists."
      return
    }

    do {
      let board = Board(
        id: input.id, createdDate: input.createdDate, title: normalizedTitle, icon: input.icon)
      try database.write { database in
        try Board.upsert {
          board
        }
        .execute(database)
      }
      errorMessage = nil
    } catch {
      if isDuplicateTitleConstraint(error) {
        errorMessage = "A board with that title already exists."
      } else {
        errorMessage = "Failed to update board."
      }
      Logger.databaseLogger.error("Failed updating board: \(String(describing: error), privacy: .public)")
    }
  }

  private func normalizeTitle(_ title: String) -> String {
    title.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func hasDuplicateTitle(_ title: String, excluding boardID: UUID? = nil) -> Bool {
    do {
      return try database.read { database in
        let duplicateCount: Int?

        if let boardID {
          duplicateCount =
            try Board
            .where { $0.title.eq(title) && $0.id.neq(boardID) }
            .count()
            .fetchOne(database)
        } else {
          duplicateCount =
            try Board
            .where { $0.title.eq(title) }
            .count()
            .fetchOne(database)
        }

        return (duplicateCount ?? 0) > 0
      }
    } catch {
      Logger.databaseLogger.error(
        "Failed checking board title duplicates: \(String(describing: error), privacy: .public)")
      return false
    }
  }

  private func isDuplicateTitleConstraint(_ error: any Error) -> Bool {
    String(describing: error)
      .localizedCaseInsensitiveContains("UNIQUE constraint failed: board.title")
  }

  private var defaultStatusLabels: [String] {
    ["To-Do", "Doing", "Finished"]
  }

  private func insertDefaultStatusesAndSeedItem(for board: Board, in database: Database) throws {
    var firstStatusID: UUID?

    for (columnIndex, label) in defaultStatusLabels.enumerated() {
      let status = BoardStatus(label: label, columnIndex: columnIndex, boardID: board.id)
      try BoardStatus.insert {
        status
      }
      .execute(database)

      if columnIndex == 0 {
        firstStatusID = status.id
      }
    }

    guard let firstStatusID else {
      return
    }

    try BoardItem.insert {
      BoardItem(
        title: "New Item",
        description: "",
        rowIndex: 0,
        boardID: board.id,
        statusID: firstStatusID
      )
    }
    .execute(database)
  }
}
