import SwiftUI

/// Temporary root for milestone 1: shows Pip and the subjects discovered in
/// the bundled content, proving the loader works. Replaced by the profile
/// picker + home screen in milestone 2.
struct RootView: View {
    @Environment(AppEnvironment.self) private var environment

    private var language: ContentLanguage? {
        environment.content.resolvedLanguage(code: ContentLibrary.fallbackLanguageCode)
    }

    var body: some View {
        VStack(spacing: 24) {
            Pip(color: Palette.sun, mood: .happy)
                .frame(width: 140, height: 140)

            Text("app.name")
                .font(.funkelTitle)

            if let language {
                VStack(spacing: 12) {
                    ForEach(language.subjects) { subject in
                        Label(subject.title, systemImage: subject.icon)
                            .font(.funkelHeadline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .background(Color(hex: subject.colorHex), in: .rect(cornerRadius: 20))
                    }
                }
                .padding(.horizontal, 32)
            } else {
                Text("content.missing")
                    .font(.funkelBody)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background.ignoresSafeArea())
    }
}

#Preview {
    RootView()
        .environment(AppEnvironment.live())
}
