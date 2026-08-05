import XCTest
@testable import DawtCore

final class CyclePredictionEngineTests: XCTestCase {
    private let engine = CyclePredictionEngine()
    private let cal = Calendar.current

    func testPredictsCycleDayFromLastPeriod() {
        var profile = UserProfile()
        profile.typicalCycleLength = 28
        profile.typicalPeriodLength = 5
        let start = cal.date(byAdding: .day, value: -3, to: cal.startOfDay(for: Date()))!
        profile.lastPeriodStart = start

        let logs = (0..<5).compactMap { offset -> DayLog? in
            guard let day = cal.date(byAdding: .day, value: offset, to: start) else { return nil }
            return DayLog(date: day, flow: .medium)
        }

        let prediction = engine.predict(profile: profile, logs: logs, asOf: Date())
        XCTAssertEqual(prediction.cycleDay, 4)
        XCTAssertEqual(prediction.phase, .menstrual)
        XCTAssertEqual(prediction.algorithmVersion, CyclePredictionEngine.algorithmVersion)
        XCTAssertNotNil(prediction.nextPeriodStart)
    }

    func testUsesTypicalPeriodLengthWhileCurrentPeriodIsOpen() {
        var profile = UserProfile()
        profile.typicalCycleLength = 28
        profile.typicalPeriodLength = 5
        let today = cal.startOfDay(for: Date())
        profile.lastPeriodStart = today
        let logs = [DayLog(date: today, flow: .medium)]

        let prediction = engine.predict(profile: profile, logs: logs, asOf: today)
        XCTAssertEqual(prediction.periodLength, 5)

        XCTAssertEqual(engine.dayMarker(for: today, profile: profile, logs: logs), .loggedPeriod)
        for offset in 1..<5 {
            let day = cal.date(byAdding: .day, value: offset, to: today)!
            XCTAssertEqual(
                engine.dayMarker(for: day, profile: profile, logs: logs),
                .predictedPeriod,
                "Day +\(offset) should be predicted from typical period length"
            )
        }
    }

    func testCatalogHasAtLeastSeventyItems() {
        XCTAssertGreaterThanOrEqual(SymptomCatalog.allCount, 70)
    }

    func testSafetyRefuseEmergency() {
        XCTAssertNotNil(AISafety.shouldRefuse("I have severe bleeding and passed out"))
    }
}
