import XCTest

/// Drives the real app the way a child and a parent would, against the real map, search and
/// routing services: say how old you are, open the planning channel from the home menu, find
/// a place, let Mo make a round trip, turn it the other way, save it, stamp it as walked and
/// collect the reward, look at the passport, and get into the parents' channel by solving the
/// sum. Screenshots of each step are attached to the test result.
final class PlanningFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testAChildPlansAndWalksARoundTrip() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(nl)", "-AppleLocale", "nl_NL"]
        app.launch()

        // First launch: Mo asks how old you are.
        let age = app.buttons["age-middle"]
        XCTAssertTrue(age.waitForExistence(timeout: 30))
        Thread.sleep(forTimeInterval: 1.5)
        attachScreenshot(of: app, named: "01-hoe-oud")
        age.tap()

        // The home menu with its four channels; a new walker starts at level 1.
        let planTile = app.buttons["tile-plan"]
        XCTAssertTrue(planTile.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["tile-routes"].exists)
        XCTAssertTrue(app.buttons["tile-passport"].exists)
        XCTAssertTrue(app.buttons["tile-parentGate"].exists)
        XCTAssertTrue(element(in: app, labelled: "Niveau 1").exists)
        Thread.sleep(forTimeInterval: 2)
        attachScreenshot(of: app, named: "02-menu")

        // Open the planning channel.
        planTile.tap()
        XCTAssertTrue(app.staticTexts["Waar beginnen we?"].waitForExistence(timeout: 15))
        Thread.sleep(forTimeInterval: 5)
        attachScreenshot(of: app, named: "03-plannen")

        // Find a place and jump to it.
        app.buttons["searchButton"].tap()
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 10))
        searchField.tap()
        searchField.typeText("Lage Vuursche")
        let firstResult = app.cells.firstMatch
        XCTAssertTrue(firstResult.waitForExistence(timeout: 30), "the search returned no places")
        attachScreenshot(of: app, named: "04-zoeken")
        firstResult.tap()

        let map = app.maps.firstMatch
        XCTAssertTrue(map.waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 5)

        // One tap sets the start; Mo then offers three round trips.
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.42)).tap()
        let middleLoop = app.buttons["loopButton-1"]
        XCTAssertTrue(middleLoop.waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1.5)
        attachScreenshot(of: app, named: "05-hoe-ver")
        middleLoop.tap()

        let saveButton = app.buttons["saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 20))
        waitForRoute(in: app)
        XCTAssertTrue(element(in: app, labelStartingWith: "Afstand").exists)
        XCTAssertTrue(element(in: app, labelled: "Jouw rondje").exists)
        XCTAssertTrue(element(in: app, labelled: "ster").exists, "a finished walk shows its stars")
        // Give the fun places along the way a moment to arrive, then look.
        Thread.sleep(forTimeInterval: 6)
        attachScreenshot(of: app, named: "06-rondje")

        // The same round trip the other way.
        app.buttons["turnLoopButton"].tap()
        Thread.sleep(forTimeInterval: 1)
        waitForRoute(in: app)
        XCTAssertTrue(element(in: app, labelled: "Jouw rondje").exists)
        Thread.sleep(forTimeInterval: 4)
        attachScreenshot(of: app, named: "07-andere-kant")

        // Save it under the suggested name; "Bewaard!" pops up for a moment.
        saveButton.tap()
        let confirm = app.buttons["confirmSaveButton"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 40))
        XCTAssertTrue(app.textFields["saveNameField"].exists)
        attachScreenshot(of: app, named: "08-bewaren")
        confirm.tap()
        XCTAssertTrue(confirm.waitForNonExistence(timeout: 10))
        XCTAssertTrue(element(in: app, labelled: "Bewaard!").waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "09-bewaard")

        // Back to the menu, then to the saved walks: it hangs on the signpost.
        app.buttons["menuButton"].tap()
        let routesTile = app.buttons["tile-routes"]
        XCTAssertTrue(routesTile.waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1)
        routesTile.tap()
        let walked = app.buttons["walkedButton"].firstMatch
        XCTAssertTrue(walked.waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1)
        attachScreenshot(of: app, named: "10-mijn-wandelingen")

        // Stamp it as walked: confetti, stars, and a new level for a walk of this length.
        walked.tap()
        let rewardDone = app.buttons["rewardDone"]
        XCTAssertTrue(rewardDone.waitForExistence(timeout: 10))
        let rewardTitle = app.staticTexts["rewardTitle"]
        XCTAssertTrue(rewardTitle.exists)
        XCTAssertTrue(rewardTitle.label.hasPrefix("Niveau"), "a walk of about 4 km lifts a new walker a level, got: \(rewardTitle.label)")
        XCTAssertTrue(element(in: app, labelled: "Nieuw stempel: Eerste stappen").exists)
        Thread.sleep(forTimeInterval: 1.2)
        attachScreenshot(of: app, named: "11-beloning")
        rewardDone.tap()
        XCTAssertTrue(rewardDone.waitForNonExistence(timeout: 10))

        // The passport now counts one walk and the first stamp is earned.
        app.buttons["menuButton"].tap()
        let passportTile = app.buttons["tile-passport"]
        XCTAssertTrue(passportTile.waitForExistence(timeout: 10))
        XCTAssertFalse(element(in: app, labelled: "Niveau 1 ·").exists, "the home menu shows the new level")
        Thread.sleep(forTimeInterval: 1)
        passportTile.tap()
        XCTAssertTrue(element(in: app, labelled: "1 wandeling").waitForExistence(timeout: 10))
        XCTAssertTrue(element(in: app, labelled: "Eerste stappen, gehaald").exists)
        Thread.sleep(forTimeInterval: 1.5)
        attachScreenshot(of: app, named: "12-paspoort")

        // The parents' channel opens only after the sum is solved.
        app.buttons["menuButton"].tap()
        let parentsTile = app.buttons["tile-parentGate"]
        XCTAssertTrue(parentsTile.waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1)
        parentsTile.tap()
        let question = app.staticTexts["gateQuestion"]
        XCTAssertTrue(question.waitForExistence(timeout: 10))
        let numbers = question.label.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        XCTAssertEqual(numbers.count, 2, "could not read the sum from \(question.label)")
        let answerField = app.textFields["gateAnswer"]
        answerField.tap()
        answerField.typeText("1")
        attachScreenshot(of: app, named: "13-voor-ouders-som")
        app.buttons["gateContinue"].tap()
        XCTAssertTrue(element(in: app, labelled: "Dat klopt niet").waitForExistence(timeout: 5), "a wrong answer must not open the parents' channel")

        // A wrong answer brings a new sum.
        let newNumbers = question.label.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        XCTAssertEqual(newNumbers.count, 2)
        answerField.tap()
        answerField.typeText(String(newNumbers[0] * newNumbers[1]))
        app.buttons["gateContinue"].tap()
        XCTAssertTrue(element(in: app, labelled: "Privacy").waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1.5)
        attachScreenshot(of: app, named: "14-voor-ouders")
    }

    /// The route is ready once it can be saved. The app turns a round trip by itself when a
    /// direction has no paths; a hand-drawn stretch that fails is offered as a straight line.
    @MainActor
    private func waitForRoute(in app: XCUIApplication) {
        let saveButton = app.buttons["saveButton"]
        let straightLine = app.buttons["straightLineFallbackButton"]
        let deadline = Date().addingTimeInterval(90)
        while !saveButton.isEnabled, Date() < deadline {
            if straightLine.exists {
                straightLine.tap()
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTAssertTrue(saveButton.isEnabled, "the route was not computed in time")
    }

    /// Any element whose label contains the text, whatever kind of element SwiftUI made of it.
    @MainActor
    private func element(in app: XCUIApplication, labelled text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    @MainActor
    private func element(in app: XCUIApplication, labelStartingWith text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", text)).firstMatch
    }

    @MainActor
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
