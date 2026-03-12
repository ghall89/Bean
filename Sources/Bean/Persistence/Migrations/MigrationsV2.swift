import SQLiteData

func registerMigrationV2(on migrator: inout DatabaseMigrator) {
  migrator.registerMigration("v2") { database in
    try #sql(
      """
      CREATE TABLE "board_tag"(
        "id" TEXT NOT NULL PRIMARY KEY,
        "createdDate" TEXT NOT NULL,
        "name" TEXT NOT NULL COLLATE NOCASE,
        "colorName" TEXT,
        "boardID" TEXT NOT NULL REFERENCES "board"("id") ON DELETE CASCADE,
        UNIQUE("boardID", "name")
      )
      """
    )
    .execute(database)

    try #sql(
      """
      CREATE INDEX "idx_board_tag_board_name"
      ON "board_tag"("boardID", "name")
      """
    )
    .execute(database)

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
}
