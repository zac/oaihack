import Foundation

public enum RenderSource: Sendable {
    case jsonString(String)
    case spec(UISpec)
    case patchStream(initial: UISpec, patches: AnySpecPatchSequence)
}
