import SwiftUI

enum KanbanItemContextMenuItem {
  case edit
  case move(statuses: [BoardStatus], selectedStatusID: UUID?)
  case tags(tags: [BoardTag], assignedTagIDs: Set<UUID>)
  case divider
  case delete

  @ViewBuilder
  func rowView(
    onEdit: @escaping @MainActor () -> Void,
    onMove: @escaping @MainActor (UUID) -> Void,
    onToggleTag: @escaping @MainActor (UUID) -> Void,
    onDelete: @escaping @MainActor () -> Void
  ) -> some View {
    switch self {
    case .edit:
      Button("Edit", systemImage: "pencil", action: onEdit)

    case .move(let statuses, let selectedStatusID):
      Menu("Move to", systemImage: "arrow.right.circle") {
        ForEach(statuses, id: \.id) { status in
          Button {
            onMove(status.id)
          } label: {
            Label(
              status.label,
              systemImage: status.id == selectedStatusID ? "checkmark" : "arrow.right"
            )
          }
          .disabled(status.id == selectedStatusID)
        }
      }

    case .tags(let tags, let assignedTagIDs):
      Menu("Tags", systemImage: "tag") {
        if tags.isEmpty {
          Button("No tags") {}
            .disabled(true)
        } else {
          ForEach(tags, id: \.id) { tag in
            Button {
              onToggleTag(tag.id)
            } label: {
              Label(tag.name, systemImage: assignedTagIDs.contains(tag.id) ? "checkmark" : "circle")
            }
          }
        }
      }

    case .divider:
      Divider()

    case .delete:
      Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
    }
  }
}

struct KanbanItemContextMenuItemView: View {
  let item: KanbanItemContextMenuItem
  let onEdit: @MainActor () -> Void
  let onMove: @MainActor (UUID) -> Void
  let onToggleTag: @MainActor (UUID) -> Void
  let onDelete: @MainActor () -> Void

  var body: some View {
    item.rowView(
      onEdit: onEdit,
      onMove: onMove,
      onToggleTag: onToggleTag,
      onDelete: onDelete
    )
  }
}

struct KanbanItemContextMenuContents: View {
  let menuItems: [KanbanItemContextMenuItem]
  let onEdit: @MainActor () -> Void
  let onMove: @MainActor (UUID) -> Void
  let onToggleTag: @MainActor (UUID) -> Void
  let onDelete: @MainActor () -> Void

  var body: some View {
    let indexedItems = Array(menuItems.enumerated())

    ForEach(indexedItems, id: \.offset) { entry in
      KanbanItemContextMenuItemView(
        item: entry.element,
        onEdit: onEdit,
        onMove: onMove,
        onToggleTag: onToggleTag,
        onDelete: onDelete
      )
    }
  }
}
