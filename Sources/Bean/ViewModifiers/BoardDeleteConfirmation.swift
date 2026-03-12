import SwiftUI

private struct BoardDeleteConfirmationModifier: ViewModifier {
  @Environment(BoardManager.self) private var boardManager
  @Binding var pendingBoard: Board?

  func body(content: Content) -> some View {
    content
      .confirmationDialog(
        "Delete Board?",
        isPresented: isPresented,
        titleVisibility: .visible,
        presenting: pendingBoard
      ) { board in
        Button("Delete \"\(board.title)\"", role: .destructive) {
          boardManager.deleteBoard(board)
        }
        Button("Cancel", role: .cancel) {
          pendingBoard = nil
        }
      } message: { _ in
        Text("This cannot be undone.")
      }
  }

  private var isPresented: Binding<Bool> {
    Binding(
      get: { pendingBoard != nil },
      set: { isPresented in
        if !isPresented {
          pendingBoard = nil
        }
      }
    )
  }
}

extension View {
  func boardDeleteConfirmation(pendingBoard: Binding<Board?>) -> some View {
    modifier(
      BoardDeleteConfirmationModifier(
        pendingBoard: pendingBoard
      )
    )
  }
}
