import SwiftUI

struct SyncBadge: View {
    let provider: SyncProvider

    var body: some View {
        Text(provider.badgeTitle)
        .font(.caption2.weight(.semibold))
        .foregroundColor(AppTheme.accentMint)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(AppTheme.accentMint.opacity(0.16))
        .clipShape(Capsule())
    }
}
