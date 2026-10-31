import SwiftUI

/// The "Spielecke": spend stars on a 2-minute game, or go to Pips Garten.
/// Mirrors web/src/ui/play/PlayCorner.tsx.
struct PlayCornerView: View {
    let profile: ChildProfile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var activeGame: GameID?
    @State private var showsGarden = false
    @State private var unlocking = false

    private let columns = [GridItem(.adaptive(minimum: 280, maximum: 420), spacing: 20)]

    var body: some View {
        let now = Date.now
        let state = profile.playState
        let ticket = state.checkTicket(now)
        let bonus = state.bonusGamesLeftToday(now)

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    CircleIconButton(systemImage: "arrow.left", label: "play.back") { dismiss() }
                        .accessibilityIdentifier("play-back")
                    Spacer()
                    StatChip(systemImage: "star.fill", value: profile.walletStars, color: Palette.sun)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text("play.wallet \(profile.walletStars)"))
                        .accessibilityIdentifier("play-wallet")
                }

                HStack(spacing: 18) {
                    Pip(color: Palette.avatarColor(profile.avatarColor), mood: .cheering)
                        .frame(width: 84, height: 84)
                        .idleBob()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("play.title")
                            .font(.funkelTitle)
                            .foregroundStyle(Palette.ink)
                        Text("play.subtitle")
                            .font(.funkelBody)
                            .foregroundStyle(.secondary)
                    }
                }

                if bonus > 0 {
                    HStack(spacing: 12) {
                        Text(verbatim: "🎁").font(.system(size: 32))
                            .accessibilityHidden(true)
                        Text("play.bonus \(bonus)")
                            .font(.funkelHeadline)
                            .foregroundStyle(Color(hex: "#2B2540"))
                        Spacer(minLength: 0)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(colors: [Color(hex: "#FFF1C7"), Color(hex: "#FFD6E8")], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: .rect(cornerRadius: Metrics.cardCorner)
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("play-bonus")
                }

                statusCard(state: state, ticket: ticket, now: now)

                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(GameID.allCases) { game in
                        PlayCard(
                            icon: game.icon,
                            title: game.title,
                            subtitle: ticket.isFree ? Text("play.startFree") : Text("play.start \(state.gameCost)"),
                            color: game.color,
                            isEnabled: ticket.isOK
                        ) {
                            start(game)
                        }
                        .accessibilityIdentifier("game-\(game.rawValue)")
                    }
                    PlayCard(icon: "🌻", title: "garden.title", subtitle: Text("play.wallet \(profile.walletStars)"), color: Color(hex: "#34C77B"), isEnabled: true) {
                        showsGarden = true
                    }
                    .accessibilityIdentifier("game-garden")
                }

                Button {
                    unlocking = true
                } label: {
                    HStack(spacing: 6) {
                        Text(verbatim: "🔓")
                        Text("play.unlock")
                    }
                    .font(.funkelCaption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PressableStyle())
                .accessibilityIdentifier("bonus-unlock")
            }
            .padding(24)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.background.ignoresSafeArea())
        .fullScreenCover(item: $activeGame) { game in
            GameFrameView(profile: profile, game: game)
        }
        .fullScreenCover(isPresented: $showsGarden) {
            GardenView(profile: profile)
        }
        .sheet(isPresented: $unlocking) {
            GrownUpGate { BonusUnlockView(profile: profile) }
        }
    }

    private func statusCard(state: PlayState, ticket: TicketCheck, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("play.ticket \(state.gameCost)")
                .font(.funkelHeadline)
                .foregroundStyle(Palette.ink)
            if let left = state.gamesLeftToday(now) {
                Text("play.left \(left)")
                    .font(.funkelBody)
                    .foregroundStyle(.secondary)
            } else {
                Text("play.unlimited")
                    .font(.funkelBody)
                    .foregroundStyle(.secondary)
            }
            switch ticket {
            case .notEnoughStars(let missing):
                Text("play.missing \(missing)")
                    .font(.funkelCaption)
                    .foregroundStyle(Color(hex: "#C2410C"))
            case .dailyLimit:
                Text("play.dailyLimit")
                    .font(.funkelCaption)
                    .foregroundStyle(Color(hex: "#C2410C"))
            default:
                EmptyView()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .funkelCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("play-status")
    }

    private func start(_ game: GameID) {
        let now = Date.now
        let state = profile.playState
        guard state.checkTicket(now).isOK else { return }
        profile.playState = state.buyingTicket(now)
        try? modelContext.save()
        activeGame = game
    }
}

extension GameID {
    var icon: String {
        switch self {
        case .memory: "🃏"
        case .balloons: "🎈"
        case .stars: "⭐"
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .memory: "game.memory"
        case .balloons: "game.balloons"
        case .stars: "game.stars"
        }
    }

    var color: Color {
        switch self {
        case .memory: Color(hex: "#8A63F2")
        case .balloons: Color(hex: "#E2558F")
        case .stars: Color(hex: "#3DA5FF")
        }
    }
}

/// A big coloured card in the play corner, styled like the subject cards at home.
private struct PlayCard: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: Text
    let color: Color
    let isEnabled: Bool
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(spacing: 18))
            layout {
                Text(verbatim: icon)
                    .font(.system(size: 38))
                    .frame(width: 72, height: 72)
                    .background(.white, in: .rect(cornerRadius: 20))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.funkelHeadline)
                    subtitle
                        .font(.funkelCaption)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(18)
            .frame(minHeight: 112)
            .funkelCard(color)
            .opacity(isEnabled ? 1 : 0.55)
        }
        .buttonStyle(PressableStyle())
        .disabled(!isEnabled)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// Grown-ups only (behind the gate): unlock 1–3 free extra games for today.
private struct BonusUnlockView: View {
    let profile: ChildProfile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Text(verbatim: "🎁")
                        .font(.system(size: 64))
                        .accessibilityHidden(true)
                    Text("play.unlock")
                        .font(.funkelTitle)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.center)
                    Text("play.unlock.message \(profile.name)")
                        .font(.funkelBody)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    ForEach(Games.bonusChoices, id: \.self) { count in
                        BigButton(title: "play.unlock.count \(count)", color: Color(hex: "#8A63F2")) {
                            profile.playState = profile.playState.grantingBonusGames(count, now: .now)
                            try? modelContext.save()
                            dismiss()
                        }
                        .accessibilityIdentifier("bonus-\(count)")
                    }
                    Text("play.unlock.footer")
                        .font(.funkelCaption)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("editor.cancel") { dismiss() }
                }
            }
        }
    }
}
