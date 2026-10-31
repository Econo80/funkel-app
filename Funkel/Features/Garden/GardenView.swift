import SwiftUI

/// Pips Garten / the farm, full screen (placeholder until the Swift port of
/// web/src/ui/play/Garden.tsx lands).
struct GardenView: View {
    let profile: ChildProfile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                CircleIconButton(systemImage: "arrow.left", label: "play.back") { dismiss() }
                    .accessibilityIdentifier("garden-back")
                Spacer()
            }
            Spacer()
            Image(systemName: "leaf.fill")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(Color(hex: "#34C77B"))
            Text("garden.title")
                .font(.funkelTitle)
            Text("port.comingSoon")
                .font(.funkelBody)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background.ignoresSafeArea())
    }
}
