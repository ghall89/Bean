import Dependencies
import Foundation
import SQLiteData

@MainActor
@Observable
final class BoardManager {
  var selectedBoardID: UUID? {
    didSet {
      persistSelectedBoardID()
    }
  }
  var errorMessage: String?

  @ObservationIgnored @Dependency(\.defaultDatabase) var database
  @ObservationIgnored private let selectedBoardIDStorageKey: String = "selected-board-id"

  init() {
    selectedBoardID = loadPersistedSelectedBoardID()
  }

  private func persistSelectedBoardID() {
    let defaults = UserDefaults.standard
    
    if let selectedBoardID {
      defaults.set(selectedBoardID.uuidString, forKey: selectedBoardIDStorageKey)
    } else {
      defaults.removeObject(forKey: selectedBoardIDStorageKey)
    }
  }

  private func loadPersistedSelectedBoardID() -> UUID? {
    guard
      let persistedID = UserDefaults.standard.string(forKey: selectedBoardIDStorageKey),
      let uuid = UUID(uuidString: persistedID)
    else {
      return nil
    }

    return uuid
  }
}
