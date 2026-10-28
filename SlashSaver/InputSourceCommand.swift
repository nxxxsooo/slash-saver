import Foundation

/// `SlashSaver input-source …`: lets terminal tools switch the input source through the
/// same signed binary, without starting the app or its keyboard monitor.
enum InputSourceCommand: Equatable {
    case current
    case select(String)
    case ascii

    static let usage = """
    usage: SlashSaver input-source current       print the current input source ID
           SlashSaver input-source select <id>   select an enabled input source
           SlashSaver input-source ascii         select the configured ASCII source; print the previous ID
    """

    /// The command in `arguments` (without the executable), or nil when they are not ours.
    static func parse(_ arguments: [String]) -> Result<InputSourceCommand, UsageError>? {
        guard arguments.first == "input-source" else { return nil }
        let rest = Array(arguments.dropFirst())
        switch (rest.first, rest.count) {
        case ("current", 1): return .success(.current)
        case ("ascii", 1): return .success(.ascii)
        case ("select", 2) where !rest[1].isEmpty: return .success(.select(rest[1]))
        default: return .failure(UsageError())
        }
    }

    struct UsageError: Error, Equatable {}

    /// Runs the command and returns the process exit status.
    func run(
        inputSources: InputSourceManager,
        preferences: AppPreferences,
        output: (String) -> Void,
        error: (String) -> Void
    ) -> Int32 {
        guard let current = inputSources.currentInputSourceID() else {
            error("cannot read the current input source")
            return 1
        }
        switch self {
        case .current:
            output(current)
            return 0
        case let .select(id):
            guard inputSources.selectInputSource(id: id) else {
                error("cannot select input source \(id)")
                return 1
            }
            return 0
        case .ascii:
            guard let target = preferences.targetInputSourceID else {
                error("no ASCII input source is configured; open Slash Saver to choose one")
                return 1
            }
            guard inputSources.selectInputSource(id: target) else {
                error("cannot select input source \(target)")
                return 1
            }
            output(current)
            return 0
        }
    }
}
