import Foundation
import Testing
@testable import SwiftUIRender

@Test("UISpec decode/encode parity")
func specDecodeEncodeParity() throws {
    let spec = try loadSpecFixture(named: "basic-spec")
    let data = try JSONEncoder().encode(spec)
    let decoded = try JSONDecoder().decode(UISpec.self, from: data)
    #expect(spec == decoded)
}

@Test("Binding path parser normalizes pointer and $data syntax")
func bindingPathNormalization() throws {
    let fromData = try BindingPath.parse("$data.customer.items[0].name")
    let fromPointer = try BindingPath.parse("/customer/items/0/name")

    #expect(fromData == fromPointer)
    #expect(fromData.canonicalPointer == "/customer/items/0/name")
}

@Test("Data document supports read/write using canonical binding path")
func dataDocumentReadWrite() throws {
    var document = DataDocument(root: .object([:]))
    let path = try BindingPath.parse("$data.profile.firstName")

    try document.write(value: .string("Ava"), path: path)
    #expect(document.read(path: path) == .string("Ava"))

    try document.remove(path: path)
    #expect(document.read(path: path) == nil)
}

@Test("Style resolver merges class styles and inline styles with warnings")
func styleResolverMergesAndWarns() throws {
    let config = RenderConfiguration(
        styleClasses: [
            "hero": [
                "color": .string("#ff0000"),
                "padding": .number(8),
            ],
        ],
        styleVariables: [
            "space-sm": .number(6),
        ],
        emitUnsupportedStyleWarnings: true
    )

    let element = UIElement(
        type: "text",
        props: ["className": .string("hero")],
        styles: [
            "padding-top": .string("var(--space-sm)"),
            "font-size": .number(18),
            "not-real": .string("x"),
        ]
    )

    let resolver = StyleResolver(configuration: config)
    let (style, issues) = resolver.resolve(element: element, componentDefaults: [:], path: "/elements/title/styles")

    #expect(style.color == "#ff0000")
    #expect(style.padding.leading == 8)
    #expect(style.padding.top == 6)
    #expect(style.fontSize == 18)
    #expect(issues.count == 1)
    #expect(issues.first?.severity == .warning)
}

@Test("Unknown component compiles to guardrail node")
func unknownComponentGuardrail() throws {
    let spec = try loadSpecFixture(named: "invalid-spec")
    let compiler = GraphCompiler(configuration: .default)
    let output = compiler.compile(spec: spec)

    guard let node = output.graph.nodes["unknownNode"] else {
        Issue.record("missing unknownNode in graph")
        return
    }

    switch node.kind {
    case .guardrail:
        break
    default:
        Issue.record("expected guardrail node")
    }

    #expect(output.issues.contains(where: { $0.message.contains("Unknown component type") }))
}

@Test("Invalid action payload emits validation error")
func actionValidation() throws {
    var spec = makeMinimalSpec()
    spec.elements["button1"] = UIElement(
        type: "button",
        parentKey: "root",
        props: [
            "text": .string("Open"),
            "action": .object([
                "name": .string("open_url"),
                "params": .object([:]),
            ]),
        ]
    )
    spec.elements["root"]?.children = ["children": ["button1"]]

    let output = GraphCompiler(configuration: .default).compile(spec: spec)
    #expect(output.issues.contains(where: { $0.message.contains("open_url requires params.url") }))
}

@Test("Spec patch operations set/add/replace/remove mutate typed UISpec")
func patchOperationsMutateSpec() throws {
    var spec = makeMinimalSpec()

    _ = try SpecPatchApplier.apply(
        SpecPatch(op: .set, path: "/elements/text1/props/text", value: .string("Updated")),
        to: &spec
    )
    #expect(spec.elements["text1"]?.props["text"] == .string("Updated"))

    let text2 = UIElement(type: "text", parentKey: "root", props: ["text": .string("Second")])
    let text2Value = try JSONValueCodableBridge.encode(text2)

    _ = try SpecPatchApplier.apply(
        SpecPatch(op: .set, path: "/elements/text2", value: text2Value),
        to: &spec
    )
    _ = try SpecPatchApplier.apply(
        SpecPatch(op: .add, path: "/elements/root/children/children/-", value: .string("text2")),
        to: &spec
    )
    #expect(spec.elements["root"]?.children["children"]?.contains("text2") == true)

    _ = try SpecPatchApplier.apply(
        SpecPatch(op: .replace, path: "/elements/text2/props/text", value: .string("Second Updated")),
        to: &spec
    )
    #expect(spec.elements["text2"]?.props["text"] == .string("Second Updated"))

    _ = try SpecPatchApplier.apply(
        SpecPatch(op: .remove, path: "/elements/text1"),
        to: &spec
    )
    #expect(spec.elements["text1"] == nil)
}

@Test("Runtime applies patch incrementally and continues after failures")
func runtimeIncrementalAndContinue() async throws {
    let engine = SpecRuntimeEngine(spec: makeMinimalSpec(), configuration: .default)
    let initial = await engine.bootstrap()
    #expect(initial.graph.nodes.count == 2)

    let update = await engine.apply(
        SpecPatch(op: .replace, path: "/elements/text1/props/text", value: .string("Patched"))
    )

    #expect(update.delta != nil)
    #expect(update.delta?.updatedNodes.keys.contains("text1") == true)

    let failed = await engine.apply(
        SpecPatch(op: .replace, path: "/elements/missing/props/text", value: .string("bad"))
    )

    #expect(failed.delta == nil)
    #expect(failed.issues.contains(where: { $0.message.contains("Patch failed") }))

    let secondUpdate = await engine.apply(
        SpecPatch(op: .replace, path: "/elements/text1/props/text", value: .string("Patched Again"))
    )

    #expect(secondUpdate.delta != nil)
    #expect(secondUpdate.delta?.updatedNodes.keys.contains("text1") == true)
}

@Test("Runtime removed keys include detached subtree")
func runtimeRemovedKeysForDetachedSubtree() async throws {
    let engine = SpecRuntimeEngine(spec: makeMinimalSpec(), configuration: .default)
    _ = await engine.bootstrap()

    let detached = await engine.apply(
        SpecPatch(op: .remove, path: "/elements/root/children/children/0")
    )

    #expect(detached.delta?.removedKeys.contains("text1") == true)
}

private func loadSpecFixture(named name: String) throws -> UISpec {
    guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") else {
        throw FixtureError.missingFixture(name)
    }
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(UISpec.self, from: data)
}

private func makeMinimalSpec() -> UISpec {
    UISpec(
        root: "root",
        elements: [
            "root": UIElement(
                type: "root",
                children: ["children": ["text1"]]
            ),
            "text1": UIElement(
                type: "text",
                parentKey: "root",
                props: ["text": .string("Hello")]
            ),
        ]
    )
}

enum FixtureError: Error {
    case missingFixture(String)
}
