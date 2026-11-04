import Testing
@testable import Challenges

// Every check here runs after the tasks it depends on have finished, so the results don't depend
// on scheduling or timing.
@Suite("Concurrency Limiter Actor")
struct ConcurrencyLimiterTests {
    @Test("Never more than `limit` operations at once, and every operation runs")
    func respectsLimit() async {
        let limiter = ConcurrencyLimiter(limit: 3)
        let tracker = LimiterActivityTracker()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<40 {
                group.addTask {
                    await limiter.withPermit {
                        await tracker.start()
                        for _ in 0..<10 { await Task.yield() }
                        await tracker.finish()
                    }
                }
            }
        }
        #expect(await tracker.peak <= 3)
        #expect(await tracker.peak >= 1)
        #expect(await tracker.finished == 40)
        #expect(await tracker.running == 0)
        #expect(await limiter.availablePermits == 3)
        #expect(await limiter.waitingCount == 0)
    }

    @Test("With a limit of 1, a read-yield-write sequence never loses an update")
    func limitOfOneIsExclusive() async {
        let limiter = ConcurrencyLimiter(limit: 1)
        let box = LimiterValueBox()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    await limiter.withPermit {
                        let value = await box.value
                        await Task.yield()           // another task could run here
                        await box.set(value + 1)
                    }
                }
            }
        }
        #expect(await box.value == 100)
    }

    @Test("Waiters get the permit in arrival order")
    func firstInFirstOut() async {
        let limiter = ConcurrencyLimiter(limit: 1)
        await limiter.acquire()
        let recorder = LimiterOrderRecorder()
        var tasks: [Task<Void, Never>] = []
        for index in 0..<5 {
            tasks.append(Task {
                await limiter.acquire()
                await recorder.append(index)
                await limiter.release()
            })
            // Wait until this task is queued before starting the next one, so the arrival order is known.
            while await limiter.waitingCount < index + 1 {
                await Task.yield()
            }
        }
        await limiter.release()
        for task in tasks {
            await task.value
        }
        #expect(await recorder.values == [0, 1, 2, 3, 4])
        #expect(await limiter.availablePermits == 1)
    }

    @Test("Permits go back to the pool when nobody is waiting")
    func permitsReturn() async {
        let limiter = ConcurrencyLimiter(limit: 2)
        await limiter.acquire()
        await limiter.acquire()
        #expect(await limiter.availablePermits == 0)
        await limiter.release()
        #expect(await limiter.availablePermits == 1)
        await limiter.release()
        #expect(await limiter.availablePermits == 2)
    }

    @Test("A throwing operation still releases its permit")
    func releasesOnError() async {
        let limiter = ConcurrencyLimiter(limit: 2)
        await #expect(throws: LimiterTestError.self) {
            try await limiter.withPermit { () async throws -> Int in
                throw LimiterTestError()
            }
        }
        #expect(await limiter.availablePermits == 2)
    }

    @Test("Results pass through")
    func returnsResult() async {
        let limiter = ConcurrencyLimiter(limit: 1)
        let result = await limiter.withPermit { 6 * 7 }
        #expect(result == 42)
    }
}

private struct LimiterTestError: Error {}

private actor LimiterActivityTracker {
    private(set) var running = 0
    private(set) var peak = 0
    private(set) var finished = 0

    func start() {
        running += 1
        peak = max(peak, running)
    }

    func finish() {
        running -= 1
        finished += 1
    }
}

private actor LimiterValueBox {
    private(set) var value = 0

    func set(_ newValue: Int) {
        value = newValue
    }
}

private actor LimiterOrderRecorder {
    private(set) var values: [Int] = []

    func append(_ value: Int) {
        values.append(value)
    }
}
