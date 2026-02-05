import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
public final class DataDocumentStore {
    public private(set) var document: DataDocument

    public init(document: DataDocument = DataDocument()) {
        self.document = document
    }

    public func read(path: BindingPath) -> JSONValue? {
        document.read(path: path)
    }

    public func write(value: JSONValue, path: BindingPath) {
        do {
            try document.write(value: value, path: path)
        } catch {
            // Intentional no-op: write failures should be surfaced by callers with diagnostics.
        }
    }

    public func write(string: String, path: BindingPath) {
        write(value: .string(string), path: path)
    }

    public func stringBinding(path: BindingPath, fallback: String = "") -> Binding<String> {
        Binding(
            get: {
                self.read(path: path)?.stringValue ?? fallback
            },
            set: { newValue in
                self.write(string: newValue, path: path)
            }
        )
    }
}
