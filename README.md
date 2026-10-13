# Rival at the Wheel — Pokémon Emerald (expansion)

A two-player hack built on **[pokeemerald-expansion](https://github.com/rh-hideout/pokeemerald-expansion) 1.17.1**, which is Pokémon Emerald with a modern battle engine. Player 1 plays the game normally in mGBA, turbo included. Player 2 controls the opposing trainers in every trainer battle, from a phone or a PC anywhere on the internet.

On the trainer's turn, the game pauses and waits. Player 2 picks a move (and a target in double battles), uses one of the trainer's items, switches Pokémon, or lets the game's AI decide. When the trainer's Pokémon is able to, player 2 can also trigger **Mega Evolution, Z-Moves, Dynamax or Terastallization**.

```
 Player 1 (PC)                                          Player 2 (phone / PC)
┌───────────────────────────────┐   HTTP    ┌─────────┐   HTTPS   ┌──────────────┐
│ mGBA                          │◄─────────►│ tunnel  │◄─────────►│ web page     │
│  ├─ patched expansion ROM     │  :8888    │ (cloud- │           │ (moves, items│
│  └─ rival_at_the_wheel_emerald│           │ flared) │           │  switches,   │
│     .lua (web server inside   │           └─────────┘           │  gimmicks)   │
│      the emulator)            │                                 └──────────────┘
└───────────────────────────────┘
```

The story, maps and trainers are Emerald's. The battles use the expansion's modern engine: the Fairy type, a physical/special split per move, Pokémon, moves and abilities up to Gen 9, terrains, hazards and so on. The game is in English.

The same idea for plain FireRed: [rival-at-the-wheel-firered](https://github.com/giovannimazza/rival-at-the-wheel-firered).

## What's in this repository

| Path | What it is |
|---|---|
| `patches/RivalAtTheWheel_Emerald.bps` | Patch for Pokémon Emerald USA (SHA-1 `f3ae088181bf583e55daf962a92bb46f4f1d07b7`). The result is a 32 MB ROM. |
| `rival_at_the_wheel_emerald.lua` | The mGBA script: web server, game bridge and the player 2 page, all in one file |
| `start_tunnel.bat` | Windows helper that puts the script online through a free Cloudflare quick tunnel |
| `source/pokeemerald-expansion-rival-at-the-wheel.diff` | All game code changes, as a patch for pokeemerald-expansion `expansion/1.17.1` |
| `tools/` | Script templates, the player 2 page, data generators and a table-dump helper |

No ROMs are included. You need your own copy of the game.

> The game-side code uses the internal name *remote trainer* (`battle_remote.c`, `gRemoteControl`, ROM signature `REMOTE-TRAINER-2`). It's the same project.

## Requirements

- Your own **Pokémon Emerald (USA, English)** ROM. Other languages won't work.
- **mGBA 0.10.5 or newer** ([mgba.io](https://mgba.io)), which has Lua scripting.
- For internet play: **cloudflared**. `start_tunnel.bat` tries to install it with `winget`.

## Quick start

### 1. Patch the ROM (once)

1. Open [Rom Patcher JS](https://www.marcrobledo.com/RomPatcher.js/).
2. Select your Emerald ROM and `RivalAtTheWheel_Emerald.bps`, then click **Apply patch**.
3. The patched ROM is 32 MB, which is expected.

Save files from vanilla Emerald are **not** compatible. Start a new game.

### 2. Start the game (player 1)

1. Open the patched ROM in mGBA.
2. Go to **Tools → Scripting…**, then **File → Load script…** and choose `rival_at_the_wheel_emerald.lua`.
3. The scripting console shows `Patch detected` and a **6-character code** for player 2.

Load the script again each time you restart mGBA. To try it on the same PC, open `http://127.0.0.1:8888`.

### 3. Put it online

1. Double-click `start_tunnel.bat`. The first time, it installs cloudflared: close the window and run it again.
2. After a few seconds it prints an address like `https://random-words.trycloudflare.com`.
3. Send player 2 that address and the code. Keep the window open while you play.

There's no need to open router ports or touch the firewall. The address changes every time the tunnel restarts.

### 4. Playing as player 2

Open the link and enter the code. When player 1 starts a trainer battle, the page vibrates and beeps and shows **Your turn!**:

- **Moves**: type, category (Physical/Special/Status), PP, power, accuracy, priority, and an effectiveness hint using the modern type chart (x2, x½, x0). Tera types are taken into account. In double battles you also choose the target.
- **Gimmick button** (purple): it only appears when the active Pokémon can Mega Evolve, use a Z-Move, Dynamax or Terastallize. Turn it on, then pick the move. For Z-Moves, only compatible moves stay selectable.
- **Items**: the items that trainer carries. Items that would do nothing right now are greyed out.
- **Switch / Party**: switch Pokémon, or choose the next one after a faint.
- **Let the game's AI decide**, or the **Auto AI** switch for every decision.

The page also shows weather, terrains, Trick Room and similar room effects, screens, Tailwind, entry hazards, and modern volatile statuses (Taunt, Encore, Perish Song, frostbite…).

Player 2 sees everything about their own team. For player 1's Pokémon they only see what the game shows on screen.

Vanilla Emerald trainers don't carry Mega Stones or Z-Crystals, so the gimmick button only shows up if you give trainers those items, or for gimmicks your build enables.

## Settings

These are at the top of `rival_at_the_wheel_emerald.lua`:

```lua
local PORT = 8888        -- web server port
local CODE = nil         -- e.g. "PIKA42" for a fixed code; nil = random each time
local LOCAL_ONLY = true  -- false also accepts devices on your home network (LAN)
local AUTO_AI = false    -- true = start with the AI in control
```

If you change `PORT`, change it in `start_tunnel.bat` too.

## What is and isn't controlled

**Remote-controlled:** every trainer battle, including double battles and battles against two trainers at once.

**Unchanged:** wild Pokémon, Wally's catching tutorial, the Safari Zone, the Battle Palace (where the AI picks moves by design), link, recorded and multi battles.

**Notes:**
- The game waits forever for player 2, so turbo mode is safe.
- Don't **pause** mGBA, because the script stops with it.
- If cloudflared shows `Unable to reach the origin service ... [::1]:8888`, the tunnel is pointing at `localhost`, which Windows resolves to IPv6. The script's server only listens on IPv4, so the tunnel must use `http://127.0.0.1:8888`. The included `start_tunnel.bat` already does this.
- If a battle seems stuck, it's waiting for player 2. The mGBA console says so.

## How it works

### Game side (C, in the expansion)

`src/battle_controller_opponent.c` normally asks the AI what to do. With this patch, in trainer battles it calls into `src/battle_remote.c`:

1. It writes a **request** and a **battle snapshot** into a 632-byte mailbox in RAM (`gRemoteControl`). The snapshot covers both sides' active Pokémon (16-bit species, abilities and items; three types; tera type; active gimmick), the trainer's party and items, legal moves and switches, and field, side and hazard state.
2. It **polls** the mailbox every frame, without advancing the battle.
3. It **validates** the answer with the engine's own helpers. Move legality uses `CheckMoveLimitations` (Taunt, Encore, Choice items, Assault Vest, Gravity, Heal Block…). Switching uses `CanBattlerEscape`/`IsAbilityPreventingEscape` (Shed Shell is respected). Gimmicks are checked against the usable gimmick, and Z-Moves against `GetUsableZMove`. Items are checked by their battle effect, including revives.

A rejected answer re-posts the request with an error code that the page displays. An "AI" answer falls back to the expansion's normal AI for that decision.

Mailbox layout (little-endian, defined in `include/battle_remote.h`; the sizes and offsets are checked at compile time):

| Offset | Field |
|---|---|
| `0x000` | magic `"RCTL"` |
| `0x004` | `reqSeq`, `reqType` (1 action, 2 move, 3 replacement), `reqBattler`, `respSeq` |
| `0x008` | `respType` (1 move, 2 item, 3 switch, 4 AI), `respArg1`, `respArg2`, `lastError` |
| `0x00C` | battle type flags, trainer id, battler count, in-battle flag |
| `0x014` | trainer items, class and name |
| `0x038` | unusable-move mask, can-switch, usable-item mask, switchable-party mask, turn, absent flags |
| `0x03E` | `respFlags` (bit 0 = use gimmick), usable gimmick |
| `0x040` | field flags (weather, terrain, rooms, gravity), side flags (screens, hazards…) |
| `0x048` | protocol version (2), Z-Move mask, party size |
| `0x050` | 4 × 64-byte battler records |
| `0x150` | 6 × 48-byte party records |
| `0x270` | player 1's party summary (ok / status / fainted) |

### Emulator side (Lua)

`rival_at_the_wheel_emerald.lua` runs inside mGBA. It finds the patch through the signature string `REMOTE-TRAINER-2` in ROM, reads and writes the mailbox, and serves the page plus a small JSON API with mGBA's socket API:

- `GET /api/state?k=CODE` — current state
- `POST /api/choose` — `seq, type, a1, a2, g`
- `POST /api/auto` — `on=0|1`

Requests need the code, and stale requests are refused.

## Building from source

On Linux or WSL:

```sh
git clone --branch expansion/1.17.1 https://github.com/rh-hideout/pokeemerald-expansion
cd pokeemerald-expansion
# set up the toolchain as described in INSTALL.md
git apply /path/to/source/pokeemerald-expansion-rival-at-the-wheel.diff
make release          # pokeemerald-release.gba
```

The page needs the game's name and move tables. The expansion stores them in bitfield structs with pointers, so they're read at runtime:

1. Build a separate copy with `#define REMOTE_TEST_BOOT` added to `include/battle_remote.h`. In `src/main.c`, have `InitMainCallbacks` call `SetMainCallback2(CB2_RemoteTestBoot)` instead of `gInitialMainCB2`. This test build writes the tables into `gHeap` at boot, then starts a single and a double trainer battle.
2. Run it in mGBA with `tools/dump_tables.lua`, setting `HEAP` to `gHeap` from that build's `.map`. This saves `dump.bin`.
3. Generate the data and the script:

```sh
python3 tools/gen_gamedata.py test_build.gba dump.bin charmap.txt gamedata.json
python3 tools/build_lua.py gamedata.json rival_at_the_wheel_emerald.lua \
    "pokeemerald-expansion 1.17.1=pokeemerald-release.map:pokeemerald-release.gba"
flips --create --bps-delta emerald_original.gba pokeemerald-release.gba RivalAtTheWheel_Emerald.bps
```

`build_lua.py` finds the ROM signature by scanning the `.gba` file, because link-time optimization in release builds drops its map symbol. Building the release ROM from this diff reproduces the patched ROM byte for byte.

## Testing

The optimized release build was tested end to end in a headless mGBA, with a scripted player 1 and an HTTP client acting as player 2. The tests covered:

- **Roxanne** (given a Mega Aggron for testing): Mega Evolution from the page (Aggron → Mega Aggron), X Attack (+stage, item consumed), Potion, a voluntary switch, an AI-chosen replacement, and rejection of illegal answers (Potion at full HP, switching to the active Pokémon, stale requests);
- **Tate & Liza** double battle: target selection, and two simultaneous faint replacements where the second request correctly excludes the Pokémon picked by the first;
- **Auto AI** mode.

The page was driven in a headless Chromium, and a new game on the patched ROM reaches the overworld normally.

Not tested yet: battles against two trainers at once, Z-Moves, Dynamax and Terastallization (no test trainer used them), and a full playthrough with two real players.

## Credits

- [rh-hideout/pokeemerald-expansion](https://github.com/rh-hideout/pokeemerald-expansion), built on [pret/pokeemerald](https://github.com/pret/pokeemerald)
- [mGBA](https://mgba.io) — emulator and Lua scripting API
- [Floating IPS](https://github.com/Alcaro/Flips) — BPS patches
- [cloudflared](https://github.com/cloudflare/cloudflared) — quick tunnels

Pokémon is © Nintendo / Creatures Inc. / GAME FREAK inc. This is an unofficial fan project. It doesn't contain or distribute any ROM, and you must own the game to use it.
