// Written lines for when Claude is not used or fails. The game must stay
// playable without AI, so every failure has an in-character answer.
// Vietnamese is a draft until a native speaker reviews it (M7).

import type { Expression, Locale, Localized } from "./cast.ts";

export type FallbackReason = "no_energy" | "budget_cap" | "disabled" | "refusal" | "error";
export type Speaker = "disciple" | "elder";

interface Line {
  text: Localized;
  expression: Expression;
}

const SLEEPY: Line[] = [
  {
    text: {
      en: "*yawns* Master, the mountain's Spirit Energy is spent for today. Talk again tomorrow?",
      vi: "*ngáp dài* Sư phụ ơi, Linh khí trên núi hôm nay cạn rồi. Mai mình nói chuyện tiếp nhé?",
    },
    expression: "sad",
  },
  {
    text: {
      en:
        "*nods off mid-bow* Sorry, Master… no Spirit Energy left today. I'll be sharper tomorrow!",
      vi:
        "*đang cúi chào thì ngủ gật* Đệ tử xin lỗi… hôm nay hết Linh khí rồi. Mai đệ tử sẽ tỉnh táo hơn!",
    },
    expression: "nervous",
  },
];

const THIN_AIR: Line[] = [
  {
    text: {
      en:
        "The Spirit Energy on the mountain is thin today, Master. I can barely hear you. Tomorrow?",
      vi: "Linh khí trên núi hôm nay loãng quá, sư phụ ạ. Đệ tử nghe không rõ. Mai nhé?",
    },
    expression: "thinking",
  },
];

const CHANGES_SUBJECT: Line[] = [
  {
    text: {
      en:
        "*suddenly very interested in a passing cloud* Master, did you see that? Anyway, where were we?",
      vi:
        "*bỗng chăm chú nhìn một đám mây bay qua* Sư phụ thấy không? À mà… nãy mình đang nói gì nhỉ?",
    },
    expression: "nervous",
  },
  {
    text: {
      en: "Ah! I think I left the rice on the fire. Can we talk about something else, Master?",
      vi: "Á! Hình như đệ tử để quên nồi cơm trên bếp. Mình nói chuyện khác được không sư phụ?",
    },
    expression: "nervous",
  },
];

const WANDERED: Line[] = [
  {
    text: {
      en: "*scratches head* Sorry, Master, my mind wandered off like a lost duck. Say that again?",
      vi:
        "*gãi đầu* Đệ tử xin lỗi, đầu óc vừa đi lạc như vịt lạc đàn. Sư phụ nói lại được không ạ?",
    },
    expression: "nervous",
  },
];

const ELDER_LINES: Record<"rest" | "subject" | "wander", Line[]> = {
  rest: [{
    text: {
      en:
        "*strokes beard* Even an Elder must rest when the mountain's Spirit Energy runs dry. Tomorrow, Sect Master.",
      vi: "*vuốt râu* Linh khí trên núi cạn rồi, đến lão phu cũng phải nghỉ. Mai nhé, chưởng môn.",
    },
    expression: "thinking",
  }],
  subject: [{
    text: {
      en:
        "Patience the turtle advises against that question. Patience is very wise. Ask me another.",
      vi:
        "Rùa Nhẫn Nại khuyên lão phu đừng trả lời câu đó. Nhẫn Nại khôn lắm. Chưởng môn hỏi câu khác đi.",
    },
    expression: "thinking",
  }],
  wander: [{
    text: {
      en:
        "Hm? Forgive an old man, Sect Master. My thoughts drifted off to a tea house three centuries ago.",
      vi: "Hửm? Chưởng môn thứ lỗi cho lão phu. Đầu óc vừa trôi về một quán trà ba trăm năm trước.",
    },
    expression: "thinking",
  }],
};

function linesFor(reason: FallbackReason, speaker: Speaker): Line[] {
  if (speaker === "elder") {
    if (reason === "refusal") return ELDER_LINES.subject;
    if (reason === "error") return ELDER_LINES.wander;
    return ELDER_LINES.rest;
  }
  switch (reason) {
    case "no_energy":
      return SLEEPY;
    case "budget_cap":
    case "disabled":
      return THIN_AIR;
    case "refusal":
      return CHANGES_SUBJECT;
    case "error":
      return WANDERED;
  }
}

/** A written line for a failure. `pick` (0 to 1) chooses among the variants. */
export function fallbackLine(
  reason: FallbackReason,
  speaker: Speaker,
  locale: Locale,
  pick = Math.random(),
): { reply: string; expression: Expression } {
  const lines = linesFor(reason, speaker);
  const line = lines[Math.min(lines.length - 1, Math.floor(pick * lines.length))];
  return { reply: line.text[locale], expression: line.expression };
}
