import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class RenderRuntime {
    let configuration: RenderConfiguration
    let diagnostics: RenderDiagnostics
    let graphStore = RenderGraphStore()
    let dataStore: DataDocumentStore

    private var engine: SpecRuntimeEngine?
    private var streamTask: Task<Void, Never>?

    init(source: RenderSource, configuration: RenderConfiguration, diagnostics: RenderDiagnostics? = nil) {
        self.configuration = configuration
        self.diagnostics = diagnostics ?? RenderDiagnostics()
        self.dataStore = DataDocumentStore(document: DataDocument(root: configuration.initialData))

        Task {
            await load(source: source)
        }
    }

    func load(source: RenderSource) async {
        streamTask?.cancel()
        diagnostics.clear()

        switch source {
        case let .jsonString(json):
            do {
                let spec = try JSONDecoder().decode(UISpec.self, from: Data(json.utf8))
                await bootstrap(spec: spec)
            } catch {
                applyFallback(message: "Failed to decode UISpec: \(error)")
            }

        case let .spec(spec):
            await bootstrap(spec: spec)

        case let .patchStream(initial, patches):
            await bootstrap(spec: initial)
            startStreaming(patches)
        }
    }

    func run(action: RenderAction) {
        let context = RenderActionContext(
            setData: { [weak self] path, value in
                await MainActor.run {
                    self?.dataStore.write(value: value, path: path)
                }
            },
            readData: { [weak self] path in
                await MainActor.run {
                    self?.dataStore.read(path: path)
                }
            },
            reportIssue: { [weak self] issue in
                await MainActor.run {
                    self?.diagnostics.append(issue)
                }
            }
        )

        Task {
            await BuiltinActionExecutor.execute(action, handler: configuration.actionHandler, context: context)
        }
    }

    private func bootstrap(spec: UISpec) async {
        let engine = SpecRuntimeEngine(spec: spec, configuration: configuration)
        self.engine = engine

        let output = await engine.bootstrap()
        graphStore.bootstrap(graph: output.graph)
        diagnostics.append(contentsOf: output.issues)
    }

    private func startStreaming(_ patches: AnySpecPatchSequence) {
        guard let engine else { return }

        streamTask = Task {
            for await patch in patches {
                if Task.isCancelled { break }

                let outcome = await engine.apply(patch)
                await MainActor.run {
                    self.apply(outcome: outcome)
                }
            }
        }
    }

    private func apply(outcome: PatchApplyOutcome) {
        diagnostics.append(contentsOf: outcome.issues)
        if let delta = outcome.delta {
            graphStore.apply(delta: delta)
        }
    }

    private func applyFallback(message: String) {
        let key = "guardrail-root"
        let graph = RenderGraph(
            rootKey: key,
            nodes: [
                key: RenderNode(
                    key: key,
                    meta: NodeMeta(key: key, parentKey: nil, type: "guardrail", children: [:]),
                    style: ResolvedStyle(),
                    kind: .guardrail(message: message)
                )
            ]
        )

        graphStore.bootstrap(graph: graph)
        diagnostics.append(
            GuardrailIssue(
                severity: .error,
                message: message,
                path: nil
            )
        )
    }
}
