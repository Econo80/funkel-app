// Backups: all profiles in one JSON file the grown-ups keep (Files, iCloud,
// e-mail …). Nothing is uploaded anywhere; the file only leaves the device if
// a grown-up shares it.
import { dayKey, normalizeProfile, type Profile } from "./profile";

export const BACKUP_APP = "funkel";
export const BACKUP_VERSION = 1;

export interface Backup {
  app: typeof BACKUP_APP;
  version: number;
  exportedAt: string;
  profiles: Profile[];
}

export function makeBackup(profiles: Profile[], now = new Date()): Backup {
  return { app: BACKUP_APP, version: BACKUP_VERSION, exportedAt: now.toISOString(), profiles };
}

export const backupFileName = (now = new Date()) => `Funkel-Sicherung-${dayKey(now)}.json`;

export type BackupProblem = "notJson" | "notFunkel" | "newerVersion" | "noProfiles";

/**
 * Reads a backup file. Profiles go through the same upgrade path as stored
 * ones, so backups from older versions of the app keep working.
 */
export function readBackup(text: string): { backup: Backup } | { problem: BackupProblem } {
  let data: unknown;
  try {
    data = JSON.parse(text);
  } catch {
    return { problem: "notJson" };
  }
  const b = data as Partial<Backup> | null;
  if (!b || typeof b !== "object" || b.app !== BACKUP_APP || !Array.isArray(b.profiles)) return { problem: "notFunkel" };
  if (typeof b.version !== "number" || b.version > BACKUP_VERSION) return { problem: "newerVersion" };
  const profiles = b.profiles
    .filter((p): p is Profile => !!p && typeof p === "object" && typeof p.id === "string" && typeof p.name === "string")
    .map((p) => normalizeProfile(p));
  if (profiles.length === 0) return { problem: "noProfiles" };
  return { backup: { app: BACKUP_APP, version: b.version, exportedAt: typeof b.exportedAt === "string" ? b.exportedAt : "", profiles } };
}
