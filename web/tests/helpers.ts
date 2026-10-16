import { existsSync, readdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { ContentLibrary, type JsonLoader } from "../src/content/library";
import type { SubjectDescriptor } from "../src/content/types";
import { providerFor } from "../src/providers";

/** Reads the shared ../Content folder straight from disk (no build step needed). */
const contentRoot = join(dirname(fileURLToPath(import.meta.url)), "..", "..", "Content");

export const diskLoader: JsonLoader = async (path) => {
  if (path === "languages.json") {
    return readdirSync(contentRoot, { withFileTypes: true })
      .filter((e) => e.isDirectory() && existsSync(join(contentRoot, e.name, "manifest.json")))
      .map((e) => e.name)
      .sort();
  }
  return JSON.parse(readFileSync(join(contentRoot, path), "utf8"));
};

export const library = () => ContentLibrary.create(diskLoader);

export async function germanSubject(id: string): Promise<{ lib: ContentLibrary; subject: SubjectDescriptor }> {
  const lib = await library();
  const subject = lib.language("de")?.subjects.find((s) => s.id === id);
  if (!subject) throw new Error(`no subject ${id}`);
  return { lib, subject };
}

export async function germanProvider(id: string) {
  const { lib, subject } = await germanSubject(id);
  return providerFor(subject, lib);
}

export const AGES = Array.from({ length: 11 }, (_, i) => 4 + i);
