import SQLiteData
import SwiftUI

struct SidebarView: View {
  @Environment(BoardManager.self) private var boardManager
  @FetchAll(Board.order { $0.createdDate.asc() }, animation: .default) private var boards

  var body: some View {
    @Bindable var boardManager = boardManager

    List(selection: $boardManager.selectedBoardID) {
      ForEach(boards, id: \.id) { board in
        SidebarBoardRowView(board: board)
      }
    }
    .listStyle(.sidebar)
    .toolbar {
      ToolbarItem {
        Button("New Board", systemImage: "plus") {
          createBoardImmediately()
        }
      }
    }
    .task {
      boardManager.createInitialBoardIfNeeded()
      ensureSelectedBoardIsValid()
    }
    .onChange(of: boardIDs) {
      ensureSelectedBoardIsValid()
    }
    .alert("Board Error", isPresented: errorAlertIsPresented) {
      Button("OK", role: .cancel) {
        boardManager.errorMessage = nil
      }
    } message: {
      Text(boardManager.errorMessage ?? "Unknown board error")
    }
  }

  private func createBoardImmediately() {
    boardManager.createBoard(
      Board(
        title: nextUntitledBoardTitle(),
        icon: "square.grid.2x2"
      )
    )
  }

  private var errorAlertIsPresented: Binding<Bool> {
    Binding(
      get: { boardManager.errorMessage != nil },
      set: { isPresented in
        if !isPresented {
          boardManager.errorMessage = nil
        }
      }
    )
  }

  private var boardIDs: [UUID] {
    boards.map(\.id)
  }

  private func ensureSelectedBoardIsValid() {
    guard let selectedBoardID = boardManager.selectedBoardID else {
      boardManager.selectedBoardID = boards.first?.id
      return
    }

    guard boards.contains(where: { $0.id == selectedBoardID }) else {
      boardManager.selectedBoardID = boards.first?.id
      return
    }
  }

  private func nextUntitledBoardTitle() -> String {
    if !boards.contains(where: { $0.title.caseInsensitiveCompare("Untitled") == .orderedSame }) {
      return "Untitled"
    }

    var index = 2
    while true {
      let candidate = "Untitled \(index)"
      let exists = boards.contains {
        $0.title.caseInsensitiveCompare(candidate) == .orderedSame
      }
      if !exists {
        return candidate
      }
      index += 1
    }
  }
}
