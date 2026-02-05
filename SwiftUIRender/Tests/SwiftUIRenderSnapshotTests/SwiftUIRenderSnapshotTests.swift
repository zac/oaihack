import Foundation
import SnapshotTesting
import SwiftUI
import XCTest
@testable import SwiftUIRender

#if os(iOS)
import UIKit
#endif

final class SwiftUIRenderSnapshotTests: XCTestCase {
    @MainActor
    func testBasicStructureSnapshot() async throws {
        let spec = try loadSpecFixture(named: "basic-spec")
        let diagnostics = RenderDiagnostics()
        let runtime = RenderRuntime(source: .spec(spec), configuration: .default, diagnostics: diagnostics)

        await runtime.load(source: .spec(spec))
        let rootNode = runtime.graphStore.rootBox?.node
        assertSnapshot(of: rootNode, as: .dump, record: false)
    }

    @MainActor
    func testGuardrailStructureSnapshot() async throws {
        let spec = try loadSpecFixture(named: "invalid-spec")
        let diagnostics = RenderDiagnostics()
        let runtime = RenderRuntime(source: .spec(spec), configuration: .default, diagnostics: diagnostics)

        await runtime.load(source: .spec(spec))
        let rootNode = runtime.graphStore.rootBox?.node
        assertSnapshot(of: rootNode, as: .dump, record: false)
    }

    #if os(iOS)
    @MainActor
    func testBasicImageSnapshot_iPhoneSE() async throws {
        let spec = try loadSpecFixture(named: "basic-spec")
        let diagnostics = RenderDiagnostics()
        let runtime = RenderRuntime(source: .spec(spec), configuration: .default, diagnostics: diagnostics)

        await runtime.load(source: .spec(spec))

        guard let root = runtime.graphStore.rootBox else {
            XCTFail("expected root node")
            return
        }

        let view = NodeView(box: root, runtime: runtime)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        let host = UIHostingController(rootView: view)

        assertSnapshot(of: host, as: .image(on: .iPhoneSe), record: false)
    }
    #endif

    private func loadSpecFixture(named name: String) throws -> UISpec {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") else {
            throw SnapshotFixtureError.missingFixture(name)
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(UISpec.self, from: data)
    }
}

enum SnapshotFixtureError: Error {
    case missingFixture(String)
}
