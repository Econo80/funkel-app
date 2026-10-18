import { describe, expect, it } from "vitest";
import { backupFileName, makeBackup, readBackup } from "../src/domain/backup";
import { placeInGarden } from "../src/domain/garden";
import { createProfile, defaultSettings, giveStars, recordRound, type Profile } from "../src/domain/profile";
import { seededRng } from "../src/domain/random";

const day = new Date(2026, 9, 18, 10);
const child = (name: string, age: number): Profile => {
  let p = createProfile({ ...defaultSettings(), name, age }, day);
  p = recordRound(p, { subjectId: "maths", languageCode: "de", correct: 9, total: 10, correctContentIds: [], effectiveAge: age }, day).profile;
  p = placeInGarden(giveStars(p, 40), 3, "wheat", day, seededRng(1));
  return p;
};

describe("backups", () => {
  it("round-trip every profile with stars, garden and progress", () => {
    const profiles = [child("Lena", 5), child("Emil", 10)];
    const text = JSON.stringify(makeBackup(profiles, day));
    const result = readBackup(text);
    expect("backup" in result).toBe(true);
    if (!("backup" in result)) return;
    expect(result.backup.profiles).toEqual(profiles);
    expect(result.backup.exportedAt).toBe(day.toISOString());
    expect(result.backup.profiles[0].garden[3]?.itemId).toBe("wheat");
    expect(backupFileName(day)).toBe("Funkel-Sicherung-2026-10-18.json");
  });

  it("upgrade profiles from older backups", () => {
    const old = { app: "funkel", version: 1, exportedAt: "", profiles: [{ id: "a", name: "Lena", age: 5, totalStars: 9 }] };
    const result = readBackup(JSON.stringify(old));
    if (!("backup" in result)) throw new Error("expected a backup");
    expect(result.backup.profiles[0]).toMatchObject({ name: "Lena", walletStars: 9, gardenMinutesPerDay: 20 });
  });

  it("explain files that aren't usable", () => {
    expect(readBackup("not json")).toEqual({ problem: "notJson" });
    expect(readBackup(JSON.stringify({ hello: 1 }))).toEqual({ problem: "notFunkel" });
    expect(readBackup(JSON.stringify({ app: "funkel", version: 99, profiles: [] }))).toEqual({ problem: "newerVersion" });
    expect(readBackup(JSON.stringify({ app: "funkel", version: 1, profiles: [{ nope: true }] }))).toEqual({ problem: "noProfiles" });
  });
});
