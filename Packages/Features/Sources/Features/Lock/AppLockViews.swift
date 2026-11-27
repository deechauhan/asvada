import DesignSystem
import SwiftUI

/// The cover over a locked app: the aubergine field with the ā, and an Unlock button. It's opaque,
/// so the app switcher and anyone glancing see nothing of your keepsakes.
struct AppLockCover: View {
    let model: AppLockModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Palette.aubergineTop.color, Palette.aubergineBottom.color],
                startPoint: .top,
                endPoint: .bottom,
            )
            .ignoresSafeArea()
            VStack(spacing: Spacing.large) {
                Text("ā")
                    .font(.system(size: 64, weight: .heavy, design: .serif))
                    .foregroundStyle(Palette.onAubergine.color)
                    .accessibilityHidden(true)
                Text(model.isLocked ? "Locked" : "Asvada")
                    .typeToken(.title)
                    .foregroundStyle(Palette.onAubergine.color)
                if model.isLocked {
                    Button {
                        Task { await model.unlock() }
                    } label: {
                        Label("Unlock", systemImage: "faceid")
                            .typeToken(.headline)
                            .foregroundStyle(Palette.onBrand.color)
                            .padding(.horizontal, Spacing.xl)
                            .padding(.vertical, Spacing.medium)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.tint(Palette.brand.color).interactive(), in: Capsule())
                    .accessibilityHint("Asks for Face ID or your passcode")
                    .accessibilityIdentifier("unlockButton")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("appLockCover")
        .task(id: model.isLocked && model.isActive) {
            if model.isLocked, model.isActive, model.promptsAutomatically {
                await model.unlock()
            }
        }
    }
}

/// Settings: the lock's toggle and how soon it falls.
struct AppLockSettingsSection: View {
    let model: AppLockModel
    @State private var message: String?

    var body: some View {
        Section {
            Toggle("Lock with Face ID", isOn: toggle)
                .accessibilityIdentifier("appLockToggle")
            if model.isEnabled {
                Picker("Lock", selection: delay) {
                    ForEach(AppLockDelay.allCases) { delay in
                        Text(delay.title).tag(delay)
                    }
                }
                .accessibilityIdentifier("appLockDelay")
            }
        } header: {
            Text("Lock")
        } footer: {
            Text(message ?? "Asks for Face ID, or your passcode, when you come back. The app switcher shows only a cover.")
                .accessibilityIdentifier("appLockMessage")
        }
    }

    private var toggle: Binding<Bool> {
        Binding(
            get: { model.isEnabled },
            set: { isOn in
                if isOn {
                    Task { await turnOn() }
                } else {
                    message = nil
                    model.disable()
                }
            },
        )
    }

    private var delay: Binding<AppLockDelay> {
        Binding(get: { model.delay }, set: { model.setDelay($0) })
    }

    private func turnOn() async {
        switch await model.enable() {
        case .enabled, .cancelled:
            message = nil
        case .unavailable:
            message = "This phone has no passcode set, so there's nothing to unlock with. Set one in the Settings app first."
        }
    }
}
