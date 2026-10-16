import { describe, expect, it } from "vitest";
import {
  Keyframes,
  difficultyForAge,
  difficultyForEffectiveAge,
  effectiveAge,
  isEligible,
  nextAdjustment,
} from "../src/domain/difficulty";
import { AGES } from "./helpers";

describe("difficulty scaling (mirrors DifficultyScaleTests.swift)", () => {
  it("interpolates and clamps keyframes", () => {
    const curve = new Keyframes([[4, 0], [6, 10]]);
    expect(curve.value(2)).toBe(0);
    expect(curve.value(5)).toBeCloseTo(5);
    expect(curve.value(20)).toBe(10);
  });

  it("clamps effective age", () => {
    expect(effectiveAge(4, -1.5)).toBe(4);
    expect(effectiveAge(14, 1.5)).toBe(14);
    expect(effectiveAge(7, 5)).toBe(8.5);
  });

  it("gives the youngest only counting", () => {
    const d = difficultyForAge(4);
    expect(Object.keys(d.maths.operationWeights).sort()).toEqual(["counting", "numberRecognition"]);
    expect(d.maths.countingMax).toBe(5);
    expect(d.answerOptionCount).toBe(3);
    expect(d.usesPictureOptions).toBe(true);
    expect(d.allowsGentleTimer).toBe(false);
    expect(d.maths.usesNumberPad).toBe(false);
  });

  it("unlocks operations with age", () => {
    const six = difficultyForAge(6).maths.operationWeights;
    expect(six.addition).toBeDefined();
    expect(six.multiplication).toBeUndefined();
    const nine = difficultyForAge(9).maths.operationWeights;
    expect(nine.multiplication).toBeDefined();
    expect(nine.division).toBeDefined();
    expect(nine.wordProblem).toBeDefined();
    expect(nine.counting).toBeUndefined();
  });

  it("normalises weights at every age", () => {
    for (const age of AGES) {
      const d = difficultyForAge(age);
      const sum = (r: object) => Object.values(r).reduce((a: number, b) => a + (b as number), 0);
      expect(sum(d.maths.operationWeights)).toBeCloseTo(1);
      expect(sum(d.vocabulary.questionTypeWeights)).toBeCloseTo(1);
    }
  });

  it("never shrinks ranges as a child grows", () => {
    let previous = difficultyForEffectiveAge(4);
    for (let step = 1; step <= 100; step++) {
      const current = difficultyForEffectiveAge(4 + step * 0.1);
      expect(current.maths.addSubResultMax).toBeGreaterThanOrEqual(previous.maths.addSubResultMax);
      expect(current.vocabulary.spellingMaxLength).toBeGreaterThanOrEqual(previous.vocabulary.spellingMaxLength);
      expect(current.answerOptionCount).toBeGreaterThanOrEqual(previous.answerOptionCount);
      previous = current;
    }
  });

  it("offers the timer from 9", () => {
    expect(difficultyForAge(8).allowsGentleTimer).toBe(false);
    expect(difficultyForAge(9).allowsGentleTimer).toBe(true);
  });

  it("adapts gently and is capped", () => {
    expect(nextAdjustment(0, 10, 10)).toBeCloseTo(0.15);
    expect(nextAdjustment(0, 7, 10)).toBe(0);
    expect(nextAdjustment(0, 2, 10)).toBeCloseTo(-0.2);
    expect(nextAdjustment(1.45, 10, 10)).toBe(1.5);
    expect(nextAdjustment(0.3, 0, 0)).toBe(0.3);
  });

  it("uses an eligibility window", () => {
    const d = difficultyForAge(8);
    expect(isEligible(d, 4)).toBe(true);
    expect(isEligible(d, 8, 10)).toBe(true);
    expect(isEligible(d, 10)).toBe(false);
    expect(isEligible(d, 4, 6)).toBe(false);
  });
});
