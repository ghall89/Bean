import SQLiteData

func registerMigrationV1(on migrator: inout DatabaseMigrator) {
  migrator.registerMigration("v1") { database in
    try createBoardTable(in: database)
    try createBoardStatusTable(in: database)
    try createBoardItemTable(in: database)
    try createBoardStatusIndex(in: database)
    try createBoardItemIndex(in: database)
  }
}

nonisolated private func createBoardTable(in database: Database) throws {
  try #sql(
    """
    CREATE TABLE "board"(
      "id" TEXT NOT NULL PRIMARY KEY,
      "createdDate" TEXT NOT NULL,
      "title" TEXT NOT NULL UNIQUE COLLATE NOCASE,
      "icon" TEXT NOT NULL
    )
    """
  )
  .execute(database)
}

nonisolated private func createBoardStatusTable(in database: Database) throws {
  try #sql(
    """
    CREATE TABLE "board_status"(
      "id" TEXT NOT NULL PRIMARY KEY,
      "createdDate" TEXT NOT NULL,
      "label" TEXT NOT NULL,
      "columnIndex" INTEGER NOT NULL,
      "boardID" TEXT NOT NULL REFERENCES "board"("id") ON DELETE CASCADE
    )
    """
  )
  .execute(database)
}

nonisolated private func createBoardItemTable(in database: Database) throws {
  try #sql(
    """
    CREATE TABLE "board_item"(
      "id" TEXT NOT NULL PRIMARY KEY,
      "createdDate" TEXT NOT NULL,
      "title" TEXT NOT NULL,
      "description" TEXT NOT NULL,
      "rowIndex" INTEGER NOT NULL,
      "boardID" TEXT NOT NULL REFERENCES "board"("id") ON DELETE CASCADE,
      "statusID" TEXT NOT NULL REFERENCES "board_status"("id") ON DELETE CASCADE,
      UNIQUE("statusID", "rowIndex")
    )
    """
  )
  .execute(database)
}

nonisolated private func createBoardStatusIndex(in database: Database) throws {
  try #sql(
    """
    CREATE INDEX "idx_board_status_board_order"
    ON "board_status"("boardID", "columnIndex")
    """
  )
  .execute(database)
}

nonisolated private func createBoardItemIndex(in database: Database) throws {
  try #sql(
    """
    CREATE INDEX "idx_board_item_board_status_order"
    ON "board_item"("boardID", "statusID", "rowIndex")
    """
  )
  .execute(database)
}
