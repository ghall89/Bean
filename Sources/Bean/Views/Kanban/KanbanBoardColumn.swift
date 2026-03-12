import SwiftUI

struct KanbanBoardColumn: View {
  @Environment(BoardManager.self) private var boardManager

  let boardID: UUID
  let status: BoardStatus
  let boardStatuses: [BoardStatus]
  let items: [BoardItem]

  @State private var targetedRowIndex: Int?
  @State private var isTargetingColumnEnd: Bool = false
  @State private var isRenameDialogPresented: Bool = false
  @State private var renameLabel: String = ""
  @State private var pendingStatusDeletion: BoardStatus?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        Text(status.label)
          .font(.headline)
        Text("\(items.count)")
          .font(.caption)
          .foregroundStyle(.secondary)

        Spacer(minLength: 8)

        Menu {
          Button("Rename", systemImage: "pencil") {
            beginRenamingColumn()
          }

          Divider()

          Button("Add Column Before", systemImage: "plus.square.on.square") {
            boardManager.createBoardStatus(
              boardID: boardID,
              label: nextNewColumnName(),
              at: status.columnIndex
            )
          }

          Button("Add Column After", systemImage: "plus.square") {
            boardManager.createBoardStatus(
              boardID: boardID,
              label: nextNewColumnName(),
              at: status.columnIndex + 1
            )
          }

          Divider()

          Button("Delete Column", systemImage: "trash", role: .destructive) {
            pendingStatusDeletion = status
          }
          .disabled(boardStatuses.count <= 1)
        } label: {
          Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("Column actions")

        Button {
          createNewItem()
        } label: {
          Image(systemName: "plus")
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("New item")
      }

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 8) {
          ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            KanbanItemView(item: item)
              .id(item.id)
              .draggable(item.id.uuidString)
              .overlay(alignment: .top) {
                if targetedRowIndex == index {
                  RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.accentColor)
                    .frame(height: 4)
                    .padding(.horizontal, 6)
                    .offset(y: -6)
                }
              }
              .dropDestination(for: String.self) { droppedItemIDs, _ in
                moveDroppedItem(droppedItemIDs, toRowIndex: index)
                targetedRowIndex = nil
                isTargetingColumnEnd = false
                return true
              } isTargeted: { isTargeted in
                if isTargeted {
                  targetedRowIndex = index
                  isTargetingColumnEnd = false
                } else if targetedRowIndex == index {
                  targetedRowIndex = nil
                }
              }
          }

          RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(isTargetingColumnEnd ? Color.accentColor : Color.clear)
            .frame(height: 4)
            .padding(.horizontal, 6)
            .dropDestination(for: String.self) { droppedItemIDs, _ in
              moveDroppedItem(droppedItemIDs, toRowIndex: items.count)
              targetedRowIndex = nil
              isTargetingColumnEnd = false
              return true
            } isTargeted: { isTargeted in
              isTargetingColumnEnd = isTargeted
              if isTargeted {
                targetedRowIndex = nil
              }
            }
        }
      }
      .contentShape(Rectangle())
      .frame(maxHeight: .infinity)
      .dropDestination(for: String.self) { droppedItemIDs, _ in
        moveDroppedItem(droppedItemIDs, toRowIndex: items.count)
        targetedRowIndex = nil
        isTargetingColumnEnd = false
        return true
      } isTargeted: { isTargeted in
        isTargetingColumnEnd = isTargeted
      }
    }
    .padding(12)
    .frame(width: 280, alignment: .topLeading)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .strokeBorder(columnBorderColor, lineWidth: 2)
    )
    .animation(.easeInOut(duration: 0.15), value: columnIsDropTargeted)
    .confirmationDialog("Rename Column", isPresented: $isRenameDialogPresented, titleVisibility: .visible) {
      TextField("Column name", text: $renameLabel)

      Button("Save") {
        boardManager.updateBoardStatus(
          BoardStatus(
            id: status.id,
            createdDate: status.createdDate,
            label: renameLabel,
            columnIndex: status.columnIndex,
            boardID: status.boardID
          )
        )
      }
      .disabled(renameLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    .confirmationDialog(
      "Delete Column?",
      isPresented: isDeleteColumnPresented,
      titleVisibility: .visible,
      presenting: pendingStatusDeletion
    ) { pendingStatus in
      Button("Delete \"\(pendingStatus.label)\"", role: .destructive) {
        boardManager.deleteBoardStatus(pendingStatus)
      }
      Button("Cancel", role: .cancel) {
        pendingStatusDeletion = nil
      }
    } message: { _ in
      Text(deleteColumnMessage)
    }
  }

  private func moveDroppedItem(_ droppedItemIDs: [String], toRowIndex destinationRowIndex: Int) {
    guard
      let droppedItemID = droppedItemIDs.first,
      let itemID = UUID(uuidString: droppedItemID)
    else {
      return
    }

    boardManager.moveBoardItem(
      itemID: itemID,
      destinationStatusID: status.id,
      destinationRowIndex: destinationRowIndex
    )
  }

  private var columnIsDropTargeted: Bool {
    targetedRowIndex != nil || isTargetingColumnEnd
  }

  private var columnBorderColor: Color {
    columnIsDropTargeted ? Color.primary.opacity(0.25) : .clear
  }

  private var isDeleteColumnPresented: Binding<Bool> {
    Binding(
      get: { pendingStatusDeletion != nil },
      set: { isPresented in
        if !isPresented {
          pendingStatusDeletion = nil
        }
      }
    )
  }

  private func beginRenamingColumn() {
    renameLabel = status.label
    isRenameDialogPresented = true
  }

  private func createNewItem() {
    boardManager.createBoardItem(
      BoardItem(
        title: "New Item",
        description: "",
        rowIndex: items.count,
        boardID: boardID,
        statusID: status.id
      ))
  }

  private func nextNewColumnName() -> String {
    let usedLabels = Set(boardStatuses.map { $0.label.lowercased() })
    if !usedLabels.contains("new column") {
      return "New Column"
    }

    var index = 2
    while true {
      let candidate = "New Column \(index)"
      if !usedLabels.contains(candidate.lowercased()) {
        return candidate
      }
      index += 1
    }
  }

  private var deleteColumnMessage: String {
    guard let currentIndex = boardStatuses.firstIndex(where: { $0.id == status.id }) else {
      return "Items in this column will move to a neighboring column."
    }

    if currentIndex < boardStatuses.count - 1 {
      let destination = boardStatuses[currentIndex + 1]
      return "Items in this column will move to \"\(destination.label)\"."
    }

    if currentIndex > 0 {
      let destination = boardStatuses[currentIndex - 1]
      return "Items in this column will move to \"\(destination.label)\"."
    }

    return "A board must keep at least one column."
  }
}
