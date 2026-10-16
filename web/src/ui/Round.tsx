import { useEffect, useLayoutEffect, useMemo, useRef, useState } from "preact/hooks";
import type { ContentLibrary } from "../content/library";
import type { SubjectDescriptor } from "../content/types";
import { profileDifficulty, recordRound, scoreOf, type Profile, type RoundSummary } from "../domain/profile";
import { correctAnswerText, spokenText, type AnswerOption, type Question } from "../domain/question";
import { systemRng } from "../domain/random";
import * as R from "../domain/round";
import { playSound, speak, stopSpeaking, vibrate } from "../services/feedback";
import { t } from "../services/i18n";
import { providerFor } from "../providers";
import { BigButton, CircleButton, Confetti, Pip, avatarColor, fittingFontSize } from "./components";

const PRAISE = ["feedback.correct.1", "feedback.correct.2", "feedback.correct.3", "feedback.correct.4", "feedback.correct.5"];

/** Hosts a round from start to summary, including "play again". */
export function RoundScreen({ library, subject, profile, speechLocale, onSave, onClose }: {
  library: ContentLibrary;
  subject: SubjectDescriptor;
  profile: Profile;
  speechLocale: string;
  onSave: (p: Profile) => Promise<void>;
  onClose: () => void;
}) {
  const [state, setState] = useState<R.RoundState>();
  const [summary, setSummary] = useState<RoundSummary>();
  const [failed, setFailed] = useState(false);
  const [attempt, setAttempt] = useState(0);
  const difficulty = useMemo(() => profileDifficulty(profile), [profile.age, profile.difficultyAdjustment]);

  // Build the round.
  useEffect(() => {
    let cancelled = false;
    setSummary(undefined);
    setState(undefined);
    (async () => {
      try {
        const provider = await providerFor(subject, library);
        const recent = new Set(profile.progress[`${subject.languageCode}/${subject.id}`]?.recentCorrectContentIds ?? []);
        const questions = provider.makeQuestions(profile.roundLength, difficulty, recent, systemRng);
        if (!cancelled) setState(R.startRound(questions, difficulty.maths.allowsNegativeResults));
      } catch (error) {
        console.error(error);
        if (!cancelled) setFailed(true);
      }
    })();
    return () => { cancelled = true; stopSpeaking(); };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [attempt]);

  // Save when finished.
  useEffect(() => {
    if (state?.phase !== "finished" || summary || state.results.length === 0) return;
    stopSpeaking();
    const { profile: updated, summary: s } = recordRound(profile, {
      subjectId: subject.id,
      languageCode: subject.languageCode,
      correct: R.correctCount(state),
      total: state.results.length,
      correctContentIds: state.correctContentIds,
      effectiveAge: difficulty.effectiveAge,
    });
    setSummary(s);
    void onSave(updated);
  }, [state?.phase]);

  const close = () => { stopSpeaking(); onClose(); };

  if (failed) {
    return (
      <main class="screen center column narrow">
        <p>{t("round.error")}</p>
        <BigButton onClick={close}>{t("summary.done")}</BigButton>
      </main>
    );
  }
  if (summary) {
    return <Summary summary={summary} color={subject.color} profile={profile} onAgain={() => setAttempt((a) => a + 1)} onDone={close} />;
  }
  if (!state) return <main class="screen center" aria-busy="true"><Pip color={avatarColor(profile.avatarColor)} mood="thinking" bob /></main>;

  return (
    <Round
      state={state}
      setState={setState}
      color={subject.color}
      profile={profile}
      speechLocale={speechLocale}
      library={library}
      languageCode={subject.languageCode}
      timerSeconds={profile.gentleTimerEnabled && difficulty.allowsGentleTimer ? difficulty.timerSeconds : undefined}
      onClose={close}
    />
  );
}

function Round({ state, setState, color, profile, speechLocale, library, languageCode, timerSeconds, onClose }: {
  state: R.RoundState;
  setState: (s: R.RoundState | ((s: R.RoundState | undefined) => R.RoundState | undefined)) => void;
  color: string;
  profile: Profile;
  speechLocale: string;
  library: ContentLibrary;
  languageCode: string;
  timerSeconds?: number;
  onClose: () => void;
}) {
  const question = R.currentQuestion(state)!;
  const [praise, setPraise] = useState(PRAISE[0]);
  const [celebration, setCelebration] = useState(0);
  const [announcement, setAnnouncement] = useState("");
  const update = (fn: (s: R.RoundState) => R.RoundState) => setState((s) => (s ? fn(s) : s));

  const readAloud = () => speak(spokenText(question), speechLocale);

  // Auto read-aloud for each new question.
  useEffect(() => {
    if (profile.readAloudEnabled) readAloud();
  }, [question.id]);

  // Feedback: sound, vibration, confetti, announcement, auto-advance.
  useEffect(() => {
    if (state.phase === "correct") {
      const phrase = PRAISE[Math.floor(Math.random() * PRAISE.length)];
      setPraise(phrase);
      setCelebration((c) => c + 1);
      setAnnouncement(t(phrase));
      if (profile.soundEnabled) playSound("correct");
      if (profile.hapticsEnabled) vibrate("correct");
      const index = state.index;
      const timer = setTimeout(() => update((s) => (s.index === index && s.phase === "correct" ? R.next(s) : s)), 1300);
      return () => clearTimeout(timer);
    }
    if (state.phase === "wrong") {
      const answer = correctAnswerText(question.format);
      setAnnouncement(t("feedback.wrong.answer %@", answer));
      if (profile.soundEnabled) playSound("gentle");
      if (profile.hapticsEnabled) vibrate("gentle");
      if (profile.readAloudEnabled) {
        void library.phrasing(languageCode).then((p) => speak(p.text("speech.answer", { answer }), speechLocale));
      }
    }
    return undefined;
  }, [state.phase, state.index]);

  return (
    <main class="screen round">
      <div class="round-top">
        <CircleButton label={t("round.close")} onClick={onClose} testId="round-close">✕</CircleButton>
        <ProgressDots results={state.results} current={state.index} total={state.questions.length} color={color} />
        <CircleButton label={t("round.readAloud")} onClick={readAloud} testId="read-aloud">🔊</CircleButton>
      </div>
      {timerSeconds && state.phase === "answering" && (
        <div class="timer" aria-hidden="true" key={question.id}>
          <div class="timer-fill" style={{ background: color, animationDuration: `${timerSeconds}s` }} />
        </div>
      )}

      <div class="column round-body" key={question.id}>
        <QuestionCard question={question} color={color} />
        {question.format.kind === "multipleChoice" && (
          <ChoiceGrid state={state} options={question.format.options} correctIndex={question.format.correctIndex} color={color} onChoose={(i) => update((s) => R.choose(s, i))} />
        )}
        {question.format.kind === "numberEntry" && <NumberPad state={state} color={color} update={update} />}
        {question.format.kind === "buildSequence" && <SequenceBuilder state={state} tiles={question.format.tiles} answerLength={question.format.answer.length} color={color} update={update} />}
      </div>

      <FeedbackBar
        phase={state.phase}
        praise={t(praise)}
        answer={correctAnswerText(question.format)}
        explanation={question.explanation}
        profileColor={avatarColor(profile.avatarColor)}
        celebration={celebration}
        onNext={() => update(R.next)}
      />
      <Confetti trigger={celebration} />
      <div class="visually-hidden" aria-live="polite">{announcement}</div>
    </main>
  );
}

function ProgressDots({ results, current, total, color }: { results: boolean[]; current: number; total: number; color: string }) {
  return (
    <div class="dots" role="img" aria-label={t("round.progress %lld %lld", Math.min(current + 1, total), total)}>
      {Array.from({ length: total }, (_, i) => (
        <span
          key={i}
          class={`dot${i === current ? " current" : ""}`}
          style={{ background: i < results.length ? (results[i] ? "var(--correct)" : "var(--reveal)") : i === current ? color : undefined }}
        />
      ))}
    </div>
  );
}

function QuestionCard({ question, color }: { question: Question; color: string }) {
  const visual = question.visual;
  // Screen readers hear the same words as read-aloud ("3 plus 4", not "3 · 4");
  // counting questions keep the objects so they can be counted.
  const label = visual?.kind === "countable" ? undefined : spokenText(question);
  return (
    <section class="card question-card" aria-label={label}>
      {visual?.kind === "emoji" && <div class="visual-emoji" aria-hidden="true">{visual.emoji}</div>}
      {visual?.kind === "equation" && <div class="visual-equation" style={{ color }} aria-hidden={label ? "true" : undefined}>{visual.text}</div>}
      {visual?.kind === "countable" && (
        <div class="countables">
          {Array.from({ length: visual.count }, (_, i) => (
            <span key={i} class="countable" style={{ animationDelay: `${i * 60}ms`, fontSize: visual.count <= 5 ? "3.4rem" : visual.count <= 10 ? "2.8rem" : "2.3rem" }}>{visual.symbol}</span>
          ))}
        </div>
      )}
      <h2 class="prompt" aria-hidden={label ? "true" : undefined}>{question.prompt}</h2>
      {question.sentence && <p class="sentence" aria-hidden={label ? "true" : undefined}>{question.sentence}</p>}
    </section>
  );
}

// MARK: Multiple choice

function ChoiceGrid({ state, options, correctIndex, color, onChoose }: {
  state: R.RoundState; options: AnswerOption[]; correctIndex: number; color: string; onChoose: (i: number) => void;
}) {
  const grid = useRef<HTMLDivElement>(null);
  const [width, setWidth] = useState(0);
  useLayoutEffect(() => {
    const el = grid.current;
    if (!el) return;
    const observer = new ResizeObserver(([entry]) => setWidth(entry.contentRect.width));
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  const texts = options.filter((o) => !o.emoji).map((o) => o.text);
  const longStyle = texts.some((x) => x.length > 12);
  const longest = Math.max(0, ...texts.map((x) => x.length));
  const columns = longest >= 23 ? 1 : longest >= 7 ? (options.length === 3 ? 1 : 2) : options.length === 3 ? 3 : 2;
  const rem = parseFloat(getComputedStyle(document.documentElement).fontSize) || 16;
  const columnWidth = (width - 14 * (columns - 1)) / columns - 32;
  const fontSize = fittingFontSize(texts, columnWidth, (longStyle ? 1.5 : 2.1) * rem, Math.min(15, rem), longStyle ? 600 : 700);

  const stateOf = (i: number) => {
    if (state.phase !== "correct" && state.phase !== "wrong") return "idle";
    if (i === correctIndex) return state.phase === "correct" ? "correct" : "revealed";
    return i === state.selectedOptionIndex ? "chosen-wrong" : "dimmed";
  };

  return (
    <div ref={grid} class="choice-grid" style={{ gridTemplateColumns: `repeat(${columns}, 1fr)` }}>
      {options.map((option, i) => {
        const s = stateOf(i);
        const isGroup = option.emoji && /^\d+$/.test(option.text);
        return (
          <button
            key={option.id}
            class={`choice pressable ${s}`}
            style={{ "--accent": color } as never}
            disabled={s !== "idle"}
            aria-label={option.text}
            aria-pressed={s === "correct" || s === "revealed" ? true : undefined}
            onClick={() => onChoose(i)}
            data-testid={import.meta.env.DEV ? (i === correctIndex ? "answer-correct" : "answer-wrong") : undefined}
          >
            {option.emoji ? (
              <span aria-hidden="true" class={isGroup ? "choice-group" : "choice-picture"}>{option.emoji}</span>
            ) : (
              <span aria-hidden="true" style={{ fontSize: `${fontSize}px`, fontWeight: longStyle ? 600 : 700 }}>{option.text}</span>
            )}
            {(s === "correct" || s === "revealed") && <span class="choice-check" aria-hidden="true">✓</span>}
          </button>
        );
      })}
    </div>
  );
}

// MARK: Number pad

function NumberPad({ state, color, update }: { state: R.RoundState; color: string; update: (fn: (s: R.RoundState) => R.RoundState) => void }) {
  const answering = state.phase === "answering";

  // Hardware keyboards (tablets, computers) work too.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (/^\d$/.test(e.key)) update((s) => R.appendDigit(s, Number(e.key)));
      else if (e.key === "Backspace") update(R.deleteDigit);
      else if (e.key === "-") update(R.toggleSign);
      else if (e.key === "Enter") update(R.submitNumber);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  return (
    <div class="number-pad">
      <div class="card number-display" style={{ color: state.numberInput ? color : undefined }} aria-live="polite">{state.numberInput || "?"}</div>
      <div class="keys">
        {[1, 2, 3, 4, 5, 6, 7, 8, 9].map((d) => (
          <button key={d} class="card key pressable" disabled={!answering} onClick={() => update((s) => R.appendDigit(s, d))} data-testid={`key-${d}`}>{d}</button>
        ))}
        {state.allowsNegative ? (
          <button class="card key pressable" disabled={!answering} aria-label={t("round.sign")} onClick={() => update(R.toggleSign)}>±</button>
        ) : <span />}
        <button class="card key pressable" disabled={!answering} onClick={() => update((s) => R.appendDigit(s, 0))} data-testid="key-0">0</button>
        <button class="card key pressable" disabled={!answering} aria-label={t("round.delete")} onClick={() => update(R.deleteDigit)}>⌫</button>
      </div>
      <BigButton color={color} disabled={!R.canSubmitNumber(state)} onClick={() => update(R.submitNumber)} testId="key-check">✓ {t("round.check")}</BigButton>
    </div>
  );
}

// MARK: Tiles

function SequenceBuilder({ state, tiles, answerLength, color, update }: {
  state: R.RoundState; tiles: string[]; answerLength: number; color: string; update: (fn: (s: R.RoundState) => R.RoundState) => void;
}) {
  const answering = state.phase === "answering";
  const letters = tiles.every((x) => [...x].length === 1);
  return (
    <div class={`sequence ${letters ? "letters" : "words"}`}>
      <div class="card slots">
        {Array.from({ length: answerLength }, (_, position) => {
          const tileIndex = state.placedTiles[position];
          return tileIndex === undefined ? (
            <span key={position} class="slot" style={{ borderColor: color }} aria-hidden="true" />
          ) : (
            <button key={position} class="tile pressable" style={{ background: color }} disabled={!answering}
              title={t("round.tile.remove")} onClick={() => update((s) => R.removeTile(s, position))}>
              {tiles[tileIndex]}
            </button>
          );
        })}
      </div>
      <div class="tile-pool">
        {tiles.map((tile, i) => {
          const used = state.placedTiles.includes(i);
          return (
            <button key={i} class={`tile pressable${used ? " used" : ""}`} style={{ background: color }} disabled={used || !answering}
              onClick={() => update((s) => R.placeTile(s, i))} data-testid={`tile-${i}`}>
              {tile}
            </button>
          );
        })}
      </div>
      <BigButton color={color} disabled={!R.canSubmitSequence(state)} onClick={() => update(R.submitSequence)} testId="sequence-check">✓ {t("round.check")}</BigButton>
    </div>
  );
}

// MARK: Feedback

function FeedbackBar({ phase, praise, answer, explanation, profileColor, celebration, onNext }: {
  phase: R.Phase; praise: string; answer: string; explanation?: string; profileColor: string; celebration: number; onNext: () => void;
}) {
  if (phase === "correct") {
    return (
      <div class="feedback correct">
        <Pip color={profileColor} mood="cheering" size={60} hop={celebration} />
        <strong>{praise}</strong>
        <span class="feedback-star" aria-hidden="true">⭐</span>
      </div>
    );
  }
  if (phase === "wrong") {
    return (
      <div class="feedback wrong">
        <strong>{t("feedback.wrong.title")}</strong>
        <p>{t("feedback.wrong.answer %@", answer)}</p>
        {explanation && <p class="explanation">{explanation}</p>}
        <BigButton color="var(--ink)" onClick={onNext} testId="round-next">→ {t("round.next")}</BigButton>
      </div>
    );
  }
  return null;
}

// MARK: Summary

function Summary({ summary, color, profile, onAgain, onDone }: {
  summary: RoundSummary; color: string; profile: Profile; onAgain: () => void; onDone: () => void;
}) {
  const score = scoreOf(summary);
  const message = score >= 1 ? "summary.message.perfect" : score >= 0.8 ? "summary.message.great" : score >= 0.5 ? "summary.message.good" : "summary.message.keepGoing";
  const [shown, setShown] = useState(0);
  const [celebration, setCelebration] = useState(0);

  useEffect(() => {
    if (profile.soundEnabled) playSound("finish");
    setCelebration(1);
    let n = 0;
    const timer = setInterval(() => {
      n += 1;
      setShown(Math.min(n, summary.starsEarned));
      if (n >= summary.starsEarned) clearInterval(timer);
    }, 140);
    return () => clearInterval(timer);
  }, []);

  return (
    <main class="screen">
      <div class="column narrow center summary">
        <Pip color={avatarColor(profile.avatarColor)} mood="cheering" size={150} hop={celebration} />
        <h1>{t("summary.title")}</h1>
        <p class="summary-message">{t(message)}</p>
        <div class="card summary-card">
          <div class="summary-stars" aria-label={t("summary.stars %lld", summary.starsEarned)}>
            <span aria-hidden="true">⭐ {t("summary.stars %lld", shown)}</span>
          </div>
          <p class="muted">{t("summary.score %lld %lld", summary.correct, summary.total)}</p>
          {(summary.streak > 1 || summary.streakGrew) && <p class="streak-pill">🔥 {t("summary.streak %lld", summary.streak)}</p>}
        </div>
        <BigButton color={color} onClick={onAgain} testId="summary-again">↻ {t("summary.again")}</BigButton>
        <BigButton color="rgba(43,37,64,.75)" onClick={onDone} testId="summary-done">⌂ {t("summary.done")}</BigButton>
      </div>
      <Confetti trigger={celebration} count={score >= 0.8 ? 70 : 40} />
    </main>
  );
}
