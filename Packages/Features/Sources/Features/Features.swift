import DesignSystem
import Model
import Storage

/// Placeholder for the `Features` module. Real types arrive with their backlog items.
public enum FeaturesModule {
    public static let name = "Features"

    /// Proves the feature layer links the core packages it depends on.
    public static let linkedModules = [DesignSystemModule.name, ModelModule.name, StorageModule.name]
}
