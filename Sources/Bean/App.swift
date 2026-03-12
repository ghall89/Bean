import OSLog
import SQLiteData
import SwiftUI

@main
struct BeanApp: App {
  @State private var boardManager = BoardManager()

  init() {
    prepareDependencies {
      do {
        $0.defaultDatabase = try appDatabase()
      } catch {
        let errorDescription = error.localizedDescription
        Logger.databaseLogger.fault(
          "Failed to initialize app database. Using default database dependency. Error: \(errorDescription, privacy: .public)"
        )
      }
    }
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(boardManager)
    }
  }
}

extension Logger {
  static let subsystem = Bundle.main.bundleIdentifier!

  static let viewCycle = Logger(subsystem: subsystem, category: "view-cycle")
  static let database = Logger(subsystem: subsystem, category: "database")
}
