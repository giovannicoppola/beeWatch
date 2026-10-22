import XCTest

/// The Apple Watch tour, as a script. Not a test of anything: tools/tour/watch-record.mjs films the
/// Watch simulator while this runs and reads the `TOUR` lines it prints, one per caption and touch,
/// stamped with the wall clock the recording shares. It opens the installed (Debug) beeWatch on its
/// sample goals (`-sample YES`, see Shared/Services/SampleGoals.swift): invented goals, no Beeminder
/// account, and nothing logged leaves the watch.
@MainActor
final class WatchTourTests: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "com.beewatch.ios.watchkitapp")

    func testTour() throws {
        continueAfterFailure = false
        app.launchArguments += ["-sample", "YES"]
        app.launch()
        XCTAssert(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Pushups'")).firstMatch.waitForExistence(timeout: 30))
        pause(1.5)

        caption("Every goal, most urgent first", "Red is due today; green has days to spare.")
        hold(2.6)
        crown(0.7, hold: 2.2)
        crown(-0.7, hold: 1.0)

        caption("Log it in two taps", "A quick value, then confirm.")
        tap(frame(in: app, .button, prefix: "Pushups"), in: app, hold: 2.2)
        tap(frame(in: app, .button, "10"), in: app, hold: 1.4)
        tap(frame(in: app, .button, "Log 10"), in: app, hold: 3.6)

        caption("Back to the list, updated", "Pushups is safe for two more days.")
        hold(3.6)

        log("end")
        hold(5.0)
    }

    /// Turns the Digital Crown, which scrolls the goal list.
    private func crown(_ delta: Double, hold seconds: TimeInterval) {
        log("hold", ["hold": seconds])
        XCUIDevice.shared.rotateDigitalCrown(delta: delta)
        pause(seconds)
    }

    // MARK: - Finding things

    /// A matching element's frame from one snapshot of the app's hierarchy, waiting for it to appear.
    private func frame(in target: XCUIApplication, _ type: XCUIElement.ElementType, _ label: String? = nil, prefix: String? = nil) -> CGRect {
        for _ in 0..<30 {
            var found: CGRect?
            func walk(_ s: XCUIElementSnapshot) {
                let match = (label.map { s.label == $0 } ?? true) && (prefix.map { s.label.hasPrefix($0) } ?? true)
                if found == nil && s.elementType == type && match && !s.frame.isEmpty { found = s.frame }
                s.children.forEach(walk)
            }
            if let snap = try? target.snapshot() { walk(snap) }
            if let found { return found }
            pause(0.5)
        }
        XCTFail("nothing on screen matches \(label ?? prefix ?? "")")
        return .zero
    }

    // MARK: - Moves

    private func tap(_ frame: CGRect, in target: XCUIApplication, hold seconds: TimeInterval) {
        log("tap", ["x": frame.midX, "y": frame.midY, "hold": 0.3 + seconds])
        pause(0.3)
        target.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap()
        pause(seconds)
    }

    private func hold(_ seconds: TimeInterval) {
        log("hold", ["hold": seconds])
        pause(seconds)
    }

    private func pause(_ seconds: TimeInterval) { Thread.sleep(forTimeInterval: seconds) }

    // MARK: - The log watch-record.mjs reads

    private func caption(_ title: String, _ sub: String) { log("caption", ["title": title, "sub": sub]) }

    private func log(_ type: String, _ fields: [String: Any] = [:]) {
        var event = fields
        event["type"] = type
        event["t"] = Date().timeIntervalSince1970
        let data = try! JSONSerialization.data(withJSONObject: event, options: [.sortedKeys])
        print("TOUR " + String(decoding: data, as: UTF8.self))
    }
}
