import SwiftUI
import UniformTypeIdentifiers

/// Wraps the `.html`/`.ireal` export text for SwiftUI's `.fileExporter`.
struct IrealDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.html, .plainText] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents, let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = string
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
