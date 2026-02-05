import Foundation

actor SpecRuntimeEngine {
    private var spec: UISpec
    private let compiler: GraphCompiler

    init(spec: UISpec, configuration: RenderConfiguration) {
        self.spec = spec
        self.compiler = GraphCompiler(configuration: configuration)
    }

    func bootstrap() -> GraphCompileOutput {
        compiler.compile(spec: spec)
    }

    func currentSpec() -> UISpec {
        spec
    }

    func apply(_ patch: SpecPatch) -> PatchApplyOutcome {
        let oldSpec = spec
        let oldReachable = compiler.reachableKeys(in: oldSpec)

        let touchedKeys: Set<String>
        do {
            touchedKeys = try SpecPatchApplier.apply(patch, to: &spec)
        } catch {
            let issue = GuardrailIssue(
                severity: .error,
                message: "Patch failed: \(error)",
                path: patch.path
            )
            return PatchApplyOutcome(delta: nil, issues: [issue])
        }

        let newReachable = compiler.reachableKeys(in: spec)
        let removedKeys = oldReachable.subtracting(newReachable)
        let addedKeys = newReachable.subtracting(oldReachable)

        var dirty = touchedKeys
        for key in touchedKeys {
            dirty.formUnion(ancestorChain(for: key, in: oldSpec))
            dirty.formUnion(ancestorChain(for: key, in: spec))
        }

        if patch.path == "/root" {
            dirty.formUnion(oldReachable)
            dirty.formUnion(newReachable)
        }

        let descendants = compiler.descendants(of: dirty.union(addedKeys), in: spec)
        let keysToCompile = descendants.intersection(newReachable).union(addedKeys)

        let compileOutput = compiler.compile(keys: keysToCompile, in: spec)

        let delta = GraphDelta(
            rootKey: spec.root,
            updatedNodes: compileOutput.nodes,
            removedKeys: removedKeys,
            issues: compileOutput.issues
        )

        return PatchApplyOutcome(delta: delta, issues: compileOutput.issues)
    }

    private func ancestorChain(for key: String, in spec: UISpec) -> Set<String> {
        var result: Set<String> = []
        var cursor = key

        while let element = spec.elements[cursor], let parent = element.parentKey {
            if result.contains(parent) {
                break
            }
            result.insert(parent)
            cursor = parent
        }

        return result
    }
}
