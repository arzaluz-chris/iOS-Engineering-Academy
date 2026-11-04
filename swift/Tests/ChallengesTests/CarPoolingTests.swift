import Testing
@testable import Challenges

/// Deterministic pseudo-random numbers (a 64-bit LCG), so a failing case reproduces.
private struct SeededGenerator {
    var state: UInt64
    mutating func next(below bound: Int) -> Int {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Int((state >> 33) % UInt64(bound))
    }
}

private func booking(_ passengers: Int, _ pickup: Int, _ dropoff: Int) -> ShuttleBooking {
    ShuttleBooking(passengers: passengers, pickup: pickup, dropoff: dropoff)
}

@Suite("Car Pooling")
struct CarPoolingTests {
    @Test("Examples from the problem statement")
    func examples() {
        let bookings = [booking(3, 2, 7), booking(2, 5, 9), booking(4, 8, 12)]
        #expect(!canServeAllBookings(bookings, seats: 5))
        #expect(canServeAllBookings(bookings, seats: 6))
    }

    @Test("No bookings")
    func noBookings() {
        #expect(canServeAllBookings([], seats: 0))
    }

    @Test("Drop-offs happen before pickups at the same mile")
    func backToBack() {
        #expect(canServeAllBookings([booking(4, 0, 5), booking(4, 5, 9)], seats: 4))
    }

    @Test("One booking larger than the shuttle")
    func tooLarge() {
        #expect(!canServeAllBookings([booking(9, 1, 2)], seats: 8))
    }

    @Test("Peak load in the middle of a long ride")
    func peakInMiddle() {
        let bookings = [booking(2, 0, 100), booking(3, 40, 60), booking(1, 50, 55), booking(5, 70, 80)]
        #expect(canServeAllBookings(bookings, seats: 7))
        #expect(!canServeAllBookings(bookings, seats: 6))
    }

    @Test("Random bookings agree with the naive version")
    func agreesWithBruteForce() {
        var generator = SeededGenerator(state: 55)
        for _ in 0..<500 {
            let bookings = (0..<generator.next(below: 8)).map { _ in
                let pickup = generator.next(below: 15)
                return booking(1 + generator.next(below: 4), pickup, pickup + 1 + generator.next(below: 6))
            }
            let seats = generator.next(below: 12)
            #expect(
                canServeAllBookings(bookings, seats: seats) == canServeAllBookingsBruteForce(bookings, seats: seats),
                "bookings: \(bookings), seats: \(seats)"
            )
        }
    }
}
