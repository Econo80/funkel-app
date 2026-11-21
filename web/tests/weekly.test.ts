import { describe, expect, it } from "vitest";
import { createProfile, defaultSettings, recordRound, type RoundRecord } from "../src/domain/profile";
import { skillTally, weekSummary } from "../src/domain/weekly";

const at = (d: number, h = 10) => new Date(2026, 10, d, h);
const round = (d: number, subjectId: string, correct: number, total: number, extra: Partial<RoundRecord> = {}): RoundRecord => ({
  date: at(d).toISOString(), subjectId, languageCode: "de", correct, total, starsEarned: correct, effectiveAge: 8, ...extra,
});

describe("weekly overview", () => {
  it("counts the last seven days, today included, next to the seven before", () => {
    const rounds = [
      round(5, "maths", 5, 10),                          // two weeks ago: not counted
      round(10, "maths", 8, 10),                         // the week before
      round(15, "maths", 9, 10, { effectiveAge: 8 }),
      round(15, "maths", 10, 10, { effectiveAge: 8.5 }),
      round(17, "generalKnowledge", 6, 10),
      round(21, "maths", 7, 10, { effectiveAge: 9 }),    // today
    ];
    const w = weekSummary({ rounds }, at(21, 18));
    expect(w.days[0]).toBe("2026-11-15");
    expect(w.days[6]).toBe("2026-11-21");
    expect(w.dayRounds).toEqual([2, 0, 1, 0, 0, 0, 1]);
    expect(w.week).toEqual({ daysLearned: 3, rounds: 4, questions: 40, correct: 32, stars: 32 });
    expect(w.previous).toEqual({ daysLearned: 1, rounds: 1, questions: 10, correct: 8, stars: 8 });
    expect(w.subjects[0]).toMatchObject({ subjectId: "maths", rounds: 3, questions: 30, correct: 26, levelStart: 8, levelEnd: 9 });
    expect(w.subjects[1]).toMatchObject({ subjectId: "generalKnowledge", rounds: 1 });
  });

  it("names what went well and what to practise, once there are enough answers", () => {
    const rounds = [
      round(20, "maths", 8, 10, { skills: { addition: [5, 5], division: [1, 4], subtraction: [1, 1] } }),
      round(21, "generalKnowledge", 9, 10, { skills: { animals: [4, 4], history: [2, 3] } }),
      round(21, "generalKnowledge", 9, 10, { skills: { history: [1, 2] } }),
      round(21, "vocabulary", 10, 10), // older rounds without skills still count in the totals
    ];
    const w = weekSummary({ rounds }, at(21, 18));
    expect(w.strong.map((s) => s.skill)).toEqual(["addition", "animals"]);
    expect(w.practice.map((s) => [s.skill, s.correct, s.asked])).toEqual([["division", 1, 4], ["history", 3, 5]]);
    expect(w.week.rounds).toBe(4);
  });

  it("is empty for a child who hasn't learned this week", () => {
    const w = weekSummary({ rounds: [round(1, "maths", 5, 10)] }, at(21));
    expect(w.week.rounds).toBe(0);
    expect(w.dayRounds.every((n) => n === 0)).toBe(true);
    expect(w.strong).toEqual([]);
  });

  it("tallies a round's answers per kind of question and keeps them in the history", () => {
    expect(skillTally(["addition", "addition", undefined, "division"], [true, false, true, true]))
      .toEqual({ addition: [1, 2], division: [1, 1] });
    const p = createProfile({ ...defaultSettings(), name: "Emil", age: 7 }, at(21));
    const { profile } = recordRound(p, {
      subjectId: "maths", languageCode: "de", correct: 2, total: 3, correctContentIds: [], effectiveAge: 7,
      skills: { addition: [2, 3] },
    }, at(21));
    expect(profile.rounds[0].skills).toEqual({ addition: [2, 3] });
    const plain = recordRound(p, { subjectId: "maths", languageCode: "de", correct: 1, total: 1, correctContentIds: [], effectiveAge: 7 }, at(21));
    expect(plain.profile.rounds[0].skills).toBeUndefined();
  });
});
