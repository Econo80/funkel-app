import Foundation

/// The play corner's fields, stored like the web app does (web field names
/// and shapes in `backupExtras`; the wallet is a native field).
extension ChildProfile {
    enum PlayField {
        static let gamesEnabled = "gamesEnabled"
        static let gameCost = "gameCost"
        static let gamesPerDay = "gamesPerDay"
        static let gameDifficulty = "gameDifficulty"
        static let gameDay = "gameDay"
        static let gamesToday = "gamesToday"
        static let bonusGames = "bonusGames"
        static let bonusDay = "bonusDay"
    }

    /// Missing fields fall back to the web app's defaults. Setting it writes
    /// everything back; remember to save the model context.
    var playState: PlayState {
        get {
            PlayState(
                age: age,
                walletStars: walletStars,
                gamesEnabled: webField(PlayField.gamesEnabled) ?? true,
                gameCost: webField(PlayField.gameCost) ?? 10,
                gamesPerDay: webField(PlayField.gamesPerDay) ?? 3,
                gameDifficulty: webField(PlayField.gameDifficulty, as: GameDifficulty.self) ?? .normal,
                gameDay: webField(PlayField.gameDay),
                gamesToday: webField(PlayField.gamesToday) ?? 0,
                bonusGames: webField(PlayField.bonusGames) ?? 0,
                bonusDay: webField(PlayField.bonusDay)
            )
        }
        set {
            walletStars = newValue.walletStars
            setGameSettings(enabled: newValue.gamesEnabled, cost: newValue.gameCost, perDay: newValue.gamesPerDay, difficulty: newValue.gameDifficulty)
            setWebField(PlayField.gameDay, newValue.gameDay)
            setWebField(PlayField.gamesToday, newValue.gamesToday)
            setWebField(PlayField.bonusGames, newValue.bonusGames)
            setWebField(PlayField.bonusDay, newValue.bonusDay)
        }
    }

    var gamesEnabled: Bool { webField(PlayField.gamesEnabled) ?? true }

    /// The grown-up's settings, clamped like the web app does.
    func setGameSettings(enabled: Bool, cost: Int, perDay: Int, difficulty: GameDifficulty) {
        setWebField(PlayField.gamesEnabled, enabled)
        setWebField(PlayField.gameCost, cost.clamped(to: Games.costRange))
        setWebField(PlayField.gamesPerDay, perDay.clamped(to: Games.perDayRange))
        setWebField(PlayField.gameDifficulty, difficulty.rawValue)
    }
}
