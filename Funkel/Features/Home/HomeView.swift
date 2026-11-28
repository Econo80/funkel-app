import SwiftUI

/// The child's home: a compact header with greeting, streak and stars, and a tile
/// for each subject and game below it, all on one screen (web/src/ui/Home.tsx).
/// The page only scrolls when it can't fit: with a gift card or very large text.
struct HomeView: View {
    let profile: ChildProfile
    let language: ContentLanguage
    let onSwitchProfile: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var activeSubject: SubjectDescriptor?
    /// The Denken subject while its weekly Denk-Test runs.
    @State private var testSubject: SubjectDescriptor?
    @State private var showsGrownUps = false
    @State private var activeExtra: HomeExtra?

    private static let spacing: CGFloat = 12

    private var subjects: [SubjectDescriptor] {
        language.subjects.filter { $0.isTopic ? $0.id == profile.schoolTopic : profile.isSubjectEnabled($0.id) }
    }

    /// The Denken subject, when it is on the home screen: its Denk-Test card comes after the subjects.
    private var thinkingSubject: SubjectDescriptor? {
        subjects.first { $0.provider == .logic }
    }

    private var tileCount: Int {
        subjects.count + (thinkingSubject != nil ? 1 : 0) + (profile.sudokuEnabled ? 1 : 0) + (profile.gamesEnabled ? 1 : 0)
    }

    /// A gift card or very large text needs more room than one screen: then the page scrolls.
    private var scrollsWholePage: Bool {
        profile.giftStars > 0 || dynamicTypeSize.isAccessibilitySize
    }

    private var testSubtitle: Text {
        let tests = profile.thinkingTests
        if ThinkingTest.canTakeTest(tests) { return Text("thinkingTest.ready") }
        let daysLeft = ThinkingTest.daysUntilTest(tests)
        return Text("thinkingTest.nextIn \(daysLeft)")
    }

    private var sudokuSubtitle: Text {
        let solved = profile.sudokusSolved
        return solved > 0 ? Text("sudoku.count \(solved)") : Text("sudoku.start")
    }

    private var streak: Int {
        StreakCalculator.displayedStreak(current: profile.currentStreak, lastPlayedDay: profile.lastPlayedDay, now: .now)
    }

    /// 2 columns on small phones, 3 on phones and portrait tablets, 4 on wide screens in landscape.
    static func columnCount(for size: CGSize) -> Int {
        if size.width < 340 { return 2 }
        if size.width >= 900 && size.width > size.height { return 4 }
        return 3
    }

    var body: some View {
        GeometryReader { geometry in
            let columns = Self.columnCount(for: geometry.size)
            Group {
                if scrollsWholePage {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Self.spacing) {
                            header
                            if profile.giftStars > 0 {
                                GiftCard(stars: profile.giftStars) {
                                    profile.giftStars = 0
                                    try? modelContext.save()
                                }
                            }
                            tileGrid(columns: columns, metrics: .scrolling)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 16)
                        .frame(maxWidth: 1100)
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    VStack(alignment: .leading, spacing: Self.spacing) {
                        header
                        // The tiles share what is left below the header.
                        GeometryReader { area in
                            let rows = max(1, (tileCount + columns - 1) / columns)
                            let fitted = (area.size.height - Self.spacing * CGFloat(rows - 1)) / CGFloat(rows)
                            let height = max(HomeTileMetrics.minHeight, fitted)
                            let width = (area.size.width - Self.spacing * CGFloat(columns - 1)) / CGFloat(columns)
                            let icon = min(76, max(40, min(height * 0.42, width * 0.45)))
                            // Only scrolls when even the smallest rows don't fit (a very short window).
                            ScrollView {
                                tileGrid(columns: columns, metrics: HomeTileMetrics(height: height, iconSize: icon))
                            }
                            .scrollDisabled(fitted >= HomeTileMetrics.minHeight)
                            // Fitting tiles keep their shadows at the bottom edge.
                            .scrollClipDisabled(fitted >= HomeTileMetrics.minHeight)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                    .frame(maxWidth: 1100)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .background(Palette.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(item: $activeSubject) { subject in
            RoundContainerView(subject: subject, profile: profile)
        }
        .fullScreenCover(item: $testSubject) { subject in
            RoundContainerView(subject: subject, profile: profile, isTest: true)
        }
        .fullScreenCover(item: $activeExtra) { extra in
            switch extra {
            case .sudoku: SudokuView(profile: profile)
            case .playCorner: PlayCornerView(profile: profile)
            }
        }
        .sheet(isPresented: $showsGrownUps) {
            GrownUpGate { GrownUpsView() }
        }
    }

    private func tileGrid(columns: Int, metrics: HomeTileMetrics) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Self.spacing), count: columns), spacing: Self.spacing) {
            ForEach(subjects) { subject in
                SubjectCard(
                    subject: subject,
                    progress: profile.subjectProgress(for: subject.id, language: subject.languageCode),
                    isAvailable: QuestionProviderFactory.isAvailable(subject.provider),
                    metrics: metrics
                ) {
                    activeSubject = subject
                }
            }
            if let thinkingSubject {
                let ready = ThinkingTest.canTakeTest(profile.thinkingTests)
                HomeExtraCard(title: "thinkingTest.title", subtitle: testSubtitle, systemImage: "flask.fill", color: Color(hex: thinkingSubject.colorHex), metrics: metrics) {
                    testSubject = thinkingSubject
                }
                .disabled(!ready)
                .opacity(ready ? 1 : 0.6)
                .accessibilityIdentifier("thinking-test")
            }
            if profile.sudokuEnabled {
                HomeExtraCard(title: "sudoku.title", subtitle: sudokuSubtitle, systemImage: "puzzlepiece.fill", color: SudokuView.color, metrics: metrics) {
                    activeExtra = .sudoku
                }
                .accessibilityIdentifier("sudoku")
            }
            if profile.gamesEnabled {
                HomeExtraCard(title: "play.title", subtitle: Text("play.wallet \(profile.walletStars)"), systemImage: "gamecontroller.fill", color: Color(hex: "#E2558F"), metrics: metrics) {
                    activeExtra = .playCorner
                }
                .accessibilityIdentifier("play-corner")
            }
        }
    }

    /// One compact line: Pip, the greeting, streak and stars, and the two buttons;
    /// on narrow screens the chips go on a second line.
    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                pip
                hello
                Spacer(minLength: 0)
                HStack(spacing: 8) { statChips }
                headerButtons
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    pip
                    hello
                    Spacer(minLength: 0)
                    headerButtons
                }
                // Side by side, or stacked when large text doesn't fit.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { statChips }
                    VStack(alignment: .leading, spacing: 8) { statChips }
                }
            }
        }
    }
}

private extension HomeView {
    var pip: some View {
        Pip(color: Palette.avatarColor(profile.avatarColor), mood: .happy)
            .frame(width: 56, height: 56)
            .idleBob()
    }

    var hello: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("home.greeting \(profile.name)")
                .font(.system(.title, design: .rounded).weight(.heavy))
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text("home.subtitle")
                .font(.funkelBody)
                .foregroundStyle(.secondary)
        }
        .layoutPriority(1)
    }

    var headerButtons: some View {
        HStack(spacing: 8) {
            CircleIconButton(systemImage: "gearshape.fill", label: "grownups.button") {
                showsGrownUps = true
            }
            .accessibilityIdentifier("grown-ups")
            CircleIconButton(systemImage: "person.2.fill", label: "home.switchProfile", action: onSwitchProfile)
                .accessibilityIdentifier("switch-profile")
        }
    }

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
    let metrics: HomeTileMetrics
    let action: () -> Void

    private var color: Color { Color(hex: subject.colorHex) }

    private var subtitle: Text {
        if !isAvailable { return Text("home.subject.comingSoon") }
        if let progress, progress.roundsPlayed > 0 { return Text("home.subject.rounds \(progress.roundsPlayed)") }
        return Text("home.subject.start")
    }

    /// The ring shows how many answers were right, once there are some.
    private var accuracy: Double? {
        guard isAvailable, let progress, progress.questionsAnswered > 0 else { return nil }
        return progress.accuracy
    }

    var body: some View {
        Button(action: action) {
            HomeTile(metrics: metrics, color: color, progress: accuracy, title: Text(subject.title), subtitle: subtitle) {
                SubjectIcon(subject: subject)
            }
            .opacity(isAvailable ? 1 : 0.55)
        }
        .buttonStyle(PressableStyle())
        .disabled(!isAvailable)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("subject-\(subject.id)")
    }
}
