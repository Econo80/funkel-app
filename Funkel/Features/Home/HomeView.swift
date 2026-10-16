import SwiftUI

/// The child's home: greeting, streak and stars, one big card per subject.
struct HomeView: View {
    let profile: ChildProfile
    let language: ContentLanguage
    let onSwitchProfile: () -> Void

    @State private var activeSubject: SubjectDescriptor?

    private let columns = [GridItem(.adaptive(minimum: 280, maximum: 420), spacing: 20)]

    private var subjects: [SubjectDescriptor] {
        language.subjects.filter { profile.isSubjectEnabled($0.id) }
    }

    private var streak: Int {
        StreakCalculator.displayedStreak(current: profile.currentStreak, lastPlayedDay: profile.lastPlayedDay, now: .now)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(subjects) { subject in
                        SubjectCard(
                            subject: subject,
                            progress: profile.subjectProgress(for: subject.id, language: subject.languageCode),
                            isAvailable: QuestionProviderFactory.isAvailable(subject.provider)
                        ) {
                            activeSubject = subject
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(item: $activeSubject) { subject in
            RoundContainerView(subject: subject, profile: profile)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Pip(color: Palette.avatarColor(profile.avatarColor), mood: .happy)
                    .frame(width: 84, height: 84)
                Spacer()
                CircleIconButton(systemImage: "person.2.fill", label: "home.switchProfile", action: onSwitchProfile)
                    .accessibilityIdentifier("switch-profile")
            }

            Text("home.greeting \(profile.name)")
                .font(.funkelTitle)
                .foregroundStyle(Palette.ink)
            Text("home.subtitle")
                .font(.funkelBody)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                StatChip(systemImage: "flame.fill", value: streak, color: .orange)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("home.streak \(streak)"))
                StatChip(systemImage: "star.fill", value: profile.totalStars, color: Palette.sun)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("home.stars \(profile.totalStars)"))
            }
        }
    }
}

private struct SubjectCard: View {
    let subject: SubjectDescriptor
    let progress: SubjectProgress?
    let isAvailable: Bool
    let action: () -> Void

    private var color: Color { Color(hex: subject.colorHex) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 18) {
                Image(systemName: subject.icon)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 72, height: 72)
                    .background(.white, in: .rect(cornerRadius: 20))

                VStack(alignment: .leading, spacing: 4) {
                    Text(subject.title)
                        .font(.funkelHeadline)
                    if !isAvailable {
                        Text("home.subject.comingSoon")
                            .font(.funkelCaption)
                    } else if let progress, progress.roundsPlayed > 0 {
                        Text("home.subject.rounds \(progress.roundsPlayed)")
                            .font(.funkelCaption)
                    } else {
                        Text("home.subject.start")
                            .font(.funkelCaption)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

                if isAvailable, let progress, progress.questionsAnswered > 0 {
                    ProgressRing(progress: progress.accuracy)
                        .frame(width: 40, height: 40)
                        .accessibilityHidden(true)
                }
            }
            .padding(18)
            .frame(minHeight: 112)
            .funkelCard(color)
            .opacity(isAvailable ? 1 : 0.55)
        }
        .buttonStyle(PressableStyle())
        .disabled(!isAvailable)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("subject-\(subject.id)")
    }
}
