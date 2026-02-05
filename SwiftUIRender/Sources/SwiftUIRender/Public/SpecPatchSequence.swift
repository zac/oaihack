import Foundation

public struct AnySpecPatchSequence: AsyncSequence, Sendable {
    public typealias Element = SpecPatch

    private let stream: AsyncStream<SpecPatch>

    public init(_ stream: AsyncStream<SpecPatch>) {
        self.stream = stream
    }

    public init<S>(_ base: S) where S: AsyncSequence & Sendable, S.Element == SpecPatch {
        stream = AsyncStream { continuation in
            let task = Task {
                do {
                    for try await patch in base {
                        continuation.yield(patch)
                    }
                } catch {
                    // v1 stream contract is best-effort and diagnostics are surfaced at patch application.
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    public func makeAsyncIterator() -> AsyncStream<SpecPatch>.Iterator {
        stream.makeAsyncIterator()
    }

    public static func immediate(_ patches: [SpecPatch]) -> AnySpecPatchSequence {
        AnySpecPatchSequence(
            AsyncStream { continuation in
                for patch in patches {
                    continuation.yield(patch)
                }
                continuation.finish()
            }
        )
    }
}
