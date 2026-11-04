# Vietnamese typing test (M2, Gate 1)

**Question:** can players type Vietnamese into the game's chat box in a web browser, on desktop and on phones?

The web build's title screen has two text boxes to compare:
- **Godot's box** (the default): Godot's own text field, drawn on the game canvas.
- **The browser's box:** turn on "Use the browser's text box" to lay a normal HTML text field over it. It uses the browser's own typing support, so input methods behave as they do on any website.

M4's chat screen uses whichever box works on more devices.

## What we know already (headless Chromium, 2026-11-04)

| Test | Godot's box | Browser's box |
|---|---|---|
| Plain key presses (`Chuong mon`) | Works | Works |
| Text committed the way input methods and phone keyboards commit it (`insertText`) | **Ignored**: the text never arrived | Works, as single precomposed letters |
| Decomposed input (letter plus separate tone mark) | — | Flagged as "Combining marks: yes" |

This is a strong hint that Godot's box may fail with some keyboards, but it is not proof. Real Telex and VNI tools differ: some send key presses, some commit text. Only real devices answer the question.

## Steps for each tester

1. Open the test build at https://haobui14.github.io/LittleMountainSect/. Developers can also serve the `web-build` artifact from any CI run locally.
2. Click **Tiếng Việt** if you like; the language doesn't affect typing.
3. **Godot's box:** click it and type the test sentence below with your usual Vietnamese keyboard.
4. Press **Copy report** and paste the report into the results table, or send it to the developer.
5. Turn on **Use the browser's text box**, type the same sentence, and copy that report too.

**Test sentence:** `Chưởng môn ơi, đệ tử muốn ăn bánh bao.`

It contains ư, ở, ô, ơ, đ, ệ, ử, ă and á, which covers every Vietnamese tone mark and most special letters.

**A box passes when:**
- the sentence shows exactly as typed, and
- the report says "Combining marks: no", and
- the code points show single letters: for example, ở is U+1EDF, not U+006F followed by U+031B and U+0309.

## Devices and keyboards to cover

| Device | Keyboard | Godot's box | Browser's box | Notes |
|---|---|---|---|---|
| Windows, Chrome | Unikey, Telex | | | |
| Windows, Chrome | Unikey, VNI | | | |
| Windows, Edge or Firefox | EVKey, Telex | | | |
| Windows | Windows' built-in Vietnamese keyboard | | | |
| macOS, Safari | Vietnamese – Telex (built in) | | | |
| macOS, Chrome | Vietnamese – Telex (built in) | | | |
| Android, Chrome | Gboard, Vietnamese Telex | | | |
| Android, Chrome | Laban Key | | | |
| iPhone, Safari | iOS Vietnamese keyboard (Telex) | | | |

**Gate 1 needs:** at least one box passes on desktop and on at least one phone. If only the browser's box passes, that's still a pass, and M4 uses the browser's box.

## Download size and load time

| Build file | Raw | Gzipped |
|---|---|---|
| `index.wasm` (the engine) | 38 MB | 9.7 MB |
| Everything else | 0.5 MB | 0.3 MB |
| **Total** | **39 MB** | **9.9 MB** |

- **GitHub Pages** compresses files, so players download about 10 MB. The live site confirms it: every file is sent gzipped, and the engine is 9.8 MB of the 10 MB. CI's deploy job prints these numbers after each publish.
- **itch.io** does not compress, so players would download about 39 MB, which is slow on a phone.

Measure the first load and a reload on each phone, and note the network (Wi-Fi or 4G):

| Device | Network | Host | First load | Reload |
|---|---|---|---|---|
| | | GitHub Pages | | |
| | | itch.io (optional) | | |

If 10 MB is still too slow, a custom Godot web build without unused engine modules can roughly halve the engine file. That is an M8 task.

## For developers: the automated check

`tools/web-check/typing_check.cjs` drives both boxes in headless Chromium and prints what the game's report says. It reads `window.lmsTypingReport`, which the web build publishes for this purpose. To run it, export the web build, serve `build/web` on port 8060, then:

```bash
node tools/web-check/typing_check.cjs http://127.0.0.1:8060/index.html /tmp 640 465 725 522
```

The last four numbers are the screen positions of Godot's box and the switch on the 1280×720 test screen.
