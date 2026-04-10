import SwiftUI

struct UserResultRow: View {
    let user: AppUser

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Circle()
                .fill(avatarColor(for: user.displayName))
                .frame(width: 40, height: 40)
                .overlay {
                    Text(String(user.displayName.prefix(1)).uppercased())
                        .font(.plurBodyBold(16))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.plurBodyBold(14))
                    .foregroundStyle(Color.plurGhost)
                Text("@\(user.username)")
                    .font(.plurCaption())
                    .foregroundStyle(Color.plurMuted)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.plurFaint)
        }
        .padding(.vertical, Spacing.xs)
        .padding(.horizontal, Spacing.md)
    }

    private func avatarColor(for name: String) -> Color {
        let colors: [Color] = [.plurViolet, .plurRose, .plurTeal, .plurAmber]
        let hash = name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return colors[abs(hash) % colors.count]
    }
}
