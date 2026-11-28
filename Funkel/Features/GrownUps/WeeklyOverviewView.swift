import SwiftUI

/// A child's last seven days for grown-ups: when, how much, how well, and what
/// to practise (mirrors web/src/ui/WeeklyOverview.tsx). Pushed from the grown-up area.
struct WeeklyOverviewView: View {
    let profile: ChildProfile

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    private var week: WeeklySummary { WeeklySummary(profile: profile) }

    /// Subject titles and icons in the child's content language, like the profile editor.
    private var language: ContentLanguage? {
        environment.content.resolvedLanguage(code: profile.learningLanguage)
    }

    private var nameText: String { profile.name }

    /// The last Denk-Tests, newest first.
    private var recentTests: [ThinkingTest.Result] {
        Array(profile.thinkingTests.reversed().prefix(6))
    }

    var body: some View {
        content(week)
            .accessibilityIdentifier("weekly")
            .navigationTitle(Text("weekly.title \(nameText)"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("grownups.done") { dismiss() }
                        .accessibilityIdentifier("weekly-done")
                }
            }
    }

    private func content(_ week: WeeklySummary) -> some View {
        List {
            Section {
                WeekDayBars(week: week)
            }

            if week.week.rounds == 0 {
                Section {
                    Text("weekly.empty")
                        .font(.funkelBody)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("weekly-empty")
                }
            } else {
                Section {
                    WeekTiles(week: week)
                }

                Section("weekly.subjects") {
                    ForEach(week.subjects) { subjectWeek in
                        WeekSubjectRow(week: subjectWeek, subject: language?.subject(id: subjectWeek.subjectID))
                    }
                }

                Section("weekly.strong") {
                    if week.strong.isEmpty {
                        Text("weekly.noSkills")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(week.strong) { skill in
                            WeekSkillRow(skill: skill, subject: language?.subject(id: skill.subjectID))
                        }
                    }
                }

                Section("weekly.practice") {
                    if week.practice.isEmpty {
                        Text("weekly.noPractice")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(week.practice) { skill in
                            WeekSkillRow(skill: skill, subject: language?.subject(id: skill.subjectID))
                        }
                    }
                }
            }

            let tests = recentTests
            if !tests.isEmpty {
                Section {
                    ForEach(Array(tests.enumerated()), id: \.offset) { _, test in
                        ThinkingTestRow(test: test)
                    }
                } header: {
                    Text("thinkingTest.history")
                } footer: {
                    Text("thinkingTest.footer")
                }
            }

            Section {
                EmptyView()
            } footer: {
                Text("weekly.footer")
            }
        }
    }
}

/// One Denk-Test: the day, points and Denk-Niveau.
private struct ThinkingTestRow: View {
    let test: ThinkingTest.Result

    private var detailText: String {
        let levelText = ProfileEditorView.formatLevelAge(test.levelAge)
        return String(localized: "thinkingTest.row \(test.points) \(test.total) \(levelText)")
    }

    var body: some View {
        HStack {
            if let date = Backup.date(fromISO: test.date) {
                Text(date, format: .dateTime.day().month(.abbreviated))
            }
            Spacer(minLength: 8)
            Text(verbatim: detailText)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .font(.funkelBody)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("weekly-test")
    }
}

/// One bar per day, oldest first, today last.
private struct WeekDayBars: View {
    let week: WeeklySummary

    private static let barHeight: CGFloat = 80

    private var most: Int { max(1, week.dayRounds.max() ?? 0) }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(week.days.indices, id: \.self) { index in
                WeekDayBar(
                    rounds: week.dayRounds[index],
                    date: week.dates[index],
                    height: Self.barHeight * CGFloat(week.dayRounds[index]) / CGFloat(most),
                    trackHeight: Self.barHeight
                )
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("weekly.daysAria \(week.week.daysLearned)"))
    }
}

private struct WeekDayBar: View {
    let rounds: Int
    let date: Date
    let height: CGFloat
    let trackHeight: CGFloat

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.12))
                RoundedRectangle(cornerRadius: 6)
                    .fill(Palette.sun)
                    .frame(height: height)
            }
            .frame(height: trackHeight)
            Text(verbatim: rounds > 0 ? String(rounds) : " ")
                .font(.caption.weight(.bold))
            Text(date, format: .dateTime.weekday(.abbreviated))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Days, rounds, questions, share right and stars, each with the week before.
private struct WeekTiles: View {
    let week: WeeklySummary

    private struct Tile: Identifiable {
        let id: String
        let label: LocalizedStringKey
        let value: String
        let before: String
    }

    private static func values(_ totals: WeeklySummary.Totals) -> [String] {
        [
            "\(totals.daysLearned)/\(WeeklySummary.weekDays)",
            String(totals.rounds),
            String(totals.questions),
            totals.questions > 0 ? "\(WeeklySummary.percent(totals.correct, of: totals.questions)) %" : "–",
            String(totals.stars),
        ]
    }

    private var tiles: [Tile] {
        let now = Self.values(week.week)
        let before = Self.values(week.previous)
        let ids = ["days", "rounds", "questions", "correct", "stars"]
        let labels: [LocalizedStringKey] = [
            "weekly.daysLabel", "weekly.roundsLabel", "weekly.questionsLabel", "weekly.correct", "weekly.starsLabel",
        ]
        return ids.indices.map { Tile(id: ids[$0], label: labels[$0], value: now[$0], before: before[$0]) }
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
            ForEach(tiles) { tile in
                WeekTile(label: tile.label, value: tile.value, beforeText: tile.before)
                    .accessibilityIdentifier("weekly-\(tile.id)")
            }
        }
        .padding(.vertical, 6)
    }
}

private struct WeekTile: View {
    let label: LocalizedStringKey
    let value: String
    let beforeText: String

    var body: some View {
        VStack(spacing: 2) {
            Text(verbatim: value)
                .font(.funkelHeadline)
            Text(label)
                .font(.funkelCaption)
            Text("weekly.before \(beforeText)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))
        .accessibilityElement(children: .combine)
    }
}

/// A subject's rounds, share right and level (and the level before, if it changed).
private struct WeekSubjectRow: View {
    let week: WeeklySummary.SubjectWeek
    let subject: SubjectDescriptor?

    /// A level change smaller than this is not shown.
    private static let levelChange = 0.25

    private var detailText: String {
        let levelText = ProfileEditorView.formatLevelAge(week.levelEnd)
        let percent = WeeklySummary.percent(week.correct, of: week.questions)
        let rounds: String = String(localized: "weekly.roundsCount \(week.rounds)")
        let correct: String = String(percent) + " % " + String(localized: "weekly.correct")
        var level: String = String(localized: "editor.level \(levelText)")
        if abs(week.levelEnd - week.levelStart) >= Self.levelChange {
            let beforeText = ProfileEditorView.formatLevelAge(week.levelStart)
            let before: String = String(localized: "weekly.levelBefore \(beforeText)")
            level += " (" + before + ")"
        }
        return [rounds, correct, level].joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label {
                Text(verbatim: subject?.title ?? week.subjectID)
                    .font(.funkelBody.weight(.bold))
            } icon: {
                if let subject {
                    SubjectIcon(subject: subject)
                        .foregroundStyle(Color(hex: subject.colorHex))
                } else {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Palette.sun)
                }
            }
            Text(verbatim: detailText)
                .font(.funkelCaption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("weekly-subject-\(week.subjectID)")
    }
}

/// A kind of question that went well or needs practice: "Addition · 100 %".
private struct WeekSkillRow: View {
    let skill: WeeklySummary.SkillWeek
    let subject: SubjectDescriptor?

    private var skillText: String {
        let name: String = String(localized: String.LocalizationValue("skill." + skill.skill))
        let percent = WeeklySummary.percent(skill.correct, of: skill.asked)
        return name + " · " + String(percent) + " %"
    }

    var body: some View {
        Label {
            Text(verbatim: skillText)
                .font(.funkelBody)
        } icon: {
            if let subject {
                SubjectIcon(subject: subject)
                    .foregroundStyle(Color(hex: subject.colorHex))
            }
        }
        .accessibilityIdentifier("weekly-skill")
    }
}
