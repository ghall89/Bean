import SQLiteData
import SwiftUI
struct KanbanBoardView: View {
  @Environment(BoardManager.self) private var boardManager
  @FetchAll(Board.order { $0.createdDate.asc() }, animation: .default) private var boards
  @FetchAll(BoardStatus.order { $0.columnIndex.asc() }, animation: .default) private var statuses
  @FetchAll(BoardItem.order { $0.rowIndex.asc() }, animation: .default) private var items
  @FetchAll(BoardTag.order { $0.name.asc() }, animation: .default) private var tags
  @FetchAll(BoardItemTagAssignment.order { $0.createdDate.asc() }, animation: .default) private var itemTags

  @State private var targetedInsertionIndex: Int?
  @State private var isCreateTagAlertPresented: Bool = false
  @State private var draftTagName: String = ""
  @State private var pendingTagRename: BoardTag?
  @State private var draftRenameTagName: String = ""
  @State private var pendingTagDeletion: BoardTag?
  @State private var searchText: String = ""
  @State private var selectedTagTokens: [BoardSearchTagToken] = []
  @State private var suggestedTagTokens: [BoardSearchTagToken] = []

  private var selectedBoard: Board? {
    guard let selectedBoardID = boardManager.selectedBoardID else {
      return nil
    }
    return boards.first { $0.id == selectedBoardID }
  }

  var body: some View {
    Group {
      if let selectedBoard {
        VStack(alignment: .leading, spacing: 0) {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
              ForEach(selectedBoardTags, id: \.id) { tag in
                HStack(spacing: 6) {
                  Text(tag.name)
                    .font(.caption)
                    .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(tagChipBackground(for: tag), in: Capsule())
                .contextMenu {
                  Menu("Color", systemImage: "paintpalette") {
                    Button {
                      updateTagColor(tag, to: nil)
                    } label: {
                      Label("Default", systemImage: tag.colorName == nil ? "checkmark" : "circle")
                    }

                    Divider()

                    ForEach(BoardTagColor.allCases, id: \.self) { colorOption in
                      Button {
                        updateTagColor(tag, to: colorOption)
                      } label: {
                        Label(
                          colorOption.displayName,
                          systemImage: tag.colorName == colorOption.rawValue ? "checkmark" : "circle.fill"
                        )
                          .foregroundStyle(tag.colorName == colorOption.rawValue ? Color.primary : colorOption.color)
                      }
                    }
                  }

                  Button("Rename", systemImage: "pencil") {
                    beginRenamingTag(tag)
                  }

                  Divider()

                  Button("Delete", systemImage: "trash", role: .destructive) {
                    pendingTagDeletion = tag
                  }
                }
              }

              Button {
                draftTagName = ""
                isCreateTagAlertPresented = true
              } label: {
                Label("Tag", systemImage: "plus")
                  .font(.caption)
              }
              .buttonStyle(.borderless)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
          }

          ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 0) {
              columnDropSlot(at: 0, totalColumns: selectedBoardStatuses.count)

              ForEach(Array(selectedBoardStatuses.enumerated()), id: \.element.id) { index, status in
                KanbanBoardColumn(
                  boardID: selectedBoard.id,
                  status: status,
                  boardStatuses: selectedBoardStatuses,
                  items: itemsByStatus[status.id] ?? []
                )
                .id(status.id)
                .draggable(columnDragURL(for: status.id))

                columnDropSlot(at: index + 1, totalColumns: selectedBoardStatuses.count)
              }
            }
            .animation(.snappy(duration: 0.24, extraBounce: 0.08), value: selectedBoardStatusIDs)
            .padding(24)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle(selectedBoard.title)
        .searchable(
          text: $searchText,
          tokens: $selectedTagTokens,
          suggestedTokens: $suggestedTagTokens,
          placement: .toolbar
        ) { token in
          Label(token.name, systemImage: "tag")
        }
        .alert("New Tag", isPresented: $isCreateTagAlertPresented) {
          TextField("Tag name", text: $draftTagName)
          Button("Cancel", role: .cancel) {}
          Button("Add") {
            boardManager.createBoardTag(boardID: selectedBoard.id, name: draftTagName)
          }
          .disabled(draftTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .alert("Rename Tag", isPresented: isRenameTagAlertPresented, presenting: pendingTagRename) { tag in
          TextField("Tag name", text: $draftRenameTagName)
          Button("Cancel", role: .cancel) {
            pendingTagRename = nil
          }
          Button("Save") {
            boardManager.updateBoardTag(
              BoardTag(
                id: tag.id,
                createdDate: tag.createdDate,
                name: draftRenameTagName,
                colorName: tag.colorName,
                boardID: tag.boardID
              )
            )
            pendingTagRename = nil
          }
          .disabled(draftRenameTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: { tag in
          Text("Update tag \"\(tag.name)\".")
        }
        .confirmationDialog(
          "Delete Tag?",
          isPresented: isDeleteTagDialogPresented,
          titleVisibility: .visible,
          presenting: pendingTagDeletion
        ) { tag in
          Button("Delete \"\(tag.name)\"", role: .destructive) {
            boardManager.deleteBoardTag(tag)
            pendingTagDeletion = nil
          }
          Button("Cancel", role: .cancel) {
            pendingTagDeletion = nil
          }
        } message: { _ in
          Text("This removes the tag from all items on this board.")
        }
        .task(id: selectedBoard.id) {
          boardManager.ensureDefaultStatuses(for: selectedBoard.id)
          syncTagTokenState()
        }
        .onChange(of: selectedBoardTags.map(\.id)) { _, _ in
          syncTagTokenState()
        }
        .onChange(of: selectedTagTokens) { _, _ in
          syncTagTokenState()
        }
      } else {
        ContentUnavailableView(
          "No Board Selected", systemImage: "rectangle.stack",
          description: Text("Create a board or pick one from the sidebar."))
      }
    }
  }
}
extension KanbanBoardView {
  var selectedBoardStatuses: [BoardStatus] {
    guard let selectedBoardID = boardManager.selectedBoardID else {
      return []
    }

    let boardStatuses = statuses.filter { $0.boardID == selectedBoardID }
    return boardStatuses.sorted { $0.columnIndex < $1.columnIndex }
  }

  var itemsByStatus: [UUID: [BoardItem]] {
    guard let selectedBoardID = boardManager.selectedBoardID else {
      return [:]
    }

    let selectedTagIDs = Set(selectedTagTokens.map(\.id))
    let boardTagIDs = Set(selectedBoardTags.map(\.id))
    let activeTagIDs = selectedTagIDs.intersection(boardTagIDs)
    let boardItemTags = itemTagIDsByItemID(boardID: selectedBoardID)

    let boardItems = items.filter {
      $0.boardID == selectedBoardID
        && matchesSelectedTags(for: $0.id, activeTagIDs: activeTagIDs, boardItemTags: boardItemTags)
        && matchesSearchQuery(searchText, in: $0.title)
    }

    var grouped: [UUID: [BoardItem]] = [:]
    for item in boardItems {
      guard let statusID = item.statusID else {
        continue
      }
      grouped[statusID, default: []].append(item)
    }

    return grouped.mapValues { boardItems in
      boardItems.sorted { $0.rowIndex < $1.rowIndex }
    }
  }

  func itemTagIDsByItemID(boardID: UUID) -> [UUID: Set<UUID>] {
    var grouped: [UUID: Set<UUID>] = [:]
    for assignment in itemTags where assignment.boardID == boardID {
      grouped[assignment.itemID, default: []].insert(assignment.tagID)
    }
    return grouped
  }

  func matchesSelectedTags(
    for itemID: UUID,
    activeTagIDs: Set<UUID>,
    boardItemTags: [UUID: Set<UUID>]
  ) -> Bool {
    guard !activeTagIDs.isEmpty else {
      return true
    }

    guard let itemTagIDs = boardItemTags[itemID] else {
      return false
    }

    return !itemTagIDs.isDisjoint(with: activeTagIDs)
  }

  func matchesSearchQuery(_ query: String, in title: String) -> Bool {
    let normalizedQuery = normalizeForSearch(query)
    if normalizedQuery.isEmpty {
      return true
    }

    let normalizedTitle = normalizeForSearch(title)
    if normalizedTitle.contains(normalizedQuery) {
      return true
    }

    return isSubsequence(normalizedQuery, of: normalizedTitle)
  }

  func normalizeForSearch(_ value: String) -> String {
    value
      .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  func isSubsequence(_ pattern: String, of text: String) -> Bool {
    guard !pattern.isEmpty else {
      return true
    }

    var patternIndex = pattern.startIndex
    for character in text {
      if character == pattern[patternIndex] {
        pattern.formIndex(after: &patternIndex)
        if patternIndex == pattern.endIndex {
          return true
        }
      }
    }

    return false
  }

  func syncTagTokenState() {
    let boardTokens = selectedBoardTags.map(BoardSearchTagToken.init)
    let boardTokenIDs = Set(boardTokens.map(\.id))

    selectedTagTokens = selectedTagTokens.filter { boardTokenIDs.contains($0.id) }

    let selectedTokenIDs = Set(selectedTagTokens.map(\.id))
    suggestedTagTokens = boardTokens.filter { !selectedTokenIDs.contains($0.id) }
  }

  var selectedBoardTags: [BoardTag] {
    guard let selectedBoardID = boardManager.selectedBoardID else {
      return []
    }

    return tags
      .filter { $0.boardID == selectedBoardID }
      .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
  }

  func columnDragURL(for statusID: UUID) -> URL {
    URL(string: "bean-column://\(statusID.uuidString)")!
  }

  func moveDroppedColumn(_ droppedURLs: [URL], toColumnIndex destinationIndex: Int) {
    guard
      let droppedURL = droppedURLs.first,
      droppedURL.scheme == "bean-column",
      let droppedHost = droppedURL.host,
      let movedStatusID = UUID(uuidString: droppedHost)
    else {
      return
    }

    let adjustedDestinationIndex: Int
    if
      let sourceIndex = selectedBoardStatuses.firstIndex(where: { $0.id == movedStatusID }),
      sourceIndex < destinationIndex {
      adjustedDestinationIndex = destinationIndex - 1
    } else {
      adjustedDestinationIndex = destinationIndex
    }

    withAnimation(.snappy(duration: 0.24, extraBounce: 0.08)) {
      boardManager.moveBoardStatus(statusID: movedStatusID, destinationColumnIndex: adjustedDestinationIndex)
    }
  }

  @ViewBuilder
  func columnDropSlot(at insertionIndex: Int, totalColumns: Int) -> some View {
    let isTargeted = targetedInsertionIndex == insertionIndex
    let isEdgeSlot = insertionIndex == 0 || insertionIndex == totalColumns

    Rectangle()
      .fill(Color.clear)
      .frame(width: columnDropSlotWidth(isTargeted: isTargeted, isEdgeSlot: isEdgeSlot))
      .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
      .dropDestination(for: URL.self) { droppedURLs, _ in
        moveDroppedColumn(droppedURLs, toColumnIndex: insertionIndex)
        targetedInsertionIndex = nil
        return true
      } isTargeted: { isTargeted in
        if isTargeted {
          targetedInsertionIndex = insertionIndex
        } else if targetedInsertionIndex == insertionIndex {
          targetedInsertionIndex = nil
        }
      }
  }

  func columnDropSlotWidth(isTargeted: Bool, isEdgeSlot: Bool) -> CGFloat {
    if isTargeted {
      return 32
    }

    return isEdgeSlot ? 8 : 16
  }

  var selectedBoardStatusIDs: [UUID] {
    selectedBoardStatuses.map(\.id)
  }

  func tagChipBackground(for tag: BoardTag) -> some ShapeStyle {
    let baseColor = tag.color ?? Color.secondary
    return baseColor.opacity(0.12)
  }

  func updateTagColor(_ tag: BoardTag, to color: BoardTagColor?) {
    boardManager.updateBoardTag(
      BoardTag(
        id: tag.id,
        createdDate: tag.createdDate,
        name: tag.name,
        colorName: color?.rawValue,
        boardID: tag.boardID
      )
    )
  }

  var isRenameTagAlertPresented: Binding<Bool> {
    Binding(
      get: { pendingTagRename != nil },
      set: { isPresented in
        if !isPresented {
          pendingTagRename = nil
        }
      }
    )
  }

  var isDeleteTagDialogPresented: Binding<Bool> {
    Binding(
      get: { pendingTagDeletion != nil },
      set: { isPresented in
        if !isPresented {
          pendingTagDeletion = nil
        }
      }
    )
  }

  func beginRenamingTag(_ tag: BoardTag) {
    draftRenameTagName = tag.name
    pendingTagRename = tag
  }
}

private struct BoardSearchTagToken: Identifiable, Hashable {
  let id: UUID
  let name: String

  init(tag: BoardTag) {
    id = tag.id
    name = tag.name
  }
}
