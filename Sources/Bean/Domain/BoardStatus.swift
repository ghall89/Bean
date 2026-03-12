import Foundation
import SQLiteData

@Table("board_status")
struct BoardStatus {
  var id: UUID = .init()
  var createdDate: Date = .init()

  var label: String
  var columnIndex: Int

  var boardID: UUID
}
