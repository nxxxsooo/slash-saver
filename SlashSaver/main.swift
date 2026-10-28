import AppKit

if let parsed = InputSourceCommand.parse(Array(CommandLine.arguments.dropFirst())) {
    switch parsed {
    case let .success(command):
        exit(command.run(
            inputSources: InputSourceManager(),
            preferences: AppPreferences(),
            output: { print($0) },
            error: { FileHandle.standardError.write(Data("SlashSaver: \($0)\n".utf8)) }
        ))
    case .failure:
        FileHandle.standardError.write(Data("\(InputSourceCommand.usage)\n".utf8))
        exit(64)
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
