import SwiftUI

struct ActivePolicyCard: View {
    let name: String
    let policy: ActivePolicy
    let isPaused: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: isPaused ? "pause.circle.fill" : "shield.lefthalf.filled")
                    .font(.title3)
                    .foregroundStyle(.indigo)
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.headline)
                    Text(policy.mode.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 12) {
                Label(isPaused ? "Focus paused" : policy.origin == .focus ? "iOS Focus" : "Manual",
                      systemImage: policy.origin == .focus ? "moon.fill" : "hand.tap")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(isPaused ? "iOS Focus restrictions are paused" : policy.origin == .focus ? "Activated by iOS Focus" : "Activated by you")
                Spacer(minLength: 0)
                Button(action: action) {
                    Text(isPaused ? "Continue restrictions" : policy.origin == .focus ? "Pause restrictions" : "Stop restrictions")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 44)
                        .background(.indigo, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }
}
