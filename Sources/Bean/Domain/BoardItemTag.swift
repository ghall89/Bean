import Foundation
import SQLiteData

@Table("board_item_tag")
struct BoardItemTagAssignment {
  var id: UUID = .init()
  var createdDate: Date = .init()

  var boardID: UUID
  var itemID: UUID
  var tagID: UUID
}
