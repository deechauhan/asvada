import DesignSystem
import Storage
import SwiftData
import SwiftUI

/// First launch, a wow in under a minute: welcome, stamp your passport, see the spread (and share
/// it), then savour one thing you loved. Every step can be skipped.
public struct OnboardingFlow: View {
    enum Step: Int {
        case welcome
        case stamp
        case passport
        case firstKeepsake
    }

    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = Step.welcome
    @State private var stamped: Set<String> = []
    let onFinish: () -> Void

    public init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    public var body: some View {
        ZStack {
            content
                .id(step)
                .transition(Motion.landing(reduceMotion: reduceMotion))
        }
        .overlay(alignment: .topTrailing) {
            Button("Skip", action: skip)
                .typeToken(.callout)
                .foregroundStyle(step == .welcome ? Palette.onAubergine.color : Palette.textSecondary.color)
                .padding(Spacing.large)
                .accessibilityIdentifier("onboardingSkip")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            WelcomeStep(onBegin: advance)
        case .stamp:
            StampStep(stamped: $stamped, onContinue: advance)
        case .passport:
            PassportStep(stamped: stamped, onContinue: advance)
        case .firstKeepsake:
            FirstKeepsakeStep(onDone: finish)
        }
    }

    /// Moves on; leaving the stamp step saves the countries.
    private func advance() {
        if step == .stamp {
            saveStamps()
        }
        guard let next = Step(rawValue: step.rawValue + 1) else {
            finish()
            return
        }
        withAnimation(Motion.animation(Motion.settle, reduceMotion: reduceMotion)) { step = next }
    }

    /// Skip goes to the next step; skipping the last finishes.
    private func skip() {
        if step == .firstKeepsake {
            finish()
        } else {
            advance()
        }
    }

    private func saveStamps() {
        do {
            try OnboardingStore.stamp(stamped, in: Repository(context: context))
        } catch {
            assertionFailure("Saving stamped countries failed: \(error)")
        }
    }

    private func finish() {
        onFinish()
    }
}

/// Aubergine, the ā landing with a thunk, the tagline and Begin.
private struct WelcomeStep: View {
    @State private var landed = false
    let onBegin: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            AMark(size: 120)
                .thunk(trigger: landed)
                .onAppear { landed = true }
            Text("Savour what you've lived.")
                .typeToken(.voice)
                .foregroundStyle(Palette.onAubergine.color)
            Spacer()
            Button(action: onBegin) {
                Text("Begin")
                    .typeToken(.headline)
                    .frame(maxWidth: 280)
                    .padding(.vertical, Spacing.small)
            }
            .buttonStyle(.borderedProminent)
            .tint(Palette.saffron.color)
            .foregroundStyle(Palette.onSaffron.color)
            .accessibilityIdentifier("onboardingBegin")
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Palette.aubergineTop.color, Palette.aubergineBottom.color],
                startPoint: .top,
                endPoint: .bottom,
            )
            .ignoresSafeArea(),
        )
    }
}

/// A step's serif heading and its continue button, on paper.
struct OnboardingPage<Content: View>: View {
    let title: String
    let action: String
    let onContinue: () -> Void
    let content: Content

    init(title: String, action: String = "Continue", onContinue: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.title = title
        self.action = action
        self.onContinue = onContinue
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            Text(title)
                .typeToken(.display)
                .foregroundStyle(Palette.textPrimary.color)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, Spacing.xxl)
            content
            Button(action: onContinue) {
                Text(action)
                    .typeToken(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.small)
            }
            .buttonStyle(.borderedProminent)
            .tint(Palette.brand.color)
            .accessibilityIdentifier("onboardingContinue")
        }
        .padding(.horizontal, Spacing.large)
        .padding(.bottom, Spacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.background.color.ignoresSafeArea())
    }
}
