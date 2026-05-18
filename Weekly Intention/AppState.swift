import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    var isRecallPresented: Bool = false

    /// Set to true right before presenting Recall so the search field can autofocus.
    var shouldFocusRecallSearch: Bool = false

    func presentRecall(focusSearch: Bool = true) {
        shouldFocusRecallSearch = focusSearch
        isRecallPresented = true
    }
}
