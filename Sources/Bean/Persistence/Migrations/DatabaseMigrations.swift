import SQLiteData

func makeLibraryMigrator() -> DatabaseMigrator {
  var migrator: DatabaseMigrator = .init()

  #if DEBUG
    migrator.eraseDatabaseOnSchemaChange = true
  #endif

  registerMigrationV1(on: &migrator)
  registerMigrationV2(on: &migrator)
  registerMigrationV3(on: &migrator)

  return migrator
}
