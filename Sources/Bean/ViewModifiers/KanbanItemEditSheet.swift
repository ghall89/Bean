import SwiftUI
private struct KanbanItemEditSheetModifier: ViewModifier {
  @Environment(BoardManager.self) private var boardManager

  private enum EditField {
    case title
    case description
  }

  let item: BoardItem
  let boardTags: [BoardTag]
  let assignedTagIDs: Set<UUID>
  let assignedTagsSummary: String
  @Binding var isPresented: Bool

  @State private var draftTitle: String = ""
  @State private var draftDescription: String = ""
  @FocusState private var focusedField: EditField?

  func body(content: Content) -> some View {
    content
      .onChange(of: isPresented) { _, isPresented in
        guard isPresented else {
          return
        }
        draftTitle = item.title
        draftDescription = item.description
      }
      .sheet(isPresented: $isPresented) {
        editSheetContent
      }
  }

  private var editSheetContent: some View {
    NavigationStack {
      Form {
        titleField
        descriptionField
        tagsSection
      }
      .formStyle(.grouped)
      .navigationTitle("Edit Item")
      .toolbar {
        cancelToolbarItem
        saveToolbarItem
      }
      .onAppear {
        focusedField = .title
      }
    }
    .frame(minWidth: 420, minHeight: 280)
  }

  private var titleField: some View {
    TextField("Title", text: $draftTitle)
      .focused($focusedField, equals: .title)
      .onChange(of: draftTitle) { _, newValue in
        if newValue.count > 120 {
          draftTitle = String(newValue.prefix(120))
        }
      }
  }

  private var descriptionField: some View {
    TextField("Description", text: $draftDescription, axis: .vertical)
      .focused($focusedField, equals: .description)
      .lineLimit(4...10)
      .onChange(of: draftDescription) { _, newValue in
        if newValue.count > 2_000 {
          draftDescription = String(newValue.prefix(2_000))
        }
      }
  }

  private var tagsSection: some View {
    Section("Tags") {
      if boardTags.isEmpty {
        Text("No tags available")
          .foregroundStyle(.secondary)
      } else {
        LabeledContent("Assigned") {
          Menu {
            ForEach(boardTags, id: \.id) { tag in
              Button {
                boardManager.toggleTag(tagID: tag.id, forItemID: item.id)
              } label: {
                Label(tag.name, systemImage: assignedTagIDs.contains(tag.id) ? "checkmark" : "circle")
              }
            }
          } label: {
            Text(assignedTagsSummary)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
  }

  private var cancelToolbarItem: some ToolbarContent {
    ToolbarItem(placement: .cancellationAction) {
      Button("Cancel") {
        isPresented = false
      }
      .keyboardShortcut(.cancelAction)
    }
  }

  private var saveToolbarItem: some ToolbarContent {
    ToolbarItem(placement: .confirmationAction) {
      Button("Save") {
        saveEdits()
      }
      .disabled(draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      .keyboardShortcut(.defaultAction)
      .keyboardShortcut(.return, modifiers: .command)
    }
  }

  private func saveEdits() {
    boardManager.updateBoardItem(
      BoardItem(
        id: item.id,
        createdDate: item.createdDate,
        title: draftTitle,
        description: draftDescription,
        rowIndex: item.rowIndex,
        boardID: item.boardID,
        statusID: item.statusID
      )
    )

    isPresented = false
  }
}

extension View {
  func kanbanItemEditSheet(
    item: BoardItem,
    boardTags: [BoardTag],
    assignedTagIDs: Set<UUID>,
    assignedTagsSummary: String,
    isPresented: Binding<Bool>
  ) -> some View {
    modifier(
      KanbanItemEditSheetModifier(
        item: item,
        boardTags: boardTags,
        assignedTagIDs: assignedTagIDs,
        assignedTagsSummary: assignedTagsSummary,
        isPresented: isPresented
      )
    )
  }
}
