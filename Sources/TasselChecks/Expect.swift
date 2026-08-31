import Foundation

/// The smallest assertion helper that will do the job, so the checks can run on
/// a Mac with only the Command Line Tools installed.
enum Expect {
    nonisolated(unsafe) static private(set) var failures: [String] = []
    nonisolated(unsafe) static private var current = "?"

    static func suite(_ name: String, _ body: () -> Void) {
        current = name
        body()
    }

    static func that(_ condition: Bool, _ message: @autoclosure () -> String) {
        if !condition {
            failures.append("\(current): \(message())")
        }
    }

    static func near(
        _ value: Double,
        _ expected: Double,
        _ tolerance: Double,
        _ message: @autoclosure () -> String
    ) {
        if !(abs(value - expected) <= tolerance) {
            failures.append("\(current): \(message()) — got \(value), expected \(expected) ± \(tolerance)")
        }
    }

    static func report() -> Never {
        if failures.isEmpty {
            print("all checks passed")
            exit(0)
        }
        for failure in failures {
            FileHandle.standardError.write(Data("FAIL  \(failure)\n".utf8))
        }
        FileHandle.standardError.write(Data("\n\(failures.count) check(s) failed\n".utf8))
        exit(1)
    }
}
