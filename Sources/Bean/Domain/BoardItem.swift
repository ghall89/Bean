import Foundation
import SQLiteData

@Table("board_item")
struct BoardItem {
  var id: UUID = .init()
  var createdDate: Date = .init()

  var title: String
  var description: String
  var rowIndex: Int

  var boardID: UUID
  var statusID: UUID?
}
