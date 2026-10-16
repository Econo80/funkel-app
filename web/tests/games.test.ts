import { describe, expect, it } from "vitest";
import {
  GARDEN_SIZE,
  balloonRuleForAge,
  bonusGamesLeftToday,
  gameAge,
  grantBonusGames,
  buyTicket,
  checkTicket,
  clearPlot,
  daysUntilNextStage,
  gamesLeftToday,
  memoryBoard,
  memoryPairsForAge,
  placeInGarden,
  plotPicture,
  spawnBalloon,
} from "../src/domain/games";
import { createProfile, defaultSettings, normalizeProfile, recordRound, resetProgress, type Profile } from "../src/domain/profile";
import { seededRng } from "../src/domain/random";

const day = (d: number) => new Date(2026, 9, d, 10);
const child = (stars: number, overrides: Partial<Profile> = {}): Profile => ({
  ...createProfile({ ...defaultSettings(), name: "Lena", age: 6 }, day(1)),
  totalStars: stars,
  walletStars: stars,
  ...overrides,
});

describe("star wallet", () => {
  it("earns stars into both the lifetime total and the wallet", () => {
    const { profile } = recordRound(child(0), { subjectId: "maths", languageCode: "de", correct: 7, total: 10, correctContentIds: [], effectiveAge: 6 }, day(1));
    expect(profile.totalStars).toBe(7);
    expect(profile.walletStars).toBe(7);
  });

  it("migrates profiles saved before the play corner existed", () => {
    const old = { id: "x", name: "Lena", age: 5, totalStars: 9, createdAt: "2026-10-16T00:00:00.000Z" } as Partial<Profile> & { id: string };
    const p = normalizeProfile(old);
    expect(p.walletStars).toBe(9);
    expect(p.garden).toHaveLength(GARDEN_SIZE);
    expect(p).toMatchObject({ gamesEnabled: true, gameCost: 10, gamesPerDay: 3, gamesToday: 0 });
  });

  it("is cleared by a grown-up reset, including the garden", () => {
    let p = placeInGarden(child(20), 0, "flower", day(1), seededRng(1));
    p = resetProgress(p);
    expect(p).toMatchObject({ walletStars: 0, totalStars: 0 });
    expect(p.garden.every((x) => x === null)).toBe(true);
  });
});

describe("game tickets", () => {
  it("costs stars but never touches the lifetime total", () => {
    const p = buyTicket(child(25), day(1));
    expect(p.walletStars).toBe(15);
    expect(p.totalStars).toBe(25);
    expect(p.gamesToday).toBe(1);
  });

  it("explains why a game can't start", () => {
    expect(checkTicket(child(4), day(1))).toEqual({ ok: false, reason: "notEnoughStars", missing: 6 });
    expect(checkTicket(child(50, { gamesEnabled: false }), day(1))).toEqual({ ok: false, reason: "disabled" });
    let p = child(100);
    for (let i = 0; i < 3; i++) p = buyTicket(p, day(1));
    expect(checkTicket(p, day(1))).toEqual({ ok: false, reason: "dailyLimit" });
    expect(buyTicket(p, day(1))).toBe(p);
    expect(gamesLeftToday(p, day(1))).toBe(0);
  });

  it("opens again the next day and supports 'no limit'", () => {
    let p = child(100);
    for (let i = 0; i < 3; i++) p = buyTicket(p, day(1));
    expect(checkTicket(p, day(2)).ok).toBe(true);
    expect(gamesLeftToday(p, day(2))).toBe(3);
    let unlimited = child(100, { gamesPerDay: 0 });
    for (let i = 0; i < 8; i++) unlimited = buyTicket(unlimited, day(1));
    expect(unlimited.walletStars).toBe(20);
    expect(gamesLeftToday(unlimited, day(1))).toBeUndefined();
  });
});

describe("grown-up bonus games", () => {
  it("are free, skip the daily limit and expire at midnight", () => {
    let p = child(0);
    for (let i = 0; i < 3; i++) p = buyTicket({ ...p, walletStars: 100 }, day(1));
    p = { ...p, walletStars: 0 };
    expect(checkTicket(p, day(1))).toEqual({ ok: false, reason: "dailyLimit" });

    p = grantBonusGames(p, 2, day(1));
    expect(bonusGamesLeftToday(p, day(1))).toBe(2);
    expect(checkTicket(p, day(1))).toEqual({ ok: true, free: true });
    p = buyTicket(p, day(1));
    expect(p.walletStars).toBe(0);
    expect(bonusGamesLeftToday(p, day(1))).toBe(1);
    expect(bonusGamesLeftToday(p, day(2))).toBe(0);
  });

  it("add up but are capped", () => {
    const p = grantBonusGames(grantBonusGames(child(0), 3, day(1)), 3, day(1));
    expect(bonusGamesLeftToday(p, day(1))).toBe(6);
    expect(bonusGamesLeftToday(grantBonusGames(p, 50, day(1)), day(1))).toBe(10);
  });
});

describe("game difficulty", () => {
  it("shifts the games two years either way", () => {
    expect(gameAge({ age: 5, gameDifficulty: "normal" })).toBe(5);
    expect(gameAge({ age: 5, gameDifficulty: "hard" })).toBe(7);
    expect(gameAge({ age: 5, gameDifficulty: "easy" })).toBe(4);
    expect(gameAge({ age: 14, gameDifficulty: "hard" })).toBe(14);
  });

  it("starts a 5-year-old's memory at 6 pairs and grows each board", () => {
    const rng = seededRng(8);
    expect(memoryBoard(5, rng)).toHaveLength(12);
    expect(memoryBoard(5, rng, 1)).toHaveLength(16);
    expect(memoryBoard(5, rng, 99)).toHaveLength(30);
  });
});

describe("memory", () => {
  it("deals pairs that grow with age", () => {
    const rng = seededRng(3);
    for (const age of [4, 6, 9, 13]) {
      const board = memoryBoard(age, rng);
      expect(board).toHaveLength(memoryPairsForAge(age) * 2);
      const counts = new Map<string, number>();
      board.forEach((c) => counts.set(c.picture, (counts.get(c.picture) ?? 0) + 1));
      expect([...counts.values()].every((n) => n === 2)).toBe(true);
    }
    expect(memoryPairsForAge(4)).toBeLessThan(memoryPairsForAge(12));
  });
});

describe("balloons", () => {
  it("uses age-appropriate rules that are always correct", () => {
    const rng = seededRng(5);
    expect(balloonRuleForAge(5, rng)).toEqual({ kind: "all" });
    expect(balloonRuleForAge(8, rng)).toEqual({ kind: "even" });
    const rule = balloonRuleForAge(11, rng);
    expect(rule.kind).toBe("product");
    let good = 0;
    for (let i = 0; i < 400; i++) {
      const b = spawnBalloon(rule, rng);
      const [a, c] = b.label!.split("·").map(Number);
      expect(b.good).toBe(a * c === (rule as { target: number }).target);
      if (b.good) good++;
    }
    expect(good).toBeGreaterThan(80);
    for (let i = 0; i < 200; i++) {
      const b = spawnBalloon({ kind: "even" }, rng);
      expect(b.good).toBe(Number(b.label) % 2 === 0);
    }
  });
});

describe("Pips Garten", () => {
  it("buys and places items with the wallet", () => {
    const p = placeInGarden(child(5), 3, "flower", day(1), seededRng(1));
    expect(p.walletStars).toBe(2);
    expect(p.garden[3]?.itemId).toBe("flower");
    expect(placeInGarden(p, 3, "stone", day(1), seededRng(1))).toBe(p);
    expect(placeInGarden(p, 4, "house", day(1), seededRng(1))).toBe(p);
    expect(clearPlot(p, 3).garden[3]).toBeNull();
  });

  it("grows plants over days", () => {
    const p = placeInGarden(child(20), 0, "tree", day(1), seededRng(2));
    const plot = p.garden[0]!;
    expect(plotPicture(plot, day(1))).toBe("🌱");
    expect(daysUntilNextStage(plot, day(1))).toBe(3);
    expect(plotPicture(plot, day(4))).toBe("🪴");
    expect(["🌳", "🌲", "🍎"]).toContain(plotPicture(plot, day(8)));
    expect(daysUntilNextStage(plot, day(8))).toBeUndefined();
  });
});
