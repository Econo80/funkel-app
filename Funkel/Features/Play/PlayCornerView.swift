import SwiftUI

/// The "Spielecke": spend stars on short games, or go to Pips Garten
/// (placeholder until the Swift port of web/src/ui/play/PlayCorner.tsx lands).
struct PlayCornerView: View {
    let profile: ChildProfile
    @Environment(\.dismiss) private var dismiss
    @State private var showsGarden = false

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                CircleIconButton(systemImage: "arrow.left", label: "play.back") { dismiss() }
                    .accessibilityIdentifier("play-back")
                Spacer()
            }
            Text("play.title")
                .font(.funkelTitle)
            Text("port.comingSoon")
                .font(.funkelBody)
                .foregroundStyle(.secondary)
            Button {
                showsGarden = true
            } label: {
                Label("garden.title", systemImage: "leaf.fill")
                    .font(.funkelHeadline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(Color(hex: "#34C77B"), in: .capsule)
            }
            .buttonStyle(PressableStyle())
            .accessibilityIdentifier("game-garden")
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background.ignoresSafeArea())
        .fullScreenCover(isPresented: $showsGarden) {
            GardenView(profile: profile)
        }
    }
}
