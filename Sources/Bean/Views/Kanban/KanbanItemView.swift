import SQLiteData
import SwiftUI

struct KanbanItemView: View {
  @Environment(BoardManager.self) private var boardManager
  @FetchAll(BoardStatus.order { $0.columnIndex.asc() }, animation: .default) private var statuses
  @FetchAll(BoardTag.order { $0.name.asc() }, animation: .default) private var tags
  @FetchAll(BoardItemTagAssignment.order { $0.createdDate.asc() }, animation: .default) private var itemTags

  let item: BoardItem
  @State private var isEditSheetPresented: Bool = false
  @State private var isDeleteConfirmationPresented: Bool = false

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(item.title)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.primary)

      if !item.description.isEmpty {
        Text(item.description)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(3)
      }

      if !assignedTags.isEmpty {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 6) {
            ForEach(assignedTags, id: \.id) { tag in
              Text(tag.name)
                .font(.caption2)
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background((tag.color ?? Color.secondary).opacity(0.14), in: Capsule())
            }
          }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(10)
    .background(.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .strokeBorder(.quaternary)
    )
    .contextMenu {
      KanbanItemContextMenuContents(
        menuItems: contextMenuItems,
        onEdit: beginEditing,
        onMove: moveItem,
        onToggleTag: toggleTag,
        onDelete: beginDelete
      )
    }
    .onTapGesture(count: 2) {
      beginEditing()
    }
    .kanbanItemEditSheet(
      item: item,
      boardTags: boardTags,
      assignedTagIDs: assignedTagIDs,
      assignedTagsSummary: assignedTagsSummary,
      isPresented: $isEditSheetPresented
    )
    .confirmationDialog("Delete Item?", isPresented: $isDeleteConfirmationPresented, titleVisibility: .visible) {
      Button("Delete \"\(item.title)\"", role: .destructive) {
        boardManager.deleteBoardItem(item)
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This cannot be undone.")
    }
  }

  private func beginEditing() {
    isEditSheetPresented = true
  }

  private func toggleTag(_ tagID: UUID) {
    boardManager.toggleTag(tagID: tagID, forItemID: item.id)
  }

  private func beginDelete() {
    isDeleteConfirmationPresented = true
  }

  private func moveItem(to statusID: UUID) {
    guard statusID != item.statusID else {
      return
    }

    boardManager.moveBoardItem(
      itemID: item.id,
      destinationStatusID: statusID,
      destinationRowIndex: .max
    )
  }

  private var boardStatuses: [BoardStatus] {
    statuses
      .filter { $0.boardID == item.boardID }
      .sorted { $0.columnIndex < $1.columnIndex }
  }

  private var boardTags: [BoardTag] {
    tags
      .filter { $0.boardID == item.boardID }
      .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
  }

  private var assignedTagIDs: Set<UUID> {
    Set(
      itemTags
        .filter { $0.itemID == item.id }
        .map(\.tagID)
    )
  }

  private var assignedTags: [BoardTag] {
    boardTags.filter { assignedTagIDs.contains($0.id) }
  }

  private var assignedTagsSummary: String {
    if assignedTags.isEmpty {
      return "None"
    }

    if assignedTags.count <= 2 {
      return assignedTags.map(\.name).joined(separator: ", ")
    }

    let firstTwo = assignedTags.prefix(2).map(\.name).joined(separator: ", ")
    return "\(firstTwo) +\(assignedTags.count - 2)"
  }

  private var contextMenuItems: [KanbanItemContextMenuItem] {
    [
      .edit,
      .move(statuses: boardStatuses, selectedStatusID: item.statusID),
      .tags(tags: boardTags, assignedTagIDs: assignedTagIDs),
      .divider,
      .delete,
    ]
  }
}
