import WidgetKit
import SwiftUI

@main
struct BeeWatchComplicationBundle: WidgetBundle {
    var body: some Widget {
        // App launcher
        AppLauncherComplication()
        // Most urgent goal (dynamic - always shows closest to derailing)
        MostUrgentComplication()
        // Goals by position (1-5)
        Goal1Complication()
        Goal2Complication()
        Goal3Complication()
        Goal4Complication()
        Goal5Complication()
    }
}
