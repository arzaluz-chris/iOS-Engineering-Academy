/// An async semaphore: lets at most `limit` operations hold a permit at the same time. Callers that
/// find no permit free suspend (they don't block a thread) and get one in arrival order.
///
/// The actor keeps the free permit count and a FIFO queue of suspended callers' continuations.
/// `acquire()` checks and takes a permit with no `await` in between, so two callers can't both take
/// the last one. `release()` hands the permit straight to the first waiter instead of returning it
/// to the pool, so a caller arriving later can't take it first.
/// `acquire` and `release` are O(1) amortized; O(w) space for w waiting callers.
public actor ConcurrencyLimiter {
    public let limit: Int
    private var freePermits: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var firstWaiter = 0   // waiters before this index were already resumed

    public init(limit: Int) {
        precondition(limit > 0, "limit must be positive")
        self.limit = limit
        self.freePermits = limit
    }

    public var availablePermits: Int { freePermits }

    public var waitingCount: Int { waiters.count - firstWaiter }

    /// Takes a permit, suspending until one is free.
    public func acquire() async {
        if freePermits > 0 {
            freePermits -= 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
        // Resumed by release(), which passed its permit to this caller.
    }

    /// Gives a permit back: to the longest-waiting caller if there is one, otherwise to the pool.
    public func release() {
        guard firstWaiter < waiters.count else {
            precondition(freePermits < limit, "release() called more times than acquire()")
            freePermits += 1
            return
        }
        let next = waiters[firstWaiter]
        firstWaiter += 1
        if firstWaiter * 2 >= waiters.count {   // drop resumed entries once they're half the array
            waiters.removeFirst(firstWaiter)
            firstWaiter = 0
        }
        next.resume()
    }

    /// Runs `operation` while holding a permit, and releases it however the operation ends.
    public func withPermit<T: Sendable>(_ operation: @Sendable () async throws -> T) async rethrows -> T {
        await acquire()
        defer { release() }
        return try await operation()
    }
}
