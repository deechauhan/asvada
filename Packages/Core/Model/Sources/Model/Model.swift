import SwiftData

/// Placeholder for the `Model` module name, kept for linkage checks.
public enum ModelModule {
    public static let name = "Model"

    /// Every persistent model type, in schema order.
    public static var models: [any PersistentModel.Type] {
        [
            ExperienceCollection.self,
            Item.self,
            Entry.self,
            Photo.self,
            Trip.self,
            Tag.self,
            Person.self,
        ]
    }
}
