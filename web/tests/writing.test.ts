import { describe, expect, it } from "vitest";
import { difficultyForAge } from "../src/domain/difficulty";
import { makeQuestion, onlyCaseDiffers, writtenMatches, type Question } from "../src/domain/question";
import { seededRng } from "../src/domain/random";
import * as R from "../src/domain/round";
import { germanProvider } from "./helpers";

const writeQuestion = (answer: string, caseSensitive: boolean, showLength = false): Question =>
  makeQuestion({ subjectId: "vocabulary", prompt: "", format: { kind: "writeText", answer, caseSensitive, showLength } });

const type = (s: R.RoundState, text: string) => [...text].reduce((acc, ch) => R.typeText(acc, ch), s);

describe("writing answers", () => {
  it("ignores spaces and punctuation, and accepts ss for ß", () => {
    expect(writtenMatches("der hund bellt", "Der Hund bellt.", false)).toBe(true);
    expect(writtenMatches("  Der  Hund bellt ", "Der Hund bellt.", true)).toBe(true);
    expect(writtenMatches("gross", "groß", true)).toBe(true);
    expect(writtenMatches("Fußball", "Fussball", true)).toBe(true);
    expect(writtenMatches("Der Hund belt.", "Der Hund bellt.", false)).toBe(false);
  });

  it("counts capitals only when asked, with a gentle hint", () => {
    expect(writtenMatches("der hund bellt", "Der Hund bellt.", true)).toBe(false);
    expect(onlyCaseDiffers("der hund bellt", "Der Hund bellt.")).toBe(true);
    expect(onlyCaseDiffers("Der Hund belt", "Der Hund bellt.")).toBe(false);
  });

  it("types with shift for one capital, deletes, and checks", () => {
    let s = R.startRound([writeQuestion("Hund", true)], false);
    s = R.toggleShift(s);
    s = type(s, "hund");
    expect(s.textInput).toBe("Hund");
    expect(s.shift).toBe(false);
    s = R.deleteText(s);
    s = type(s, "t");
    expect(R.submitText(s).phase).toBe("wrong");
    s = type(R.deleteText(s), "d");
    expect(R.submitText(s).phase).toBe("correct");
  });

  it("stops at the word's length when the boxes are shown, and never starts with a space", () => {
    let s = R.startRound([writeQuestion("Ball", false, true)], false);
    s = type(s, " balll");
    expect(s.textInput).toBe("ball");
    expect(R.submitText(s).phase).toBe("correct");
    expect(R.canSubmitText(R.startRound([writeQuestion("Ball", false)], false))).toBe(false);
  });
});

describe("writing in Wörter", () => {
  it("starts with picture words at 6½, adds dictation at 8 and sentences at 7", () => {
    const at = (age: number) => difficultyForAge(age).vocabulary;
    expect(at(6).questionTypeWeights.writeWord).toBeUndefined();
    expect(at(7).questionTypeWeights.writeWord).toBeGreaterThan(0);
    expect(at(7).questionTypeWeights.sentence).toBeGreaterThan(0);
    expect(at(7).questionTypeWeights.dictation).toBeUndefined();
    expect(at(8).questionTypeWeights.dictation).toBeGreaterThan(0);
    expect(at(7)).toMatchObject({ writeShowsLength: true, writeCaseSensitive: false, sentenceDictation: false });
    expect(at(10)).toMatchObject({ writeShowsLength: false, writeCaseSensitive: true, sentenceDictation: true });
  });

  it("asks young children to copy sentences and older ones to write from dictation", async () => {
    const provider = await germanProvider("vocabulary");
    const rng = seededRng(4);
    for (const [age, kind] of [[7, "copy"], [8, "copy"], [10, "listen"], [13, "listen"]] as const) {
      const questions = Array.from({ length: 10 }, () => provider.makeQuestions(10, difficultyForAge(age), new Set(), rng)).flat();
      const sentences = questions.filter((q) => q.contentId?.startsWith("sentence:"));
      expect(sentences.length).toBeGreaterThan(5);
      for (const q of sentences) {
        expect(q.visual?.kind).toBe(kind);
        expect(q.format.kind).toBe("writeText");
        if (q.format.kind === "writeText") expect(q.spoken).toContain(q.format.answer);
      }
      const words = questions.filter((q) => q.format.kind === "writeText" && !q.contentId?.startsWith("sentence:"));
      expect(words.length).toBeGreaterThan(3);
      for (const q of words) {
        if (q.format.kind !== "writeText") continue;
        expect(q.format.answer).toMatch(/^\p{L}+$/u);
        // Picture words are nouns, so the picture names exactly one word.
        if (q.visual?.kind === "emoji") expect(q.format.answer[0]).toBe(q.format.answer[0].toLocaleUpperCase("de"));
        if (q.visual?.kind === "emoji" && q.format.showLength) expect([...q.format.answer].length).toBeLessThanOrEqual(difficultyForAge(age).vocabulary.spellingMaxLength + 2);
      }
    }
  });
});
