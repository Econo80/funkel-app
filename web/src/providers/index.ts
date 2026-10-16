import type { ContentLibrary } from "../content/library";
import type { SubjectDescriptor } from "../content/types";
import { MathsQuestionGenerator } from "./maths";
import type { QuestionProvider } from "./provider";
import { QuestionBankProvider } from "./questionBank";
import { VocabularyQuestionGenerator } from "./vocabulary";

export type { QuestionProvider } from "./provider";

/** Maps a subject's provider kind to its engine. */
export async function providerFor(subject: SubjectDescriptor, library: ContentLibrary): Promise<QuestionProvider> {
  switch (subject.provider) {
    case "maths":
      return new MathsQuestionGenerator(subject.id, await library.mathsContent(subject), await library.phrasing(subject.languageCode));
    case "wordList":
      return new VocabularyQuestionGenerator(subject.id, (await library.wordList(subject)).words, await library.phrasing(subject.languageCode));
    case "questionBank":
      return new QuestionBankProvider(subject.id, (await library.questionBank(subject)).questions);
  }
}
