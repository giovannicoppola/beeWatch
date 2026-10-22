import SwiftUI

/// XCUITest has to attach to an app of its own; the tour drives beeWatch, not this.
@main
struct TourHost: App {
    var body: some Scene { WindowGroup { Text("beeWatch tour runner") } }
}
