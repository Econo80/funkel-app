import { describe, expect, it } from "vitest";
import {
  ageOn, applySettings, createProfile, defaultSettings, setSubjectAdjustment, subjectAdaptivity, withCurrentAge, type Profile,
} from "../src/domain/profile";

const on = (y: number, m: number, d: number) => new Date(y, m - 1, d, 12);

describe("birthday", () => {
  it("counts full years, the birthday itself included", () => {
    expect(ageOn("2019-03-15", on(2026, 3, 14))).toBe(6);
    expect(ageOn("2019-03-15", on(2026, 3, 15))).toBe(7);
    expect(ageOn("2019-03-15", on(2026, 12, 31))).toBe(7);
    expect(ageOn(undefined)).toBeUndefined();
    expect(ageOn("2019-13-01")).toBeUndefined();
    expect(ageOn("")).toBeUndefined();
  });

  it("sets the age from the birthday in the editor, and forgets an invalid one", () => {
    const p = createProfile({ ...defaultSettings(), name: "Emil", age: 6 });
    const withBirthday = applySettings(p, { ...p, birthDate: "2019-03-15" });
    expect(withBirthday.birthDate).toBe("2019-03-15");
    expect(withBirthday.age).toBe(ageOn("2019-03-15"));
    const without = applySettings(withBirthday, { ...withBirthday, birthDate: undefined, age: 9 });
    expect(without).toMatchObject({ age: 9, birthDate: undefined });
    expect(applySettings(p, { ...p, birthDate: "kaputt" }).birthDate).toBeUndefined();
  });

  it("grows a year on the birthday: a lead shrinks, the others grow with the child", () => {
    let p: Profile = { ...createProfile({ ...defaultSettings(), name: "Emil", age: 7 }), birthDate: "2019-03-15" };
    p = setSubjectAdjustment(p, "de", "generalKnowledge", 2.5);
    p = setSubjectAdjustment(p, "de", "maths", 0.5);
    p = setSubjectAdjustment(p, "de", "vocabulary", -1);

    expect(withCurrentAge(p, on(2027, 3, 14))).toBe(p);
    const older = withCurrentAge(p, on(2027, 3, 15));
    expect(older.age).toBe(8);
    expect(subjectAdaptivity(older, "de", "generalKnowledge").adjustment).toBe(1.5);
    expect(subjectAdaptivity(older, "de", "maths").adjustment).toBe(0);
    expect(subjectAdaptivity(older, "de", "vocabulary").adjustment).toBe(-1);

    // Without a birthday nothing changes by itself.
    const plain = { ...p, birthDate: undefined };
    expect(withCurrentAge(plain, on(2030, 1, 1))).toBe(plain);
  });
});
