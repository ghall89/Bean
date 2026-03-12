import SwiftUI

private struct BoardRenameConfirmationModifier: ViewModifier {
  @Environment(BoardManager.self) private var boardManager
  let board: Board
  @Binding var isPresented: Bool
  @State private var renameTitle: String = ""

  func body(content: Content) -> some View {
    content
      .onChange(of: isPresented) { _, isPresented in
        if isPresented {
          renameTitle = board.title
        }
      }
      .confirmationDialog("Rename Board", isPresented: $isPresented, titleVisibility: .visible) {
        TextField("Board title", text: $renameTitle)

        Button("Save") {
          boardManager.updateBoard(
            Board(
              id: board.id,
              createdDate: board.createdDate,
              title: renameTitle,
              icon: board.icon
            )
          )
        }
        .disabled(renameTitle.isEmpty)
      }
  }
}

extension View {
  func boardRenameConfirmation(
    board: Board,
    isPresented: Binding<Bool>
  ) -> some View {
    modifier(
      BoardRenameConfirmationModifier(
        board: board,
        isPresented: isPresented
      )
    )
  }
}
