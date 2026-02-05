import SwiftUI

public struct RenderView: View {
    public let diagnostics: RenderDiagnostics

    @State private var runtime: RenderRuntime

    public init(
        source: RenderSource,
        configuration: RenderConfiguration = .default,
        diagnostics: RenderDiagnostics? = nil
    ) {
        let diagnostics = diagnostics ?? RenderDiagnostics()
        self.diagnostics = diagnostics
        _runtime = State(initialValue: RenderRuntime(source: source, configuration: configuration, diagnostics: diagnostics))
    }

    public var body: some View {
        Group {
            if let rootBox = runtime.graphStore.rootBox {
                ScrollView {
                    NodeView(box: rootBox, runtime: runtime)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ProgressView("Rendering...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
