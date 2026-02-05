import Foundation
import Observation

@MainActor
@Observable
final class NodeBox: Identifiable {
    let id: String
    var node: RenderNode

    init(node: RenderNode) {
        self.id = node.key
        self.node = node
    }
}

@MainActor
@Observable
final class RenderGraphStore {
    private(set) var rootKey: String = ""
    private var nodeMap: [String: NodeBox] = [:]

    var rootBox: NodeBox? {
        nodeMap[rootKey]
    }

    func bootstrap(graph: RenderGraph) {
        rootKey = graph.rootKey
        nodeMap = graph.nodes.reduce(into: [:]) { partial, entry in
            partial[entry.key] = NodeBox(node: entry.value)
        }
    }

    func apply(delta: GraphDelta) {
        rootKey = delta.rootKey

        for key in delta.removedKeys {
            nodeMap.removeValue(forKey: key)
        }

        for (key, node) in delta.updatedNodes {
            if let existing = nodeMap[key] {
                existing.node = node
            } else {
                nodeMap[key] = NodeBox(node: node)
            }
        }
    }

    func box(for key: String) -> NodeBox? {
        nodeMap[key]
    }

    func contains(key: String) -> Bool {
        nodeMap[key] != nil
    }
}
