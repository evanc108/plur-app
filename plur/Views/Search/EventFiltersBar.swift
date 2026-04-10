import SwiftUI

struct EventFiltersBar: View {
    var selectedLocation: EDMTrainLocation?
    @Binding var festivalOnly: Bool
    var onLocationTap: () -> Void
    var onChanged: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                // Location chip
                filterChip(
                    label: selectedLocation?.displayName ?? "Location",
                    icon: "mappin",
                    isActive: selectedLocation != nil
                ) {
                    onLocationTap()
                }

                // Festival toggle
                filterChip(
                    label: "Festivals",
                    icon: "sparkles",
                    isActive: festivalOnly
                ) {
                    festivalOnly.toggle()
                    onChanged()
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.xs)
        }
    }

    private func filterChip(
        label: String,
        icon: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.plurMicro())
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(
                Capsule()
                    .fill(isActive ? Color.plurViolet.opacity(0.2) : Color.plurGlass)
            )
            .overlay(
                Capsule()
                    .stroke(isActive ? Color.plurViolet.opacity(0.4) : Color.plurBorder, lineWidth: 1)
            )
            .foregroundStyle(isActive ? Color.plurViolet : Color.plurMuted)
        }
        .buttonStyle(.plain)
    }
}
