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

    func testCatalogHasAtLeastSeventyItems() {
        XCTAssertGreaterThanOrEqual(SymptomCatalog.allCount, 70)
    }

    func testSafetyRefuseEmergency() {
        XCTAssertNotNil(AISafety.shouldRefuse("I have severe bleeding and passed out"))
    }
}
