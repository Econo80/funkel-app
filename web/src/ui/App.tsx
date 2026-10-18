import { useState } from "preact/hooks";
import type { ContentLibrary } from "../content/library";
import type { SubjectDescriptor } from "../content/types";
import { giftSeen, type Profile } from "../domain/profile";
import { t } from "../services/i18n";
import { deleteProfile, saveProfile, setMeta } from "../services/storage";
import { GrownUpGate, GrownUps, ProfileEditor } from "./GrownUps";
import { Home } from "./Home";
import { ProfilePicker } from "./ProfilePicker";
import { PlayCorner } from "./play/PlayCorner";
import { RoundScreen } from "./Round";
import { SudokuScreen } from "./Sudoku";

type Overlay = { kind: "grownUps" } | { kind: "newProfile" } | undefined;

export function App({ library, initialProfiles, initialActiveId }: {
  library: ContentLibrary; initialProfiles: Profile[]; initialActiveId?: string;
}) {
  const [profiles, setProfiles] = useState(initialProfiles);
  const [activeId, setActiveId] = useState(initialActiveId);
  const [subject, setSubject] = useState<SubjectDescriptor>();
  const [playing, setPlaying] = useState(false);
  const [puzzling, setPuzzling] = useState(false);
  const [overlay, setOverlay] = useState<Overlay>();

  const active = profiles.find((p) => p.id === activeId);
  const language = active ? library.resolvedLanguage(active.learningLanguage) : undefined;

  const selectProfile = (id: string | undefined) => {
    setActiveId(id);
    setPlaying(false);
    setPuzzling(false);
    void setMeta("activeProfileId", id ?? null);
  };

  const upsert = async (profile: Profile) => {
    await saveProfile(profile);
    setProfiles((list) => {
      const exists = list.some((p) => p.id === profile.id);
      return exists ? list.map((p) => (p.id === profile.id ? profile : p)) : [...list, profile];
    });
  };

  const remove = async (id: string) => {
    await deleteProfile(id);
    setProfiles((list) => list.filter((p) => p.id !== id));
    if (id === activeId) selectProfile(undefined);
  };

  if (library.languages.length === 0) {
    return <main class="screen center"><p>{t("content.missing")}</p></main>;
  }

  return (
    <>
      {active && language ? (
        subject ? (
          <RoundScreen
            key={subject.id}
            library={library}
            subject={subject}
            profile={active}
            speechLocale={language.speechLocale}
            onSave={upsert}
            onClose={() => setSubject(undefined)}
          />
        ) : puzzling && active.sudokuEnabled ? (
          <SudokuScreen profile={active} onSave={upsert} onBack={() => setPuzzling(false)} />
        ) : playing && active.gamesEnabled ? (
          <PlayCorner profile={active} onSave={upsert} onBack={() => setPlaying(false)} />
        ) : (
          <Home
            profile={active}
            language={language}
            onStart={setSubject}
            onPlay={() => setPlaying(true)}
            onSudoku={() => setPuzzling(true)}
            onGiftSeen={() => void upsert(giftSeen(active))}
            onSwitchProfile={() => selectProfile(undefined)}
            onGrownUps={() => setOverlay({ kind: "grownUps" })}
          />
        )
      ) : (
        <ProfilePicker
          profiles={profiles}
          onSelect={(p) => selectProfile(p.id)}
          onAdd={() => setOverlay({ kind: "newProfile" })}
          onGrownUps={() => setOverlay({ kind: "grownUps" })}
        />
      )}

      {overlay && (
        <GrownUpGate onCancel={() => setOverlay(undefined)}>
          {overlay.kind === "grownUps" ? (
            <GrownUps library={library} profiles={profiles} onSave={upsert} onDelete={remove} onDone={() => setOverlay(undefined)} />
          ) : (
            <ProfileEditor
              library={library}
              onSave={async (p) => {
                await upsert(p);
                selectProfile(p.id);
                setOverlay(undefined);
              }}
              onCancel={() => setOverlay(undefined)}
            />
          )}
        </GrownUpGate>
      )}
    </>
  );
}
