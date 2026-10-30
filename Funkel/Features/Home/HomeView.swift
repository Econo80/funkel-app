import SwiftUI

/// The child's home: greeting, streak and stars, one big card per subject.
struct HomeView: View {
    let profile: ChildProfile
    let language: ContentLanguage
    let onSwitchProfile: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var activeSubject: SubjectDescriptor?
    @State private var showsGrownUps = false

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
                if profile.giftStars > 0 {
                    GiftCard(stars: profile.giftStars) {
                        profile.giftStars = 0
                        try? modelContext.save()
                    }
                }
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
        .sheet(isPresented: $showsGrownUps) {
            GrownUpGate { GrownUpsView() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Pip(color: Palette.avatarColor(profile.avatarColor), mood: .happy)
                    .frame(width: 84, height: 84)
                    .idleBob()
                Spacer()
                CircleIconButton(systemImage: "gearshape.fill", label: "grownups.button") {
                    showsGrownUps = true
                }
                .accessibilityIdentifier("grown-ups")
                CircleIconButton(systemImage: "person.2.fill", label: "home.switchProfile", action: onSwitchProfile)
                    .accessibilityIdentifier("switch-profile")
            }

            Text("home.greeting \(profile.name)")
                .font(.funkelTitle)
                .foregroundStyle(Palette.ink)
            Text("home.subtitle")
                .font(.funkelBody)
                .foregroundStyle(.secondary)

            // Side by side, or stacked when large text doesn't fit.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { statChips }
                VStack(alignment: .leading, spacing: 10) { statChips }
            }
        }
    }
}

private extension HomeView {
    @ViewBuilder
    var statChips: some View {
        StatChip(systemImage: "flame.fill", value: streak, color: .orange)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("home.streak \(streak)"))
        StatChip(systemImage: "star.fill", value: profile.totalStars, color: Palette.sun)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("home.stars \(profile.totalStars)"))
    }
}

/// "Ein Geschenk für dich!" – stars a grown-up gave, shown once until the child says thanks.
private struct GiftCard: View {
    let stars: Int
    let onThanks: () -> Void

    @State private var celebration = 0

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) { content }
            VStack(alignment: .leading, spacing: 14) { content }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color(hex: "#FFF1C7"), Color(hex: "#FFD6E8")], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: .rect(cornerRadius: 28)
        )
        .overlay { ConfettiBurst(trigger: celebration, count: 50).allowsHitTesting(false) }
        .onAppear { celebration += 1 }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("gift-card")
    }

    @ViewBuilder
    private var content: some View {
        Image(systemName: "gift.fill")
            .font(.system(size: 44, weight: .bold))
            .foregroundStyle(Color(hex: "#E2558F"))
            .symbolEffect(.bounce, value: celebration)
        VStack(alignment: .leading, spacing: 2) {
            Text("home.gift.title")
                .font(.funkelHeadline)
            Text("home.gift \(stars)")
                .font(.funkelBody)
        }
        // The card is always light, so its text stays dark in dark mode too.
        .foregroundStyle(Color(hex: "#2B2540"))
        Spacer(minLength: 0)
        Button(action: onThanks) {
            Text("home.gift.thanks")
                .font(.funkelHeadline)
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .foregroundStyle(.white)
                .background(Color(hex: "#E2558F"), in: .capsule)
        }
        .buttonStyle(PressableStyle())
        .accessibilityIdentifier("gift-thanks")
    }
}

private struct SubjectCard: View {
    let subject: SubjectDescriptor
    let progress: SubjectProgress?
    let isAvailable: Bool
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var color: Color { Color(hex: subject.colorHex) }

    var body: some View {
        Button(action: action) {
            // Large text: icon above the title, so the title gets the full width.
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(spacing: 18))
            layout {
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

                if isAvailable, let progress, progress.questionsAnswered > 0, !dynamicTypeSize.isAccessibilitySize {
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
