import Foundation
import SQLiteData
import SwiftUI

@Table("board_tag")
struct BoardTag: Identifiable {
  var id: UUID = .init()
  var createdDate: Date = .init()

  var name: String
  var colorName: String?

  var boardID: UUID

  var color: Color? {
    guard let colorName else {
      return nil
    }

    return BoardTagColor(rawValue: colorName)?.color
  }
}

enum BoardTagColor: String, CaseIterable {
  case red
  case orange
  case yellow
  case green
  case mint
  case cyan
  case blue
  case indigo
  case pink

  var color: Color {
    switch self {
    case .red: .red
    case .orange: .orange
    case .yellow: .yellow
    case .green: .green
    case .mint: .mint
    case .cyan: .cyan
    case .blue: .blue
    case .indigo: .indigo
    case .pink: .pink
    }
  }

  var displayName: String {
    rawValue.capitalized
  }
}
