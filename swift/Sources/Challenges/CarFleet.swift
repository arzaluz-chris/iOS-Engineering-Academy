/// Counts how many fleets reach `target`. Cars drive toward `target` on a one-lane road;
/// a faster car that catches a slower one stays behind it, and from then on they're one fleet.
///
/// Sorts the cars by position, closest to the target first, then walks back down the road.
/// The fleets found so far form a stack whose arrival times increase from bottom to top,
/// and a car only ever needs to compare itself with the top, the slowest fleet ahead of it:
/// if it would arrive no later than that fleet, it joins it; otherwise it becomes a new fleet
/// on top. Since only the top is read, the stack collapses to one variable.
/// Arrival times are compared as fractions, by cross-multiplying, so there's no floating point.
/// O(n log n) time for the sort, O(n) space.
///
/// Assumes distinct starting positions, all below `target`, and positive speeds.
public func carFleets(target: Int, positions: [Int], speeds: [Int]) -> Int {
    let cars = zip(positions, speeds).sorted { $0.0 > $1.0 }
    var fleets = 0
    var slowestAhead: (distance: Int, speed: Int)? = nil

    for (position, speed) in cars {
        let distance = target - position
        if let ahead = slowestAhead, distance * ahead.speed <= ahead.distance * speed {
            continue
        }
        fleets += 1
        slowestAhead = (distance: distance, speed: speed)
    }
    return fleets
}

/// Naive version: a car leads its own fleet exactly when every car ahead of it would arrive
/// strictly earlier on its own. Checks that for each car against all the others. O(n²) time.
public func carFleetsBruteForce(target: Int, positions: [Int], speeds: [Int]) -> Int {
    var fleets = 0
    for i in positions.indices {
        let distance = target - positions[i]
        var blocked = false
        for j in positions.indices where positions[j] > positions[i] {
            let distanceAhead = target - positions[j]
            if distance * speeds[j] <= distanceAhead * speeds[i] {
                blocked = true
                break
            }
        }
        if !blocked {
            fleets += 1
        }
    }
    return fleets
}
