import Foundation
import SQLiteData

@Table("board")
struct Board {
  var id: UUID = .init()
  var createdDate: Date = .init()

  var title: String
  var icon: String
}
