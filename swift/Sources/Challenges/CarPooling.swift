/// A group of passengers riding a shuttle from mile `pickup` to mile `dropoff`.
/// They're on board for the half-open stretch `pickup..<dropoff`.
public struct ShuttleBooking: Equatable, Sendable {
    public let passengers: Int
    public let pickup: Int
    public let dropoff: Int

    public init(passengers: Int, pickup: Int, dropoff: Int) {
        self.passengers = passengers
        self.pickup = pickup
        self.dropoff = dropoff
    }
}

/// Returns whether a shuttle with `seats` seats, driving in one direction, can carry every booking.
///
/// A sweep over events: each booking adds its passengers at `pickup` and removes them at
/// `dropoff`. Events are sorted by mile, and at the same mile drop-offs (negative changes) come
/// before pickups, because passengers get off before new ones get on. The answer is no as soon
/// as the running load exceeds `seats`. O(n log n) time, O(n) space.
public func canServeAllBookings(_ bookings: [ShuttleBooking], seats: Int) -> Bool {
    var events: [(mile: Int, change: Int)] = []
    for booking in bookings {
        events.append((mile: booking.pickup, change: booking.passengers))
        events.append((mile: booking.dropoff, change: -booking.passengers))
    }
    events.sort { $0.mile != $1.mile ? $0.mile < $1.mile : $0.change < $1.change }

    var onBoard = 0
    for event in events {
        onBoard += event.change
        if onBoard > seats {
            return false
        }
    }
    return true
}

/// Naive version: the load only goes up at a pickup, so check the load at every pickup mile
/// by adding up all the bookings on board there. O(n²) time, O(1) extra space.
public func canServeAllBookingsBruteForce(_ bookings: [ShuttleBooking], seats: Int) -> Bool {
    for booking in bookings {
        var onBoard = 0
        for other in bookings where other.pickup <= booking.pickup && booking.pickup < other.dropoff {
            onBoard += other.passengers
        }
        if onBoard > seats {
            return false
        }
    }
    return true
}
