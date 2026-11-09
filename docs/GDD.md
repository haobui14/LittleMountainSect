# Little Mountain Sect: Game Design Document

Nov 3, 2026 · @Hao Bui

## At a glance

Little Mountain Sect (working name) is a funny, warm management game set in a xianxia world. Xianxia is a Chinese fantasy genre about people who train to become immortal.

The player founds a small sect, which is a school for these trainees. Each in-game day, the player teaches disciples, builds the mountain, sends out missions, and deals with rival sects. Claude makes the disciples feel alive: they talk freely, make choices, remember the past, and create new stories.

The first version is a single-player web game made in Godot, planned for 13 weeks. It uses Claude Haiku 5.5. A $20 monthly budget covers about 38 to 75 daily players, so the AI limit is a core part of the design.

| Decision | Choice |
| --- | --- |
| Game type | Simulation and management |
| Setting | A sect in a xianxia world |
| Player role | New sect founder |
| Long-term goal | Open-ended sect story, with no fixed ending |
| Main activities | Teach disciples, build the sect, send missions, deal with other sects |
| Tone | Funny and warm |
| Time | Day by day |
| When things go badly | Serious setbacks only; disciples never die |
| Art style | Cute 2D characters |
| Claude's jobs | Free conversation, characters who decide, new events and stories, helper or advisor |
| AI limit | Spirit Energy that refills each real day |
| Who pays for AI | You pay, and the game is free for players |
| AI budget | Under $20 a month |
| Multiplayer | Single-player only |
| Project goal | Grow a community |
| Engine | Godot |
| Languages | English and Vietnamese |
| First version size | Medium (up to about 3 months) |
| Platform | Web browser first (recommended) |
| AI model | Claude Haiku 5.5 (recommended) |

The last two rows are recommendations. All other rows are your answers.

## Game vision

**Pitch:** Found a tiny sect on a leaky mountain. Raise strange, lovable disciples who talk back, remember everything, and cause trouble you never planned.

### Design pillars

1. **Every disciple is a person.** Each one has a voice, funny habits, and memories of the player.
2. **Small sect, big stories.** The fun comes from a few people you care about, not from huge numbers.
3. **Trouble, not tragedy.** Mistakes cost time and resources, but nobody dies.
4. **Rules keep it fair. Claude gives it life.** Code decides results. Claude decides words and personality.
5. **Always playable.** If Spirit Energy or the budget runs out, the game continues with written text.

### Target players

- **Main group:** Xianxia fans who read web novels or watch Chinese fantasy shows, in English or Vietnamese.
- **Second group:** Cozy management players who enjoy characters and small stories.
- **Not the target:** Players who want very deep, difficult systems.

### Similar games

| Game | Main focus | How this game differs |
| --- | --- | --- |
| [Amazing Cultivation Simulator](https://en.wikipedia.org/wiki/Amazing_Cultivation_Simulator) | Deep sect management, with "a massive learning curve" | Much simpler, with daily turns |
| [Immortal Life](https://nodal.gg/game/immortal-family-2013240) | Relaxed xianxia farming and life simulation | The player leads a whole sect |
| [Immortal Family](https://nodal.gg/game/immortal-family-2013240) | Clan management and growing numbers | Focus on a small cast of characters |
| [The Scroll of Taiwu](https://nodal.gg/game/immortal-family-2013240) | Martial arts story across generations of heirs | Lighter, funnier, and easier to start |

Amazing Cultivation Simulator [sold over 700,000 copies in China](https://en.wikipedia.org/wiki/Amazing_Cultivation_Simulator), which shows real demand for sect games.

The main difference here is free conversation with disciples who remember you. The pages checked do not mention this feature in these games, but nobody played them to confirm it.

## Core gameplay

The player is the founder, called the Sect Master. The target is about 3 minutes for each in-game day, and about 10 days in one play session.

### The start

The game begins with a leaky hut, 3 unknown disciples, a small bag of Spirit Stones, and one strange Elder. The first 5 days teach the game through the Elder's advice.

### The daily loop

&#91;embedded content: Daily loop: 5 steps, repeated each in-game day\]

The morning report comes from the evening story request, so it adds no extra AI cost. If Spirit Energy runs out, the blue steps use written text and the loop continues.

### Long-term progress

- **Days:** Finish missions, solve small problems, and keep disciples happy.
- **Seasons:** Win tournaments, upgrade buildings, and reach the next realm.
- **Years:** Raise the sect's rank from Unknown Mountain to Famous Sect, turn senior disciples into Elders, and fill the Sect Chronicle.

## Game systems

The first version stays small on purpose: 12 disciples, 8 buildings, 4 mission types, and 3 rival sects. These numbers are starting values, and playtests can change them.

### Disciples

The player starts with 3 disciples and can have up to 12. Each disciple has:

- **Stats:** Talent, Body, Spirit, and Wit. These numbers affect results.
- **Mood and Loyalty:** These change with how the player treats them.
- **Spirit root:** Metal, Wood, Water, Fire, or Earth. This sets their best techniques.
- **Quirks:** Funny traits, such as "afraid of chickens" or "sure he is the chosen one."
- **Memories:** Short notes about what happened to them.

Talking to a disciple can give a small Mood bonus, once per day. Chat matters, but players cannot repeat it for easy gains.

### Cultivation

Cultivation means training the body and spirit to gain power. Disciples move through 4 realms, or stages: Qi Refining, Foundation Building, Golden Core, and Nascent Soul.

Each breakthrough to a new realm is a risky test. Failure costs progress and adds a funny side effect, such as green hair for 10 days.

These are the starting values from M5, and every number is in `game/sim/balance.gd`:

- **Training** fills progress up to 100. It slows in each higher realm (×1, ×0.7, ×0.5, ×0.35), and each level of a disciple's technique adds 10%.
- **Breaking through** is a home task for a disciple at 100 progress.
  - The base chance is 35%, 20% or 5%, depending on the realm being left.
  - Each point of Talent + Spirit adds 3%, each Training Yard level 5%, and each point of Mood 1%.
  - The best pill in stock is used up and adds its bonus: a Foundation Pill adds 15%, a Golden Core Pill 30%.
  - The chance always stays between 5% and 95%.
- **Success:** the next realm, with +2 Mood and +2 Loyalty.
- **Failure:** −40 progress, −1 Mood, and one side effect for 5–10 days. The side effects are green hair, a squeaky voice, hiccups (weaker on missions), floating (half as useful at work), backwards qi (trains half as fast) and glowing at night (rests half as well).
- **Techniques:** each spirit root has one, such as the Iron Chopsticks Palm (Metal) or the Immovable Nap Stance (Earth). Disciples learn its levels by studying in the Library. Each level adds mission power and training speed.

### Buildings and resources

The sect uses 4 resources: Spirit Stones (money), Food, Herbs, and Reputation. The mountain is one screen with 8 fixed building slots, and each building has 3 levels.

| Building | What it does |
| --- | --- |
| Main Hall | Raises the sect's rank and disciple limit |
| Disciple Huts | Improves rest and recovery |
| Training Yard | Speeds up training |
| Spirit Field | Grows Food and Herbs |
| Kitchen | Turns Food into better Mood |
| Alchemy Room | Makes pills that help breakthroughs |
| Library | Teaches new techniques |
| Mission Hall | Unlocks harder missions |

**Starting values (M5).** Upgrades cost Spirit Stones. The Main Hall also needs Reputation, which isn't spent.

| Building | Level 1 / 2 / 3 | Effect |
| --- | --- | --- |
| Main Hall | Free at the start / 150 / 250, plus 15 / 50 Reputation | Unknown Mountain, Rising Sect, then Famous Sect. Room for 4, 8 or 12 disciples. A higher rank attracts more talented hopefuls |
| Kitchen | 40 / 100 / 200 | Fed disciples get +1, +1 or +2 Mood each evening. Meals cost a little more Food |
| Alchemy Room | 60 / 140 / 280 | One brew a day per level. Foundation Pill (level 1, 10 Herbs), Healing Pill (level 2, 8 Herbs and 10 Stones) and Golden Core Pill (level 3, 25 Herbs and 30 Stones). At most 9 of each |
| Library | 60 / 140 / 280 | Studying gains 10 + Wit a day. At 100, the disciple learns the next level of their technique, up to the Library's level |
| Mission Hall | 50 / 120 / 240 | Level 1 unlocks Escort a Merchant, level 2 Explore a Secret Realm. Level 3 gives +25% mission rewards |

**Growth.** From day 3, a hopeful comes to the gate every 4–7 days while the sect has room, and waits for 2 days. Taking them in costs 20 Spirit Stones plus 10 per disciple.

### Missions

The player sends a team of 1 to 4 disciples. Rules work out the result from stats, Mood, and a random roll. Claude then writes the story.

| Mission | Days | Risk | Main reward | Needs |
| --- | --- | --- | --- | --- |
| Gather Herbs | 1 to 2 | Low | Herbs and Food | — |
| Hunt a Monster | 2 to 3 | Medium | Spirit Stones | — |
| Escort a Merchant | 3 to 4 | Medium | Spirit Stones and Reputation | Mission Hall 1 |
| Explore a Secret Realm | 4 to 5 | High | Herbs, Reputation, and a random pill on a good result | Mission Hall 2 |

When a mission goes very badly, a disciple gets one of these setbacks:

- **Injured:** The disciple must rest for several days.
- **Lost cultivation:** The disciple loses some training progress.
- **Lost:** The disciple goes missing, and a rescue event starts.
- **Left the sect:** An unhappy disciple leaves, but may return later.

Disciples never die. A lost disciple comes home through the rescue event, and one who left returns after 5–15 days, with Mood 0 and Loyalty of at least 40.

### Surprise events

Small problems keep the days lively, such as a spirit goose that claims the Kitchen or a wandering master who offers a lesson.

- **When:** from day 3, each night after a cooldown of 2–3 days, with a 50% chance. The event waits for the player in the morning, before the day plan.
- **What:** the rules pick one of 20 problems (none of the last 5 again), a place the mountain has, and a pair of disciples at home. A lost disciple's rescue comes before anything else.
- **Choices:** each problem has 3 choices, and at least one is free. The rules roll the result and change resources, Mood, a relationship, progress, side effects, injuries or pills.
- **Words:** Claude writes the title, the story and the choices' text for 2 Spirit Energy, the night before. Without it, the game uses the written text for each problem.

### Other sects

Three rival sects share the region. Each has an Attitude score from -100 to 100. Example sects:

- **Iron Frog Sect:** Proud, loud, and always challenging someone.
- **Moonlit Tea Society:** Rich, polite, and secretly planning something.
- **Perfect Hair Pavilion:** Strong, but mainly worried about looking good.

The player can trade, send gifts, and form alliances. A tournament runs every season, and a season is 30 days. A friendly sect with low trust can betray the player by breaking a deal or stealing a technique.

Wars are big contests for land and Reputation. Losing costs resources and land, but nobody dies.

### Generations

The story has no fixed ending, and generations change without death:

- Senior disciples can become Elders who teach and give advice.
- Others can ascend to heaven or leave to travel, and they may send funny letters home.
- The Sect Chronicle records big events in a history book the player can read.

### After the first version

These ideas wait until players ask for them:

- More rival sects
- The founder retires, and the player chooses the next Sect Master
- Free building placement
- Phone apps

## Claude in the game

Claude never changes the game directly. It suggests words and actions, and code checks them before anything happens.

### Claude's four jobs

| Job | What the player sees | When it runs |
| --- | --- | --- |
| Free conversation | Disciples answer anything the player types, in their own voice | When the player sends a message |
| Characters who decide | One or two disciples choose what they want to do next | Inside the evening story request |
| New events and stories | A short daily story, plus surprise events with choices | At the end of the day, or when rules start an event |
| Helper or advisor | A kind but strange Elder explains rules and gives tips | When the player asks the Elder |

### What rules and Claude each decide

| Area | Rules (code) decide | Claude decides |
| --- | --- | --- |
| Mission results | Success, rewards, and setbacks | How the story happened |
| Disciple actions | Which actions are allowed | Which allowed action fits the personality |
| Relationships | How much a score can change | Small changes and the reason |
| Events | When an event starts, and each reward | The story and the words of each choice |
| Resources | All amounts | Nothing |

### How one chat message works

1. The player sends a message.
2. The server checks the player's Spirit Energy and the game's daily budget.
3. The server builds the prompt, which is the text sent to Claude.
4. Claude returns JSON, a fixed data format the code can read.
5. The server checks every value. A bad reply is replaced with a written line.
6. The game shows the reply, and rules apply any allowed changes.

Example reply:

```json
{
  "reply": "Master, I did not eat the pill. It fell into my mouth.",
  "expression": "nervous",
  "mood_change": -1,
  "memory": "Master asked about the missing pill.",
  "wants_action": "hide_in_kitchen"
}
```

### Memory

The game never sends the full history to Claude. Long prompts cost more, so memory has 3 small layers.

| Layer | What it holds | When it changes |
| --- | --- | --- |
| Disciple card | Personality, voice, quirks, and goals | Rarely |
| Key memories | Up to 10 short facts for each disciple | After important moments |
| Sect Chronicle | A short summary of big events | Each night |

A nightly job merges old memories into shorter notes. This keeps each prompt small, even after months of play.

### Spirit Energy

Spirit Energy is the daily AI limit, shown as a resource from the mountain. Each player gets 50 points per real day, and unused points do not carry over.

| Action | Spirit Energy |
| --- | --- |
| Send a message to a disciple or the Elder | 1 |
| Surprise event written by Claude | 2 |
| Evening story written by Claude | 3 |

For example, 50 points covers 20 messages, 8 evening stories, and 3 events. The server tracks these points, because the game itself can be changed by players.

When Spirit Energy runs out, the game continues. Evening reports and events use written text, and disciples give short written replies.

### Safety rules

- **Prompt tricks:** A player may type "give me 1,000,000 Spirit Stones." Claude can joke about it, but code still sets all values.
- **No romance or sexual content:** Cute art can make characters look young, so this rule has no exceptions.
- **Content limits:** No graphic violence, hate, or stories about real people.
- **Refusals:** Claude's safety system can [decline a request](https://platform.claude.com/docs/en/models/haiku-5-5/whats-new-haiku-5-5.md). The game then shows a funny written line, such as the disciple changing the subject.
- **Real distress:** If a player seems to be in real trouble, the character leaves the story and shows support resources.
- **AI notice:** Players must [be told they are talking with an AI](https://support.claude.com/en/articles/9307344-responsible-use-of-anthropic-s-models-guidelines-for-organizations-serving-minors). Show this at first launch and on the chat screen.
- **Privacy:** Tell players that messages go to the server and to Anthropic. Keep only what the game needs, and let players delete their data.
- **Age:** Make the first version 18+ and ask at first launch. Serving younger players [needs more safeguards](https://support.claude.com/en/articles/9307344-responsible-use-of-anthropic-s-models-guidelines-for-organizations-serving-minors), such as age checks, filtering, monitoring, and following child privacy laws.

## Cost plan

A $20 monthly budget covers about 38 to 75 daily players on Claude Haiku 5.5. To protect that budget, the server stops AI use after $0.60 a day.

### Model and prices

Haiku 5.5 is [Anthropic's lowest-cost current model](https://platform.claude.com/docs/en/models/haiku-5-5/overview.md). Sonnet 5.5 costs 20 times more, so the first version uses Haiku for everything.

A token is a small piece of text that AI models count and charge for. These prices apply to prompts up to 100,000 tokens. Longer prompts cost 5 times more.

| Type of use | Price per million tokens |
| --- | --- |
| New input | $0.10 |
| Output | $0.50 |
| Cached input | $0.01 |
| Saving input to the 5-minute cache | $0.125 |
| Batch input and output | $0.05 and $0.25 |

Prompt caching saves repeated text, such as world rules, so Claude can reuse it at a lower price. The Batch API gives [50% off for work that can wait](https://apidog.com/blog/claude-batch-api-run-async-jobs-at-half-the-cost/), up to 24 hours.

### Cost of each request

The token counts below were measured in the M2 eval ([rules-v3](evals/20261104-1621-rules-v3/report.md)), averaged over English and Vietnamese, with Haiku 5.5 at effort `low` and thinking off. Cached tokens are the shared rules at the start of every prompt. When no recent request saved them, they are charged as new input, which gives the "no cache" cost. The nightly memory job is still an estimate; it arrives in M5.

| Request | Cached tokens | New tokens | Output tokens | Cost | Cost, no cache | Spirit Energy |
| --- | --- | --- | --- | --- | --- | --- |
| Chat message | 3,200 | 230 | 190 | $0.00018 | $0.00044 | 1 |
| Surprise event | 2,400 | 370 | 360 | $0.00029 | $0.00046 | 2 |
| Evening story | 2,900 | 610 | 870 | $0.00058 | $0.00078 | 3 |
| Nightly memory job (batch) | 0 | 3,000 | 500 | $0.00034 | $0.00034 | None |

The shared rules grew to about 2,400 tokens, larger than first estimated, but replies came out shorter. Thinking is off because, in three eval runs, replies without it read as well and arrived faster.

### How far the budget goes

&#91;embedded content: Cost model in this document, using Claude Haiku 5.5 prices from November 2026\]

The plan keeps $2 as a safety reserve, so the spending cap is $18. Full use means each player spends all 50 Spirit Energy each day: 20 chat messages, 3 surprise events and 8 evening stories. The chart shows the first estimate, $0.015 a day.

Measured in M2, full use costs about $0.009 a day when caching works, which covers about 66 daily players, and $0.016 if caching never helps, which covers about 37. Real players spread out more than eval calls, so the true cost falls between the two. The Spirit Energy prices stay at 1, 2 and 3. The usage log will show real cache hits once beta players arrive.

### Protecting the budget

- **Daily cap:** Stop AI use for everyone after $0.60 a day. The game then uses written text until the next day.
- **Player limit:** The server enforces 50 Spirit Energy for each account.
- **Credit limit:** Keep auto-reload off in your Claude account, so spending cannot pass the credits you added.
- **Usage log:** Record the tokens and cost of every request, then check the numbers each week.

### Growing a community on a small budget

Growth needs more players than the AI budget can support, so the plan grows shared content first and live AI use later.

1. **Founding Disciples:** Start with 40 invited players. A small, named group feels special and gives better feedback.
2. **Shared world news:** Each night, a batch job writes 10 short events in each language for all players. This costs about $0.29 a month in total.
3. **Community space:** Open a Discord server with English and Vietnamese channels, and ask players to post funny moments.
4. **Flexible Spirit Energy:** Lower the daily amount as more players join. Moving from 50 to 25 points almost doubles capacity.
5. **More funding:** Above about 75 daily players, you need more budget, donations, or paid options.

## Art, audio, and language

Cute portraits and short text carry most of the game's feeling, which keeps art work small enough for 3 months.

### Art

- **Disciples:** Build each portrait from parts: body, hair, robe, and face. This makes many characters from few drawings.
- **Expressions:** Use 6 faces: happy, sad, angry, nervous, proud, and thinking. Claude picks one with each reply.
- **Mountain:** Use one illustrated screen. Buildings change as they level up, with small mist and bird animations.
- **Main screens:** Mountain, Disciples, Chat, Day Plan, Evening Story, Sect Chronicle, and Settings.
- **Style:** Soft colors, round shapes, and clear text on small windows.

### Audio

- **Music:** Calm loops with Chinese instruments, such as the guzheng (a long plucked zither) and flute.
- **Sound effects:** Short, playful sounds for menus, breakthroughs, and funny events.
- **Web limit:** Browsers can block sound until the player acts, so [start audio after the first click](https://docs.godotengine.org/de/4.4/_sources/tutorials/export/exporting_for_web.rst.txt).

### Language

The game launches in English and Vietnamese. The player chooses a language, and Claude replies in that language.

- **Menus:** Use Godot's translation system with a [CSV file](https://docs.godotengine.org/ja/4.3/_sources/tutorials/i18n/localization_using_gettext.rst.txt). CSV is a simple table format.
- **Font:** Choose a cute font with every Vietnamese mark, then test it on all screens.
- **Layout:** Leave extra room in buttons, because the two languages have different text lengths.
- **Typing:** Test Vietnamese typing tools, such as Telex and VNI, in the web chat box during week 1.
- **Word list:** Put the list below in Claude's shared prompt, so names stay the same.

| English | Vietnamese |
| --- | --- |
| Sect | Tông môn |
| Sect Master | Chưởng môn |
| Disciple | Đệ tử |
| Elder | Trưởng lão |
| Cultivation | Tu luyện |
| Spirit Stones | Linh thạch |
| Spirit Energy | Linh khí |
| Secret Realm | Bí cảnh |
| Qi Refining | Luyện Khí |
| Foundation Building | Trúc Cơ |
| Golden Core | Kim Đan |
| Nascent Soul | Nguyên Anh |
| Iron Frog Sect | Thiết Oa Tông |
| Moonlit Tea Society | Nguyệt Trà Hội |
| Perfect Hair Pavilion | Mỹ Phát Các |

This list is a first draft and needs a native speaker's review.

## Technical design

Build the game in Godot 4 with GDScript, export it to the web, and use Supabase as a small server. A web game is easy to test and share with one link, and Godot can add desktop builds later.

&#91;embedded content: System design: browser, server, and Claude API\]

The browser version is public, so anyone can inspect its files. The Claude API key must stay on the server.

### Godot web rules

These rules come from [Godot's web export guide](https://docs.godotengine.org/de/4.4/_sources/tutorials/export/exporting_for_web.rst.txt).

| Rule | Reason |
| --- | --- |
| Use GDScript, not C# | Godot 4 C# projects cannot export to the web |
| Use the Compatibility renderer | Web builds support only WebGL 2.0 |
| Keep the single-threaded export | It is the default and runs well on itch.io without special settings |
| Do not stream replies | Web requests do not support chunked responses, so show a "thinking" animation |
| Save to the server | Browser saves can fail in private mode or inside embedded pages |
| Allow the game's web address on the server | Browsers block requests between sites unless the server allows them |
| Test the download size early | itch.io does not compress files automatically, but GitHub Pages does |

Browsers also pause games in background tabs. This suits a turn-based game, but the server should keep finished replies so the game can load them later.

### Server

The [Supabase free plan](https://www.jetadmin.io/blog/supabase-pricing-2026-guide-to-plans-limits-and-real-world-costs/) can start the project. It includes a 500 MB database and 500,000 function calls a month. At 75 daily players with full use, the game makes about 70,000 Claude requests a month.

Free projects pause after 7 days without use, and they have no automatic backups. The paid plan costs $25 a month, which is outside the Claude budget.

[Anonymous sign-in](https://supabase.com/docs/guides/auth/auth-anonymous) lets players start without an email. Players lose an anonymous account if they clear browser data, so offer an email link later. Supabase strongly recommends CAPTCHA to stop abuse.

| Table | What it holds |
| --- | --- |
| players | Account, language, age check, and Spirit Energy |
| saves | Full game state as JSON |
| memories | Disciple memories and the Sect Chronicle |
| ai\_usage | Tokens and cost for each request |
| daily\_budget | Total Claude spending for each day |

### Claude API settings

These settings follow [Anthropic's Haiku 5.5 notes](https://platform.claude.com/docs/en/models/haiku-5-5/whats-new-haiku-5-5.md).

- **Model:** Use `claude-haiku-5-5`, and keep the name in one server setting.
- **Effort:** Start with low effort, then compare it with the default medium effort.
- **Output limit:** Thinking counts toward `max_tokens`, so leave extra room for the reply.
- **Unsupported settings:** Do not send `temperature`, `top_p`, or `top_k`.
- **Message order:** End the messages with a user turn, because prefilled assistant text returns an error.
- **Reading replies:** Select content by `type`, because a reply can start with thinking blocks.
- **Refusals:** Check for `stop_reason: "refusal"`. Haiku 5.5 has no automatic server fallback.
- **Caching:** Put shared rules first. The [minimum cached prompt](https://platform.claude.com/docs/en/models/haiku-5-5/overview.md) is 512 tokens.
- **Context:** Build each prompt from short memories. Long chat history keeps old thinking and raises costs.

## Roadmap

The plan has 4 phases over 13 weeks and assumes about 10 hours of work each week. If a gate fails, fix that problem before starting the next phase.

&#91;embedded content: Roadmap: 4 phases and 4 gates, not drawn to scale\]

### First tasks for Claude

Claude can write most of the code, prompts, and tests. Start with the tasks that test the riskiest ideas.

- [x] Run 10 test chats in English and 10 in Vietnamese with Haiku 5.5. Done in M2; the reports are in `docs/evals/`.
- [x] Measure real token counts for chat messages and evening stories. Done in M2; see the cost table.
- [ ] Build a Godot web test with a Vietnamese chat box, then try it on desktop and phone. The test is built and live; the device tests are next.
- [ ] Create a Godot project with one disciple, one full day loop, and a local save.
- [x] Create the Supabase AI gateway with Spirit Energy checks and the daily budget cap. Live since M2.

### Beta success measures

These are starting targets. Change them after the first playtest.

| Measure | Target |
| --- | --- |
| Players who return on day 7 | 30% or more |
| Messages per active player each day | 8 or more |
| AI cost per active player each day | $0.015 or less |
| Time to receive a reply | 5 seconds or less |
| Claude replies rejected by the server | Under 2% |
| Discord members by the end of the beta | 100 or more |

## Risks and open questions

The biggest risk is the conflict between growing a community and a $20 monthly budget. The two tests in week 1 matter next, because they decide whether the main idea works.

| Risk | Why it matters | Plan |
| --- | --- | --- |
| Budget limits growth | $20 covers only about 38 to 75 daily players | Start with invited players, keep the daily cap, and add shared content |
| Humor may be weak | Funny characters are the main reason to play | Test 10 chats in each language in week 1 before building more |
| Vietnamese typing may fail | Vietnamese players need the chat box to work well | Test in week 1. If it fails, try a browser text box through [JavaScriptBridge](https://docs.godotengine.org/de/4.4/_sources/tutorials/export/exporting_for_web.rst.txt) |
| 13 weeks is tight | The plan has a game, server, art, and two languages | Cut rival sects and buildings first, not disciple personality |
| Art takes too long | Cute characters are the first thing people see | Use simple placeholders until the game is fun |
| Stories feel repeated | Players quickly notice AI patterns | Give each story a random place, problem, and disciple pair |
| Bots use the budget | Free AI services attract abuse | Use invite codes, CAPTCHA, per-player limits, and the daily cap |
| Saves are lost | The free server plan has [no automatic backups](https://www.jetadmin.io/blog/supabase-pricing-2026-guide-to-plans-limits-and-real-world-costs/) | Export data weekly, or move to the paid plan |
| Model changes | Haiku 5.5 [can retire from October 7, 2027](https://platform.claude.com/docs/en/models/haiku-5-5/overview.md) | Keep the model name in one setting, and retest before switching |

### Open questions

- [ ] What is the final game name in English and Vietnamese?
- [ ] Who makes the art, and what is the art budget?
- [ ] How many hours can you work on this each week? The roadmap assumes about 10.
- [ ] Is server hosting separate from the $20 Claude budget?
- [ ] Do you have a Max or Team plan? These plans [may include monthly API credits](https://dev.to/hassann/claude-haiku-55-pricing-53cb), so check the official terms for use in a public game.
- [ ] Would you accept player donations if the community outgrows the budget?
- [ ] Should the game stay 18+? Cute art may attract younger players.
- [ ] Do you want a "Copy story" button? The game stays single-player, but sharing could help growth.

## Sources

All facts were checked on November 3, 2026. Anthropic's main pricing page and Supabase's own pricing page could not be opened, so those numbers come from the pages below. The Godot web page is the 4.4 version, so check it against your Godot version.

- [Claude Haiku 5.5 overview](https://platform.claude.com/docs/en/models/haiku-5-5/overview.md) (Anthropic)
- [What's new in Claude Haiku 5.5](https://platform.claude.com/docs/en/models/haiku-5-5/whats-new-haiku-5-5.md) (Anthropic)
- [Guidelines for organizations serving minors](https://support.claude.com/en/articles/9307344-responsible-use-of-anthropic-s-models-guidelines-for-organizations-serving-minors) (Anthropic)
- [Claude Batch API guide](https://apidog.com/blog/claude-batch-api-run-async-jobs-at-half-the-cost/) (Apidog)
- [Claude Haiku 5.5 pricing](https://dev.to/hassann/claude-haiku-55-pricing-53cb) (DEV Community)
- [Exporting for the Web](https://docs.godotengine.org/de/4.4/_sources/tutorials/export/exporting_for_web.rst.txt) (Godot docs)
- [Localization using gettext](https://docs.godotengine.org/ja/4.3/_sources/tutorials/i18n/localization_using_gettext.rst.txt) (Godot docs)
- [Anonymous sign-ins](https://supabase.com/docs/guides/auth/auth-anonymous) (Supabase docs)
- [Supabase pricing guide](https://www.jetadmin.io/blog/supabase-pricing-2026-guide-to-plans-limits-and-real-world-costs/) (Jet Admin)
- [Amazing Cultivation Simulator](https://en.wikipedia.org/wiki/Amazing_Cultivation_Simulator) (Wikipedia)
- [Games like Immortal Family](https://nodal.gg/game/immortal-family-2013240) (Nodal)
