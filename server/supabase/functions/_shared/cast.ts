// Fixed lists the prompts and schemas share: expressions, spirit roots,
// realms, quirks, the actions a character may ask for, and the Elder.
// Vietnamese text here is a draft until a native speaker reviews it (M7).

export type Locale = "en" | "vi";
export type Localized = Record<Locale, string>;

export const EXPRESSIONS = ["happy", "sad", "angry", "nervous", "proud", "thinking"] as const;
export type Expression = typeof EXPRESSIONS[number];

export const SPIRIT_ROOTS = ["metal", "wood", "water", "fire", "earth"] as const;
export type SpiritRoot = typeof SPIRIT_ROOTS[number];
export const SPIRIT_ROOT_NAMES: Record<SpiritRoot, Localized> = {
  metal: { en: "Metal", vi: "Kim" },
  wood: { en: "Wood", vi: "Mộc" },
  water: { en: "Water", vi: "Thủy" },
  fire: { en: "Fire", vi: "Hỏa" },
  earth: { en: "Earth", vi: "Thổ" },
};

export const REALMS = [
  "qi_refining",
  "foundation_building",
  "golden_core",
  "nascent_soul",
] as const;
export type Realm = typeof REALMS[number];
export const REALM_NAMES: Record<Realm, Localized> = {
  qi_refining: { en: "Qi Refining", vi: "Luyện Khí" },
  foundation_building: { en: "Foundation Building", vi: "Trúc Cơ" },
  golden_core: { en: "Golden Core", vi: "Kim Đan" },
  nascent_soul: { en: "Nascent Soul", vi: "Nguyên Anh" },
};

/** Actions a character may say they want to do next. The rules decide if it happens. */
export const ACTIONS = [
  "train",
  "rest",
  "meditate",
  "cook",
  "tend_field",
  "study",
  "explore",
  "hide",
] as const;
export type Action = typeof ACTIONS[number];

/** Funny traits. A disciple card names one to three of these by id. */
export const QUIRKS = {
  afraid_of_chickens: { en: "afraid of chickens", vi: "sợ gà" },
  chosen_one: { en: "certain they are the chosen one", vi: "tin chắc mình là người được chọn" },
  always_hungry: {
    en: "always hungry, especially while meditating",
    vi: "lúc nào cũng đói, nhất là khi đang thiền",
  },
  talks_to_sword: {
    en: "talks to their sword, which has never answered",
    vi: "hay nói chuyện với thanh kiếm, dù nó chưa từng đáp lời",
  },
  overly_polite: {
    en: "apologizes to doors after bumping into them",
    vi: "va vào cửa xong còn xin lỗi cái cửa",
  },
  secret_poet: { en: "writes terrible poems in secret", vi: "lén làm thơ dở tệ" },
  lazy_genius: {
    en: "brilliant, but naps through every lesson",
    vi: "thiên tài nhưng ngủ gật trong mọi buổi học",
  },
  gossip: { en: "knows every rumor on the mountain", vi: "biết hết mọi tin đồn trên núi" },
  competitive: {
    en: "turns everything into a competition",
    vi: "chuyện gì cũng biến thành cuộc thi",
  },
  clumsy_alchemist: {
    en: "every pill they make explodes a little",
    vi: "luyện viên đan nào cũng nổ một chút",
  },
  herb_whisperer: { en: "believes herbs have feelings", vi: "tin rằng thảo dược cũng có cảm xúc" },
  humble_bragger: {
    en: "brags by pretending to be humble",
    vi: "khoe khoang bằng cách giả vờ khiêm tốn",
  },
  stone_counter: {
    en: "counts Spirit Stones to fall asleep",
    vi: "phải đếm Linh thạch mới ngủ được",
  },
  dramatic: {
    en: "describes every scratch as a mortal wound",
    vi: "trầy xước nhẹ cũng kể như trọng thương",
  },
  grudge_keeper: {
    en: "keeps a list of everyone who ever insulted them",
    vi: "có cuốn sổ ghi tên tất cả những ai từng chê mình",
  },
  superstitious: { en: "reads omens in their breakfast", vi: "đọc điềm báo trong bữa sáng" },
  cloud_watcher: {
    en: "is convinced the clouds are spying on the sect",
    vi: "tin chắc mây đang theo dõi tông môn",
  },
  stray_collector: {
    en: "keeps adopting stray spirit beasts",
    vi: "hay nhặt linh thú hoang về nuôi",
  },
  honest_to_a_fault: {
    en: "cannot tell a lie, not even a kind one",
    vi: "không biết nói dối, kể cả lời nói dối thiện ý",
  },
  early_riser: {
    en: "wakes before the roosters and resents them for it",
    vi: "dậy sớm hơn cả gà trống và rất bực vì điều đó",
  },
} as const satisfies Record<string, Localized>;
export type QuirkId = keyof typeof QUIRKS;
export const QUIRK_IDS = Object.keys(QUIRKS) as [QuirkId, ...QuirkId[]];

/** The sect's one strange Elder. */
export const ELDER = {
  name: { en: "Elder Mo Wen", vi: "Mạc Vấn trưởng lão" },
  card: `Role: the sect's only Elder. Nobody knows how old he is, including him.
Personality: kind underneath, but strange. He answers questions with riddles first and then, \
a little grudgingly, with a clear and correct tip. His name means "don't ask", which he finds \
very funny. He claims to have ascended to heaven twice "by accident" and come back for the \
tea. He keeps a pet turtle named Patience (Vietnamese: Nhẫn Nại) that he consults on hard \
questions.
Speaking style: slow, warm, a little theatrical; gives advice as if it were ancient wisdom, \
even when it is obvious. Never mean.`,
  /** What the Elder knows about the game, so his tips are true. */
  knowledge: `How the sect works (use this to give correct tips):
- Each day: the morning report, then the Sect Master plans the day by sending each disciple \
to train, work, rest or go on a mission; free time to talk; then results and the evening story.
- Spirit Energy (Linh khí) powers talking and stories. It refills every real day.
- Disciples have Talent, Body, Spirit and Wit, plus Mood and Loyalty. Their spirit root \
(Metal, Wood, Water, Fire or Earth) decides their best techniques. Happy, rested disciples \
do better.
- Cultivation has four realms: Qi Refining, Foundation Building, Golden Core, Nascent Soul. \
Breakthroughs are risky: failure costs progress and causes a funny side effect for a while. \
Pills from the Alchemy Room help.
- Resources: Spirit Stones (money), Food, Herbs and Reputation.
- Buildings, each with three levels: Main Hall (rank and how many disciples), Disciple Huts \
(rest), Training Yard (faster training), Spirit Field (Food and Herbs), Kitchen (Food into \
Mood), Alchemy Room (pills), Library (techniques), Mission Hall (harder missions).
- Missions take teams of one to four: Gather Herbs (safe), Hunt a Monster and Escort a \
Merchant (some risk), Explore a Secret Realm (dangerous, best rewards). Bad luck means injury, \
lost progress, getting lost (a rescue follows) or an unhappy disciple leaving for a while. \
Nobody ever dies.
- Three rival sects: Iron Frog Sect, Moonlit Tea Society and Perfect Hair Pavilion. Trade, \
gifts and alliances change their attitude. A tournament ends every season of 30 days.
- Good early habits: build the Spirit Field early, keep disciples fed and rested before \
missions, and match missions to stats.`,
} as const;
