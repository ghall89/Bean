import Dependencies
import Foundation
import OSLog
import SQLiteData

func appDatabasePath() throws -> String {
  let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
  let appDirectoryName = Bundle.main.bundleIdentifier ?? "Bean"
  let appSupportDirectory = directory.appendingPathComponent(appDirectoryName, isDirectory: true)

  try FileManager.default.createDirectory(
    at: appSupportDirectory,
    withIntermediateDirectories: true,
  )

  let dbName: String = "bean-db.sqlite"

  return appSupportDirectory.appendingPathComponent(dbName).path
}

func appDatabase() throws -> any DatabaseWriter {
  @Dependency(\.context) var context
  var configuration: Configuration = .init()
  configuration.prepareDatabase { database in
    database.trace(options: .profile) {
      if context == .preview {
        Logger.database.debug("\($0.expandedDescription)")
      } else {
        Logger.database.debug("\($0.expandedDescription)")
      }
    }
  }

  let database = try defaultDatabase(
    path: try appDatabasePath(),
    configuration: configuration,
  )

  Logger.database.info("open '\(database.path)'")

  let migrator = makeLibraryMigrator()

  try migrator.migrate(database)

  return database
}

extension Logger {
  static let databaseLogger = Logger(subsystem: subsystem, category: "database")
}
