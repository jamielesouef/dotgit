import Foundation

protocol Clocking: Sendable {
    func now() -> Date
    var timeZone: TimeZone { get }
}
