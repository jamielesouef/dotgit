import Foundation

struct SystemClock: Clocking {
    let timeZone: TimeZone

    func now() -> Date {
        Date()
    }
}
