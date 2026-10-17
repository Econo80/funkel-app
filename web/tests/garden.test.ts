import { describe, expect, it } from "vitest";
import {
  GARDEN_COLUMNS,
  GARDEN_ITEMS,
  GARDEN_SIZE,
  buyLand,
  canClear,
  clearPlot,
  collectProduce,
  connections,
  daysUntilNextStage,
  gardenRows,
  homeSpace,
  nextLandPrice,
  occupancy,
  placeInGarden,
  placementProblem,
  plotPicture,
  readyProduce,
  sellGoods,
} from "../src/domain/garden";
import { createProfile, defaultSettings, normalizeProfile, type Profile } from "../src/domain/profile";
import { seededRng } from "../src/domain/random";

const day = (d: number) => new Date(2026, 9, d, 10);
const rich = (stars = 500): Profile => ({ ...createProfile({ ...defaultSettings(), name: "Lena", age: 6 }, day(1)), walletStars: stars });
const place = (p: Profile, cell: number, id: string, d = 1) => placeInGarden(p, cell, id, day(d), seededRng(cell));

describe("farm buildings", () => {
  it("take days to build and big ones cover several cells", () => {
    const p = place(rich(), 0, "barn");
    expect(p.walletStars).toBe(460);
    expect(plotPicture(p.garden[0]!, day(1))).toBe("🚧");
    expect(daysUntilNextStage(p.garden[0]!, day(1))).toBe(2);
    expect(plotPicture(p.garden[0]!, day(3))).toBe("art:barn");
    const covered = occupancy(p.garden);
    expect([0, 1, GARDEN_COLUMNS, GARDEN_COLUMNS + 1].map((c) => covered[c])).toEqual([0, 0, 0, 0]);
    expect(covered[2]).toBeUndefined();
    // Nothing else fits on top of it.
    expect(placementProblem(p, GARDEN_COLUMNS + 1, "stone", day(1))).toBe("space");
  });

  it("shift left or up so they fit at the edge", () => {
    const p = place(rich(), GARDEN_COLUMNS - 1, "pond");
    expect(p.garden[GARDEN_COLUMNS - 2]?.itemId).toBe("pond");
    const bottomRight = GARDEN_SIZE - 1;
    const q = place(rich(), bottomRight, "barn");
    expect(q.garden[bottomRight - GARDEN_COLUMNS - 1]?.itemId).toBe("barn");
  });
});

describe("farm animals", () => {
  it("need a finished home with room", () => {
    let p = rich();
    expect(placementProblem(p, 5, "cow", day(1))).toBe("home");
    p = place(p, 0, "barn");
    expect(placementProblem(p, 5, "cow", day(2))).toBe("home"); // still being built
    for (const [i, id] of ["cow", "pig", "sheep", "horse"].entries()) p = place(p, 2 + i, id, 3);
    expect(homeSpace(p.garden, "farm", day(3))).toEqual({ capacity: 4, used: 4 });
    expect(placementProblem(p, 12, "goat", day(3))).toBe("full");
    // A full home can't be cleared away from under its animals.
    expect(canClear(p, 0, day(3))).toBe(false);
    expect(clearPlot(p, 0, day(3))).toBe(p);
    expect(canClear(clearPlot(p, 2, day(3)), 0, day(3))).toBe(false);
  });

  it("small animals live anywhere, and a house is home for cats", () => {
    let p = place(rich(), 0, "rabbit");
    expect(p.garden[0]?.itemId).toBe("rabbit");
    expect(placementProblem(p, 1, "cat", day(1))).toBe("home");
    p = place(p, 1, "house");
    expect(placementProblem(p, 2, "cat", day(1))).toBeUndefined();
  });

  it("chicks grow into hens that lay one egg a day", () => {
    let p = place(place(rich(), 0, "coop"), 1, "chick", 2);
    const chick = () => p.garden[1]!;
    expect(plotPicture(chick(), day(2))).toBe("🐣");
    expect(plotPicture(chick(), day(4))).toBe("🐥");
    expect(readyProduce(chick(), day(4))).toBeUndefined();
    expect(plotPicture(chick(), day(6))).toBe("🐔");
    expect(readyProduce(chick(), day(6))).toBe("egg");
    p = collectProduce(p, 1, day(6));
    expect(p.farmGoods.egg).toBe(1);
    expect(readyProduce(chick(), day(6))).toBeUndefined();
    expect(collectProduce(p, 1, day(6))).toBe(p);
    expect(readyProduce(chick(), day(7))).toBe("egg");
  });

  it("cows give milk from the day after they arrive", () => {
    let p = place(place(rich(), 0, "barn"), 2, "cow", 3);
    expect(readyProduce(p.garden[2]!, day(3))).toBeUndefined();
    p = collectProduce(p, 2, day(4));
    expect(p.farmGoods.milk).toBe(1);
  });

  it("sells eggs and milk in fives for spendable stars only", () => {
    const p = { ...rich(10), totalStars: 50, farmGoods: { egg: 7, milk: 4 } };
    const sold = sellGoods(p);
    expect(sold).toMatchObject({ walletStars: 12, totalStars: 50, farmGoods: { egg: 0, milk: 1 } });
    expect(sellGoods(sold)).toBe(sold);
  });
});

describe("more land", () => {
  it("adds four rows at a time, three times", () => {
    let p = rich(200);
    expect(gardenRows(p.garden)).toBe(8);
    for (const price of [25, 40, 60]) {
      expect(nextLandPrice(p.garden)).toBe(price);
      const before = p.walletStars;
      p = buyLand(p);
      expect(p.walletStars).toBe(before - price);
    }
    expect(gardenRows(p.garden)).toBe(20);
    expect(nextLandPrice(p.garden)).toBeUndefined();
    expect(buyLand(p)).toBe(p);
  });

  it("moves old 6-column gardens into the wide farm, keeping land already bought", () => {
    const old = normalizeProfile({ id: "x", garden: [{ itemId: "flower", plantedDay: "2026-10-01" }] as Profile["garden"] });
    expect(old.garden).toHaveLength(GARDEN_SIZE);
    expect(old.farmGoods).toEqual({ egg: 0, milk: 0 });

    // 6 columns × 6 rows = one land purchase; a barn at row 1, column 4.
    const legacy: Profile["garden"] = Array.from({ length: 36 }, () => null);
    legacy[6 + 4] = { itemId: "barn", plantedDay: "2026-10-01" };
    legacy[35] = { itemId: "stone", plantedDay: "2026-10-01" };
    const moved = normalizeProfile({ id: "y", garden: legacy });
    expect(gardenRows(moved.garden)).toBe(12);
    expect(moved.garden[GARDEN_COLUMNS + 4]?.itemId).toBe("barn");
    expect(moved.garden[5 * GARDEN_COLUMNS + 5]?.itemId).toBe("stone");
    expect(nextLandPrice(moved.garden)).toBe(40);
    // Saved again, it is not moved a second time.
    expect(normalizeProfile(moved).garden).toEqual(moved.garden);
  });

  it("has a name-able, buyable picture for every item", () => {
    for (const item of GARDEN_ITEMS) {
      expect(item.stages).toHaveLength(item.days.length);
      expect(item.price).toBeGreaterThanOrEqual(item.connects ? 0 : 1);
      expect(item.price === 0).toBe(item.category === "paths");
      if (item.needs) expect(GARDEN_ITEMS.some((h) => h.houses?.group === item.needs)).toBe(true);
    }
  });
});

describe("roads, paths and fences", () => {
  it("are free and join up with their neighbours", () => {
    let p = rich(0);
    for (const cell of [0, 1, 2, 2 + GARDEN_COLUMNS]) p = place(p, cell, "road");
    p = place(p, 3, "fence");
    expect(p.walletStars).toBe(0);
    expect(connections(p.garden, 0)).toEqual({ n: false, e: true, s: false, w: false });
    expect(connections(p.garden, 2)).toEqual({ n: false, e: false, s: true, w: true });
    // A road doesn't join a fence; the right edge doesn't wrap to the next row.
    expect(connections(p.garden, 3)).toEqual({ n: false, e: false, s: false, w: false });
    const edge = place(place(rich(0), GARDEN_COLUMNS - 1, "path"), GARDEN_COLUMNS, "path");
    expect(connections(edge.garden, GARDEN_COLUMNS - 1).e).toBe(false);
  });
});
