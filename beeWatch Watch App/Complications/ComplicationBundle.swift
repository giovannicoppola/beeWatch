import WidgetKit
import SwiftUI

@main
struct BeeWatchComplicationBundle: WidgetBundle {
    var body: some Widget {
        // App launcher
        AppLauncherComplication()
        // Goals by urgency (1-5)
        Goal1Complication()
        Goal2Complication()
        Goal3Complication()
        Goal4Complication()
        Goal5Complication()
    }
}
