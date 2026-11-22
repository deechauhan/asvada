@testable import Model

/// `Tag` clashes with Swift Testing's `Tag` in files that import Testing (and `Model.Tag`
/// resolves to SwiftData's `@Model` macro), so tests refer to the model through this alias.
/// This file deliberately doesn't import Testing.
typealias ModelTag = Tag
