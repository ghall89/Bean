import SFSymbols
import SwiftUI

struct SidebarBoardRowView: View {
  @Environment(BoardManager.self) private var boardManager
  let board: Board

  @State private var isSymbolPickerPresented: Bool = false
  @State private var isRenameDialogPresented: Bool = false
  @State private var pendingBoardDeletion: Board?

  var body: some View {
    Label(board.title, systemImage: board.icon)
      .tag(board.id)
      .contextMenu {
        Button("Rename", systemImage: "pencil") {
          isRenameDialogPresented = true
        }
        Button("Change Icon", systemImage: "circlebadge.2") {
          isSymbolPickerPresented = true
        }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) {
          pendingBoardDeletion = board
        }
      }
      .boardRenameConfirmation(board: board, isPresented: $isRenameDialogPresented)
      .sfSymbolPicker(isPresented: $isSymbolPickerPresented, selection: selectedIcon)
      .boardDeleteConfirmation(pendingBoard: $pendingBoardDeletion)
  }

  private var selectedIcon: Binding<String?> {
    Binding(
      get: { board.icon },
      set: { newValue in
        guard let newValue, newValue != board.icon else {
          return
        }
        boardManager.updateBoard(
          Board(
            id: board.id,
            createdDate: board.createdDate,
            title: board.title,
            icon: newValue
          )
        )
      }
    )
  }
}
