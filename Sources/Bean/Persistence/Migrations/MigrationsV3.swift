import SQLiteData

func registerMigrationV3(on migrator: inout DatabaseMigrator) {
  migrator.registerMigration("v3") { database in
    try renameOriginalTables(in: database)
    try dropLegacyIndexes(in: database)
    try rebuildBoardItemTable(in: database)
    try rebuildBoardItemTagTable(in: database)
    try dropTemporaryTables(in: database)
  }
}

nonisolated private func renameOriginalTables(in database: Database) throws {
  try #sql(
    """
    ALTER TABLE "board_item_tag" RENAME TO "board_item_tag_old"
    """
  )
  .execute(database)

  try #sql(
    """
    ALTER TABLE "board_item" RENAME TO "board_item_old"
    """
  )
  .execute(database)
}

nonisolated private func dropLegacyIndexes(in database: Database) throws {
  try #sql(
    """
    DROP INDEX IF EXISTS "idx_board_item_board_status_order"
    """
  )
  .execute(database)

  try #sql(
    """
    DROP INDEX IF EXISTS "idx_board_item_tag_board"
    """
  )
  .execute(database)

  try #sql(
    """
    DROP INDEX IF EXISTS "idx_board_item_tag_item"
    """
  )
  .execute(database)
}

nonisolated private func rebuildBoardItemTable(in database: Database) throws {
  try #sql(
    """
    CREATE TABLE "board_item"(
      "id" TEXT NOT NULL PRIMARY KEY,
      "createdDate" TEXT NOT NULL,
      "title" TEXT NOT NULL,
      "description" TEXT NOT NULL,
      "rowIndex" INTEGER NOT NULL,
      "boardID" TEXT NOT NULL REFERENCES "board"("id") ON DELETE CASCADE,
      "statusID" TEXT REFERENCES "board_status"("id") ON DELETE CASCADE,
      UNIQUE("statusID", "rowIndex")
    )
    """
  )
  .execute(database)

  try #sql(
    """
    INSERT INTO "board_item"(
      "id", "createdDate", "title", "description", "rowIndex", "boardID", "statusID"
    )
    SELECT
      "id", "createdDate", "title", "description", "rowIndex", "boardID", "statusID"
    FROM "board_item_old"
    """
  )
  .execute(database)

  try #sql(
    """
    CREATE INDEX "idx_board_item_board_status_order"
    ON "board_item"("boardID", "statusID", "rowIndex")
    """
  )
  .execute(database)
}

nonisolated private func rebuildBoardItemTagTable(in database: Database) throws {
  try #sql(
    """
    CREATE TABLE "board_item_tag"(
      "id" TEXT NOT NULL PRIMARY KEY,
      "createdDate" TEXT NOT NULL,
      "boardID" TEXT NOT NULL REFERENCES "board"("id") ON DELETE CASCADE,
      "itemID" TEXT NOT NULL REFERENCES "board_item"("id") ON DELETE CASCADE,
      "tagID" TEXT NOT NULL REFERENCES "board_tag"("id") ON DELETE CASCADE,
      UNIQUE("itemID", "tagID")
    )
    """
  )
  .execute(database)

  try #sql(
    """
    INSERT INTO "board_item_tag"(
      "id", "createdDate", "boardID", "itemID", "tagID"
    )
    SELECT
      "id", "createdDate", "boardID", "itemID", "tagID"
    FROM "board_item_tag_old"
    """
  )
  .execute(database)

  try #sql(
    """
    CREATE INDEX "idx_board_item_tag_board"
    ON "board_item_tag"("boardID")
    """
  )
  .execute(database)

  try #sql(
    """
    CREATE INDEX "idx_board_item_tag_item"
    ON "board_item_tag"("itemID")
    """
  )
  .execute(database)
}

nonisolated private func dropTemporaryTables(in database: Database) throws {
  try #sql(
    """
    DROP TABLE "board_item_tag_old"
    """
  )
  .execute(database)

  try #sql(
    """
    DROP TABLE "board_item_old"
    """
  )
  .execute(database)
}
