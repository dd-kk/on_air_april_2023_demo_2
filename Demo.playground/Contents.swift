import Foundation

public struct Logger {
    public init() {}
    
    public func log(event: Events) {
        let logItem = AnalyticsEvent(
            timestamp: Date().timeIntervalSince1970,
            event: event
        )
        let json = try! JSONEncoder().encode(logItem)
        print("Encoded event as:\n\(String(data: json, encoding: .utf8)!)")
        print("_______________________________________")
        let decodedEvent = try! JSONDecoder().decode(AnalyticsEvent.self, from: json)
        print("Decoded event \(decodedEvent)")
    }
}

let logger = Logger()

logger.log(event: .report_an_accident_tap(ReportAnAccidentTap(source: .tripDetails)))
print("========================================")
logger.log(event: .trip_report_tap(TripReportTap(source: .tripsList)))
print("========================================")
logger.log(event: .main_screen)
