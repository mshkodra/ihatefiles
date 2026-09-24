import XCTest
@testable import ihatefiles

/// Exercises `ProcessRunning` + `CancellableProcess`'s cancellation path
/// against a real, long-running local process (`/bin/sleep`) — no network,
/// no yt-dlp/ffmpeg involved. This directly investigates the concern raised
/// in Phase 4 (a mid-download cancellation test that hung and was never
/// root-caused): if `Process.terminate()` alone doesn't reliably and
/// promptly end a subprocess, this test would hang or time out too.
final class CancellableProcessTests: XCTestCase {

    func testCancelTerminatesRunningProcessPromptly() async throws {
        let cancellable = CancellableProcess()
        let started = expectation(description: "process started")

        let task = Task {
            try await ProcessRunning.run(
                executableURL: URL(fileURLWithPath: "/bin/sleep"),
                arguments: ["30"],
                onLaunch: { process in
                    cancellable.store(process)
                    started.fulfill()
                },
                onStdoutLine: { _ in }
            )
        }

        await fulfillment(of: [started], timeout: 5)
        cancellable.cancel()

        let start = Date()
        do {
            try await task.value
            XCTFail("Expected the terminated process to throw, not exit cleanly")
        } catch {
            // Any throw is fine here (SIGTERM produces a non-zero exit,
            // surfaced as ProcessRunning.ProcessError) — what matters is
            // that it resolved at all, and quickly.
        }
        let elapsed = Date().timeIntervalSince(start)

        // SIGTERM should end `sleep` almost instantly; well under the 2s
        // SIGKILL escalation grace period in CancellableProcess.cancel().
        XCTAssertLessThan(elapsed, 2.0, "cancel() took \(elapsed)s to resolve — process may not be terminating promptly")
    }

    // A second test attempted to exercise the SIGKILL-escalation fallback
    // by spawning a shell that traps/ignores SIGTERM (`sh -c "trap '' TERM;
    // sleep 30"`). It was removed: the process still exited near-instantly
    // (~0.0003s) under SIGTERM despite the trap, almost certainly because
    // `/bin/sh` exec-replaces itself with the trailing `sleep` command when
    // there's nothing left to do after it — which drops the trap along with
    // the shell process image, defeating the intended repro rather than
    // proving anything about the escalation path. No reliable way to
    // construct a genuinely SIGTERM-resistant test process turned up in the
    // time available, so the SIGKILL fallback in `CancellableProcess.cancel`
    // remains defensive/untested-in-isolation rather than proven — flagged
    // honestly rather than claiming coverage that doesn't exist. What *is*
    // proven, by the test above using a real subprocess (not a fake/mock):
    // the normal SIGTERM cancellation path is prompt and reliable.
}
