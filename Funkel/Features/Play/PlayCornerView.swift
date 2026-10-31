import SwiftData
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
                header
                hero

                if bonus > 0 {
                    HStack(spacing: 10) {
                        Text(verbatim: "🎁").accessibilityHidden(true)
                        Text("play.bonus \(bonus)")
                    }
                    .font(.funkelHeadline)
                    .foregroundStyle(Color(hex: "#2B2540"))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(colors: [Color(hex: "#FFF1C7"), Color(hex: "#FFE08A")], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: .rect(cornerRadius: Metrics.cardCorner)
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("play-bonus")
                }

                status(state, ticket: ticket, now: now)

                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(GameID.allCases) { game in
                        PlayCard(
                            icon: game.icon,
                            title: game.title,
                            subtitle: ticket.isFree ? Text("play.startFree") : Text("play.start \(state.gameCost)"),
                            color: game.color
                        ) {
                            start(game)
                        }
                        .disabled(!ticket.isOK)
                        .opacity(ticket.isOK ? 1 : 0.55)
                        .accessibilityIdentifier("game-\(game.rawValue)")
                    }
                    PlayCard(icon: "🌻", title: "garden.title", subtitle: Text("play.wallet \(profile.walletStars)"), color: Color(hex: "#34C77B")) {
                        showsGarden = true
                    }
                    .accessibilityIdentifier("game-garden")
                }

                Button {
                    unlocking = true
                } label: {
                    Text(verbatim: "🔓 ") + Text("play.unlock")
                }
                .font(.funkelCaption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .accessibilityIdentifier("bonus-unlock")
            }
            .padding(24)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.background.ignoresSafeArea())
        .fullScreenCover(item: $activeGame) { game in
            GameFrame(profile: profile, game: game) { controls in
                let age = profile.playState.gameAge
                switch game {
                case .memory: MemoryGameView(age: age, controls: controls)
                case .balloons: BalloonPopView(age: age, controls: controls)
                case .stars: StarCatcherView(age: age, color: Palette.avatarColor(profile.avatarColor), controls: controls)
                }
            }
        }
        .fullScreenCover(isPresented: $showsGarden) {
            GardenView(profile: profile)
        }
        .sheet(isPresented: $unlocking) {
            GrownUpGate {
                BonusUnlockSheet(name: profile.name) { count in
                    profile.playState = profile.playState.grantingBonusGames(count, now: .now)
                    try? modelContext.save()
                    unlocking = false
                }
            }
        }
    }

    private var header: some View {
        HStack {
            CircleIconButton(systemImage: "arrow.left", label: "play.back") { dismiss() }
                .accessibilityIdentifier("play-back")
            Spacer()
            StatChip(systemImage: "star.fill", value: profile.walletStars, color: Palette.sun)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("play.wallet \(profile.walletStars)"))
                .accessibilityIdentifier("play-wallet")
        }
    }

    private var hero: some View {
        HStack(spacing: 16) {
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
    }

    private func status(_ state: PlayState, ticket: TicketCheck, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("play.ticket \(state.gameCost)")
                .font(.funkelHeadline)
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
                    .padding(.top, 6)
            case .dailyLimit:
                Text("play.dailyLimit")
                    .font(.funkelCaption)
                    .padding(.top, 6)
            case .ok, .disabled:
                EmptyView()
            }
        }
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .funkelCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("play-status")
    }

    /// Spends the ticket first, so leaving mid-game doesn't give it back.
    private func start(_ game: GameID) {
        let state = profile.playState
        guard state.checkTicket(.now).isOK else { return }
        profile.playState = state.buyingTicket(.now)
        try? modelContext.save()
        activeGame = game
    }
}

/// A big coloured card for a game, like the subject cards on the home screen.
private struct PlayCard: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: Text
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(verbatim: icon)
                    .font(.system(size: 38))
                    .frame(width: 72, height: 72)
                    .background(.white, in: .rect(cornerRadius: 20))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.funkelHeadline)
                    subtitle
                        .font(.funkelBody)
                        .opacity(0.9)
                }
                .foregroundStyle(.white)
                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .funkelCard(color)
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// Behind the grown-up gate: unlock 1–3 free games for today.
private struct BonusUnlockSheet: View {
    let name: String
    let onGrant: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Button("editor.cancel") { dismiss() }
                        .font(.funkelBody)
                    Spacer()
                }
                Text(verbatim: "🎁")
                    .font(.system(size: 64))
                    .accessibilityHidden(true)
                Text("play.unlock")
                    .font(.funkelTitle)
                    .multilineTextAlignment(.center)
                Text("play.unlock.message \(name)")
                    .font(.funkelBody)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                ForEach(Games.bonusChoices, id: \.self) { count in
                    BigButton(title: "play.unlock.count \(count)", color: Color(hex: "#8A63F2")) { onGrant(count) }
                        .accessibilityIdentifier("bonus-\(count)")
                }
                Text("play.unlock.footer")
                    .font(.funkelCaption)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(Palette.ink)
            .padding(24)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.background.ignoresSafeArea())
    }
}
