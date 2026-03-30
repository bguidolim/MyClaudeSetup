import Foundation
@testable import mcs
import Testing

struct ValidatePackCommandTests {
    // MARK: - Argument Parsing

    @Test("ValidatePack parses with no arguments (defaults to current directory)")
    func validateDefaultSource() throws {
        let cmd = try ValidatePack.parse([])
        #expect(cmd.source == nil)
    }

    @Test("ValidatePack parses source argument")
    func validateWithSource() throws {
        let cmd = try ValidatePack.parse(["/path/to/pack"])
        #expect(cmd.source == "/path/to/pack")
    }

    @Test("ValidatePack parses pack identifier")
    func validateWithIdentifier() throws {
        let cmd = try ValidatePack.parse(["ios"])
        #expect(cmd.source == "ios")
    }

    // MARK: - Subcommand Registration

    @Test("PackCommand includes validate subcommand")
    func validateSubcommandRegistered() {
        let subcommands = PackCommand.configuration.subcommands
        #expect(subcommands.contains { $0 == ValidatePack.self })
    }
}
