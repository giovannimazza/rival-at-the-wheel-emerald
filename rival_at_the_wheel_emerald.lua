-- ===========================================================================
--  RIVAL AT THE WHEEL - script for mGBA (0.10 or newer)
--  pokeemerald-expansion (built from Emerald USA) with the "Rival at the Wheel" patch.
--
--  Load this file in mGBA:  Tools > Scripting... > File > Load script
--  The second player opens the web page shown in the console and enters
--  the code. On the trainer's turn, the game waits for their choice.
-- ===========================================================================

-- -------------------------------- SETTINGS ---------------------------------
local PORT = 8888           -- web server port (change it if it's already in use)
local CODE = nil            -- e.g. "PIKA42" for a fixed code; nil = random
local LOCAL_ONLY = true     -- true: only the tunnel / this PC can connect. false: also other devices on your LAN
local AUTO_AI = false       -- true: start with the AI in control (player 2 can take over from the page)
-- ---------------------------------------------------------------------------

local SIGNATURE = "REMOTE-TRAINER-2"
local MAILBOX_SIZE = 0x278
local REMOTE_MAGIC = 0x4C544352

-- Addresses generated automatically for each patch build
local BUILDS = {
  { name = "pokeemerald-expansion 1.17.1", rc = 0x02020A78, sig = 0x08AB6270 },
}

-- Game character table (byte -> text)
local CHARMAP = {
  [0x00]=" ", [0x01]="À", [0x02]="Á", [0x03]="Â", [0x04]="Ç", [0x05]="È", [0x06]="É", [0x07]="Ê",
  [0x08]="Ë", [0x09]="Ì", [0x0A]="こ", [0x0B]="Î", [0x0C]="Ï", [0x0D]="Ò", [0x0E]="Ó", [0x0F]="Ô",
  [0x10]="Œ", [0x11]="Ù", [0x12]="Ú", [0x13]="Û", [0x14]="Ñ", [0x15]="ß", [0x16]="à", [0x17]="á",
  [0x18]="ね", [0x19]="ç", [0x1A]="è", [0x1B]="é", [0x1C]="ê", [0x1D]="ë", [0x1E]="ì", [0x1F]="ま",
  [0x20]="î", [0x21]="ï", [0x22]="ò", [0x23]="ó", [0x24]="ô", [0x25]="œ", [0x26]="ù", [0x27]="ú",
  [0x28]="û", [0x29]="ñ", [0x2A]="º", [0x2B]="ª", [0x2C]="わ", [0x2D]="&", [0x2E]="+", [0x2F]="ぁ",
  [0x30]="ぃ", [0x31]="ぅ", [0x32]="ぇ", [0x33]="ぉ", [0x34]="ゃ", [0x35]="=", [0x36]=";", [0x37]="が",
  [0x38]="ぎ", [0x39]="~", [0x3A]="げ", [0x3B]="ご", [0x3C]="ざ", [0x3D]="じ", [0x3E]="ず", [0x3F]="ぜ",
  [0x40]="ぞ", [0x41]="だ", [0x42]="ぢ", [0x43]="づ", [0x44]="で", [0x45]="ど", [0x46]="ば", [0x47]="び",
  [0x48]="ぶ", [0x49]="べ", [0x4A]="ぼ", [0x4B]="ぱ", [0x4C]="ぴ", [0x4D]="ぷ", [0x4E]="ぺ", [0x4F]="ぽ",
  [0x50]="っ", [0x51]="¿", [0x52]="¡", [0x53]="ウ", [0x54]="エ", [0x55]="オ", [0x56]="カ", [0x57]="キ",
  [0x58]="ク", [0x59]="ケ", [0x5A]="Í", [0x5B]="%", [0x5C]="(", [0x5D]=")", [0x5E]="セ", [0x5F]="ソ",
  [0x60]="タ", [0x61]="チ", [0x62]="ツ", [0x63]="テ", [0x64]="ト", [0x65]="ナ", [0x66]="ニ", [0x67]="ヌ",
  [0x68]="â", [0x69]="ノ", [0x6A]="ハ", [0x6B]="ヒ", [0x6C]="フ", [0x6D]="ヘ", [0x6E]="ホ", [0x6F]="í",
  [0x70]="ミ", [0x71]="ム", [0x72]="メ", [0x73]="モ", [0x74]="ヤ", [0x75]="ユ", [0x76]="ヨ", [0x77]="ラ",
  [0x78]="リ", [0x79]="ル", [0x7A]="レ", [0x7B]="ロ", [0x7C]="ワ", [0x7D]="ヲ", [0x7E]="ン", [0x7F]="ァ",
  [0x80]="ィ", [0x81]="ゥ", [0x82]="ェ", [0x83]="ォ", [0x84]="ャ", [0x85]="<", [0x86]=">", [0x87]="ガ",
  [0x88]="ギ", [0x89]="グ", [0x8A]="ゲ", [0x8B]="ゴ", [0x8C]="ザ", [0x8D]="ジ", [0x8E]="ズ", [0x8F]="ゼ",
  [0x90]="ゾ", [0x91]="ダ", [0x92]="ヂ", [0x93]="ヅ", [0x94]="デ", [0x95]="ド", [0x96]="バ", [0x97]="ビ",
  [0x98]="ブ", [0x99]="ベ", [0x9A]="ボ", [0x9B]="パ", [0x9C]="ピ", [0x9D]="プ", [0x9E]="ペ", [0x9F]="ポ",
  [0xA0]="ッ", [0xA1]="0", [0xA2]="1", [0xA3]="2", [0xA4]="3", [0xA5]="4", [0xA6]="5", [0xA7]="6",
  [0xA8]="7", [0xA9]="8", [0xAA]="9", [0xAB]="!", [0xAC]="?", [0xAD]=".", [0xAE]="-", [0xAF]="·",
  [0xB0]="…", [0xB1]="“", [0xB2]="”", [0xB3]="‘", [0xB4]="’", [0xB5]="♂", [0xB6]="♀", [0xB7]="¥",
  [0xB8]=",", [0xB9]="×", [0xBA]="/", [0xBB]="A", [0xBC]="B", [0xBD]="C", [0xBE]="D", [0xBF]="E",
  [0xC0]="F", [0xC1]="G", [0xC2]="H", [0xC3]="I", [0xC4]="J", [0xC5]="K", [0xC6]="L", [0xC7]="M",
  [0xC8]="N", [0xC9]="O", [0xCA]="P", [0xCB]="Q", [0xCC]="R", [0xCD]="S", [0xCE]="T", [0xCF]="U",
  [0xD0]="V", [0xD1]="W", [0xD2]="X", [0xD3]="Y", [0xD4]="Z", [0xD5]="a", [0xD6]="b", [0xD7]="c",
  [0xD8]="d", [0xD9]="e", [0xDA]="f", [0xDB]="g", [0xDC]="h", [0xDD]="i", [0xDE]="j", [0xDF]="k",
  [0xE0]="l", [0xE1]="m", [0xE2]="n", [0xE3]="o", [0xE4]="p", [0xE5]="q", [0xE6]="r", [0xE7]="s",
  [0xE8]="t", [0xE9]="u", [0xEA]="v", [0xEB]="w", [0xEC]="x", [0xED]="y", [0xEE]="z", [0xEF]="▶",
  [0xF0]=":", [0xF1]="Ä", [0xF2]="Ö", [0xF3]="Ü", [0xF4]="ä", [0xF5]="ö", [0xF6]="ü", [0xFF]="$",
}

local HTML = [==========[
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="theme-color" content="#14161c">
<title>Rival at the Wheel · Emerald</title>
<style>
:root {
  --bg: #14161c; --panel: #1d2029; --panel2: #262a35; --line: #333847;
  --text: #eceef3; --muted: #9aa1b2; --accent: #ffcb05; --danger: #ff5a5f;
  --ok: #46d17d; --warn: #ffb547; --blue: #4ea8ff;
  --radius: 14px;
}
* { box-sizing: border-box; }
html, body { margin: 0; background: var(--bg); color: var(--text);
  font: 15px/1.35 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
body { padding: 0 0 120px; }
button { font: inherit; color: inherit; }
.wrap { max-width: 760px; margin: 0 auto; padding: 0 16px; }
header { position: sticky; top: 0; z-index: 5; background: rgba(20,22,28,.94);
  backdrop-filter: blur(6px); border-bottom: 1px solid var(--line); }
header .wrap { display: flex; align-items: center; gap: 10px; min-height: 56px; }
.logo { font-weight: 800; letter-spacing: .5px; font-size: 16px; white-space: nowrap; }
.logo span { color: var(--accent); }
.dot { width: 10px; height: 10px; border-radius: 50%; background: var(--muted); flex: none; }
.dot.on { background: var(--ok); box-shadow: 0 0 8px var(--ok); }
.dot.off { background: var(--danger); }
.spacer { flex: 1; }
.toggle { display: flex; align-items: center; gap: 8px; font-size: 13px; color: var(--muted); cursor: pointer; user-select: none; }
.toggle input { display: none; }
.toggle .sw { width: 38px; height: 22px; border-radius: 11px; background: var(--panel2); border: 1px solid var(--line); position: relative; transition: .2s; }
.toggle .sw::after { content: ""; position: absolute; top: 2px; left: 2px; width: 16px; height: 16px; border-radius: 50%; background: var(--muted); transition: .2s; }
.toggle input:checked + .sw { background: #3a3215; border-color: var(--accent); }
.toggle input:checked + .sw::after { left: 18px; background: var(--accent); }

.banner { margin: 16px 0; padding: 16px 18px; border-radius: var(--radius); background: var(--panel);
  border: 1px solid var(--line); display: flex; gap: 14px; align-items: center; }
.banner .big { font-size: 19px; font-weight: 800; }
.banner .small { color: var(--muted); font-size: 13px; margin-top: 2px; }
.banner.turn { background: linear-gradient(135deg, #3d3410, #2a2412); border-color: var(--accent); animation: glow 1.6s ease-in-out infinite; }
.banner.turn .big { color: var(--accent); }
.banner.err { border-color: var(--danger); background: #2b1719; }
@keyframes glow { 50% { box-shadow: 0 0 0 4px rgba(255,203,5,.15); } }
.icon { font-size: 26px; width: 34px; text-align: center; flex: none; }

h2 { font-size: 12px; text-transform: uppercase; letter-spacing: 1.2px; color: var(--muted); margin: 22px 0 8px; font-weight: 700; }
.card { background: var(--panel); border: 1px solid var(--line); border-radius: var(--radius); padding: 12px 14px; }
.grid2 { display: grid; grid-template-columns: 1fr; gap: 10px; }
@media (min-width: 600px) { .grid2 { grid-template-columns: 1fr 1fr; } }

.mon { display: flex; flex-direction: column; gap: 6px; }
.mon.dim { opacity: .45; }
.mon .top { display: flex; align-items: baseline; gap: 8px; flex-wrap: wrap; }
.mon .name { font-weight: 800; font-size: 16px; }
.mon .lv { color: var(--muted); font-size: 13px; }
.mon .tag { font-size: 11px; color: var(--muted); border: 1px solid var(--line); border-radius: 6px; padding: 1px 6px; }
.hp { height: 8px; background: #0e1015; border-radius: 4px; overflow: hidden; }
.hp > i { display: block; height: 100%; background: var(--ok); border-radius: 4px; transition: width .4s; }
.hp > i.mid { background: var(--warn); } .hp > i.low { background: var(--danger); }
.hptext { font-size: 12px; color: var(--muted); display: flex; justify-content: space-between; gap: 8px; }
.chips { display: flex; flex-wrap: wrap; gap: 4px; }
.type { font-size: 10.5px; font-weight: 800; letter-spacing: .4px; padding: 2px 7px; border-radius: 5px; color: #fff; text-shadow: 0 1px 1px rgba(0,0,0,.35); }
.st { font-size: 10.5px; font-weight: 800; padding: 2px 7px; border-radius: 5px; background: #444; color: #fff; }
.st.psn { background: #a040a0; } .st.brn { background: #f08030; } .st.frz { background: #6ac6e8; color: #111; }
.st.par { background: #e0c020; color: #111; } .st.slp { background: #8a8a9a; } .st.tox { background: #702a8a; } .st.fnt { background: #3a3a3a; color: #bbb; }
.st.misc { background: #2f3646; color: #cdd3e1; }
.st.gim { background: linear-gradient(135deg,#7b5cff,#ff5cb8); color: #fff; }
.gimmick-btn { width: 100%; margin: 0 0 10px; background: var(--panel2); border: 2px solid #5a4bb0; color: #cfc6ff; border-radius: 12px; padding: 11px; cursor: pointer; font-weight: 800; }
.gimmick-btn.on { background: linear-gradient(135deg,#4a37c9,#b03a85); border-color: #ff8ad0; color: #fff; }
.stage { font-size: 11px; padding: 1px 6px; border-radius: 5px; background: #23324a; color: #9cc8ff; }
.stage.neg { background: #4a2328; color: #ffaab0; }
.meta { font-size: 12px; color: var(--muted); }

.choices { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
.choice { text-align: left; background: var(--panel2); border: 2px solid transparent; border-radius: 12px; padding: 10px 12px;
  cursor: pointer; min-height: 64px; display: flex; flex-direction: column; gap: 4px; transition: transform .08s, border-color .15s; }
.choice:active { transform: scale(.98); }
.choice .t { font-weight: 800; font-size: 15px; }
.choice .s { font-size: 12px; color: var(--muted); display: flex; gap: 6px; flex-wrap: wrap; align-items: center; }
.choice.sel { border-color: var(--accent); background: #34301c; }
.choice:disabled { opacity: .35; cursor: not-allowed; }
.choice.wide { grid-column: 1 / -1; }
.eff { font-size: 10.5px; font-weight: 800; padding: 1px 6px; border-radius: 5px; }
.eff.x2 { background: #1f4d2e; color: #7dffa6; } .eff.x4 { background: #145c2c; color: #a6ffc2; }
.eff.half { background: #4d3a1f; color: #ffc777; } .eff.zero { background: #4d1f22; color: #ff9da1; }
.tabs { display: flex; gap: 6px; margin: 4px 0 10px; overflow-x: auto; }
.tabs button { background: var(--panel2); border: 1px solid var(--line); border-radius: 20px; padding: 7px 14px; cursor: pointer; white-space: nowrap; font-weight: 700; font-size: 13px; }
.tabs button.on { background: var(--accent); color: #1a1600; border-color: var(--accent); }
.note { font-size: 12.5px; color: var(--muted); margin: 8px 2px 0; }
.ai-btn { width: 100%; margin-top: 10px; background: transparent; border: 1px dashed #4a5064; color: var(--muted); border-radius: 12px; padding: 11px; cursor: pointer; font-weight: 700; }
.ai-btn.sel { border-style: solid; border-color: var(--accent); color: var(--accent); }

.confirm { position: fixed; left: 0; right: 0; bottom: 0; z-index: 10; background: rgba(20,22,28,.97);
  border-top: 1px solid var(--line); padding: 12px 16px calc(12px + env(safe-area-inset-bottom)); transform: translateY(110%); visibility: hidden; transition: transform .2s, visibility .2s; }
.confirm.show { transform: none; visibility: visible; }
.confirm .wrap { display: flex; gap: 10px; align-items: center; padding: 0; }
.confirm .what { flex: 1; font-size: 14px; } .confirm .what b { color: var(--accent); }
.btn { border: 0; border-radius: 12px; padding: 13px 20px; font-weight: 800; cursor: pointer; }
.btn.go { background: var(--accent); color: #1a1600; } .btn.no { background: var(--panel2); }
.btn:disabled { opacity: .5; }

.party { display: flex; flex-direction: column; gap: 8px; }
.prow { display: grid; grid-template-columns: 1fr auto; gap: 4px 10px; background: var(--panel); border: 1px solid var(--line); border-radius: 12px; padding: 10px 12px; }
.prow.field { border-color: #4b5570; }
.prow .moves { grid-column: 1 / -1; display: flex; flex-wrap: wrap; gap: 4px; }
.mv { font-size: 11.5px; background: var(--panel2); border-radius: 6px; padding: 2px 7px; color: #c9cfdc; }
.balls { display: flex; gap: 6px; }
.ball { width: 14px; height: 14px; border-radius: 50%; border: 2px solid #555; background: #222; }
.ball.ok { background: linear-gradient(#ff5050 50%, #fff 50%); border-color: #222; }
.ball.stat { background: linear-gradient(#e0a020 50%, #fff 50%); border-color: #222; }
.ball.fnt { background: #444; border-color: #333; }

.login { max-width: 380px; margin: 12vh auto 0; text-align: center; padding: 0 16px; }
.login h1 { font-size: 26px; margin: 0 0 6px; } .login h1 span { color: var(--accent); }
.login p { color: var(--muted); }
.login input { width: 100%; font: 800 26px/1 ui-monospace, monospace; letter-spacing: 6px; text-align: center; text-transform: uppercase;
  background: var(--panel); color: var(--text); border: 2px solid var(--line); border-radius: 14px; padding: 16px; margin: 14px 0; }
.login input:focus { outline: none; border-color: var(--accent); }
.login .btn { width: 100%; }
.toast { position: fixed; left: 50%; top: 70px; transform: translateX(-50%); background: var(--danger); color: #fff; padding: 10px 16px; border-radius: 10px; font-weight: 700; z-index: 20; box-shadow: 0 6px 20px rgba(0,0,0,.4); max-width: 90vw; }
.hidden { display: none !important; }
.modal-bg { position: fixed; inset: 0; background: rgba(0,0,0,.6); z-index: 30; display: flex; align-items: flex-end; justify-content: center; }
.modal { background: var(--panel); width: 100%; max-width: 520px; border-radius: 18px 18px 0 0; padding: 16px 16px calc(18px + env(safe-area-inset-bottom)); }
.modal h3 { margin: 4px 0 12px; }
</style>
</head>
<body>

<div id="login" class="login hidden">
  <h1>Rival at <span>the Wheel</span></h1>
  <p>Enter the code player 1 sees in the mGBA scripting console.</p>
  <input id="codeInput" maxlength="12" autocomplete="off" autocapitalize="characters" spellcheck="false" placeholder="CODE">
  <button class="btn go" id="codeBtn">Join</button>
  <p id="loginErr" style="color:var(--danger)"></p>
</div>

<div id="app" class="hidden">
  <header><div class="wrap">
    <div class="dot" id="dot"></div>
    <div class="logo">Rival at <span>the Wheel</span></div>
    <div class="spacer"></div>
    <label class="toggle" title="The game's AI chooses for you"><input type="checkbox" id="autoAi"><span class="sw"></span>Auto AI</label>
  </div></header>
  <main class="wrap">
    <div id="banner"></div>
    <div id="action"></div>
    <div id="field"></div>
    <div id="partyBox"></div>
  </main>
</div>

<div class="confirm" id="confirm"><div class="wrap">
  <div class="what" id="confirmWhat"></div>
  <button class="btn no" id="cancelBtn">Cancel</button>
  <button class="btn go" id="sendBtn">Confirm</button>
</div></div>

<div id="modalRoot"></div>
<div id="toast" class="toast hidden"></div>

<script>
const GAME = {"species":["","Bulbasaur","Ivysaur","Venusaur","Charmander","Charmeleon","Charizard","Squirtle","Wartortle","Blastoise","Caterpie","Metapod","Butterfree","Weedle","Kakuna","Beedrill","Pidgey","Pidgeotto","Pidgeot","Rattata","Raticate","Spearow","Fearow","Ekans","Arbok","Pikachu","Raichu","Sandshrew","Sandslash","Nidoran♀","Nidorina","Nidoqueen","Nidoran♂","Nidorino","Nidoking","Clefairy","Clefable","Vulpix","Ninetales","Jigglypuff","Wigglytuff","Zubat","Golbat","Oddish","Gloom","Vileplume","Paras","Parasect","Venonat","Venomoth","Diglett","Dugtrio","Meowth","Persian","Psyduck","Golduck","Mankey","Primeape","Growlithe","Arcanine","Poliwag","Poliwhirl","Poliwrath","Abra","Kadabra","Alakazam","Machop","Machoke","Machamp","Bellsprout","Weepinbell","Victreebel","Tentacool","Tentacruel","Geodude","Graveler","Golem","Ponyta","Rapidash","Slowpoke","Slowbro","Magnemite","Magneton","Farfetch’d","Doduo","Dodrio","Seel","Dewgong","Grimer","Muk","Shellder","Cloyster","Gastly","Haunter","Gengar","Onix","Drowzee","Hypno","Krabby","Kingler","Voltorb","Electrode","Exeggcute","Exeggutor","Cubone","Marowak","Hitmonlee","Hitmonchan","Lickitung","Koffing","Weezing","Rhyhorn","Rhydon","Chansey","Tangela","Kangaskhan","Horsea","Seadra","Goldeen","Seaking","Staryu","Starmie","Mr. Mime","Scyther","Jynx","Electabuzz","Magmar","Pinsir","Tauros","Magikarp","Gyarados","Lapras","Ditto","Eevee","Vaporeon","Jolteon","Flareon","Porygon","Omanyte","Omastar","Kabuto","Kabutops","Aerodactyl","Snorlax","Articuno","Zapdos","Moltres","Dratini","Dragonair","Dragonite","Mewtwo","Mew","Chikorita","Bayleef","Meganium","Cyndaquil","Quilava","Typhlosion","Totodile","Croconaw","Feraligatr","Sentret","Furret","Hoothoot","Noctowl","Ledyba","Ledian","Spinarak","Ariados","Crobat","Chinchou","Lanturn","Pichu","Cleffa","Igglybuff","Togepi","Togetic","Natu","Xatu","Mareep","Flaaffy","Ampharos","Bellossom","Marill","Azumarill","Sudowoodo","Politoed","Hoppip","Skiploom","Jumpluff","Aipom","Sunkern","Sunflora","Yanma","Wooper","Quagsire","Espeon","Umbreon","Murkrow","Slowking","Misdreavus","Unown","Wobbuffet","Girafarig","Pineco","Forretress","Dunsparce","Gligar","Steelix","Snubbull","Granbull","Qwilfish","Scizor","Shuckle","Heracross","Sneasel","Teddiursa","Ursaring","Slugma","Magcargo","Swinub","Piloswine","Corsola","Remoraid","Octillery","Delibird","Mantine","Skarmory","Houndour","Houndoom","Kingdra","Phanpy","Donphan","Porygon2","Stantler","Smeargle","Tyrogue","Hitmontop","Smoochum","Elekid","Magby","Miltank","Blissey","Raikou","Entei","Suicune","Larvitar","Pupitar","Tyranitar","Lugia","Ho-Oh","Celebi","Treecko","Grovyle","Sceptile","Torchic","Combusken","Blaziken","Mudkip","Marshtomp","Swampert","Poochyena","Mightyena","Zigzagoon","Linoone","Wurmple","Silcoon","Beautifly","Cascoon","Dustox","Lotad","Lombre","Ludicolo","Seedot","Nuzleaf","Shiftry","Taillow","Swellow","Wingull","Pelipper","Ralts","Kirlia","Gardevoir","Surskit","Masquerain","Shroomish","Breloom","Slakoth","Vigoroth","Slaking","Nincada","Ninjask","Shedinja","Whismur","Loudred","Exploud","Makuhita","Hariyama","Azurill","Nosepass","Skitty","Delcatty","Sableye","Mawile","Aron","Lairon","Aggron","Meditite","Medicham","Electrike","Manectric","Plusle","Minun","Volbeat","Illumise","Roselia","Gulpin","Swalot","Carvanha","Sharpedo","Wailmer","Wailord","Numel","Camerupt","Torkoal","Spoink","Grumpig","Spinda","Trapinch","Vibrava","Flygon","Cacnea","Cacturne","Swablu","Altaria","Zangoose","Seviper","Lunatone","Solrock","Barboach","Whiscash","Corphish","Crawdaunt","Baltoy","Claydol","Lileep","Cradily","Anorith","Armaldo","Feebas","Milotic","Castform","Kecleon","Shuppet","Banette","Duskull","Dusclops","Tropius","Chimecho","Absol","Wynaut","Snorunt","Glalie","Spheal","Sealeo","Walrein","Clamperl","Huntail","Gorebyss","Relicanth","Luvdisc","Bagon","Shelgon","Salamence","Beldum","Metang","Metagross","Regirock","Regice","Registeel","Latias","Latios","Kyogre","Groudon","Rayquaza","Jirachi","Deoxys","Turtwig","Grotle","Torterra","Chimchar","Monferno","Infernape","Piplup","Prinplup","Empoleon","Starly","Staravia","Staraptor","Bidoof","Bibarel","Kricketot","Kricketune","Shinx","Luxio","Luxray","Budew","Roserade","Cranidos","Rampardos","Shieldon","Bastiodon","Burmy","Wormadam","Mothim","Combee","Vespiquen","Pachirisu","Buizel","Floatzel","Cherubi","Cherrim","Shellos","Gastrodon","Ambipom","Drifloon","Drifblim","Buneary","Lopunny","Mismagius","Honchkrow","Glameow","Purugly","Chingling","Stunky","Skuntank","Bronzor","Bronzong","Bonsly","Mime Jr.","Happiny","Chatot","Spiritomb","Gible","Gabite","Garchomp","Munchlax","Riolu","Lucario","Hippopotas","Hippowdon","Skorupi","Drapion","Croagunk","Toxicroak","Carnivine","Finneon","Lumineon","Mantyke","Snover","Abomasnow","Weavile","Magnezone","Lickilicky","Rhyperior","Tangrowth","Electivire","Magmortar","Togekiss","Yanmega","Leafeon","Glaceon","Gliscor","Mamoswine","Porygon-Z","Gallade","Probopass","Dusknoir","Froslass","Rotom","Uxie","Mesprit","Azelf","Dialga","Palkia","Heatran","Regigigas","Giratina","Cresselia","Phione","Manaphy","Darkrai","Shaymin","Arceus","Victini","Snivy","Servine","Serperior","Tepig","Pignite","Emboar","Oshawott","Dewott","Samurott","Patrat","Watchog","Lillipup","Herdier","Stoutland","Purrloin","Liepard","Pansage","Simisage","Pansear","Simisear","Panpour","Simipour","Munna","Musharna","Pidove","Tranquill","Unfezant","Blitzle","Zebstrika","Roggenrola","Boldore","Gigalith","Woobat","Swoobat","Drilbur","Excadrill","Audino","Timburr","Gurdurr","Conkeldurr","Tympole","Palpitoad","Seismitoad","Throh","Sawk","Sewaddle","Swadloon","Leavanny","Venipede","Whirlipede","Scolipede","Cottonee","Whimsicott","Petilil","Lilligant","Basculin","Sandile","Krokorok","Krookodile","Darumaka","Darmanitan","Maractus","Dwebble","Crustle","Scraggy","Scrafty","Sigilyph","Yamask","Cofagrigus","Tirtouga","Carracosta","Archen","Archeops","Trubbish","Garbodor","Zorua","Zoroark","Minccino","Cinccino","Gothita","Gothorita","Gothitelle","Solosis","Duosion","Reuniclus","Ducklett","Swanna","Vanillite","Vanillish","Vanilluxe","Deerling","Sawsbuck","Emolga","Karrablast","Escavalier","Foongus","Amoonguss","Frillish","Jellicent","Alomomola","Joltik","Galvantula","Ferroseed","Ferrothorn","Klink","Klang","Klinklang","Tynamo","Eelektrik","Eelektross","Elgyem","Beheeyem","Litwick","Lampent","Chandelure","Axew","Fraxure","Haxorus","Cubchoo","Beartic","Cryogonal","Shelmet","Accelgor","Stunfisk","Mienfoo","Mienshao","Druddigon","Golett","Golurk","Pawniard","Bisharp","Bouffalant","Rufflet","Braviary","Vullaby","Mandibuzz","Heatmor","Durant","Deino","Zweilous","Hydreigon","Larvesta","Volcarona","Cobalion","Terrakion","Virizion","Tornadus","Thundurus","Reshiram","Zekrom","Landorus","Kyurem","Keldeo","Meloetta","Genesect","Chespin","Quilladin","Chesnaught","Fennekin","Braixen","Delphox","Froakie","Frogadier","Greninja","Bunnelby","Diggersby","Fletchling","Fletchinder","Talonflame","Scatterbug","Spewpa","Vivillon","Litleo","Pyroar","Flabébé","Floette","Florges","Skiddo","Gogoat","Pancham","Pangoro","Furfrou","Espurr","Meowstic","Honedge","Doublade","Aegislash","Spritzee","Aromatisse","Swirlix","Slurpuff","Inkay","Malamar","Binacle","Barbaracle","Skrelp","Dragalge","Clauncher","Clawitzer","Helioptile","Heliolisk","Tyrunt","Tyrantrum","Amaura","Aurorus","Sylveon","Hawlucha","Dedenne","Carbink","Goomy","Sliggoo","Goodra","Klefki","Phantump","Trevenant","Pumpkaboo","Gourgeist","Bergmite","Avalugg","Noibat","Noivern","Xerneas","Yveltal","Zygarde","Diancie","Hoopa","Volcanion","Rowlet","Dartrix","Decidueye","Litten","Torracat","Incineroar","Popplio","Brionne","Primarina","Pikipek","Trumbeak","Toucannon","Yungoos","Gumshoos","Grubbin","Charjabug","Vikavolt","Crabrawler","Crabominable","Oricorio","Cutiefly","Ribombee","Rockruff","Lycanroc","Wishiwashi","Mareanie","Toxapex","Mudbray","Mudsdale","Dewpider","Araquanid","Fomantis","Lurantis","Morelull","Shiinotic","Salandit","Salazzle","Stufful","Bewear","Bounsweet","Steenee","Tsareena","Comfey","Oranguru","Passimian","Wimpod","Golisopod","Sandygast","Palossand","Pyukumuku","Type: Null","Silvally","Minior","Komala","Turtonator","Togedemaru","Mimikyu","Bruxish","Drampa","Dhelmise","Jangmo-o","Hakamo-o","Kommo-o","Tapu Koko","Tapu Lele","Tapu Bulu","Tapu Fini","Cosmog","Cosmoem","Solgaleo","Lunala","Nihilego","Buzzwole","Pheromosa","Xurkitree","Celesteela","Kartana","Guzzlord","Necrozma","Magearna","Marshadow","Poipole","Naganadel","Stakataka","Blacephalon","Zeraora","Meltan","Melmetal","Grookey","Thwackey","Rillaboom","Scorbunny","Raboot","Cinderace","Sobble","Drizzile","Inteleon","Skwovet","Greedent","Rookidee","Corvisquire","Corviknight","Blipbug","Dottler","Orbeetle","Nickit","Thievul","Gossifleur","Eldegoss","Wooloo","Dubwool","Chewtle","Drednaw","Yamper","Boltund","Rolycoly","Carkol","Coalossal","Applin","Flapple","Appletun","Silicobra","Sandaconda","Cramorant","Arrokuda","Barraskewda","Toxel","Toxtricity","Sizzlipede","Centiskorch","Clobbopus","Grapploct","Sinistea","Polteageist","Hatenna","Hattrem","Hatterene","Impidimp","Morgrem","Grimmsnarl","Obstagoon","Perrserker","Cursola","Sirfetch’d","Mr. Rime","Runerigus","Milcery","Alcremie","Falinks","Pincurchin","Snom","Frosmoth","Stonjourner","Eiscue","Indeedee","Morpeko","Cufant","Copperajah","Dracozolt","Arctozolt","Dracovish","Arctovish","Duraludon","Dreepy","Drakloak","Dragapult","Zacian","Zamazenta","Eternatus","Kubfu","Urshifu","Zarude","Regieleki","Regidrago","Glastrier","Spectrier","Calyrex","Wyrdeer","Kleavor","Ursaluna","Basculegion","Sneasler","Overqwil","Enamorus","Venusaur","Charizard","Charizard","Blastoise","Beedrill","Pidgeot","Alakazam","Slowbro","Gengar","Kangaskhan","Pinsir","Gyarados","Aerodactyl","Mewtwo","Mewtwo","Ampharos","Steelix","Scizor","Heracross","Houndoom","Tyranitar","Sceptile","Blaziken","Swampert","Gardevoir","Sableye","Mawile","Aggron","Medicham","Manectric","Sharpedo","Camerupt","Altaria","Banette","Absol","Glalie","Salamence","Metagross","Latias","Latios","Lopunny","Garchomp","Lucario","Abomasnow","Gallade","Audino","Diancie","Rayquaza","Kyogre","Groudon","Rattata","Raticate","Raichu","Sandshrew","Sandslash","Vulpix","Ninetales","Diglett","Dugtrio","Meowth","Persian","Geodude","Graveler","Golem","Grimer","Muk","Exeggutor","Marowak","Meowth","Ponyta","Rapidash","Slowpoke","Slowbro","Farfetch’d","Weezing","Mr. Mime","Articuno","Zapdos","Moltres","Slowking","Corsola","Zigzagoon","Linoone","Darumaka","Darmanitan","Yamask","Stunfisk","Growlithe","Arcanine","Voltorb","Electrode","Typhlosion","Qwilfish","Sneasel","Samurott","Lilligant","Zorua","Zoroark","Braviary","Sliggoo","Goodra","Avalugg","Decidueye","Pikachu","Pikachu","Pikachu","Pikachu","Pikachu","Pikachu","Pikachu","Pikachu","Pikachu","Pikachu","Pikachu","Pikachu","Pikachu","Pikachu","Pichu","Unown","Unown","Unown","Unown","Unown","Unown","Unown","Unown","Unown","Unown","Unown","Unown","Unown","Unown","Unown","Unown","Unown","Unown","Unown","Unown","Unown","Unown","Unown","Unown","Unown","Unown","Unown","Castform","Castform","Castform","Deoxys","Deoxys","Deoxys","Burmy","Burmy","Wormadam","Wormadam","Cherrim","Shellos","Gastrodon","Rotom","Rotom","Rotom","Rotom","Rotom","Dialga","Palkia","Giratina","Shaymin","Arceus","Arceus","Arceus","Arceus","Arceus","Arceus","Arceus","Arceus","Arceus","Arceus","Arceus","Arceus","Arceus","Arceus","Arceus","Arceus","Arceus","Basculin","Basculin","Darmanitan","Darmanitan","Deerling","Deerling","Deerling","Sawsbuck","Sawsbuck","Sawsbuck","Tornadus","Thundurus","Landorus","Enamorus","Kyurem","Kyurem","Keldeo","Meloetta","Genesect","Genesect","Genesect","Genesect","Greninja","Greninja","Vivillon","Vivillon","Vivillon","Vivillon","Vivillon","Vivillon","Vivillon","Vivillon","Vivillon","Vivillon","Vivillon","Vivillon","Vivillon","Vivillon","Vivillon","Vivillon","Vivillon","Vivillon","Vivillon","Flabébé","Flabébé","Flabébé","Flabébé","Floette","Floette","Floette","Floette","Floette","Florges","Florges","Florges","Florges","Furfrou","Furfrou","Furfrou","Furfrou","Furfrou","Furfrou","Furfrou","Furfrou","Furfrou","Meowstic","Aegislash","Pumpkaboo","Pumpkaboo","Pumpkaboo","Gourgeist","Gourgeist","Gourgeist","Xerneas","Zygarde","Zygarde","Zygarde","Zygarde","Hoopa","Oricorio","Oricorio","Oricorio","Rockruff","Lycanroc","Lycanroc","Wishiwashi","Silvally","Silvally","Silvally","Silvally","Silvally","Silvally","Silvally","Silvally","Silvally","Silvally","Silvally","Silvally","Silvally","Silvally","Silvally","Silvally","Silvally","Minior","Minior","Minior","Minior","Minior","Minior","Minior","Minior","Minior","Minior","Minior","Minior","Minior","Mimikyu","Necrozma","Necrozma","Necrozma","Magearna","Cramorant","Cramorant","Toxtricity","Sinistea","Polteageist","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Eiscue","Indeedee","Morpeko","Zacian","Zamazenta","Eternatus","Urshifu","Zarude","Calyrex","Calyrex","Basculegion","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Alcremie","Sprigatito","Floragato","Meowscarada","Fuecoco","Crocalor","Skeledirge","Quaxly","Quaxwell","Quaquaval","Lechonk","Oinkologne","Oinkologne","Tarountula","Spidops","Nymble","Lokix","Pawmi","Pawmo","Pawmot","Tandemaus","Maushold","Maushold","Fidough","Dachsbun","Smoliv","Dolliv","Arboliva","Squawkabilly","Squawkabilly","Squawkabilly","Squawkabilly","Nacli","Naclstack","Garganacl","Charcadet","Armarouge","Ceruledge","Tadbulb","Bellibolt","Wattrel","Kilowattrel","Maschiff","Mabosstiff","Shroodle","Grafaiai","Bramblin","Brambleghast","Toedscool","Toedscruel","Klawf","Capsakid","Scovillain","Rellor","Rabsca","Flittle","Espathra","Tinkatink","Tinkatuff","Tinkaton","Wiglett","Wugtrio","Bombirdier","Finizen","Palafin","Palafin","Varoom","Revavroom","Cyclizar","Orthworm","Glimmet","Glimmora","Greavard","Houndstone","Flamigo","Cetoddle","Cetitan","Veluza","Dondozo","Tatsugiri","Tatsugiri","Tatsugiri","Annihilape","Clodsire","Farigiraf","Dudunsparce","Dudunsparce","Kingambit","Great Tusk","Scream Tail","Brute Bonnet","Flutter Mane","Slither Wing","Sandy Shocks","Iron Treads","Iron Bundle","Iron Hands","Iron Jugulis","Iron Moth","Iron Thorns","Frigibax","Arctibax","Baxcalibur","Gimmighoul","Gimmighoul","Gholdengo","Wo-Chien","Chien-Pao","Ting-Lu","Chi-Yu","Roaring Moon","Iron Valiant","Koraidon","Miraidon","Tauros","Tauros","Tauros","Wooper","Walking Wake","Iron Leaves","Dipplin","Poltchageist","Poltchageist","Sinistcha","Sinistcha","Okidogi","Munkidori","Fezandipiti","Ogerpon","Ogerpon","Ogerpon","Ogerpon","Ogerpon","Ogerpon","Ogerpon","Ogerpon","Ursaluna","Archaludon","Hydrapple","Gouging Fire","Raging Bolt","Iron Boulder","Iron Crown","Terapagos","Terapagos","Terapagos","Pecharunt","","Mothim","Mothim","Scatterbug","Scatterbug","Scatterbug","Scatterbug","Scatterbug","Scatterbug","Scatterbug","Scatterbug","Scatterbug","Scatterbug","Scatterbug","Scatterbug","Scatterbug","Scatterbug","Scatterbug","Scatterbug","Scatterbug","Scatterbug","Scatterbug","Spewpa","Spewpa","Spewpa","Spewpa","Spewpa","Spewpa","Spewpa","Spewpa","Spewpa","Spewpa","Spewpa","Spewpa","Spewpa","Spewpa","Spewpa","Spewpa","Spewpa","Spewpa","Spewpa","Raticate","Gumshoos","Vikavolt","Lurantis","Salazzle","Mimikyu","Kommo-o","Marowak","Ribombee","Araquanid","Togedemaru","Pikachu","Eevee","Venusaur","Blastoise","Charizard","Butterfree","Pikachu","Meowth","Machamp","Gengar","Kingler","Lapras","Eevee","Snorlax","Garbodor","Melmetal","Rillaboom","Cinderace","Inteleon","Corviknight","Orbeetle","Drednaw","Coalossal","Flapple","Appletun","Sandaconda","Toxtricity","Toxtricity","Centiskorch","Hatterene","Grimmsnarl","Alcremie","Copperajah","Duraludon","Urshifu","Urshifu","Mimikyu","Clefable","Victreebel","Starmie","Dragonite","Meganium","Feraligatr","Skarmory","Froslass","Emboar","Excadrill","Scolipede","Scrafty","Eelektross","Chandelure","Chesnaught","Delphox","Greninja","Pyroar","Malamar","Dragalge","Hawlucha","Floette","Barbaracle","Zygarde","Drampa","Falinks","Heatran","Darkrai","Zeraora","Raichu","Raichu","Chimecho","Absol","Staraptor","Garchomp","Lucario","Golurk","Meowstic","Meowstic","Crabominable","Golisopod","Magearna","Magearna","Scovillain","Baxcalibur","Tatsugiri","Tatsugiri","Tatsugiri","Glimmora"],"speciesTypes":[[0,0],[13,4],[13,4],[13,4],[11,11],[11,11],[11,3],[12,12],[12,12],[12,12],[7,7],[7,7],[7,3],[7,4],[7,4],[7,4],[1,3],[1,3],[1,3],[1,1],[1,1],[1,3],[1,3],[4,4],[4,4],[14,14],[14,14],[5,5],[5,5],[4,4],[4,4],[4,5],[4,4],[4,4],[4,5],[19,19],[19,19],[11,11],[11,11],[1,19],[1,19],[4,3],[4,3],[13,4],[13,4],[13,4],[7,13],[7,13],[7,4],[7,4],[5,5],[5,5],[1,1],[1,1],[12,12],[12,12],[2,2],[2,2],[11,11],[11,11],[12,12],[12,12],[12,2],[15,15],[15,15],[15,15],[2,2],[2,2],[2,2],[13,4],[13,4],[13,4],[12,4],[12,4],[6,5],[6,5],[6,5],[11,11],[11,11],[12,15],[12,15],[14,9],[14,9],[1,3],[1,3],[1,3],[12,12],[12,16],[4,4],[4,4],[12,12],[12,16],[8,4],[8,4],[8,4],[6,5],[15,15],[15,15],[12,12],[12,12],[14,14],[14,14],[13,15],[13,15],[5,5],[5,5],[2,2],[2,2],[1,1],[4,4],[4,4],[5,6],[5,6],[1,1],[13,13],[1,1],[12,12],[12,12],[12,12],[12,12],[12,12],[12,15],[15,19],[7,3],[16,15],[14,14],[11,11],[7,7],[1,1],[12,12],[12,3],[12,16],[1,1],[1,1],[12,12],[14,14],[11,11],[1,1],[6,12],[6,12],[6,12],[6,12],[6,3],[1,1],[16,3],[14,3],[11,3],[17,17],[17,17],[17,3],[15,15],[15,15],[13,13],[13,13],[13,13],[11,11],[11,11],[11,11],[12,12],[12,12],[12,12],[1,1],[1,1],[1,3],[1,3],[7,3],[7,3],[7,4],[7,4],[4,3],[12,14],[12,14],[14,14],[19,19],[1,19],[19,19],[19,3],[15,3],[15,3],[14,14],[14,14],[14,14],[13,13],[12,19],[12,19],[6,6],[12,12],[13,3],[13,3],[13,3],[1,1],[13,13],[13,13],[7,3],[12,5],[12,5],[15,15],[18,18],[18,3],[12,15],[8,8],[15,15],[15,15],[1,15],[7,7],[7,9],[1,1],[5,3],[9,5],[19,19],[19,19],[12,4],[7,9],[7,6],[7,2],[18,16],[1,1],[1,1],[11,11],[11,6],[16,5],[16,5],[12,6],[12,12],[12,12],[16,3],[12,3],[9,3],[18,11],[18,11],[12,17],[5,5],[5,5],[1,1],[1,1],[1,1],[2,2],[2,2],[16,15],[14,14],[11,11],[1,1],[1,1],[14,14],[11,11],[12,12],[6,5],[6,5],[6,18],[15,3],[11,3],[15,13],[13,13],[13,13],[13,13],[11,11],[11,2],[11,2],[12,12],[12,5],[12,5],[18,18],[18,18],[1,1],[1,1],[7,7],[7,7],[7,3],[7,7],[7,4],[12,13],[12,13],[12,13],[13,13],[13,18],[13,18],[1,3],[1,3],[12,3],[12,3],[15,19],[15,19],[15,19],[7,12],[7,3],[13,13],[13,2],[1,1],[1,1],[1,1],[7,5],[7,3],[7,8],[1,1],[1,1],[1,1],[2,2],[2,2],[1,19],[6,6],[1,1],[1,1],[18,8],[9,19],[9,6],[9,6],[9,6],[2,15],[2,15],[14,14],[14,14],[14,14],[14,14],[7,7],[7,7],[13,4],[4,4],[4,4],[12,18],[12,18],[12,12],[12,12],[11,5],[11,5],[11,11],[15,15],[15,15],[1,1],[5,5],[5,17],[5,17],[13,13],[13,18],[1,3],[17,3],[1,1],[4,4],[6,15],[6,15],[12,5],[12,5],[12,12],[12,18],[5,15],[5,15],[6,13],[6,13],[6,7],[6,7],[12,12],[12,12],[1,1],[1,1],[8,8],[8,8],[8,8],[8,8],[13,3],[15,15],[18,18],[15,15],[16,16],[16,16],[16,12],[16,12],[16,12],[12,12],[12,12],[12,12],[12,6],[12,12],[17,17],[17,17],[17,3],[9,15],[9,15],[9,15],[6,6],[16,16],[9,9],[17,15],[17,15],[12,12],[5,5],[17,3],[9,15],[15,15],[13,13],[13,13],[13,5],[11,11],[11,2],[11,2],[12,12],[12,12],[12,9],[1,3],[1,3],[1,3],[1,1],[1,12],[7,7],[7,7],[14,14],[14,14],[14,14],[13,4],[13,4],[6,6],[6,6],[6,9],[6,9],[7,7],[7,13],[7,3],[7,3],[7,3],[14,14],[12,12],[12,12],[13,13],[13,13],[12,12],[12,5],[1,1],[8,3],[8,3],[1,1],[1,1],[8,8],[18,3],[1,1],[1,1],[15,15],[4,18],[4,18],[9,15],[9,15],[6,6],[15,19],[1,1],[1,3],[8,18],[17,5],[17,5],[17,5],[1,1],[2,2],[2,9],[5,5],[5,5],[4,7],[4,18],[4,2],[4,2],[13,13],[12,12],[12,12],[12,3],[13,16],[13,16],[18,16],[14,9],[1,1],[5,6],[13,13],[14,14],[11,11],[19,3],[7,3],[13,13],[16,16],[5,3],[16,5],[1,1],[15,2],[6,9],[8,8],[16,8],[14,8],[15,15],[15,15],[15,15],[9,17],[12,17],[11,9],[1,1],[8,17],[15,15],[12,12],[12,12],[18,18],[13,13],[1,1],[15,11],[13,13],[13,13],[13,13],[11,11],[11,2],[11,2],[12,12],[12,12],[12,12],[1,1],[1,1],[1,1],[1,1],[1,1],[18,18],[18,18],[13,13],[13,13],[11,11],[11,11],[12,12],[12,12],[15,15],[15,15],[1,3],[1,3],[1,3],[14,14],[14,14],[6,6],[6,6],[6,6],[15,3],[15,3],[5,5],[5,9],[1,1],[2,2],[2,2],[2,2],[12,12],[12,5],[12,5],[2,2],[2,2],[7,13],[7,13],[7,13],[7,4],[7,4],[7,4],[13,19],[13,19],[13,13],[13,13],[12,12],[5,18],[5,18],[5,18],[11,11],[11,11],[13,13],[7,6],[7,6],[18,2],[18,2],[15,3],[8,8],[8,8],[12,6],[12,6],[6,3],[6,3],[4,4],[4,4],[18,18],[18,18],[1,1],[1,1],[15,15],[15,15],[15,15],[15,15],[15,15],[15,15],[12,3],[12,3],[16,16],[16,16],[16,16],[1,13],[1,13],[14,3],[7,7],[7,9],[13,4],[13,4],[12,8],[12,8],[12,12],[7,14],[7,14],[13,9],[13,9],[9,9],[9,9],[9,9],[14,14],[14,14],[14,14],[15,15],[15,15],[8,11],[8,11],[8,11],[17,17],[17,17],[17,17],[16,16],[16,16],[16,16],[7,7],[7,7],[5,14],[2,2],[2,2],[17,17],[5,8],[5,8],[18,9],[18,9],[1,1],[1,3],[1,3],[18,3],[18,3],[11,11],[7,9],[18,17],[18,17],[18,17],[7,11],[7,11],[9,2],[6,2],[13,2],[3,3],[14,3],[17,11],[17,14],[5,3],[17,16],[12,2],[1,15],[7,9],[13,13],[13,13],[13,2],[11,11],[11,11],[11,15],[12,12],[12,12],[12,18],[1,1],[1,5],[1,3],[11,3],[11,3],[7,7],[7,7],[7,3],[11,1],[11,1],[19,19],[19,19],[19,19],[13,13],[13,13],[2,2],[2,18],[1,1],[15,15],[15,15],[9,8],[9,8],[9,8],[19,19],[19,19],[19,19],[19,19],[18,15],[18,15],[6,12],[6,12],[4,12],[4,17],[12,12],[12,12],[14,1],[14,1],[6,17],[6,17],[6,16],[6,16],[19,19],[2,3],[14,19],[6,19],[17,17],[17,17],[17,17],[9,19],[8,13],[8,13],[8,13],[8,13],[16,16],[16,16],[3,17],[3,17],[19,19],[18,3],[17,5],[6,19],[15,8],[11,12],[13,3],[13,3],[13,8],[11,11],[11,11],[11,18],[12,12],[12,12],[12,19],[1,3],[1,3],[1,3],[1,1],[1,1],[7,7],[7,14],[7,14],[2,2],[2,16],[11,3],[7,19],[7,19],[6,6],[6,6],[12,12],[4,12],[4,12],[5,5],[5,5],[12,7],[12,7],[13,13],[13,13],[13,19],[13,19],[4,11],[4,11],[1,2],[1,2],[13,13],[13,13],[13,13],[19,19],[1,15],[2,2],[7,12],[7,12],[8,5],[8,5],[12,12],[1,1],[1,1],[6,3],[1,1],[11,17],[14,9],[8,19],[12,15],[1,17],[8,13],[17,17],[17,2],[17,2],[14,19],[15,19],[13,19],[12,19],[15,15],[15,15],[15,9],[15,8],[6,4],[7,2],[7,2],[14,14],[9,3],[13,9],[18,17],[15,15],[9,19],[2,8],[4,4],[4,17],[6,9],[11,8],[14,14],[9,9],[9,9],[13,13],[13,13],[13,13],[11,11],[11,11],[11,11],[12,12],[12,12],[12,12],[1,1],[1,1],[3,3],[3,3],[3,9],[7,7],[7,15],[7,15],[18,18],[18,18],[13,13],[13,13],[1,1],[1,1],[12,12],[12,6],[14,14],[14,14],[6,6],[6,11],[6,11],[13,17],[13,17],[13,17],[5,5],[5,5],[3,12],[12,12],[12,12],[14,4],[14,4],[11,7],[11,7],[2,2],[2,2],[8,8],[8,8],[15,15],[15,15],[15,19],[18,19],[18,19],[18,19],[18,1],[9,9],[8,8],[2,2],[16,15],[5,8],[19,19],[19,19],[2,2],[14,14],[16,7],[16,7],[6,6],[16,16],[15,1],[14,18],[9,9],[9,9],[14,17],[14,16],[12,17],[12,16],[9,17],[17,8],[17,8],[17,8],[19,19],[2,2],[4,17],[2,2],[2,18],[18,13],[14,14],[17,17],[16,16],[8,8],[15,13],[1,15],[7,6],[5,1],[12,8],[2,4],[18,4],[19,3],[13,4],[11,17],[11,3],[12,12],[7,4],[1,3],[15,15],[12,15],[8,4],[1,1],[7,3],[12,18],[6,3],[15,2],[15,15],[14,17],[9,5],[7,9],[7,2],[18,11],[6,18],[13,17],[11,2],[12,5],[15,19],[18,8],[9,19],[9,9],[2,15],[14,14],[12,18],[11,5],[17,19],[8,8],[18,18],[16,16],[17,3],[9,15],[17,15],[17,15],[1,2],[17,5],[2,9],[13,16],[15,2],[1,19],[6,19],[17,3],[12,12],[5,11],[18,1],[18,1],[14,15],[16,9],[16,9],[16,16],[16,19],[5,9],[5,9],[18,18],[18,18],[6,14],[6,14],[6,14],[4,18],[4,18],[13,17],[11,8],[9,9],[15,15],[15,19],[15,15],[4,15],[2,2],[4,19],[16,15],[15,3],[2,3],[18,3],[4,15],[8,8],[18,1],[18,1],[16,16],[16,16],[5,8],[5,9],[11,6],[11,6],[14,13],[14,13],[11,8],[18,4],[2,4],[12,18],[13,2],[1,8],[1,8],[15,3],[17,9],[17,9],[16,6],[13,2],[14,14],[14,14],[14,14],[14,14],[14,14],[14,14],[14,14],[14,14],[14,14],[14,14],[14,14],[14,14],[14,14],[14,14],[14,14],[15,15],[15,15],[15,15],[15,15],[15,15],[15,15],[15,15],[15,15],[15,15],[15,15],[15,15],[15,15],[15,15],[15,15],[15,15],[15,15],[15,15],[15,15],[15,15],[15,15],[15,15],[15,15],[15,15],[15,15],[15,15],[15,15],[15,15],[11,11],[12,12],[16,16],[15,15],[15,15],[15,15],[7,7],[7,7],[7,5],[7,9],[13,13],[12,12],[12,5],[14,11],[14,12],[14,16],[14,3],[14,13],[9,17],[12,17],[8,17],[13,3],[2,2],[3,3],[4,4],[5,5],[6,6],[7,7],[8,8],[9,9],[11,11],[12,12],[13,13],[14,14],[15,15],[16,16],[17,17],[18,18],[19,19],[12,12],[12,12],[11,15],[16,11],[1,13],[1,13],[1,13],[1,13],[1,13],[1,13],[3,3],[14,3],[5,3],[19,3],[17,16],[17,16],[12,2],[1,2],[7,9],[7,9],[7,9],[7,9],[12,18],[12,18],[7,3],[7,3],[7,3],[7,3],[7,3],[7,3],[7,3],[7,3],[7,3],[7,3],[7,3],[7,3],[7,3],[7,3],[7,3],[7,3],[7,3],[7,3],[7,3],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[1,1],[1,1],[1,1],[1,1],[1,1],[1,1],[1,1],[1,1],[1,1],[15,15],[9,8],[8,13],[8,13],[8,13],[8,13],[8,13],[8,13],[19,19],[17,5],[17,5],[17,5],[17,5],[15,18],[14,3],[15,3],[8,3],[6,6],[6,6],[6,6],[12,12],[2,2],[3,3],[4,4],[5,5],[6,6],[7,7],[8,8],[9,9],[11,11],[12,12],[13,13],[14,14],[15,15],[16,16],[17,17],[18,18],[19,19],[6,3],[6,3],[6,3],[6,3],[6,3],[6,3],[6,3],[6,3],[6,3],[6,3],[6,3],[6,3],[6,3],[8,19],[15,9],[15,8],[15,17],[9,19],[3,12],[3,12],[14,4],[8,8],[8,8],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[16,16],[15,1],[14,18],[19,9],[2,9],[4,17],[2,12],[18,13],[15,16],[15,8],[12,8],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[19,19],[13,13],[13,13],[13,18],[11,11],[11,11],[11,8],[12,12],[12,12],[12,2],[1,1],[1,1],[1,1],[7,7],[7,7],[7,7],[7,18],[14,14],[14,2],[14,2],[1,1],[1,1],[1,1],[19,19],[19,19],[13,1],[13,1],[13,1],[1,3],[1,3],[1,3],[1,3],[6,6],[6,6],[6,6],[11,11],[11,15],[11,8],[14,14],[14,14],[14,3],[14,3],[18,18],[18,18],[4,1],[4,1],[13,8],[13,8],[5,13],[5,13],[6,6],[13,13],[13,11],[7,7],[7,15],[15,15],[15,15],[19,9],[19,9],[19,9],[12,12],[12,12],[3,18],[12,12],[12,12],[12,12],[9,4],[9,4],[17,1],[9,9],[6,4],[6,4],[8,8],[8,8],[3,2],[16,16],[16,16],[12,15],[12,12],[17,12],[17,12],[17,12],[2,8],[4,5],[1,15],[1,1],[1,1],[18,9],[5,2],[19,15],[13,18],[8,19],[7,2],[14,5],[5,9],[16,12],[2,14],[18,3],[11,4],[6,14],[17,16],[17,16],[17,16],[8,8],[8,8],[9,8],[18,13],[18,16],[18,5],[18,11],[17,18],[19,2],[2,17],[14,17],[2,2],[2,11],[2,12],[4,5],[12,17],[13,15],[13,17],[13,8],[13,8],[13,8],[13,8],[4,2],[4,15],[4,19],[13,13],[13,12],[13,11],[13,6],[13,13],[13,12],[13,11],[13,6],[5,1],[9,17],[13,17],[11,17],[14,17],[6,15],[9,15],[1,1],[1,1],[1,1],[4,8],[0,0],[7,3],[7,3],[7,7],[7,7],[7,7],[7,7],[7,7],[7,7],[7,7],[7,7],[7,7],[7,7],[7,7],[7,7],[7,7],[7,7],[7,7],[7,7],[7,7],[7,7],[7,7],[7,7],[7,7],[7,7],[7,7],[7,7],[7,7],[7,7],[7,7],[7,7],[7,7],[7,7],[7,7],[7,7],[7,7],[7,7],[7,7],[7,7],[7,7],[7,7],[18,1],[1,1],[7,14],[13,13],[4,11],[8,19],[17,2],[11,8],[7,19],[12,7],[14,9],[14,14],[1,1],[13,4],[12,12],[11,3],[7,3],[14,14],[1,1],[2,2],[8,4],[12,12],[12,16],[1,1],[1,1],[4,4],[9,9],[13,13],[11,11],[12,12],[3,9],[7,15],[12,6],[6,11],[13,17],[13,17],[5,5],[14,4],[14,4],[11,7],[15,19],[18,19],[19,19],[9,9],[9,17],[2,18],[2,12],[8,19],[19,3],[13,4],[12,15],[17,3],[13,19],[12,17],[9,3],[16,8],[11,2],[5,9],[7,4],[18,2],[14,14],[8,11],[13,2],[11,15],[12,18],[11,1],[18,15],[4,17],[2,3],[19,19],[6,2],[17,5],[1,17],[2,2],[11,9],[18,18],[14,14],[14,14],[14,14],[15,9],[18,8],[2,3],[17,17],[2,9],[5,8],[15,15],[15,15],[2,16],[7,9],[9,19],[9,19],[13,11],[17,16],[17,12],[17,12],[17,12],[6,4]],"moves":[{"n":"-","t":1,"c":1,"p":0,"a":0,"pp":0,"tg":1,"pr":0},{"n":"Pound","t":1,"c":1,"p":40,"a":100,"pp":35,"tg":1,"pr":0},{"n":"Karate Chop","t":2,"c":1,"p":50,"a":100,"pp":25,"tg":1,"pr":0},{"n":"Double Slap","t":1,"c":1,"p":15,"a":85,"pp":10,"tg":1,"pr":0},{"n":"Comet Punch","t":1,"c":1,"p":18,"a":85,"pp":15,"tg":1,"pr":0},{"n":"Mega Punch","t":1,"c":1,"p":80,"a":85,"pp":20,"tg":1,"pr":0},{"n":"Pay Day","t":1,"c":1,"p":40,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Fire Punch","t":11,"c":1,"p":75,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Ice Punch","t":16,"c":1,"p":75,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Thunder Punch","t":14,"c":1,"p":75,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Scratch","t":1,"c":1,"p":40,"a":100,"pp":35,"tg":1,"pr":0},{"n":"Vise Grip","t":1,"c":1,"p":55,"a":100,"pp":30,"tg":1,"pr":0},{"n":"Guillotine","t":1,"c":1,"p":1,"a":30,"pp":5,"tg":1,"pr":0},{"n":"Razor Wind","t":1,"c":2,"p":80,"a":100,"pp":10,"tg":6,"pr":0},{"n":"Swords Dance","t":1,"c":3,"p":0,"a":0,"pp":20,"tg":7,"pr":0},{"n":"Cut","t":1,"c":1,"p":50,"a":95,"pp":30,"tg":1,"pr":0},{"n":"Gust","t":3,"c":2,"p":40,"a":100,"pp":35,"tg":1,"pr":0},{"n":"Wing Attack","t":3,"c":1,"p":60,"a":100,"pp":35,"tg":1,"pr":0},{"n":"Whirlwind","t":1,"c":3,"p":0,"a":0,"pp":20,"tg":1,"pr":-6},{"n":"Fly","t":3,"c":1,"p":90,"a":95,"pp":15,"tg":1,"pr":0},{"n":"Bind","t":1,"c":1,"p":15,"a":85,"pp":20,"tg":1,"pr":0},{"n":"Slam","t":1,"c":1,"p":80,"a":75,"pp":20,"tg":1,"pr":0},{"n":"Vine Whip","t":13,"c":1,"p":45,"a":100,"pp":25,"tg":1,"pr":0},{"n":"Stomp","t":1,"c":1,"p":65,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Double Kick","t":2,"c":1,"p":30,"a":100,"pp":30,"tg":1,"pr":0},{"n":"Mega Kick","t":1,"c":1,"p":120,"a":75,"pp":5,"tg":1,"pr":0},{"n":"Jump Kick","t":2,"c":1,"p":100,"a":95,"pp":10,"tg":1,"pr":0},{"n":"Rolling Kick","t":2,"c":1,"p":60,"a":85,"pp":15,"tg":1,"pr":0},{"n":"Sand Attack","t":5,"c":3,"p":0,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Headbutt","t":1,"c":1,"p":70,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Horn Attack","t":1,"c":1,"p":65,"a":100,"pp":25,"tg":1,"pr":0},{"n":"Fury Attack","t":1,"c":1,"p":15,"a":85,"pp":20,"tg":1,"pr":0},{"n":"Horn Drill","t":1,"c":1,"p":1,"a":30,"pp":5,"tg":1,"pr":0},{"n":"Tackle","t":1,"c":1,"p":40,"a":100,"pp":35,"tg":1,"pr":0},{"n":"Body Slam","t":1,"c":1,"p":85,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Wrap","t":1,"c":1,"p":15,"a":90,"pp":20,"tg":1,"pr":0},{"n":"Take Down","t":1,"c":1,"p":90,"a":85,"pp":20,"tg":1,"pr":0},{"n":"Thrash","t":1,"c":1,"p":120,"a":100,"pp":10,"tg":5,"pr":0},{"n":"Double-Edge","t":1,"c":1,"p":120,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Tail Whip","t":1,"c":3,"p":0,"a":100,"pp":30,"tg":6,"pr":0},{"n":"Poison Sting","t":4,"c":1,"p":15,"a":100,"pp":35,"tg":1,"pr":0},{"n":"Twineedle","t":7,"c":1,"p":25,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Pin Missile","t":7,"c":1,"p":25,"a":95,"pp":20,"tg":1,"pr":0},{"n":"Leer","t":1,"c":3,"p":0,"a":100,"pp":30,"tg":6,"pr":0},{"n":"Bite","t":18,"c":1,"p":60,"a":100,"pp":25,"tg":1,"pr":0},{"n":"Growl","t":1,"c":3,"p":0,"a":100,"pp":40,"tg":6,"pr":0},{"n":"Roar","t":1,"c":3,"p":0,"a":0,"pp":20,"tg":1,"pr":-6},{"n":"Sing","t":1,"c":3,"p":0,"a":55,"pp":15,"tg":1,"pr":0},{"n":"Supersonic","t":1,"c":3,"p":0,"a":55,"pp":20,"tg":1,"pr":0},{"n":"Sonic Boom","t":1,"c":2,"p":1,"a":90,"pp":20,"tg":1,"pr":0},{"n":"Disable","t":1,"c":3,"p":0,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Acid","t":4,"c":2,"p":40,"a":100,"pp":30,"tg":6,"pr":0},{"n":"Ember","t":11,"c":2,"p":40,"a":100,"pp":25,"tg":1,"pr":0},{"n":"Flamethrower","t":11,"c":2,"p":90,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Mist","t":16,"c":3,"p":0,"a":0,"pp":30,"tg":7,"pr":0},{"n":"Water Gun","t":12,"c":2,"p":40,"a":100,"pp":25,"tg":1,"pr":0},{"n":"Hydro Pump","t":12,"c":2,"p":110,"a":80,"pp":5,"tg":1,"pr":0},{"n":"Surf","t":12,"c":2,"p":90,"a":100,"pp":15,"tg":11,"pr":0},{"n":"Ice Beam","t":16,"c":2,"p":90,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Blizzard","t":16,"c":2,"p":110,"a":70,"pp":5,"tg":6,"pr":0},{"n":"Psybeam","t":15,"c":2,"p":65,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Bubble Beam","t":12,"c":2,"p":65,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Aurora Beam","t":16,"c":2,"p":65,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Hyper Beam","t":1,"c":2,"p":150,"a":90,"pp":5,"tg":1,"pr":0},{"n":"Peck","t":3,"c":1,"p":35,"a":100,"pp":35,"tg":1,"pr":0},{"n":"Drill Peck","t":3,"c":1,"p":80,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Submission","t":2,"c":1,"p":80,"a":80,"pp":20,"tg":1,"pr":0},{"n":"Low Kick","t":2,"c":1,"p":1,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Counter","t":2,"c":1,"p":1,"a":100,"pp":20,"tg":3,"pr":-5},{"n":"Seismic Toss","t":2,"c":1,"p":1,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Strength","t":1,"c":1,"p":80,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Absorb","t":13,"c":2,"p":20,"a":100,"pp":25,"tg":1,"pr":0},{"n":"Mega Drain","t":13,"c":2,"p":40,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Leech Seed","t":13,"c":3,"p":0,"a":90,"pp":10,"tg":1,"pr":0},{"n":"Growth","t":1,"c":3,"p":0,"a":0,"pp":20,"tg":7,"pr":0},{"n":"Razor Leaf","t":13,"c":1,"p":55,"a":95,"pp":25,"tg":6,"pr":0},{"n":"Solar Beam","t":13,"c":2,"p":120,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Poison Powder","t":4,"c":3,"p":0,"a":75,"pp":35,"tg":1,"pr":0},{"n":"Stun Spore","t":13,"c":3,"p":0,"a":75,"pp":30,"tg":1,"pr":0},{"n":"Sleep Powder","t":13,"c":3,"p":0,"a":75,"pp":15,"tg":1,"pr":0},{"n":"Petal Dance","t":13,"c":2,"p":120,"a":100,"pp":10,"tg":5,"pr":0},{"n":"String Shot","t":7,"c":3,"p":0,"a":95,"pp":40,"tg":6,"pr":0},{"n":"Dragon Rage","t":17,"c":2,"p":1,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Fire Spin","t":11,"c":2,"p":35,"a":85,"pp":15,"tg":1,"pr":0},{"n":"Thunder Shock","t":14,"c":2,"p":40,"a":100,"pp":30,"tg":1,"pr":0},{"n":"Thunderbolt","t":14,"c":2,"p":90,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Thunder Wave","t":14,"c":3,"p":0,"a":90,"pp":20,"tg":1,"pr":0},{"n":"Thunder","t":14,"c":2,"p":110,"a":70,"pp":10,"tg":1,"pr":0},{"n":"Rock Throw","t":6,"c":1,"p":50,"a":90,"pp":15,"tg":1,"pr":0},{"n":"Earthquake","t":5,"c":1,"p":100,"a":100,"pp":10,"tg":11,"pr":0},{"n":"Fissure","t":5,"c":1,"p":1,"a":30,"pp":5,"tg":1,"pr":0},{"n":"Dig","t":5,"c":1,"p":80,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Toxic","t":4,"c":3,"p":0,"a":90,"pp":10,"tg":1,"pr":0},{"n":"Confusion","t":15,"c":2,"p":50,"a":100,"pp":25,"tg":1,"pr":0},{"n":"Psychic","t":15,"c":2,"p":90,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Hypnosis","t":15,"c":3,"p":0,"a":60,"pp":20,"tg":1,"pr":0},{"n":"Meditate","t":15,"c":3,"p":0,"a":0,"pp":40,"tg":7,"pr":0},{"n":"Agility","t":15,"c":3,"p":0,"a":0,"pp":30,"tg":7,"pr":0},{"n":"Quick Attack","t":1,"c":1,"p":40,"a":100,"pp":30,"tg":1,"pr":1},{"n":"Rage","t":1,"c":1,"p":20,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Teleport","t":15,"c":3,"p":0,"a":0,"pp":20,"tg":7,"pr":-6},{"n":"Night Shade","t":8,"c":2,"p":1,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Mimic","t":1,"c":3,"p":0,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Screech","t":1,"c":3,"p":0,"a":85,"pp":40,"tg":1,"pr":0},{"n":"Double Team","t":1,"c":3,"p":0,"a":0,"pp":15,"tg":7,"pr":0},{"n":"Recover","t":1,"c":3,"p":0,"a":0,"pp":5,"tg":7,"pr":0},{"n":"Harden","t":1,"c":3,"p":0,"a":0,"pp":30,"tg":7,"pr":0},{"n":"Minimize","t":1,"c":3,"p":0,"a":0,"pp":10,"tg":7,"pr":0},{"n":"Smokescreen","t":1,"c":3,"p":0,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Confuse Ray","t":8,"c":3,"p":0,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Withdraw","t":12,"c":3,"p":0,"a":0,"pp":40,"tg":7,"pr":0},{"n":"Defense Curl","t":1,"c":3,"p":0,"a":0,"pp":40,"tg":7,"pr":0},{"n":"Barrier","t":15,"c":3,"p":0,"a":0,"pp":20,"tg":7,"pr":0},{"n":"Light Screen","t":15,"c":3,"p":0,"a":0,"pp":30,"tg":7,"pr":0},{"n":"Haze","t":16,"c":3,"p":0,"a":0,"pp":30,"tg":12,"pr":0},{"n":"Reflect","t":15,"c":3,"p":0,"a":0,"pp":20,"tg":7,"pr":0},{"n":"Focus Energy","t":1,"c":3,"p":0,"a":0,"pp":30,"tg":7,"pr":0},{"n":"Bide","t":1,"c":1,"p":1,"a":0,"pp":10,"tg":7,"pr":1},{"n":"Metronome","t":1,"c":3,"p":0,"a":0,"pp":10,"tg":3,"pr":0},{"n":"Mirror Move","t":3,"c":3,"p":0,"a":0,"pp":20,"tg":3,"pr":0},{"n":"Self-Destruct","t":1,"c":1,"p":200,"a":100,"pp":5,"tg":11,"pr":0},{"n":"Egg Bomb","t":1,"c":1,"p":100,"a":75,"pp":10,"tg":1,"pr":0},{"n":"Lick","t":8,"c":1,"p":30,"a":100,"pp":30,"tg":1,"pr":0},{"n":"Smog","t":4,"c":2,"p":30,"a":70,"pp":20,"tg":1,"pr":0},{"n":"Sludge","t":4,"c":2,"p":65,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Bone Club","t":5,"c":1,"p":65,"a":85,"pp":20,"tg":1,"pr":0},{"n":"Fire Blast","t":11,"c":2,"p":110,"a":85,"pp":5,"tg":1,"pr":0},{"n":"Waterfall","t":12,"c":1,"p":80,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Clamp","t":12,"c":1,"p":35,"a":85,"pp":15,"tg":1,"pr":0},{"n":"Swift","t":1,"c":2,"p":60,"a":0,"pp":20,"tg":6,"pr":0},{"n":"Skull Bash","t":1,"c":1,"p":130,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Spike Cannon","t":1,"c":1,"p":20,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Constrict","t":1,"c":1,"p":10,"a":100,"pp":35,"tg":1,"pr":0},{"n":"Amnesia","t":15,"c":3,"p":0,"a":0,"pp":20,"tg":7,"pr":0},{"n":"Kinesis","t":15,"c":3,"p":0,"a":80,"pp":15,"tg":1,"pr":0},{"n":"Soft-Boiled","t":1,"c":3,"p":0,"a":0,"pp":5,"tg":7,"pr":0},{"n":"High Jump Kick","t":2,"c":1,"p":130,"a":90,"pp":10,"tg":1,"pr":0},{"n":"Glare","t":1,"c":3,"p":0,"a":100,"pp":30,"tg":1,"pr":0},{"n":"Dream Eater","t":15,"c":2,"p":100,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Poison Gas","t":4,"c":3,"p":0,"a":90,"pp":40,"tg":6,"pr":0},{"n":"Barrage","t":1,"c":1,"p":15,"a":85,"pp":20,"tg":1,"pr":0},{"n":"Leech Life","t":7,"c":1,"p":80,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Lovely Kiss","t":1,"c":3,"p":0,"a":75,"pp":10,"tg":1,"pr":0},{"n":"Sky Attack","t":3,"c":1,"p":140,"a":90,"pp":5,"tg":1,"pr":0},{"n":"Transform","t":1,"c":3,"p":0,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Bubble","t":12,"c":2,"p":40,"a":100,"pp":30,"tg":6,"pr":0},{"n":"Dizzy Punch","t":1,"c":1,"p":70,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Spore","t":13,"c":3,"p":0,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Flash","t":1,"c":3,"p":0,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Psywave","t":15,"c":2,"p":1,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Splash","t":1,"c":3,"p":0,"a":0,"pp":40,"tg":7,"pr":0},{"n":"Acid Armor","t":4,"c":3,"p":0,"a":0,"pp":20,"tg":7,"pr":0},{"n":"Crabhammer","t":12,"c":1,"p":100,"a":90,"pp":10,"tg":1,"pr":0},{"n":"Explosion","t":1,"c":1,"p":250,"a":100,"pp":5,"tg":11,"pr":0},{"n":"Fury Swipes","t":1,"c":1,"p":18,"a":80,"pp":15,"tg":1,"pr":0},{"n":"Bonemerang","t":5,"c":1,"p":50,"a":90,"pp":10,"tg":1,"pr":0},{"n":"Rest","t":15,"c":3,"p":0,"a":0,"pp":5,"tg":7,"pr":0},{"n":"Rock Slide","t":6,"c":1,"p":75,"a":90,"pp":10,"tg":6,"pr":0},{"n":"Hyper Fang","t":1,"c":1,"p":80,"a":90,"pp":15,"tg":1,"pr":0},{"n":"Sharpen","t":1,"c":3,"p":0,"a":0,"pp":30,"tg":7,"pr":0},{"n":"Conversion","t":1,"c":3,"p":0,"a":0,"pp":30,"tg":7,"pr":0},{"n":"Tri Attack","t":1,"c":2,"p":80,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Super Fang","t":1,"c":1,"p":1,"a":90,"pp":10,"tg":1,"pr":0},{"n":"Slash","t":1,"c":1,"p":70,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Substitute","t":1,"c":3,"p":0,"a":0,"pp":10,"tg":7,"pr":0},{"n":"Struggle","t":10,"c":1,"p":50,"a":0,"pp":1,"tg":1,"pr":0},{"n":"Sketch","t":1,"c":3,"p":0,"a":0,"pp":1,"tg":1,"pr":0},{"n":"Triple Kick","t":2,"c":1,"p":10,"a":90,"pp":10,"tg":1,"pr":0},{"n":"Thief","t":18,"c":1,"p":60,"a":100,"pp":25,"tg":1,"pr":0},{"n":"Spider Web","t":7,"c":3,"p":0,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Mind Reader","t":1,"c":3,"p":0,"a":0,"pp":5,"tg":1,"pr":0},{"n":"Nightmare","t":8,"c":3,"p":0,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Flame Wheel","t":11,"c":1,"p":60,"a":100,"pp":25,"tg":1,"pr":0},{"n":"Snore","t":1,"c":2,"p":50,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Curse","t":8,"c":3,"p":0,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Flail","t":1,"c":1,"p":1,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Conversion 2","t":1,"c":3,"p":0,"a":0,"pp":30,"tg":1,"pr":0},{"n":"Aeroblast","t":3,"c":2,"p":100,"a":95,"pp":5,"tg":1,"pr":0},{"n":"Cotton Spore","t":13,"c":3,"p":0,"a":100,"pp":40,"tg":6,"pr":0},{"n":"Reversal","t":2,"c":1,"p":1,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Spite","t":8,"c":3,"p":0,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Powder Snow","t":16,"c":2,"p":40,"a":100,"pp":25,"tg":6,"pr":0},{"n":"Protect","t":1,"c":3,"p":0,"a":0,"pp":10,"tg":7,"pr":4},{"n":"Mach Punch","t":2,"c":1,"p":40,"a":100,"pp":30,"tg":1,"pr":1},{"n":"Scary Face","t":1,"c":3,"p":0,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Feint Attack","t":18,"c":1,"p":60,"a":0,"pp":20,"tg":1,"pr":0},{"n":"Sweet Kiss","t":19,"c":3,"p":0,"a":75,"pp":10,"tg":1,"pr":0},{"n":"Belly Drum","t":1,"c":3,"p":0,"a":0,"pp":10,"tg":7,"pr":0},{"n":"Sludge Bomb","t":4,"c":2,"p":90,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Mud-Slap","t":5,"c":2,"p":20,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Octazooka","t":12,"c":2,"p":65,"a":85,"pp":10,"tg":1,"pr":0},{"n":"Spikes","t":5,"c":3,"p":0,"a":0,"pp":20,"tg":13,"pr":0},{"n":"Zap Cannon","t":14,"c":2,"p":120,"a":50,"pp":5,"tg":1,"pr":0},{"n":"Foresight","t":1,"c":3,"p":0,"a":0,"pp":40,"tg":1,"pr":0},{"n":"Destiny Bond","t":8,"c":3,"p":0,"a":0,"pp":5,"tg":7,"pr":0},{"n":"Perish Song","t":1,"c":3,"p":0,"a":0,"pp":5,"tg":14,"pr":0},{"n":"Icy Wind","t":16,"c":2,"p":55,"a":95,"pp":15,"tg":6,"pr":0},{"n":"Detect","t":2,"c":3,"p":0,"a":0,"pp":5,"tg":7,"pr":4},{"n":"Bone Rush","t":5,"c":1,"p":25,"a":90,"pp":10,"tg":1,"pr":0},{"n":"Lock-On","t":1,"c":3,"p":0,"a":0,"pp":5,"tg":1,"pr":0},{"n":"Outrage","t":17,"c":1,"p":120,"a":100,"pp":10,"tg":5,"pr":0},{"n":"Sandstorm","t":6,"c":3,"p":0,"a":0,"pp":10,"tg":12,"pr":0},{"n":"Giga Drain","t":13,"c":2,"p":75,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Endure","t":1,"c":3,"p":0,"a":0,"pp":10,"tg":7,"pr":4},{"n":"Charm","t":19,"c":3,"p":0,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Rollout","t":6,"c":1,"p":30,"a":90,"pp":20,"tg":1,"pr":0},{"n":"False Swipe","t":1,"c":1,"p":40,"a":100,"pp":40,"tg":1,"pr":0},{"n":"Swagger","t":1,"c":3,"p":0,"a":85,"pp":15,"tg":1,"pr":0},{"n":"Milk Drink","t":1,"c":3,"p":0,"a":0,"pp":5,"tg":7,"pr":0},{"n":"Spark","t":14,"c":1,"p":65,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Fury Cutter","t":7,"c":1,"p":40,"a":95,"pp":20,"tg":1,"pr":0},{"n":"Steel Wing","t":9,"c":1,"p":70,"a":90,"pp":25,"tg":1,"pr":0},{"n":"Mean Look","t":1,"c":3,"p":0,"a":0,"pp":5,"tg":1,"pr":0},{"n":"Attract","t":1,"c":3,"p":0,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Sleep Talk","t":1,"c":3,"p":0,"a":0,"pp":10,"tg":3,"pr":0},{"n":"Heal Bell","t":1,"c":3,"p":0,"a":0,"pp":5,"tg":9,"pr":0},{"n":"Return","t":1,"c":1,"p":1,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Present","t":1,"c":1,"p":1,"a":90,"pp":15,"tg":1,"pr":0},{"n":"Frustration","t":1,"c":1,"p":1,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Safeguard","t":1,"c":3,"p":0,"a":0,"pp":25,"tg":7,"pr":0},{"n":"Pain Split","t":1,"c":3,"p":0,"a":0,"pp":20,"tg":1,"pr":0},{"n":"Sacred Fire","t":11,"c":1,"p":100,"a":95,"pp":5,"tg":1,"pr":0},{"n":"Magnitude","t":5,"c":1,"p":1,"a":100,"pp":30,"tg":11,"pr":0},{"n":"Dynamic Punch","t":2,"c":1,"p":100,"a":50,"pp":5,"tg":1,"pr":0},{"n":"Megahorn","t":7,"c":1,"p":120,"a":85,"pp":10,"tg":1,"pr":0},{"n":"Dragon Breath","t":17,"c":2,"p":60,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Baton Pass","t":1,"c":3,"p":0,"a":0,"pp":40,"tg":7,"pr":0},{"n":"Encore","t":1,"c":3,"p":0,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Pursuit","t":18,"c":1,"p":40,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Rapid Spin","t":1,"c":1,"p":50,"a":100,"pp":40,"tg":1,"pr":0},{"n":"Sweet Scent","t":1,"c":3,"p":0,"a":100,"pp":20,"tg":6,"pr":0},{"n":"Iron Tail","t":9,"c":1,"p":100,"a":75,"pp":15,"tg":1,"pr":0},{"n":"Metal Claw","t":9,"c":1,"p":50,"a":95,"pp":35,"tg":1,"pr":0},{"n":"Vital Throw","t":2,"c":1,"p":70,"a":0,"pp":10,"tg":1,"pr":-1},{"n":"Morning Sun","t":1,"c":3,"p":0,"a":0,"pp":5,"tg":7,"pr":0},{"n":"Synthesis","t":13,"c":3,"p":0,"a":0,"pp":5,"tg":7,"pr":0},{"n":"Moonlight","t":19,"c":3,"p":0,"a":0,"pp":5,"tg":7,"pr":0},{"n":"Hidden Power","t":1,"c":2,"p":60,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Cross Chop","t":2,"c":1,"p":100,"a":80,"pp":5,"tg":1,"pr":0},{"n":"Twister","t":17,"c":2,"p":40,"a":100,"pp":20,"tg":6,"pr":0},{"n":"Rain Dance","t":12,"c":3,"p":0,"a":0,"pp":5,"tg":12,"pr":0},{"n":"Sunny Day","t":11,"c":3,"p":0,"a":0,"pp":5,"tg":12,"pr":0},{"n":"Crunch","t":18,"c":1,"p":80,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Mirror Coat","t":15,"c":2,"p":1,"a":100,"pp":20,"tg":3,"pr":-5},{"n":"Psych Up","t":1,"c":3,"p":0,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Extreme Speed","t":1,"c":1,"p":80,"a":100,"pp":5,"tg":1,"pr":2},{"n":"Ancient Power","t":6,"c":2,"p":60,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Shadow Ball","t":8,"c":2,"p":80,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Future Sight","t":15,"c":2,"p":120,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Rock Smash","t":2,"c":1,"p":40,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Whirlpool","t":12,"c":2,"p":35,"a":85,"pp":15,"tg":1,"pr":0},{"n":"Beat Up","t":18,"c":1,"p":1,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Fake Out","t":1,"c":1,"p":40,"a":100,"pp":10,"tg":1,"pr":3},{"n":"Uproar","t":1,"c":2,"p":90,"a":100,"pp":10,"tg":5,"pr":0},{"n":"Stockpile","t":1,"c":3,"p":0,"a":0,"pp":20,"tg":7,"pr":0},{"n":"Spit Up","t":1,"c":2,"p":1,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Swallow","t":1,"c":3,"p":0,"a":0,"pp":10,"tg":7,"pr":0},{"n":"Heat Wave","t":11,"c":2,"p":95,"a":90,"pp":10,"tg":6,"pr":0},{"n":"Hail","t":16,"c":3,"p":0,"a":0,"pp":10,"tg":12,"pr":0},{"n":"Torment","t":18,"c":3,"p":0,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Flatter","t":18,"c":3,"p":0,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Will-O-Wisp","t":11,"c":3,"p":0,"a":85,"pp":15,"tg":1,"pr":0},{"n":"Memento","t":18,"c":3,"p":0,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Facade","t":1,"c":1,"p":70,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Focus Punch","t":2,"c":1,"p":150,"a":100,"pp":20,"tg":1,"pr":-3},{"n":"Smelling Salts","t":1,"c":1,"p":70,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Follow Me","t":1,"c":3,"p":0,"a":0,"pp":20,"tg":7,"pr":2},{"n":"Nature Power","t":1,"c":3,"p":1,"a":0,"pp":20,"tg":1,"pr":0},{"n":"Charge","t":14,"c":3,"p":0,"a":0,"pp":20,"tg":7,"pr":0},{"n":"Taunt","t":18,"c":3,"p":0,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Helping Hand","t":1,"c":3,"p":0,"a":0,"pp":20,"tg":8,"pr":5},{"n":"Trick","t":15,"c":3,"p":0,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Role Play","t":15,"c":3,"p":0,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Wish","t":1,"c":3,"p":0,"a":0,"pp":10,"tg":7,"pr":0},{"n":"Assist","t":1,"c":3,"p":0,"a":0,"pp":20,"tg":3,"pr":0},{"n":"Ingrain","t":13,"c":3,"p":0,"a":0,"pp":20,"tg":7,"pr":0},{"n":"Superpower","t":2,"c":1,"p":120,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Magic Coat","t":15,"c":3,"p":0,"a":0,"pp":15,"tg":3,"pr":4},{"n":"Recycle","t":1,"c":3,"p":0,"a":0,"pp":10,"tg":7,"pr":0},{"n":"Revenge","t":2,"c":1,"p":60,"a":100,"pp":10,"tg":1,"pr":-4},{"n":"Brick Break","t":2,"c":1,"p":75,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Yawn","t":1,"c":3,"p":0,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Knock Off","t":18,"c":1,"p":65,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Endeavor","t":1,"c":1,"p":1,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Eruption","t":11,"c":2,"p":150,"a":100,"pp":5,"tg":6,"pr":0},{"n":"Skill Swap","t":15,"c":3,"p":0,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Imprison","t":15,"c":3,"p":0,"a":0,"pp":10,"tg":7,"pr":0},{"n":"Refresh","t":1,"c":3,"p":0,"a":0,"pp":20,"tg":7,"pr":0},{"n":"Grudge","t":8,"c":3,"p":0,"a":0,"pp":5,"tg":7,"pr":0},{"n":"Snatch","t":18,"c":3,"p":0,"a":0,"pp":10,"tg":3,"pr":4},{"n":"Secret Power","t":1,"c":1,"p":70,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Dive","t":12,"c":1,"p":80,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Arm Thrust","t":2,"c":1,"p":15,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Camouflage","t":1,"c":3,"p":0,"a":0,"pp":20,"tg":7,"pr":0},{"n":"Tail Glow","t":7,"c":3,"p":0,"a":0,"pp":20,"tg":7,"pr":0},{"n":"Luster Purge","t":15,"c":2,"p":95,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Mist Ball","t":15,"c":2,"p":95,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Feather Dance","t":3,"c":3,"p":0,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Teeter Dance","t":1,"c":3,"p":0,"a":100,"pp":20,"tg":11,"pr":0},{"n":"Blaze Kick","t":11,"c":1,"p":85,"a":90,"pp":10,"tg":1,"pr":0},{"n":"Mud Sport","t":5,"c":3,"p":0,"a":0,"pp":15,"tg":12,"pr":0},{"n":"Ice Ball","t":16,"c":1,"p":30,"a":90,"pp":20,"tg":1,"pr":0},{"n":"Needle Arm","t":13,"c":1,"p":60,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Slack Off","t":1,"c":3,"p":0,"a":0,"pp":5,"tg":7,"pr":0},{"n":"Hyper Voice","t":1,"c":2,"p":90,"a":100,"pp":10,"tg":6,"pr":0},{"n":"Poison Fang","t":4,"c":1,"p":50,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Crush Claw","t":1,"c":1,"p":75,"a":95,"pp":10,"tg":1,"pr":0},{"n":"Blast Burn","t":11,"c":2,"p":150,"a":90,"pp":5,"tg":1,"pr":0},{"n":"Hydro Cannon","t":12,"c":2,"p":150,"a":90,"pp":5,"tg":1,"pr":0},{"n":"Meteor Mash","t":9,"c":1,"p":90,"a":90,"pp":10,"tg":1,"pr":0},{"n":"Astonish","t":8,"c":1,"p":30,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Weather Ball","t":1,"c":2,"p":50,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Aromatherapy","t":13,"c":3,"p":0,"a":0,"pp":5,"tg":9,"pr":0},{"n":"Fake Tears","t":18,"c":3,"p":0,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Air Cutter","t":3,"c":2,"p":60,"a":95,"pp":25,"tg":6,"pr":0},{"n":"Overheat","t":11,"c":2,"p":130,"a":90,"pp":5,"tg":1,"pr":0},{"n":"Odor Sleuth","t":1,"c":3,"p":0,"a":0,"pp":40,"tg":1,"pr":0},{"n":"Rock Tomb","t":6,"c":1,"p":60,"a":95,"pp":15,"tg":1,"pr":0},{"n":"Silver Wind","t":7,"c":2,"p":60,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Metal Sound","t":9,"c":3,"p":0,"a":85,"pp":40,"tg":1,"pr":0},{"n":"Grass Whistle","t":13,"c":3,"p":0,"a":55,"pp":15,"tg":1,"pr":0},{"n":"Tickle","t":1,"c":3,"p":0,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Cosmic Power","t":15,"c":3,"p":0,"a":0,"pp":20,"tg":7,"pr":0},{"n":"Water Spout","t":12,"c":2,"p":150,"a":100,"pp":5,"tg":6,"pr":0},{"n":"Signal Beam","t":7,"c":2,"p":75,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Shadow Punch","t":8,"c":1,"p":60,"a":0,"pp":20,"tg":1,"pr":0},{"n":"Extrasensory","t":15,"c":2,"p":80,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Sky Uppercut","t":2,"c":1,"p":85,"a":90,"pp":15,"tg":1,"pr":0},{"n":"Sand Tomb","t":5,"c":1,"p":35,"a":85,"pp":15,"tg":1,"pr":0},{"n":"Sheer Cold","t":16,"c":2,"p":1,"a":30,"pp":5,"tg":1,"pr":0},{"n":"Muddy Water","t":12,"c":2,"p":90,"a":85,"pp":10,"tg":6,"pr":0},{"n":"Bullet Seed","t":13,"c":1,"p":25,"a":100,"pp":30,"tg":1,"pr":0},{"n":"Aerial Ace","t":3,"c":1,"p":60,"a":0,"pp":20,"tg":1,"pr":0},{"n":"Icicle Spear","t":16,"c":1,"p":25,"a":100,"pp":30,"tg":1,"pr":0},{"n":"Iron Defense","t":9,"c":3,"p":0,"a":0,"pp":15,"tg":7,"pr":0},{"n":"Block","t":1,"c":3,"p":0,"a":0,"pp":5,"tg":1,"pr":0},{"n":"Howl","t":1,"c":3,"p":0,"a":0,"pp":40,"tg":9,"pr":0},{"n":"Dragon Claw","t":17,"c":1,"p":80,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Frenzy Plant","t":13,"c":2,"p":150,"a":90,"pp":5,"tg":1,"pr":0},{"n":"Bulk Up","t":2,"c":3,"p":0,"a":0,"pp":20,"tg":7,"pr":0},{"n":"Bounce","t":3,"c":1,"p":85,"a":85,"pp":5,"tg":1,"pr":0},{"n":"Mud Shot","t":5,"c":2,"p":55,"a":95,"pp":15,"tg":1,"pr":0},{"n":"Poison Tail","t":4,"c":1,"p":50,"a":100,"pp":25,"tg":1,"pr":0},{"n":"Covet","t":1,"c":1,"p":60,"a":100,"pp":25,"tg":1,"pr":0},{"n":"Volt Tackle","t":14,"c":1,"p":120,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Magical Leaf","t":13,"c":2,"p":60,"a":0,"pp":20,"tg":1,"pr":0},{"n":"Water Sport","t":12,"c":3,"p":0,"a":0,"pp":15,"tg":12,"pr":0},{"n":"Calm Mind","t":15,"c":3,"p":0,"a":0,"pp":20,"tg":7,"pr":0},{"n":"Leaf Blade","t":13,"c":1,"p":90,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Dragon Dance","t":17,"c":3,"p":0,"a":0,"pp":20,"tg":7,"pr":0},{"n":"Rock Blast","t":6,"c":1,"p":25,"a":90,"pp":10,"tg":1,"pr":0},{"n":"Shock Wave","t":14,"c":2,"p":60,"a":0,"pp":20,"tg":1,"pr":0},{"n":"Water Pulse","t":12,"c":2,"p":60,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Doom Desire","t":9,"c":2,"p":140,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Psycho Boost","t":15,"c":2,"p":140,"a":90,"pp":5,"tg":1,"pr":0},{"n":"Roost","t":3,"c":3,"p":0,"a":0,"pp":5,"tg":7,"pr":0},{"n":"Gravity","t":15,"c":3,"p":0,"a":0,"pp":5,"tg":12,"pr":0},{"n":"Miracle Eye","t":15,"c":3,"p":0,"a":0,"pp":40,"tg":1,"pr":0},{"n":"Wake-Up Slap","t":2,"c":1,"p":70,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Hammer Arm","t":2,"c":1,"p":100,"a":90,"pp":10,"tg":1,"pr":0},{"n":"Gyro Ball","t":9,"c":1,"p":1,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Healing Wish","t":15,"c":3,"p":0,"a":0,"pp":10,"tg":7,"pr":0},{"n":"Brine","t":12,"c":2,"p":65,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Natural Gift","t":1,"c":1,"p":1,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Feint","t":1,"c":1,"p":30,"a":100,"pp":10,"tg":1,"pr":2},{"n":"Pluck","t":3,"c":1,"p":60,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Tailwind","t":3,"c":3,"p":0,"a":0,"pp":15,"tg":7,"pr":0},{"n":"Acupressure","t":1,"c":3,"p":0,"a":0,"pp":30,"tg":10,"pr":0},{"n":"Metal Burst","t":9,"c":1,"p":1,"a":100,"pp":10,"tg":3,"pr":0},{"n":"U-turn","t":7,"c":1,"p":70,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Close Combat","t":2,"c":1,"p":120,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Payback","t":18,"c":1,"p":50,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Assurance","t":18,"c":1,"p":60,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Embargo","t":18,"c":3,"p":0,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Fling","t":18,"c":1,"p":1,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Psycho Shift","t":15,"c":3,"p":0,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Trump Card","t":1,"c":2,"p":1,"a":0,"pp":5,"tg":1,"pr":0},{"n":"Heal Block","t":15,"c":3,"p":0,"a":100,"pp":15,"tg":6,"pr":0},{"n":"Wring Out","t":1,"c":2,"p":120,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Power Trick","t":15,"c":3,"p":0,"a":0,"pp":10,"tg":7,"pr":0},{"n":"Gastro Acid","t":4,"c":3,"p":0,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Lucky Chant","t":1,"c":3,"p":0,"a":0,"pp":30,"tg":7,"pr":0},{"n":"Me First","t":1,"c":3,"p":0,"a":0,"pp":20,"tg":4,"pr":0},{"n":"Copycat","t":1,"c":3,"p":0,"a":0,"pp":20,"tg":3,"pr":0},{"n":"Power Swap","t":15,"c":3,"p":0,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Guard Swap","t":15,"c":3,"p":0,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Punishment","t":18,"c":1,"p":60,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Last Resort","t":1,"c":1,"p":140,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Worry Seed","t":13,"c":3,"p":0,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Sucker Punch","t":18,"c":1,"p":70,"a":100,"pp":5,"tg":1,"pr":1},{"n":"Toxic Spikes","t":4,"c":3,"p":0,"a":0,"pp":20,"tg":13,"pr":0},{"n":"Heart Swap","t":15,"c":3,"p":0,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Aqua Ring","t":12,"c":3,"p":0,"a":0,"pp":20,"tg":7,"pr":0},{"n":"Magnet Rise","t":14,"c":3,"p":0,"a":0,"pp":10,"tg":7,"pr":0},{"n":"Flare Blitz","t":11,"c":1,"p":120,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Force Palm","t":2,"c":1,"p":60,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Aura Sphere","t":2,"c":2,"p":80,"a":0,"pp":20,"tg":1,"pr":0},{"n":"Rock Polish","t":6,"c":3,"p":0,"a":0,"pp":20,"tg":7,"pr":0},{"n":"Poison Jab","t":4,"c":1,"p":80,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Dark Pulse","t":18,"c":2,"p":80,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Night Slash","t":18,"c":1,"p":70,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Aqua Tail","t":12,"c":1,"p":90,"a":90,"pp":10,"tg":1,"pr":0},{"n":"Seed Bomb","t":13,"c":1,"p":80,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Air Slash","t":3,"c":2,"p":75,"a":95,"pp":15,"tg":1,"pr":0},{"n":"X-Scissor","t":7,"c":1,"p":80,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Bug Buzz","t":7,"c":2,"p":90,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Dragon Pulse","t":17,"c":2,"p":85,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Dragon Rush","t":17,"c":1,"p":100,"a":75,"pp":10,"tg":1,"pr":0},{"n":"Power Gem","t":6,"c":2,"p":80,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Drain Punch","t":2,"c":1,"p":75,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Vacuum Wave","t":2,"c":2,"p":40,"a":100,"pp":30,"tg":1,"pr":1},{"n":"Focus Blast","t":2,"c":2,"p":120,"a":70,"pp":5,"tg":1,"pr":0},{"n":"Energy Ball","t":13,"c":2,"p":90,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Brave Bird","t":3,"c":1,"p":120,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Earth Power","t":5,"c":2,"p":90,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Switcheroo","t":18,"c":3,"p":0,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Giga Impact","t":1,"c":1,"p":150,"a":90,"pp":5,"tg":1,"pr":0},{"n":"Nasty Plot","t":18,"c":3,"p":0,"a":0,"pp":20,"tg":7,"pr":0},{"n":"Bullet Punch","t":9,"c":1,"p":40,"a":100,"pp":30,"tg":1,"pr":1},{"n":"Avalanche","t":16,"c":1,"p":60,"a":100,"pp":10,"tg":1,"pr":-4},{"n":"Ice Shard","t":16,"c":1,"p":40,"a":100,"pp":30,"tg":1,"pr":1},{"n":"Shadow Claw","t":8,"c":1,"p":70,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Thunder Fang","t":14,"c":1,"p":65,"a":95,"pp":15,"tg":1,"pr":0},{"n":"Ice Fang","t":16,"c":1,"p":65,"a":95,"pp":15,"tg":1,"pr":0},{"n":"Fire Fang","t":11,"c":1,"p":65,"a":95,"pp":15,"tg":1,"pr":0},{"n":"Shadow Sneak","t":8,"c":1,"p":40,"a":100,"pp":30,"tg":1,"pr":1},{"n":"Mud Bomb","t":5,"c":2,"p":65,"a":85,"pp":10,"tg":1,"pr":0},{"n":"Psycho Cut","t":15,"c":1,"p":70,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Zen Headbutt","t":15,"c":1,"p":80,"a":90,"pp":15,"tg":1,"pr":0},{"n":"Mirror Shot","t":9,"c":2,"p":65,"a":85,"pp":10,"tg":1,"pr":0},{"n":"Flash Cannon","t":9,"c":2,"p":80,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Rock Climb","t":1,"c":1,"p":90,"a":85,"pp":20,"tg":1,"pr":0},{"n":"Defog","t":3,"c":3,"p":0,"a":0,"pp":15,"tg":1,"pr":0},{"n":"Trick Room","t":15,"c":3,"p":0,"a":0,"pp":5,"tg":12,"pr":-7},{"n":"Draco Meteor","t":17,"c":2,"p":130,"a":90,"pp":5,"tg":1,"pr":0},{"n":"Discharge","t":14,"c":2,"p":80,"a":100,"pp":15,"tg":11,"pr":0},{"n":"Lava Plume","t":11,"c":2,"p":80,"a":100,"pp":15,"tg":11,"pr":0},{"n":"Leaf Storm","t":13,"c":2,"p":130,"a":90,"pp":5,"tg":1,"pr":0},{"n":"Power Whip","t":13,"c":1,"p":120,"a":85,"pp":10,"tg":1,"pr":0},{"n":"Rock Wrecker","t":6,"c":1,"p":150,"a":90,"pp":5,"tg":1,"pr":0},{"n":"Cross Poison","t":4,"c":1,"p":70,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Gunk Shot","t":4,"c":1,"p":120,"a":80,"pp":5,"tg":1,"pr":0},{"n":"Iron Head","t":9,"c":1,"p":80,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Magnet Bomb","t":9,"c":1,"p":60,"a":0,"pp":20,"tg":1,"pr":0},{"n":"Stone Edge","t":6,"c":1,"p":100,"a":80,"pp":5,"tg":1,"pr":0},{"n":"Captivate","t":1,"c":3,"p":0,"a":100,"pp":20,"tg":6,"pr":0},{"n":"Stealth Rock","t":6,"c":3,"p":0,"a":0,"pp":20,"tg":13,"pr":0},{"n":"Grass Knot","t":13,"c":2,"p":1,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Chatter","t":3,"c":2,"p":65,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Judgment","t":1,"c":2,"p":100,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Bug Bite","t":7,"c":1,"p":60,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Charge Beam","t":14,"c":2,"p":50,"a":90,"pp":10,"tg":1,"pr":0},{"n":"Wood Hammer","t":13,"c":1,"p":120,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Aqua Jet","t":12,"c":1,"p":40,"a":100,"pp":20,"tg":1,"pr":1},{"n":"Attack Order","t":7,"c":1,"p":90,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Defend Order","t":7,"c":3,"p":0,"a":0,"pp":10,"tg":7,"pr":0},{"n":"Heal Order","t":7,"c":3,"p":0,"a":0,"pp":10,"tg":7,"pr":0},{"n":"Head Smash","t":6,"c":1,"p":150,"a":80,"pp":5,"tg":1,"pr":0},{"n":"Double Hit","t":1,"c":1,"p":35,"a":90,"pp":10,"tg":1,"pr":0},{"n":"Roar of Time","t":17,"c":2,"p":150,"a":90,"pp":5,"tg":1,"pr":0},{"n":"Spacial Rend","t":17,"c":2,"p":100,"a":95,"pp":5,"tg":1,"pr":0},{"n":"Lunar Dance","t":15,"c":3,"p":0,"a":0,"pp":10,"tg":7,"pr":0},{"n":"Crush Grip","t":1,"c":1,"p":120,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Magma Storm","t":11,"c":2,"p":100,"a":75,"pp":5,"tg":1,"pr":0},{"n":"Dark Void","t":18,"c":3,"p":0,"a":50,"pp":10,"tg":6,"pr":0},{"n":"Seed Flare","t":13,"c":2,"p":120,"a":85,"pp":5,"tg":1,"pr":0},{"n":"Ominous Wind","t":8,"c":2,"p":60,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Shadow Force","t":8,"c":1,"p":120,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Hone Claws","t":18,"c":3,"p":0,"a":0,"pp":15,"tg":7,"pr":0},{"n":"Wide Guard","t":6,"c":3,"p":0,"a":0,"pp":10,"tg":7,"pr":3},{"n":"Guard Split","t":15,"c":3,"p":0,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Power Split","t":15,"c":3,"p":0,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Wonder Room","t":15,"c":3,"p":0,"a":0,"pp":10,"tg":12,"pr":0},{"n":"Psyshock","t":15,"c":2,"p":80,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Venoshock","t":4,"c":2,"p":65,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Autotomize","t":9,"c":3,"p":0,"a":0,"pp":15,"tg":7,"pr":0},{"n":"Rage Powder","t":7,"c":3,"p":0,"a":0,"pp":20,"tg":7,"pr":2},{"n":"Telekinesis","t":15,"c":3,"p":0,"a":0,"pp":15,"tg":1,"pr":0},{"n":"Magic Room","t":15,"c":3,"p":0,"a":0,"pp":10,"tg":12,"pr":0},{"n":"Smack Down","t":6,"c":1,"p":50,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Storm Throw","t":2,"c":1,"p":60,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Flame Burst","t":11,"c":2,"p":70,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Sludge Wave","t":4,"c":2,"p":95,"a":100,"pp":10,"tg":11,"pr":0},{"n":"Quiver Dance","t":7,"c":3,"p":0,"a":0,"pp":20,"tg":7,"pr":0},{"n":"Heavy Slam","t":9,"c":1,"p":1,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Synchronoise","t":15,"c":2,"p":120,"a":100,"pp":10,"tg":11,"pr":0},{"n":"Electro Ball","t":14,"c":2,"p":1,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Soak","t":12,"c":3,"p":0,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Flame Charge","t":11,"c":1,"p":50,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Coil","t":4,"c":3,"p":0,"a":0,"pp":20,"tg":7,"pr":0},{"n":"Low Sweep","t":2,"c":1,"p":65,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Acid Spray","t":4,"c":2,"p":40,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Foul Play","t":18,"c":1,"p":95,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Simple Beam","t":1,"c":3,"p":0,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Entrainment","t":1,"c":3,"p":0,"a":100,"pp":15,"tg":1,"pr":0},{"n":"After You","t":1,"c":3,"p":0,"a":0,"pp":15,"tg":1,"pr":0},{"n":"Round","t":1,"c":2,"p":60,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Echoed Voice","t":1,"c":2,"p":40,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Chip Away","t":1,"c":1,"p":70,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Clear Smog","t":4,"c":2,"p":50,"a":0,"pp":15,"tg":1,"pr":0},{"n":"Stored Power","t":15,"c":2,"p":20,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Quick Guard","t":2,"c":3,"p":0,"a":0,"pp":15,"tg":7,"pr":3},{"n":"Ally Switch","t":15,"c":3,"p":0,"a":0,"pp":15,"tg":7,"pr":2},{"n":"Scald","t":12,"c":2,"p":80,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Shell Smash","t":1,"c":3,"p":0,"a":0,"pp":15,"tg":7,"pr":0},{"n":"Heal Pulse","t":15,"c":3,"p":0,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Hex","t":8,"c":2,"p":65,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Sky Drop","t":3,"c":1,"p":60,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Shift Gear","t":9,"c":3,"p":0,"a":0,"pp":10,"tg":7,"pr":0},{"n":"Circle Throw","t":2,"c":1,"p":60,"a":90,"pp":10,"tg":1,"pr":-6},{"n":"Incinerate","t":11,"c":2,"p":60,"a":100,"pp":15,"tg":6,"pr":0},{"n":"Quash","t":18,"c":3,"p":0,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Acrobatics","t":3,"c":1,"p":55,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Reflect Type","t":1,"c":3,"p":0,"a":0,"pp":15,"tg":1,"pr":0},{"n":"Retaliate","t":1,"c":1,"p":70,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Final Gambit","t":2,"c":2,"p":1,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Bestow","t":1,"c":3,"p":0,"a":0,"pp":15,"tg":1,"pr":0},{"n":"Inferno","t":11,"c":2,"p":100,"a":50,"pp":5,"tg":1,"pr":0},{"n":"Water Pledge","t":12,"c":2,"p":80,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Fire Pledge","t":11,"c":2,"p":80,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Grass Pledge","t":13,"c":2,"p":80,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Volt Switch","t":14,"c":2,"p":70,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Struggle Bug","t":7,"c":2,"p":50,"a":100,"pp":20,"tg":6,"pr":0},{"n":"Bulldoze","t":5,"c":1,"p":60,"a":100,"pp":20,"tg":11,"pr":0},{"n":"Frost Breath","t":16,"c":2,"p":60,"a":90,"pp":10,"tg":1,"pr":0},{"n":"Dragon Tail","t":17,"c":1,"p":60,"a":90,"pp":10,"tg":1,"pr":-6},{"n":"Work Up","t":1,"c":3,"p":0,"a":0,"pp":30,"tg":7,"pr":0},{"n":"Electroweb","t":14,"c":2,"p":55,"a":95,"pp":15,"tg":6,"pr":0},{"n":"Wild Charge","t":14,"c":1,"p":90,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Drill Run","t":5,"c":1,"p":80,"a":95,"pp":10,"tg":1,"pr":0},{"n":"Dual Chop","t":17,"c":1,"p":40,"a":90,"pp":15,"tg":1,"pr":0},{"n":"Heart Stamp","t":15,"c":1,"p":60,"a":100,"pp":25,"tg":1,"pr":0},{"n":"Horn Leech","t":13,"c":1,"p":75,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Sacred Sword","t":2,"c":1,"p":90,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Razor Shell","t":12,"c":1,"p":75,"a":95,"pp":10,"tg":1,"pr":0},{"n":"Heat Crash","t":11,"c":1,"p":1,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Leaf Tornado","t":13,"c":2,"p":65,"a":90,"pp":10,"tg":1,"pr":0},{"n":"Steamroller","t":7,"c":1,"p":65,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Cotton Guard","t":13,"c":3,"p":0,"a":0,"pp":10,"tg":7,"pr":0},{"n":"Night Daze","t":18,"c":2,"p":85,"a":95,"pp":10,"tg":1,"pr":0},{"n":"Psystrike","t":15,"c":2,"p":100,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Tail Slap","t":1,"c":1,"p":25,"a":85,"pp":10,"tg":1,"pr":0},{"n":"Hurricane","t":3,"c":2,"p":110,"a":70,"pp":10,"tg":1,"pr":0},{"n":"Head Charge","t":1,"c":1,"p":120,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Gear Grind","t":9,"c":1,"p":50,"a":85,"pp":15,"tg":1,"pr":0},{"n":"Searing Shot","t":11,"c":2,"p":100,"a":100,"pp":5,"tg":11,"pr":0},{"n":"Techno Blast","t":1,"c":2,"p":120,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Relic Song","t":1,"c":2,"p":75,"a":100,"pp":10,"tg":6,"pr":0},{"n":"Secret Sword","t":2,"c":2,"p":85,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Glaciate","t":16,"c":2,"p":65,"a":95,"pp":10,"tg":6,"pr":0},{"n":"Bolt Strike","t":14,"c":1,"p":130,"a":85,"pp":5,"tg":1,"pr":0},{"n":"Blue Flare","t":11,"c":2,"p":130,"a":85,"pp":5,"tg":1,"pr":0},{"n":"Fiery Dance","t":11,"c":2,"p":80,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Freeze Shock","t":16,"c":1,"p":140,"a":90,"pp":5,"tg":1,"pr":0},{"n":"Ice Burn","t":16,"c":2,"p":140,"a":90,"pp":5,"tg":1,"pr":0},{"n":"Snarl","t":18,"c":2,"p":55,"a":95,"pp":15,"tg":6,"pr":0},{"n":"Icicle Crash","t":16,"c":1,"p":85,"a":90,"pp":10,"tg":1,"pr":0},{"n":"V-create","t":11,"c":1,"p":180,"a":95,"pp":5,"tg":1,"pr":0},{"n":"Fusion Flare","t":11,"c":2,"p":100,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Fusion Bolt","t":14,"c":1,"p":100,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Flying Press","t":2,"c":1,"p":100,"a":95,"pp":10,"tg":1,"pr":0},{"n":"Mat Block","t":2,"c":3,"p":0,"a":0,"pp":15,"tg":7,"pr":0},{"n":"Belch","t":4,"c":2,"p":120,"a":90,"pp":10,"tg":1,"pr":0},{"n":"Rototiller","t":5,"c":3,"p":0,"a":0,"pp":10,"tg":14,"pr":0},{"n":"Sticky Web","t":7,"c":3,"p":0,"a":0,"pp":20,"tg":13,"pr":0},{"n":"Fell Stinger","t":7,"c":1,"p":50,"a":100,"pp":25,"tg":1,"pr":0},{"n":"Phantom Force","t":8,"c":1,"p":90,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Trick-or-Treat","t":8,"c":3,"p":0,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Noble Roar","t":1,"c":3,"p":0,"a":100,"pp":30,"tg":1,"pr":0},{"n":"Ion Deluge","t":14,"c":3,"p":0,"a":0,"pp":25,"tg":12,"pr":1},{"n":"Parabolic Charge","t":14,"c":2,"p":65,"a":100,"pp":20,"tg":11,"pr":0},{"n":"Forest’s Curse","t":13,"c":3,"p":0,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Petal Blizzard","t":13,"c":1,"p":90,"a":100,"pp":15,"tg":11,"pr":0},{"n":"Freeze-Dry","t":16,"c":2,"p":70,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Disarming Voice","t":19,"c":2,"p":40,"a":0,"pp":15,"tg":6,"pr":0},{"n":"Parting Shot","t":18,"c":3,"p":0,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Topsy-Turvy","t":18,"c":3,"p":0,"a":0,"pp":20,"tg":1,"pr":0},{"n":"Draining Kiss","t":19,"c":2,"p":50,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Crafty Shield","t":19,"c":3,"p":0,"a":0,"pp":10,"tg":7,"pr":3},{"n":"Flower Shield","t":19,"c":3,"p":0,"a":0,"pp":10,"tg":14,"pr":0},{"n":"Grassy Terrain","t":13,"c":3,"p":0,"a":0,"pp":10,"tg":12,"pr":0},{"n":"Misty Terrain","t":19,"c":3,"p":0,"a":0,"pp":10,"tg":12,"pr":0},{"n":"Electrify","t":14,"c":3,"p":0,"a":0,"pp":20,"tg":1,"pr":0},{"n":"Play Rough","t":19,"c":1,"p":90,"a":90,"pp":10,"tg":1,"pr":0},{"n":"Fairy Wind","t":19,"c":2,"p":40,"a":100,"pp":30,"tg":1,"pr":0},{"n":"Moonblast","t":19,"c":2,"p":95,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Boomburst","t":1,"c":2,"p":140,"a":100,"pp":10,"tg":11,"pr":0},{"n":"Fairy Lock","t":19,"c":3,"p":0,"a":0,"pp":10,"tg":12,"pr":0},{"n":"King’s Shield","t":9,"c":3,"p":0,"a":0,"pp":10,"tg":7,"pr":4},{"n":"Play Nice","t":1,"c":3,"p":0,"a":0,"pp":20,"tg":1,"pr":0},{"n":"Confide","t":1,"c":3,"p":0,"a":0,"pp":20,"tg":1,"pr":0},{"n":"Diamond Storm","t":6,"c":1,"p":100,"a":95,"pp":5,"tg":6,"pr":0},{"n":"Steam Eruption","t":12,"c":2,"p":110,"a":95,"pp":5,"tg":1,"pr":0},{"n":"Hyperspace Hole","t":15,"c":2,"p":80,"a":0,"pp":5,"tg":1,"pr":0},{"n":"Water Shuriken","t":12,"c":2,"p":15,"a":100,"pp":20,"tg":1,"pr":1},{"n":"Mystical Fire","t":11,"c":2,"p":75,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Spiky Shield","t":13,"c":3,"p":0,"a":0,"pp":10,"tg":7,"pr":4},{"n":"Aromatic Mist","t":19,"c":3,"p":0,"a":0,"pp":20,"tg":8,"pr":0},{"n":"Eerie Impulse","t":14,"c":3,"p":0,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Venom Drench","t":4,"c":3,"p":0,"a":100,"pp":20,"tg":6,"pr":0},{"n":"Powder","t":7,"c":3,"p":0,"a":100,"pp":20,"tg":1,"pr":1},{"n":"Geomancy","t":19,"c":3,"p":0,"a":0,"pp":10,"tg":7,"pr":0},{"n":"Magnetic Flux","t":14,"c":3,"p":0,"a":0,"pp":20,"tg":9,"pr":0},{"n":"Happy Hour","t":1,"c":3,"p":0,"a":0,"pp":30,"tg":7,"pr":0},{"n":"Electric Terrain","t":14,"c":3,"p":0,"a":0,"pp":10,"tg":12,"pr":0},{"n":"Dazzling Gleam","t":19,"c":2,"p":80,"a":100,"pp":10,"tg":6,"pr":0},{"n":"Celebrate","t":1,"c":3,"p":0,"a":0,"pp":40,"tg":7,"pr":0},{"n":"Hold Hands","t":1,"c":3,"p":0,"a":0,"pp":40,"tg":8,"pr":0},{"n":"Baby-Doll Eyes","t":19,"c":3,"p":0,"a":100,"pp":30,"tg":1,"pr":1},{"n":"Nuzzle","t":14,"c":1,"p":20,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Hold Back","t":1,"c":1,"p":40,"a":100,"pp":40,"tg":1,"pr":0},{"n":"Infestation","t":7,"c":2,"p":20,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Power-Up Punch","t":2,"c":1,"p":40,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Oblivion Wing","t":3,"c":2,"p":80,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Thousand Arrows","t":5,"c":1,"p":90,"a":100,"pp":10,"tg":6,"pr":0},{"n":"Thousand Waves","t":5,"c":1,"p":90,"a":100,"pp":10,"tg":6,"pr":0},{"n":"Land’s Wrath","t":5,"c":1,"p":90,"a":100,"pp":10,"tg":6,"pr":0},{"n":"Light Of Ruin","t":19,"c":2,"p":140,"a":90,"pp":5,"tg":1,"pr":0},{"n":"Origin Pulse","t":12,"c":2,"p":110,"a":85,"pp":10,"tg":6,"pr":0},{"n":"Precipice Blades","t":5,"c":1,"p":120,"a":85,"pp":10,"tg":6,"pr":0},{"n":"Dragon Ascent","t":3,"c":1,"p":120,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Hyperspace Fury","t":18,"c":1,"p":100,"a":0,"pp":5,"tg":1,"pr":0},{"n":"Shore Up","t":5,"c":3,"p":0,"a":0,"pp":5,"tg":7,"pr":0},{"n":"First Impression","t":7,"c":1,"p":90,"a":100,"pp":10,"tg":1,"pr":2},{"n":"Baneful Bunker","t":4,"c":3,"p":0,"a":0,"pp":10,"tg":7,"pr":4},{"n":"Spirit Shackle","t":8,"c":1,"p":80,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Darkest Lariat","t":18,"c":1,"p":85,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Sparkling Aria","t":12,"c":2,"p":90,"a":100,"pp":10,"tg":11,"pr":0},{"n":"Ice Hammer","t":16,"c":1,"p":100,"a":90,"pp":10,"tg":1,"pr":0},{"n":"Floral Healing","t":19,"c":3,"p":0,"a":0,"pp":10,"tg":1,"pr":0},{"n":"High Horsepower","t":5,"c":1,"p":95,"a":95,"pp":10,"tg":1,"pr":0},{"n":"Strength Sap","t":13,"c":3,"p":0,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Solar Blade","t":13,"c":1,"p":125,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Leafage","t":13,"c":1,"p":40,"a":100,"pp":40,"tg":1,"pr":0},{"n":"Spotlight","t":1,"c":3,"p":0,"a":0,"pp":15,"tg":1,"pr":3},{"n":"Toxic Thread","t":4,"c":3,"p":0,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Laser Focus","t":1,"c":3,"p":0,"a":0,"pp":30,"tg":7,"pr":0},{"n":"Gear Up","t":9,"c":3,"p":0,"a":0,"pp":20,"tg":9,"pr":0},{"n":"Throat Chop","t":18,"c":1,"p":80,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Pollen Puff","t":7,"c":2,"p":90,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Anchor Shot","t":9,"c":1,"p":80,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Psychic Terrain","t":15,"c":3,"p":0,"a":0,"pp":10,"tg":12,"pr":0},{"n":"Lunge","t":7,"c":1,"p":80,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Fire Lash","t":11,"c":1,"p":80,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Power Trip","t":18,"c":1,"p":20,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Burn Up","t":11,"c":2,"p":130,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Speed Swap","t":15,"c":3,"p":0,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Smart Strike","t":9,"c":1,"p":70,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Purify","t":4,"c":3,"p":0,"a":0,"pp":20,"tg":1,"pr":0},{"n":"Revelation Dance","t":1,"c":2,"p":90,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Core Enforcer","t":17,"c":2,"p":100,"a":100,"pp":10,"tg":6,"pr":0},{"n":"Trop Kick","t":13,"c":1,"p":70,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Instruct","t":15,"c":3,"p":0,"a":0,"pp":15,"tg":1,"pr":0},{"n":"Beak Blast","t":3,"c":1,"p":100,"a":100,"pp":15,"tg":1,"pr":-3},{"n":"Clanging Scales","t":17,"c":2,"p":110,"a":100,"pp":5,"tg":6,"pr":0},{"n":"Dragon Hammer","t":17,"c":1,"p":90,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Brutal Swing","t":18,"c":1,"p":60,"a":100,"pp":20,"tg":11,"pr":0},{"n":"Aurora Veil","t":16,"c":3,"p":0,"a":0,"pp":20,"tg":7,"pr":0},{"n":"Shell Trap","t":11,"c":2,"p":150,"a":100,"pp":5,"tg":6,"pr":-3},{"n":"Fleur Cannon","t":19,"c":2,"p":130,"a":90,"pp":5,"tg":1,"pr":0},{"n":"Psychic Fangs","t":15,"c":1,"p":85,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Stomping Tantrum","t":5,"c":1,"p":75,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Shadow Bone","t":8,"c":1,"p":85,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Accelerock","t":6,"c":1,"p":40,"a":100,"pp":20,"tg":1,"pr":1},{"n":"Liquidation","t":12,"c":1,"p":85,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Prismatic Laser","t":15,"c":2,"p":160,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Spectral Thief","t":8,"c":1,"p":90,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Sunsteel Strike","t":9,"c":1,"p":100,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Moongeist Beam","t":8,"c":2,"p":100,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Tearful Look","t":1,"c":3,"p":0,"a":0,"pp":20,"tg":1,"pr":0},{"n":"Zing Zap","t":14,"c":1,"p":80,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Nature’s Madness","t":19,"c":2,"p":1,"a":90,"pp":10,"tg":1,"pr":0},{"n":"Multi-Attack","t":1,"c":1,"p":120,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Mind Blown","t":11,"c":2,"p":150,"a":100,"pp":5,"tg":11,"pr":0},{"n":"Plasma Fists","t":14,"c":1,"p":100,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Photon Geyser","t":15,"c":2,"p":100,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Zippy Zap","t":14,"c":1,"p":80,"a":100,"pp":10,"tg":1,"pr":2},{"n":"Splishy Splash","t":12,"c":2,"p":90,"a":100,"pp":15,"tg":6,"pr":0},{"n":"Floaty Fall","t":3,"c":1,"p":90,"a":95,"pp":15,"tg":1,"pr":0},{"n":"Pika Papow","t":14,"c":2,"p":1,"a":0,"pp":20,"tg":1,"pr":0},{"n":"Bouncy Bubble","t":12,"c":2,"p":60,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Buzzy Buzz","t":14,"c":2,"p":60,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Sizzly Slide","t":11,"c":1,"p":60,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Glitzy Glow","t":15,"c":2,"p":80,"a":95,"pp":15,"tg":1,"pr":0},{"n":"Baddy Bad","t":18,"c":2,"p":80,"a":95,"pp":15,"tg":1,"pr":0},{"n":"Sappy Seed","t":13,"c":1,"p":100,"a":90,"pp":10,"tg":1,"pr":0},{"n":"Freezy Frost","t":16,"c":2,"p":100,"a":90,"pp":10,"tg":1,"pr":0},{"n":"Sparkly Swirl","t":19,"c":2,"p":120,"a":85,"pp":5,"tg":1,"pr":0},{"n":"Veevee Volley","t":1,"c":1,"p":1,"a":0,"pp":20,"tg":1,"pr":0},{"n":"Double Iron Bash","t":9,"c":1,"p":60,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Dynamax Cannon","t":17,"c":2,"p":100,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Snipe Shot","t":12,"c":2,"p":80,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Jaw Lock","t":18,"c":1,"p":80,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Stuff Cheeks","t":1,"c":3,"p":0,"a":0,"pp":10,"tg":7,"pr":0},{"n":"No Retreat","t":2,"c":3,"p":0,"a":0,"pp":5,"tg":7,"pr":0},{"n":"Tar Shot","t":6,"c":3,"p":0,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Magic Powder","t":15,"c":3,"p":0,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Dragon Darts","t":17,"c":1,"p":50,"a":100,"pp":10,"tg":2,"pr":0},{"n":"Teatime","t":1,"c":3,"p":0,"a":0,"pp":10,"tg":14,"pr":0},{"n":"Octolock","t":2,"c":3,"p":0,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Bolt Beak","t":14,"c":1,"p":85,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Fishious Rend","t":12,"c":1,"p":85,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Court Change","t":1,"c":3,"p":0,"a":100,"pp":10,"tg":12,"pr":0},{"n":"Clangorous Soul","t":17,"c":3,"p":0,"a":100,"pp":5,"tg":7,"pr":0},{"n":"Body Press","t":2,"c":1,"p":80,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Decorate","t":19,"c":3,"p":0,"a":0,"pp":15,"tg":1,"pr":0},{"n":"Drum Beating","t":13,"c":1,"p":80,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Snap Trap","t":13,"c":1,"p":35,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Pyro Ball","t":11,"c":1,"p":120,"a":90,"pp":5,"tg":1,"pr":0},{"n":"Behemoth Blade","t":9,"c":1,"p":100,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Behemoth Bash","t":9,"c":1,"p":100,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Aura Wheel","t":14,"c":1,"p":110,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Breaking Swipe","t":17,"c":1,"p":60,"a":100,"pp":15,"tg":6,"pr":0},{"n":"Branch Poke","t":13,"c":1,"p":40,"a":100,"pp":40,"tg":1,"pr":0},{"n":"Overdrive","t":14,"c":2,"p":80,"a":100,"pp":10,"tg":6,"pr":0},{"n":"Apple Acid","t":13,"c":2,"p":80,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Grav Apple","t":13,"c":1,"p":80,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Spirit Break","t":19,"c":1,"p":75,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Strange Steam","t":19,"c":2,"p":90,"a":95,"pp":10,"tg":1,"pr":0},{"n":"Life Dew","t":12,"c":3,"p":0,"a":0,"pp":10,"tg":7,"pr":0},{"n":"Obstruct","t":18,"c":3,"p":0,"a":100,"pp":10,"tg":7,"pr":4},{"n":"False Surrender","t":18,"c":1,"p":80,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Meteor Assault","t":2,"c":1,"p":150,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Eternabeam","t":17,"c":2,"p":160,"a":90,"pp":5,"tg":1,"pr":0},{"n":"Steel Beam","t":9,"c":2,"p":140,"a":95,"pp":5,"tg":1,"pr":0},{"n":"Expanding Force","t":15,"c":2,"p":80,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Steel Roller","t":9,"c":1,"p":130,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Scale Shot","t":17,"c":1,"p":25,"a":90,"pp":20,"tg":1,"pr":0},{"n":"Meteor Beam","t":6,"c":2,"p":120,"a":90,"pp":10,"tg":1,"pr":0},{"n":"Shell Side Arm","t":4,"c":2,"p":90,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Misty Explosion","t":19,"c":2,"p":100,"a":100,"pp":5,"tg":11,"pr":0},{"n":"Grassy Glide","t":13,"c":1,"p":55,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Rising Voltage","t":14,"c":2,"p":70,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Terrain Pulse","t":1,"c":2,"p":50,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Skitter Smack","t":7,"c":1,"p":70,"a":90,"pp":10,"tg":1,"pr":0},{"n":"Burning Jealousy","t":11,"c":2,"p":70,"a":100,"pp":5,"tg":6,"pr":0},{"n":"Lash Out","t":18,"c":1,"p":75,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Poltergeist","t":8,"c":1,"p":110,"a":90,"pp":5,"tg":1,"pr":0},{"n":"Corrosive Gas","t":4,"c":3,"p":0,"a":100,"pp":40,"tg":11,"pr":0},{"n":"Coaching","t":2,"c":3,"p":0,"a":0,"pp":10,"tg":8,"pr":0},{"n":"Flip Turn","t":12,"c":1,"p":60,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Triple Axel","t":16,"c":1,"p":20,"a":90,"pp":10,"tg":1,"pr":0},{"n":"Dual Wingbeat","t":3,"c":1,"p":40,"a":90,"pp":10,"tg":1,"pr":0},{"n":"Scorching Sands","t":5,"c":2,"p":70,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Jungle Healing","t":13,"c":3,"p":0,"a":0,"pp":10,"tg":7,"pr":0},{"n":"Wicked Blow","t":18,"c":1,"p":75,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Surging Strikes","t":12,"c":1,"p":25,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Thunder Cage","t":14,"c":2,"p":80,"a":90,"pp":15,"tg":1,"pr":0},{"n":"Dragon Energy","t":17,"c":2,"p":150,"a":100,"pp":5,"tg":6,"pr":0},{"n":"Freezing Glare","t":15,"c":2,"p":90,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Fiery Wrath","t":18,"c":2,"p":90,"a":100,"pp":10,"tg":6,"pr":0},{"n":"Thunderous Kick","t":2,"c":1,"p":90,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Glacial Lance","t":16,"c":1,"p":120,"a":100,"pp":5,"tg":6,"pr":0},{"n":"Astral Barrage","t":8,"c":2,"p":120,"a":100,"pp":5,"tg":6,"pr":0},{"n":"Eerie Spell","t":15,"c":2,"p":80,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Dire Claw","t":4,"c":1,"p":80,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Psyshield Bash","t":15,"c":1,"p":70,"a":90,"pp":10,"tg":1,"pr":0},{"n":"Power Shift","t":1,"c":3,"p":0,"a":0,"pp":10,"tg":7,"pr":0},{"n":"Stone Axe","t":6,"c":1,"p":65,"a":90,"pp":15,"tg":1,"pr":0},{"n":"Springtide Storm","t":19,"c":2,"p":100,"a":80,"pp":5,"tg":6,"pr":0},{"n":"Mystical Power","t":15,"c":2,"p":70,"a":90,"pp":10,"tg":1,"pr":0},{"n":"Raging Fury","t":11,"c":1,"p":120,"a":100,"pp":10,"tg":5,"pr":0},{"n":"Wave Crash","t":12,"c":1,"p":120,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Chloroblast","t":13,"c":2,"p":150,"a":95,"pp":5,"tg":1,"pr":0},{"n":"Mountain Gale","t":16,"c":1,"p":100,"a":85,"pp":10,"tg":1,"pr":0},{"n":"Victory Dance","t":2,"c":3,"p":0,"a":0,"pp":20,"tg":7,"pr":0},{"n":"Headlong Rush","t":5,"c":1,"p":120,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Barb Barrage","t":4,"c":1,"p":60,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Esper Wing","t":15,"c":2,"p":80,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Bitter Malice","t":8,"c":2,"p":75,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Shelter","t":9,"c":3,"p":0,"a":0,"pp":10,"tg":7,"pr":0},{"n":"Triple Arrows","t":2,"c":1,"p":90,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Infernal Parade","t":8,"c":2,"p":60,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Ceaseless Edge","t":18,"c":1,"p":65,"a":90,"pp":15,"tg":1,"pr":0},{"n":"Bleakwind Storm","t":3,"c":2,"p":100,"a":80,"pp":10,"tg":6,"pr":0},{"n":"Wildbolt Storm","t":14,"c":2,"p":100,"a":80,"pp":10,"tg":6,"pr":0},{"n":"Sandsear Storm","t":5,"c":2,"p":100,"a":80,"pp":10,"tg":6,"pr":0},{"n":"Lunar Blessing","t":15,"c":3,"p":0,"a":0,"pp":5,"tg":7,"pr":0},{"n":"Take Heart","t":15,"c":3,"p":0,"a":0,"pp":15,"tg":7,"pr":0},{"n":"Tera Blast","t":1,"c":2,"p":80,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Silk Trap","t":7,"c":3,"p":0,"a":0,"pp":10,"tg":7,"pr":4},{"n":"Axe Kick","t":2,"c":1,"p":120,"a":90,"pp":10,"tg":1,"pr":0},{"n":"Last Respects","t":8,"c":1,"p":50,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Lumina Crash","t":15,"c":2,"p":80,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Order Up","t":17,"c":1,"p":80,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Jet Punch","t":12,"c":1,"p":60,"a":100,"pp":15,"tg":1,"pr":1},{"n":"Spicy Extract","t":13,"c":3,"p":0,"a":0,"pp":15,"tg":1,"pr":0},{"n":"Spin Out","t":9,"c":1,"p":100,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Population Bomb","t":1,"c":1,"p":20,"a":90,"pp":10,"tg":1,"pr":0},{"n":"Ice Spinner","t":16,"c":1,"p":80,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Glaive Rush","t":17,"c":1,"p":120,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Revival Blessing","t":1,"c":3,"p":0,"a":0,"pp":1,"tg":7,"pr":0},{"n":"Salt Cure","t":6,"c":1,"p":40,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Triple Dive","t":12,"c":1,"p":30,"a":95,"pp":10,"tg":1,"pr":0},{"n":"Mortal Spin","t":4,"c":1,"p":30,"a":100,"pp":15,"tg":6,"pr":0},{"n":"Doodle","t":1,"c":3,"p":0,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Fillet Away","t":1,"c":3,"p":0,"a":0,"pp":10,"tg":7,"pr":0},{"n":"Kowtow Cleave","t":18,"c":1,"p":85,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Flower Trick","t":13,"c":1,"p":70,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Torch Song","t":11,"c":2,"p":80,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Aqua Step","t":12,"c":1,"p":80,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Raging Bull","t":1,"c":1,"p":90,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Make It Rain","t":9,"c":2,"p":120,"a":100,"pp":5,"tg":6,"pr":0},{"n":"Ruination","t":18,"c":2,"p":1,"a":90,"pp":10,"tg":1,"pr":0},{"n":"Collision Course","t":2,"c":1,"p":100,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Electro Drift","t":14,"c":2,"p":100,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Shed Tail","t":1,"c":3,"p":0,"a":0,"pp":10,"tg":7,"pr":0},{"n":"Chilly Reception","t":16,"c":3,"p":0,"a":0,"pp":10,"tg":12,"pr":0},{"n":"Tidy Up","t":1,"c":3,"p":0,"a":0,"pp":10,"tg":7,"pr":0},{"n":"Snowscape","t":16,"c":3,"p":0,"a":0,"pp":10,"tg":12,"pr":0},{"n":"Pounce","t":7,"c":1,"p":50,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Trailblaze","t":13,"c":1,"p":50,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Chilling Water","t":12,"c":2,"p":50,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Hyper Drill","t":1,"c":1,"p":100,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Twin Beam","t":15,"c":2,"p":40,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Rage Fist","t":8,"c":1,"p":50,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Armor Cannon","t":11,"c":2,"p":120,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Bitter Blade","t":11,"c":1,"p":90,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Double Shock","t":14,"c":1,"p":120,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Gigaton Hammer","t":9,"c":1,"p":160,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Comeuppance","t":18,"c":1,"p":1,"a":100,"pp":10,"tg":3,"pr":0},{"n":"Aqua Cutter","t":12,"c":1,"p":70,"a":100,"pp":20,"tg":1,"pr":0},{"n":"Blazing Torque","t":11,"c":1,"p":80,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Wicked Torque","t":18,"c":1,"p":80,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Noxious Torque","t":4,"c":1,"p":100,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Combat Torque","t":2,"c":1,"p":100,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Magical Torque","t":19,"c":1,"p":100,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Psyblade","t":15,"c":1,"p":80,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Hydro Steam","t":12,"c":2,"p":80,"a":100,"pp":15,"tg":1,"pr":0},{"n":"Blood Moon","t":1,"c":2,"p":140,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Matcha Gotcha","t":13,"c":2,"p":80,"a":90,"pp":15,"tg":6,"pr":0},{"n":"Syrup Bomb","t":13,"c":2,"p":60,"a":85,"pp":10,"tg":1,"pr":0},{"n":"Ivy Cudgel","t":13,"c":1,"p":100,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Electro Shot","t":14,"c":2,"p":130,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Tera Starstorm","t":1,"c":2,"p":120,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Fickle Beam","t":17,"c":2,"p":80,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Burning Bulwark","t":11,"c":3,"p":0,"a":0,"pp":10,"tg":7,"pr":4},{"n":"Thunderclap","t":14,"c":2,"p":70,"a":100,"pp":5,"tg":1,"pr":1},{"n":"Mighty Cleave","t":6,"c":1,"p":95,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Tachyon Cutter","t":9,"c":2,"p":50,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Hard Press","t":9,"c":1,"p":100,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Dragon Cheer","t":17,"c":3,"p":0,"a":0,"pp":15,"tg":8,"pr":0},{"n":"Alluring Voice","t":19,"c":2,"p":80,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Temper Flare","t":11,"c":1,"p":75,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Supercell Slam","t":14,"c":1,"p":100,"a":95,"pp":15,"tg":1,"pr":0},{"n":"Psychic Noise","t":15,"c":2,"p":75,"a":100,"pp":10,"tg":1,"pr":0},{"n":"Upper Hand","t":2,"c":1,"p":65,"a":100,"pp":15,"tg":1,"pr":3},{"n":"Malignant Chain","t":4,"c":2,"p":100,"a":100,"pp":5,"tg":1,"pr":0},{"n":"Breakneck Blitz","t":1,"c":1,"p":1,"a":0,"pp":1,"tg":1,"pr":0},{"n":"All-Out Pummeling","t":2,"c":1,"p":1,"a":0,"pp":1,"tg":1,"pr":0},{"n":"Supersonic Skystrike","t":3,"c":1,"p":1,"a":0,"pp":1,"tg":1,"pr":0},{"n":"Acid Downpour","t":4,"c":1,"p":1,"a":0,"pp":1,"tg":1,"pr":0},{"n":"Tectonic Rage","t":5,"c":1,"p":1,"a":0,"pp":1,"tg":1,"pr":0},{"n":"Continental Crush","t":6,"c":1,"p":1,"a":0,"pp":1,"tg":1,"pr":0},{"n":"Savage Spin-Out","t":7,"c":1,"p":1,"a":0,"pp":1,"tg":1,"pr":0},{"n":"Never-Ending Nightma","t":8,"c":1,"p":1,"a":0,"pp":1,"tg":1,"pr":0},{"n":"Corkscrew Crash","t":9,"c":1,"p":1,"a":0,"pp":1,"tg":1,"pr":0},{"n":"Inferno Overdrive","t":11,"c":1,"p":1,"a":0,"pp":1,"tg":1,"pr":0},{"n":"Hydro Vortex","t":12,"c":1,"p":1,"a":0,"pp":1,"tg":1,"pr":0},{"n":"Bloom Doom","t":13,"c":1,"p":1,"a":0,"pp":1,"tg":1,"pr":0},{"n":"Gigavolt Havoc","t":14,"c":1,"p":1,"a":0,"pp":1,"tg":1,"pr":0},{"n":"Shattered Psyche","t":15,"c":1,"p":1,"a":0,"pp":1,"tg":1,"pr":0},{"n":"Subzero Slammer","t":16,"c":1,"p":1,"a":0,"pp":1,"tg":1,"pr":0},{"n":"Devastating Drake","t":17,"c":1,"p":1,"a":0,"pp":1,"tg":1,"pr":0},{"n":"Black Hole Eclipse","t":18,"c":1,"p":1,"a":0,"pp":1,"tg":1,"pr":0},{"n":"Twinkle Tackle","t":19,"c":1,"p":1,"a":0,"pp":1,"tg":1,"pr":0},{"n":"Catastropika","t":14,"c":1,"p":210,"a":0,"pp":1,"tg":1,"pr":0},{"n":"10,000,000 Volt Thun","t":14,"c":2,"p":195,"a":0,"pp":1,"tg":1,"pr":0},{"n":"Stoked Sparksurfer","t":14,"c":2,"p":175,"a":0,"pp":1,"tg":1,"pr":0},{"n":"Extreme Evoboost","t":1,"c":3,"p":0,"a":0,"pp":1,"tg":7,"pr":0},{"n":"Pulverizing Pancake","t":1,"c":1,"p":210,"a":0,"pp":1,"tg":1,"pr":0},{"n":"Genesis Supernova","t":15,"c":2,"p":185,"a":0,"pp":1,"tg":1,"pr":0},{"n":"Sinister Arrow Raid","t":8,"c":1,"p":180,"a":0,"pp":1,"tg":1,"pr":0},{"n":"Malicious Moonsault","t":18,"c":1,"p":180,"a":0,"pp":1,"tg":1,"pr":0},{"n":"Oceanic Operetta","t":12,"c":2,"p":195,"a":0,"pp":1,"tg":1,"pr":0},{"n":"Splintered Stormshar","t":6,"c":1,"p":190,"a":0,"pp":1,"tg":1,"pr":0},{"n":"Let’s Snuggle Foreve","t":19,"c":1,"p":190,"a":0,"pp":1,"tg":1,"pr":0},{"n":"Clangorous Soulblaze","t":17,"c":2,"p":185,"a":0,"pp":1,"tg":6,"pr":0},{"n":"Guardian of Alola","t":19,"c":2,"p":1,"a":0,"pp":1,"tg":1,"pr":0},{"n":"Searing Sunraze Smas","t":9,"c":1,"p":200,"a":0,"pp":1,"tg":1,"pr":0},{"n":"Menacing Moonraze Ma","t":8,"c":2,"p":200,"a":0,"pp":1,"tg":1,"pr":0},{"n":"Light That Burns the","t":15,"c":2,"p":200,"a":0,"pp":1,"tg":1,"pr":0},{"n":"Soul-Stealing 7-Star","t":8,"c":1,"p":195,"a":0,"pp":1,"tg":1,"pr":0},{"n":"Max Guard","t":1,"c":3,"p":0,"a":0,"pp":10,"tg":7,"pr":4},{"n":"Max Strike","t":1,"c":1,"p":1,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Max Knuckle","t":2,"c":1,"p":1,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Max Airstream","t":3,"c":1,"p":1,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Max Ooze","t":4,"c":1,"p":1,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Max Quake","t":5,"c":1,"p":1,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Max Rockfall","t":6,"c":1,"p":1,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Max Flutterby","t":7,"c":1,"p":1,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Max Phantasm","t":8,"c":1,"p":1,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Max Steelspike","t":9,"c":1,"p":10,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Max Flare","t":11,"c":1,"p":1,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Max Geyser","t":12,"c":1,"p":1,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Max Overgrowth","t":13,"c":1,"p":10,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Max Lightning","t":14,"c":1,"p":1,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Max Mindstorm","t":15,"c":1,"p":1,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Max Hailstorm","t":16,"c":1,"p":1,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Max Wyrmwind","t":17,"c":1,"p":1,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Max Darkness","t":18,"c":1,"p":1,"a":0,"pp":10,"tg":1,"pr":0},{"n":"Max Starfall","t":19,"c":1,"p":1,"a":0,"pp":10,"tg":1,"pr":0},{"n":"G-Max Vine Lash","t":13,"c":1,"p":10,"a":0,"pp":10,"tg":1,"pr":0},{"n":"G-Max Wildfire","t":11,"c":1,"p":10,"a":0,"pp":10,"tg":1,"pr":0},{"n":"G-Max Cannonade","t":12,"c":1,"p":10,"a":0,"pp":10,"tg":1,"pr":0},{"n":"G-Max Befuddle","t":7,"c":1,"p":10,"a":0,"pp":10,"tg":1,"pr":0},{"n":"G-Max Volt Crash","t":14,"c":1,"p":10,"a":0,"pp":10,"tg":1,"pr":0},{"n":"G-Max Gold Rush","t":1,"c":1,"p":10,"a":0,"pp":10,"tg":1,"pr":0},{"n":"G-Max Chi Strike","t":2,"c":1,"p":10,"a":0,"pp":10,"tg":1,"pr":0},{"n":"G-Max Terror","t":8,"c":1,"p":10,"a":0,"pp":10,"tg":1,"pr":0},{"n":"G-Max Foam Burst","t":12,"c":1,"p":10,"a":0,"pp":10,"tg":1,"pr":0},{"n":"G-Max Resonance","t":16,"c":1,"p":10,"a":0,"pp":10,"tg":1,"pr":0},{"n":"G-Max Cuddle","t":1,"c":1,"p":10,"a":0,"pp":10,"tg":1,"pr":0},{"n":"G-Max Replenish","t":1,"c":1,"p":10,"a":0,"pp":10,"tg":1,"pr":0},{"n":"G-Max Malodor","t":4,"c":1,"p":10,"a":0,"pp":10,"tg":1,"pr":0},{"n":"G-Max Meltdown","t":9,"c":1,"p":10,"a":0,"pp":10,"tg":1,"pr":0},{"n":"G-Max Drum Solo","t":13,"c":1,"p":10,"a":0,"pp":10,"tg":1,"pr":0},{"n":"G-Max Fireball","t":11,"c":1,"p":10,"a":0,"pp":10,"tg":1,"pr":0},{"n":"G-Max Hydrosnipe","t":12,"c":1,"p":10,"a":0,"pp":10,"tg":1,"pr":0},{"n":"G-Max Wind Rage","t":3,"c":1,"p":10,"a":0,"pp":10,"tg":1,"pr":0},{"n":"G-Max Gravitas","t":15,"c":1,"p":10,"a":0,"pp":10,"tg":1,"pr":0},{"n":"G-Max Stonesurge","t":12,"c":1,"p":10,"a":0,"pp":10,"tg":1,"pr":0},{"n":"G-Max Volcalith","t":6,"c":1,"p":10,"a":0,"pp":10,"tg":1,"pr":0},{"n":"G-Max Tartness","t":13,"c":1,"p":10,"a":0,"pp":10,"tg":1,"pr":0},{"n":"G-Max Sweetness","t":13,"c":1,"p":10,"a":0,"pp":10,"tg":1,"pr":0},{"n":"G-Max Sandblast","t":5,"c":1,"p":10,"a":0,"pp":10,"tg":1,"pr":0},{"n":"G-Max Stun Shock","t":14,"c":1,"p":10,"a":0,"pp":10,"tg":1,"pr":0},{"n":"G-Max Centiferno","t":11,"c":1,"p":10,"a":0,"pp":10,"tg":1,"pr":0},{"n":"G-Max Smite","t":19,"c":1,"p":10,"a":0,"pp":10,"tg":1,"pr":0},{"n":"G-Max Snooze","t":18,"c":1,"p":10,"a":0,"pp":10,"tg":1,"pr":0},{"n":"G-Max Finale","t":19,"c":1,"p":10,"a":0,"pp":10,"tg":1,"pr":0},{"n":"G-Max Steelsurge","t":9,"c":1,"p":10,"a":0,"pp":10,"tg":1,"pr":0},{"n":"G-Max Depletion","t":17,"c":1,"p":10,"a":0,"pp":10,"tg":1,"pr":0},{"n":"G-Max One Blow","t":18,"c":1,"p":10,"a":0,"pp":10,"tg":1,"pr":0},{"n":"G-Max Rapid Flow","t":12,"c":1,"p":10,"a":0,"pp":10,"tg":1,"pr":0}],"items":["????????","Poké Ball","Great Ball","Ultra Ball","Master Ball","Premier Ball","Heal Ball","Net Ball","Nest Ball","Dive Ball","Dusk Ball","Timer Ball","Quick Ball","Repeat Ball","Luxury Ball","Level Ball","Lure Ball","Moon Ball","Friend Ball","Love Ball","Fast Ball","Heavy Ball","Dream Ball","Safari Ball","Sport Ball","Park Ball","Beast Ball","Cherish Ball","Potion","Super Potion","Hyper Potion","Max Potion","Full Restore","Revive","Max Revive","Fresh Water","Soda Pop","Lemonade","Moomoo Milk","Energy Powder","Energy Root","Heal Powder","Revival Herb","Antidote","Paralyze Heal","Burn Heal","Ice Heal","Awakening","Full Heal","Ether","Max Ether","Elixir","Max Elixir","Berry Juice","Sacred Ash","Sweet Heart","Max Honey","Pewter Crunchies","Rage Candy Bar","Lava Cookie","Old Gateau","Casteliacone","Lumiose Galette","Shalour Sable","Big Malasada","HP Up","Protein","Iron","Calcium","Zinc","Carbos","PP Up","PP Max","Health Feather","Muscle Feather","Resist Feather","Genius Feather","Clever Feather","Swift Feather","Ability Capsule","Ability Patch","Lonely Mint","Adamant Mint","Naughty Mint","Brave Mint","Bold Mint","Impish Mint","Lax Mint","Relaxed Mint","Modest Mint","Mild Mint","Rash Mint","Quiet Mint","Calm Mint","Gentle Mint","Careful Mint","Sassy Mint","Timid Mint","Hasty Mint","Jolly Mint","Naive Mint","Serious Mint","Rare Candy","Exp. Candy XS","Exp. Candy S","Exp. Candy M","Exp. Candy L","Exp. Candy XL","Dynamax Candy","Blue Flute","Yellow Flute","Red Flute","Black Flute","White Flute","Repel","Super Repel","Max Repel","Lure","Super Lure","Max Lure","Escape Rope","X Attack","X Defense","X Sp. Atk","X Sp. Def","X Speed","X Accuracy","Dire Hit","Guard Spec.","Poké Doll","Fluffy Tail","Poké Toy","Max Mushrooms","Bottle Cap","Gold Bottle Cap","Nugget","Big Nugget","Tiny Mushroom","Big Mushroom","Balm Mushroom","Pearl","Big Pearl","Pearl String","Stardust","Star Piece","Comet Shard","Shoal Salt","Shoal Shell","Red Shard","Blue Shard","Yellow Shard","Green Shard","Heart Scale","Honey","Rare Bone","Odd Keystone","Pretty Feather","Relic Copper","Relic Silver","Relic Gold","Relic Vase","Relic Band","Relic Statue","Relic Crown","Strange Souvenir","Helix Fossil","Dome Fossil","Old Amber","Root Fossil","Claw Fossil","Armor Fossil","Skull Fossil","Cover Fossil","Plume Fossil","Jaw Fossil","Sail Fossil","Fossilized Bird","Fossilized Fish","Fossilized Drake","Fossilized Dino","Growth Mulch","Damp Mulch","Stable Mulch","Gooey Mulch","Rich Mulch","Surprise Mulch","Boost Mulch","Amaze Mulch","Red Apricorn","Blue Apricorn","Yellow Apricorn","Green Apricorn","Pink Apricorn","White Apricorn","Black Apricorn","Wishing Piece","Galarica Twig","Armorite Ore","Dynite Ore","Orange Mail","Harbor Mail","Glitter Mail","Mech Mail","Wood Mail","Wave Mail","Bead Mail","Shadow Mail","Tropic Mail","Dream Mail","Fab Mail","Retro Mail","Fire Stone","Water Stone","Thunder Stone","Leaf Stone","Ice Stone","Sun Stone","Moon Stone","Shiny Stone","Dusk Stone","Dawn Stone","Sweet Apple","Tart Apple","Cracked Pot","Chipped Pot","Galarica Cuff","Galarica Wreath","Dragon Scale","Upgrade","Protector","Electirizer","Magmarizer","Dubious Disc","Reaper Cloth","Prism Scale","Whipped Dream","Sachet","Oval Stone","Strawberry Sweet","Love Sweet","Berry Sweet","Clover Sweet","Flower Sweet","Star Sweet","Ribbon Sweet","Everstone","Red Nectar","Yellow Nectar","Pink Nectar","Purple Nectar","Flame Plate","Splash Plate","Zap Plate","Meadow Plate","Icicle Plate","Fist Plate","Toxic Plate","Earth Plate","Sky Plate","Mind Plate","Insect Plate","Stone Plate","Spooky Plate","Draco Plate","Dread Plate","Iron Plate","Pixie Plate","Douse Drive","Shock Drive","Burn Drive","Chill Drive","Fire Memory","Water Memory","Electric Memory","Grass Memory","Ice Memory","Fighting Memory","Poison Memory","Ground Memory","Flying Memory","Psychic Memory","Bug Memory","Rock Memory","Ghost Memory","Dragon Memory","Dark Memory","Steel Memory","Fairy Memory","Rusted Sword","Rusted Shield","Red Orb","Blue Orb","Venusaurite","Charizardite X","Charizardite Y","Blastoisinite","Beedrillite","Pidgeotite","Alakazite","Slowbronite","Gengarite","Kangaskhanite","Pinsirite","Gyaradosite","Aerodactylite","Mewtwonite X","Mewtwonite Y","Ampharosite","Steelixite","Scizorite","Heracronite","Houndoominite","Tyranitarite","Sceptilite","Blazikenite","Swampertite","Gardevoirite","Sablenite","Mawilite","Aggronite","Medichamite","Manectite","Sharpedonite","Cameruptite","Altarianite","Banettite","Absolite","Glalitite","Salamencite","Metagrossite","Latiasite","Latiosite","Lopunnite","Garchompite","Lucarionite","Abomasite","Galladite","Audinite","Diancite","Normal Gem","Fire Gem","Water Gem","Electric Gem","Grass Gem","Ice Gem","Fighting Gem","Poison Gem","Ground Gem","Flying Gem","Psychic Gem","Bug Gem","Rock Gem","Ghost Gem","Dragon Gem","Dark Gem","Steel Gem","Fairy Gem","Normalium Z","Firium Z","Waterium Z","Electrium Z","Grassium Z","Icium Z","Fightinium Z","Poisonium Z","Groundium Z","Flyinium Z","Psychium Z","Buginium Z","Rockium Z","Ghostium Z","Dragonium Z","Darkinium Z","Steelium Z","Fairium Z","Pikanium Z","Eevium Z","Snorlium Z","Mewnium Z","Decidium Z","Incinium Z","Primarium Z","Lycanium Z","Mimikium Z","Kommonium Z","Tapunium Z","Solganium Z","Lunalium Z","Marshadium Z","Aloraichium Z","Pikashunium Z","Ultranecrozium Z","Light Ball","Leek","Thick Club","Lucky Punch","Metal Powder","Quick Powder","Deep Sea Scale","Deep Sea Tooth","Soul Dew","Adamant Orb","Lustrous Orb","Griseous Orb","Sea Incense","Lax Incense","Odd Incense","Rock Incense","Full Incense","Wave Incense","Rose Incense","Luck Incense","Pure Incense","Red Scarf","Blue Scarf","Pink Scarf","Green Scarf","Yellow Scarf","Macho Brace","Power Weight","Power Bracer","Power Belt","Power Lens","Power Band","Power Anklet","Silk Scarf","Charcoal","Mystic Water","Magnet","Miracle Seed","Never-Melt Ice","Black Belt","Poison Barb","Soft Sand","Sharp Beak","Twisted Spoon","Silver Powder","Hard Stone","Spell Tag","Dragon Fang","Black Glasses","Metal Coat","Choice Band","Choice Specs","Choice Scarf","Flame Orb","Toxic Orb","Damp Rock","Heat Rock","Smooth Rock","Icy Rock","Electric Seed","Psychic Seed","Misty Seed","Grassy Seed","Absorb Bulb","Cell Battery","Luminous Moss","Snowball","Bright Powder","White Herb","Exp. Share","Quick Claw","Soothe Bell","Mental Herb","King’s Rock","Amulet Coin","Cleanse Tag","Smoke Ball","Focus Band","Lucky Egg","Scope Lens","Leftovers","Shell Bell","Wide Lens","Muscle Band","Wise Glasses","Expert Belt","Light Clay","Life Orb","Power Herb","Focus Sash","Zoom Lens","Metronome","Iron Ball","Lagging Tail","Destiny Knot","Black Sludge","Grip Claw","Sticky Barb","Shed Shell","Big Root","Razor Claw","Razor Fang","Eviolite","Float Stone","Rocky Helmet","Air Balloon","Red Card","Ring Target","Binding Band","Eject Button","Weakness Policy","Assault Vest","Safety Goggles","Adrenaline Orb","Terrain Extender","Protective Pads","Throat Spray","Eject Pack","Heavy-Duty Boots","Blunder Policy","Room Service","Utility Umbrella","Cheri Berry","Chesto Berry","Pecha Berry","Rawst Berry","Aspear Berry","Leppa Berry","Oran Berry","Persim Berry","Lum Berry","Sitrus Berry","Figy Berry","Wiki Berry","Mago Berry","Aguav Berry","Iapapa Berry","Razz Berry","Bluk Berry","Nanab Berry","Wepear Berry","Pinap Berry","Pomeg Berry","Kelpsy Berry","Qualot Berry","Hondew Berry","Grepa Berry","Tamato Berry","Cornn Berry","Magost Berry","Rabuta Berry","Nomel Berry","Spelon Berry","Pamtre Berry","Watmel Berry","Durin Berry","Belue Berry","Chilan Berry","Occa Berry","Passho Berry","Wacan Berry","Rindo Berry","Yache Berry","Chople Berry","Kebia Berry","Shuca Berry","Coba Berry","Payapa Berry","Tanga Berry","Charti Berry","Kasib Berry","Haban Berry","Colbur Berry","Babiri Berry","Roseli Berry","Liechi Berry","Ganlon Berry","Salac Berry","Petaya Berry","Apicot Berry","Lansat Berry","Starf Berry","Enigma Berry","Micle Berry","Custap Berry","Jaboca Berry","Rowap Berry","Kee Berry","Maranga Berry","Enigma Berry","TM01","TM02","TM03","TM04","TM05","TM06","TM07","TM08","TM09","TM10","TM11","TM12","TM13","TM14","TM15","TM16","TM17","TM18","TM19","TM20","TM21","TM22","TM23","TM24","TM25","TM26","TM27","TM28","TM29","TM30","TM31","TM32","TM33","TM34","TM35","TM36","TM37","TM38","TM39","TM40","TM41","TM42","TM43","TM44","TM45","TM46","TM47","TM48","TM49","TM50","TM51","TM52","TM53","TM54","TM55","TM56","TM57","TM58","TM59","TM60","TM61","TM62","TM63","TM64","TM65","TM66","TM67","TM68","TM69","TM70","TM71","TM72","TM73","TM74","TM75","TM76","TM77","TM78","TM79","TM80","TM81","TM82","TM83","TM84","TM85","TM86","TM87","TM88","TM89","TM90","TM91","TM92","TM93","TM94","TM95","TM96","TM97","TM98","TM99","TM100","HM01","HM02","HM03","HM04","HM05","HM06","HM07","HM08","Oval Charm","Shiny Charm","Catching Charm","Exp. Charm","Rotom Catalog","Gracidea","Reveal Glass","DNA Splicers","Zygarde Cube","Prison Bottle","N-Solarizer","N-Lunarizer","Reins of Unity","Mega Ring","Z-Power Ring","Dynamax Band","Bike","Mach Bike","Acro Bike","Old Rod","Good Rod","Super Rod","Dowsing Machine","Town Map","Vs. Seeker","TM Case","Berry Pouch","ウエ Box Link","Coin Case","Powder Jar","Wailmer Pail","Poké Radar","オカキクケ Case","Soot Sack","Poké Flute","Fame Checker","Teachy TV","S.S. Ticket","Eon Ticket","Mystic Ticket","Aurora Ticket","Old Sea Map","Letter","Devon Parts","Go-Goggles","Devon Scope","Basement Key","Scanner","Storage Key","Key to Room 1","Key to Room 2","Key to Room 4","Key to Room 6","Meteorite","Magma Emblem","Contest Pass","Parcel","Secret Key","Bike Voucher","Gold Teeth","Card Key","Lift Key","Silph Scope","Tri-Pass","Rainbow Pass","Tea","Ruby","Sapphire","Ability Shield","Clear Amulet","Punching Glove","Covert Cloak","Loaded Dice","Auspicious Armor","Booster Energy","Big Bamboo Shoot","Gimmighoul Coin","Leader’s Crest","Malicious Armor","Mirror Herb","Scroll of Darkness","Scroll of Waters","Tera Orb","Tiny Bamboo Shoot","Bug Tera Shard","Dark Tera Shard","Dragon Tera Shard","Electric Tera Shard","Fairy Tera Shard","Fighting Tera Shard","Fire Tera Shard","Flying Tera Shard","Ghost Tera Shard","Grass Tera Shard","Ground Tera Shard","Ice Tera Shard","Normal Tera Shard","Poison Tera Shard","Psychic Tera Shard","Rock Tera Shard","Steel Tera Shard","Water Tera Shard","Adamant Crystal","Griseous Core","Lustrous Globe","Black Augurite","Linking Cord","Peat Block","Berserk Gene","Fairy Feather","Syrupy Apple","Unremarkable Teacup","Masterpiece Teacup","Cornerstone Mask","Wellspring Mask","Hearthflame Mask","Health Mochi","Muscle Mochi","Resist Mochi","Genius Mochi","Clever Mochi","Swift Mochi","Fresh-Start Mochi","Glimmering Charm","Metal Alloy","Stellar Tera Shard","Jubilife Muffin","Remedy","Fine Remedy","Superb Remedy","Aux Evasion","Aux Guard","Aux Power","Aux Powerguard","Choice Dumpling","Swap Snack","Twice-Spiced Radish","Pokéshi Doll","Strange Ball","Clefablite","Victreebelite","Starminite","Dragoninite","Meganiumite","Feraligite","Skarmorite","Froslassite","Emboarite","Excadrite","Scolipite","Scraftinite","Eelektrossite","Chandelurite","Chesnaughtite","Delphoxite","Greninjite","Pyroarite","Floettite","Malamarite","Barbaracite","Dragalgite","Hawluchanite","Zygardite","Drampanite","Falinksite","Heatranite","Darkranite","Zeraorite","Raichunite X","Raichunite Y","Chimechite","Absolite Z","Staraptite","Garchompite Z","Lucarionite Z","Golurkite","Meowsticite","Crabominite","Golisopite","Magearnite","Scovillainite","Baxcalibrite","Tatsugirinite","Glimmoranite"],"abilities":["-------","Stench","Drizzle","Speed Boost","Battle Armor","Sturdy","Damp","Limber","Sand Veil","Static","Volt Absorb","Water Absorb","Oblivious","Cloud Nine","Compound Eyes","Insomnia","Color Change","Immunity","Flash Fire","Shield Dust","Own Tempo","Suction Cups","Intimidate","Shadow Tag","Rough Skin","Wonder Guard","Levitate","Effect Spore","Synchronize","Clear Body","Natural Cure","Lightning Rod","Serene Grace","Swift Swim","Chlorophyll","Illuminate","Trace","Huge Power","Poison Point","Inner Focus","Magma Armor","Water Veil","Magnet Pull","Soundproof","Rain Dish","Sand Stream","Pressure","Thick Fat","Early Bird","Flame Body","Run Away","Keen Eye","Hyper Cutter","Pickup","Truant","Hustle","Cute Charm","Plus","Minus","Forecast","Sticky Hold","Shed Skin","Guts","Marvel Scale","Liquid Ooze","Overgrow","Blaze","Torrent","Swarm","Rock Head","Drought","Arena Trap","Vital Spirit","White Smoke","Pure Power","Shell Armor","Air Lock","Tangled Feet","Motor Drive","Rivalry","Steadfast","Snow Cloak","Gluttony","Anger Point","Unburden","Heatproof","Simple","Dry Skin","Download","Iron Fist","Poison Heal","Adaptability","Skill Link","Hydration","Solar Power","Quick Feet","Normalize","Sniper","Magic Guard","No Guard","Stall","Technician","Leaf Guard","Klutz","Mold Breaker","Super Luck","Aftermath","Anticipation","Forewarn","Unaware","Tinted Lens","Filter","Slow Start","Scrappy","Storm Drain","Ice Body","Solid Rock","Snow Warning","Honey Gather","Frisk","Reckless","Multitype","Flower Gift","Bad Dreams","Pickpocket","Sheer Force","Contrary","Unnerve","Defiant","Defeatist","Cursed Body","Healer","Friend Guard","Weak Armor","Heavy Metal","Light Metal","Multiscale","Toxic Boost","Flare Boost","Harvest","Telepathy","Moody","Overcoat","Poison Touch","Regenerator","Big Pecks","Sand Rush","Wonder Skin","Analytic","Illusion","Imposter","Infiltrator","Mummy","Moxie","Justified","Rattled","Magic Bounce","Sap Sipper","Prankster","Sand Force","Iron Barbs","Zen Mode","Victory Star","Turboblaze","Teravolt","Aroma Veil","Flower Veil","Cheek Pouch","Protean","Fur Coat","Magician","Bulletproof","Competitive","Strong Jaw","Refrigerate","Sweet Veil","Stance Change","Gale Wings","Mega Launcher","Grass Pelt","Symbiosis","Tough Claws","Pixilate","Gooey","Aerilate","Parental Bond","Dark Aura","Fairy Aura","Aura Break","Primordial Sea","Desolate Land","Delta Stream","Stamina","Wimp Out","Emergency Exit","Water Compaction","Merciless","Shields Down","Stakeout","Water Bubble","Steelworker","Berserk","Slush Rush","Long Reach","Liquid Voice","Triage","Galvanize","Surge Surfer","Schooling","Disguise","Battle Bond","Power Construct","Corrosion","Comatose","Queenly Majesty","Innards Out","Dancer","Battery","Fluffy","Dazzling","Soul-Heart","Tangling Hair","Receiver","Power Of Alchemy","Beast Boost","RKS System","Electric Surge","Psychic Surge","Misty Surge","Grassy Surge","Full Metal Body","Shadow Shield","Prism Armor","Neuroforce","Intrepid Sword","Dauntless Shield","Libero","Ball Fetch","Cotton Down","Propeller Tail","Mirror Armor","Gulp Missile","Stalwart","Steam Engine","Punk Rock","Sand Spit","Ice Scales","Ripen","Ice Face","Power Spot","Mimicry","Screen Cleaner","Steely Spirit","Perish Body","Wandering Spirit","Gorilla Tactics","Neutralizing Gas","Pastel Veil","Hunger Switch","Quick Draw","Unseen Fist","Curious Medicine","Transistor","Dragon’s Maw","Chilling Neigh","Grim Neigh","As One","As One","Lingering Aroma","Seed Sower","Thermal Exchange","Anger Shell","Purifying Salt","Well-Baked Body","Wind Rider","Guard Dog","Rocky Payload","Wind Power","Zero to Hero","Commander","Electromorphosis","Protosynthesis","Quark Drive","Good as Gold","Vessel of Ruin","Sword of Ruin","Tablets of Ruin","Beads of Ruin","Orichalcum Pulse","Hadron Engine","Opportunist","Cud Chew","Sharpness","Supreme Overlord","Costar","Toxic Debris","Armor Tail","Earth Eater","Mycelium Might","Hospitality","Mind’s Eye","Embody Aspect","Embody Aspect","Embody Aspect","Embody Aspect","Toxic Chain","Supersweet Syrup","Tera Shift","Tera Shell","Teraform Zero","Poison Puppeteer","Piercing Drill","Dragonize","Eelevate","-------","Mega Sol","Fire Mane","-------","Spicy Spray","Aura Guard"],"types":["None","Normal","Fighting","Flying","Poison","Ground","Rock","Bug","Ghost","Steel","???","Fire","Water","Grass","Electric","Psychic","Ice","Dragon","Dark","Fairy","Stellar"]};

const TYPE_COLOR = {NORMAL:"#a8a878",FIGHTING:"#c03028",FLYING:"#a890f0",POISON:"#a040a0",GROUND:"#e0c068",ROCK:"#b8a038",BUG:"#a8b820",GHOST:"#705898",STEEL:"#b8b8d0",FIRE:"#f08030",WATER:"#6890f0",GRASS:"#78c850",ELECTRIC:"#f8d030",PSYCHIC:"#f85888",ICE:"#98d8d8",DRAGON:"#7038f8",DARK:"#705848",FAIRY:"#ee99ac",STELLAR:"#3f9fb0"};
const TYPE_IDX = {};
GAME.types.forEach((n, i) => TYPE_IDX[n.toUpperCase()] = i);
// Modern type chart (Gen 6+): attacker -> {defender: multiplier}, exceptions only
const CHART = (() => {
  const raw = {
    NORMAL: {ROCK:.5, GHOST:0, STEEL:.5},
    FIGHTING: {NORMAL:2, FLYING:.5, POISON:.5, ROCK:2, BUG:.5, GHOST:0, STEEL:2, PSYCHIC:.5, ICE:2, DARK:2, FAIRY:.5},
    FLYING: {FIGHTING:2, ROCK:.5, BUG:2, STEEL:.5, GRASS:2, ELECTRIC:.5},
    POISON: {POISON:.5, GROUND:.5, ROCK:.5, GHOST:.5, STEEL:0, GRASS:2, FAIRY:2},
    GROUND: {FLYING:0, POISON:2, ROCK:2, BUG:.5, STEEL:2, FIRE:2, GRASS:.5, ELECTRIC:2},
    ROCK: {FIGHTING:.5, FLYING:2, GROUND:.5, BUG:2, STEEL:.5, FIRE:2, ICE:2},
    BUG: {FIGHTING:.5, FLYING:.5, POISON:.5, GHOST:.5, STEEL:.5, FIRE:.5, GRASS:2, PSYCHIC:2, DARK:2, FAIRY:.5},
    GHOST: {NORMAL:0, GHOST:2, PSYCHIC:2, DARK:.5},
    STEEL: {ROCK:2, STEEL:.5, FIRE:.5, WATER:.5, ELECTRIC:.5, ICE:2, FAIRY:2},
    FIRE: {ROCK:.5, BUG:2, STEEL:2, FIRE:.5, WATER:.5, GRASS:2, ICE:2, DRAGON:.5},
    WATER: {GROUND:2, ROCK:2, FIRE:2, WATER:.5, GRASS:.5, DRAGON:.5},
    GRASS: {FLYING:.5, POISON:.5, GROUND:2, ROCK:2, BUG:.5, STEEL:.5, FIRE:.5, WATER:2, GRASS:.5, DRAGON:.5},
    ELECTRIC: {FLYING:2, GROUND:0, WATER:2, GRASS:.5, ELECTRIC:.5, DRAGON:.5},
    PSYCHIC: {FIGHTING:2, POISON:2, STEEL:.5, PSYCHIC:.5, DARK:0},
    ICE: {FLYING:2, GROUND:2, STEEL:.5, FIRE:.5, WATER:.5, GRASS:2, ICE:.5, DRAGON:2},
    DRAGON: {STEEL:.5, DRAGON:2, FAIRY:0},
    DARK: {FIGHTING:.5, GHOST:2, PSYCHIC:2, DARK:.5, FAIRY:.5},
    FAIRY: {FIGHTING:2, POISON:.5, STEEL:.5, FIRE:.5, DRAGON:2, DARK:2},
  };
  const t = {};
  for (const [a, row] of Object.entries(raw)) {
    t[TYPE_IDX[a]] = {};
    for (const [d, m] of Object.entries(row)) t[TYPE_IDX[a]][TYPE_IDX[d]] = m;
  }
  return t;
})();
const TYPE_STELLAR = TYPE_IDX.STELLAR, TYPE_NONE = 0, TYPE_MYSTERY = TYPE_IDX["???"];
const GIMMICKS = {1: "Mega Evolution", 2: "Ultra Burst", 3: "Z-Move", 4: "Dynamax", 5: "Terastallize"};
const GIMMICK_TAG = {1: "MEGA", 2: "ULTRA", 3: "Z", 4: "DYNAMAX", 5: "TERA"};
const CAT_LABEL = {1: "Physical", 2: "Special", 3: "Status"};
const STAT_NAMES = ["ATK","DEF","SPE","SPA","SPD","ACC","EVA"];
const ERRORS = {
  1: "That choice is not allowed right now.",
  2: "Invalid move.",
  3: "That move can't be used right now (no PP left or blocked).",
  4: "That item can't be used right now.",
  5: "That Pokémon can't be sent out.",
  6: "The Pokémon is trapped and can't be switched out.",
  7: "That transformation can't be used with this move."
};
const TARGET_SELECTED = 1, TARGET_SMART = 2, TARGET_USER_OR_ALLY = 10;

let code = "";
let state = null, lastJson = "", lastSeq = -1, lastReqKey = "";
let sel = null;          // {kind:'move'|'item'|'switch'|'ai', a1, a2, label}
let tab = "moves";
let sending = false, failCount = 0, notified = -1, gimmickOn = false;

const $ = (id) => document.getElementById(id);
const esc = (s) => String(s ?? "").replace(/[&<>"]/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]));
const speciesName = (id) => (GAME.species[id] || "???");
const moveData = (id) => GAME.moves[id] || {n:"???",p:0,t:0,a:0,pp:0,tg:0};
const itemName = (id) => GAME.items[id] || "???";

function typeChip(t) {
  const name = GAME.types[t] || "?";
  return `<span class="type" style="background:${TYPE_COLOR[name.toUpperCase()] || '#666'}">${esc(name.toUpperCase())}</span>`;
}
function typesChips(types) {
  if (!types) return "";
  const seen = new Set();
  return types.filter(t => t && t !== TYPE_NONE && t !== TYPE_MYSTERY && !seen.has(t) && seen.add(t)).map(typeChip).join("");
}
const VOL_LABELS = [[1,"Confused"],[2,"Substitute"],[4,"Infatuated"],[8,"Leech Seed"],[16,"Cursed"],[32,"Nightmare"],[64,"Perish Song"],[128,"Encore"],[256,"Torment"],[512,"Drowsy"],[1024,"Focus Energy"],[2048,"Aqua Ring"],[4096,"Taunted"],[8192,"Trapped"]];
function statusChips(s1, vol, fainted) {
  const out = [];
  if (fainted) return `<span class="st fnt">FNT</span>`;
  if (s1 & 7) out.push(`<span class="st slp">SLP</span>`);
  if (s1 & 0x80) out.push(`<span class="st tox">TOX</span>`);
  else if (s1 & 0x8) out.push(`<span class="st psn">PSN</span>`);
  if (s1 & 0x10) out.push(`<span class="st brn">BRN</span>`);
  if (s1 & 0x20) out.push(`<span class="st frz">FRZ</span>`);
  if (s1 & 0x1000) out.push(`<span class="st frz">FRB</span>`);
  if (s1 & 0x40) out.push(`<span class="st par">PAR</span>`);
  for (const [bit, label] of VOL_LABELS) if (vol & bit) out.push(`<span class="st misc">${label}</span>`);
  return out.join("");
}
function gimmickChip(b) {
  if (!b.gimmick) return "";
  const extra = b.gimmick === 5 ? " " + esc((GAME.types[b.teraType] || "").toUpperCase()) : "";
  return `<span class="st gim">${GIMMICK_TAG[b.gimmick] || ""}${extra}</span>`;
}
function stageChips(stages) {
  if (!stages) return "";
  const out = [];
  for (let i = 1; i <= 7; i++) {
    const v = stages[i] - 6;
    if (v) out.push(`<span class="stage ${v < 0 ? "neg" : ""}">${STAT_NAMES[i-1]} ${v > 0 ? "+" : ""}${v}</span>`);
  }
  return out.join("");
}
function hpBar(pct) {
  const cls = pct <= 20 ? "low" : pct <= 50 ? "mid" : "";
  return `<div class="hp"><i class="${cls}" style="width:${Math.max(0, Math.min(100, pct))}%"></i></div>`;
}
function defendingTypes(b) {
  if (!b) return null;
  if (b.gimmick === 5 && b.teraType && b.teraType !== TYPE_STELLAR) return [b.teraType];
  return b.types;
}
function effectiveness(moveId, target) {
  const m = moveData(moveId);
  const defTypes = defendingTypes(target);
  if (!m.p || m.c === 3 || !defTypes) return null;
  let mult = 1;
  const seen = new Set();
  for (const d of defTypes) {
    if (!d || d === TYPE_MYSTERY || seen.has(d)) continue;
    seen.add(d);
    const row = CHART[m.t];
    if (row && row[d] !== undefined) mult *= row[d];
  }
  return mult;
}
function effChip(mult) {
  if (mult === null || mult === 1) return "";
  if (mult === 0) return `<span class="eff zero">x0</span>`;
  if (mult >= 4) return `<span class="eff x4">x4</span>`;
  if (mult >= 2) return `<span class="eff x2">x2</span>`;
  return `<span class="eff half">x${mult === .25 ? "¼" : "½"}</span>`;
}
function battlerLabel(b, st) {
  if (st.battlersCount < 4) return "";
  return b.id === 0 ? "left" : b.id === 2 ? "right" : b.id === 1 ? "left" : "right";
}

// ------------------------------------------------------------ network
async function api(path, body) {
  const url = `api/${path}?k=${encodeURIComponent(code)}&t=${Date.now()}`;
  const opt = body ? { method: "POST", headers: {"Content-Type":"application/x-www-form-urlencoded"}, body } : {};
  const r = await fetch(url, opt);
  const j = await r.json();
  if (r.status === 401) throw Object.assign(new Error("code"), { code: true });
  return j;
}

async function poll() {
  try {
    const st = await api("state");
    failCount = 0;
    $("dot").className = "dot on";
    const json = JSON.stringify(st);
    if (json !== lastJson) { lastJson = json; onState(st); }
  } catch (e) {
    if (e.code) { logout("Wrong code, or the code has changed."); return; }
    failCount++;
    $("dot").className = "dot off";
    if (failCount >= 3) renderBanner("err", "📡", "Connection lost", "Retrying... Check that player 1 has mGBA and the tunnel running.");
  }
  setTimeout(poll, document.hidden ? 1500 : 700);
}

function onState(st) {
  const prevKey = lastReqKey;
  state = st;
  lastReqKey = st.reqType ? `${st.reqSeq}:${st.reqType}:${st.reqBattler}` : "";
  if (lastReqKey !== prevKey) {
    // new request: clear the selection if it is a different decision
    const sameDecision = prevKey && lastReqKey && prevKey.split(":").slice(1).join(":") === lastReqKey.split(":").slice(1).join(":");
    if (!sameDecision) { sel = null; gimmickOn = false; tab = st.reqType === 3 ? "switch" : "moves"; }
    if (st.reqType && st.lastError) { showToast(ERRORS[st.lastError] || "Invalid choice."); sel = null; }
    if (st.reqType && notified !== st.reqSeq) { notified = st.reqSeq; notifyTurn(); }
  }
  $("autoAi").checked = !!st.auto;
  render();
}

async function send() {
  if (!sel || !state || !state.reqType || sending) return;
  sending = true;
  $("sendBtn").disabled = true;
  const types = { move: 1, item: 2, switch: 3, ai: 4 };
  const g = sel.kind === "move" && gimmickOn && state.gimmick ? 1 : 0;
  const body = `seq=${state.reqSeq}&type=${types[sel.kind]}&a1=${sel.a1 ?? 0}&a2=${sel.a2 ?? 0}&g=${g}`;
  try {
    const r = await api("choose", body);
    if (!r.ok) showToast(r.error || "Error");
    else { sel = null; gimmickOn = false; state.reqType = 0; lastJson = ""; render(); }
  } catch (e) { showToast("Sending failed, please try again."); }
  sending = false;
  $("sendBtn").disabled = false;
}

// ------------------------------------------------------------ interface
function renderBanner(kind, icon, big, small) {
  $("banner").innerHTML = `<div class="banner ${kind}"><div class="icon">${icon}</div><div><div class="big">${esc(big)}</div><div class="small">${esc(small || "")}</div></div></div>`;
}

function render() {
  const st = state;
  if (!st) return;
  if (st.game === "none") { renderBanner("", "🎮", "Game not running", "Player 1 needs to open the ROM in mGBA."); clearBattle(); return; }
  if (st.game === "wrong") { renderBanner("err", "⚠️", "Unpatched ROM", "The ROM open in mGBA doesn't have the Rival at the Wheel patch."); clearBattle(); return; }
  if (!st.inBattle) { renderBanner("", "🌿", "No battle right now", "When player 1 battles a trainer, it'll be your turn."); clearBattle(); hideConfirm(); return; }

  const me = st.battlers.find(b => b.id === st.reqBattler);
  const who = st.trainerName ? `${st.trainerClass} ${st.trainerName}` : st.trainerClass;
  if (st.reqType) {
    const what = st.reqType === 3 ? "Choose the next Pokémon" : `What will ${me ? speciesName(me.species) : ""} do?`;
    renderBanner("turn", "🔥", "Your turn!", `${what}${who ? " · you are " + who : ""}`);
  } else {
    renderBanner("", "⏳", "Player 1's turn", `${who ? "You are " + who + " · " : ""}turn ${st.turn + 1}`);
  }
  renderAction(st, me);
  renderField(st);
  renderParty(st);
  updateConfirm();
}

function clearBattle() { $("action").innerHTML = ""; $("field").innerHTML = ""; $("partyBox").innerHTML = ""; }

function renderAction(st, me) {
  const box = $("action");
  if (!st.reqType || !me) { box.innerHTML = ""; hideConfirm(); return; }
  const tabs = [];
  if (st.reqType !== 3) tabs.push(["moves", "Moves"]);
  if (st.reqType === 1) tabs.push(["items", "Items"]);
  if (st.reqType !== 2) tabs.push(["switch", st.reqType === 3 ? "Party" : "Switch"]);
  if (!tabs.find(t => t[0] === tab)) tab = tabs[0][0];
  let html = `<h2>${st.reqType === 3 ? "Who goes in next?" : "Your choice" + (battlerLabel(me, st) ? " · " + battlerLabel(me, st) + " Pokémon" : "")}</h2>`;
  if (tabs.length > 1) html += `<div class="tabs">${tabs.map(([k, l]) => `<button data-tab="${k}" class="${k === tab ? "on" : ""}">${l}</button>`).join("")}</div>`;
  html += `<div class="choices">`;
  if (tab === "moves") html += movesHtml(st, me);
  if (tab === "items") html += itemsHtml(st);
  if (tab === "switch") html += switchHtml(st);
  html += `</div>`;
  html += `<button class="ai-btn ${sel && sel.kind === "ai" ? "sel" : ""}" data-ai="1">🤖 Let the game's AI decide</button>`;
  box.innerHTML = html;
}

function foesOf(st) { return st.battlers.filter(b => !b.foe && b.present); }

function movesHtml(st, me) {
  const unusable = st.unusableMoves;
  if ((unusable & 15) === 15) {
    const s = sel && sel.kind === "move";
    return `<button class="choice wide ${s ? "sel" : ""}" data-move="0" data-struggle="1"><div class="t">STRUGGLE</div><div class="s">No usable moves: it will use Struggle</div></button>`;
  }
  const foes = foesOf(st);
  let html = "";
  if (st.gimmick) {
    const tera = st.gimmick === 5 ? " (" + esc((GAME.types[me.teraType] || "").toUpperCase()) + ")" : "";
    html += `<button class="gimmick-btn wide ${gimmickOn ? "on" : ""}" data-gimmick="1" style="grid-column:1/-1">✨ ${GIMMICKS[st.gimmick]}${tera}: ${gimmickOn ? "ON, with the next move" : "tap to activate"}</button>`;
  }
  for (let i = 0; i < 4; i++) {
    const id = me.moves[i];
    if (!id) { html += `<button class="choice" disabled><div class="t">—</div></button>`; continue; }
    const m = moveData(id);
    const zBlocked = gimmickOn && st.gimmick === 3 && !((st.zMoveMask >> i) & 1);
    const blocked = ((unusable >> i) & 1) || zBlocked;
    const effs = foes.length === 1 ? effChip(effectiveness(id, foes[0])) :
      foes.map(f => effChip(effectiveness(id, f))).filter(Boolean).join("");
    const isSel = sel && sel.kind === "move" && sel.a1 === i;
    html += `<button class="choice ${isSel ? "sel" : ""}" data-move="${i}" ${blocked ? "disabled" : ""}>
      <div class="t">${esc(m.n)}</div>
      <div class="s">${typeChip(m.t)} ${CAT_LABEL[m.c] || ""} · PP ${me.pp[i]}/${me.maxPp[i]} ${m.p ? "· POW " + (m.p === 1 ? "var." : m.p) : ""} ${m.a ? "· ACC " + m.a : ""} ${m.pr ? "· PRI " + (m.pr > 0 ? "+" : "") + m.pr : ""} ${effs}</div>
    </button>`;
  }
  return html;
}

function itemsHtml(st) {
  let html = "", any = false;
  st.trainerItems.forEach((id, i) => {
    if (!id) return;
    any = true;
    const ok = (st.itemUsable >> i) & 1;
    const isSel = sel && sel.kind === "item" && sel.a1 === i;
    html += `<button class="choice ${isSel ? "sel" : ""}" data-item="${i}" ${ok ? "" : "disabled"}>
      <div class="t">${esc(itemName(id))}</div><div class="s">${ok ? "Use on the active Pokémon" : "Not useful right now"}</div></button>`;
  });
  if (!any) html = `<div class="note wide" style="grid-column:1/-1">This trainer has no items (left).</div>`;
  return html;
}

function switchHtml(st) {
  let html = "";
  if (st.reqType === 1 && !st.canSwitch) html += `<div class="note" style="grid-column:1/-1">⛓️ The Pokémon is trapped and can't be switched out.</div>`;
  let any = false;
  for (const p of st.party) {
    if (p.onField) continue;
    any = true;
    const ok = p.canSend && (st.reqType === 3 || st.canSwitch);
    const pct = p.maxHP ? Math.round(p.hp * 100 / p.maxHP) : 0;
    const isSel = sel && sel.kind === "switch" && sel.a1 === p.slot;
    html += `<button class="choice ${isSel ? "sel" : ""}" data-switch="${p.slot}" ${ok ? "" : "disabled"}>
      <div class="t">${esc(p.egg ? "EGG" : speciesName(p.species))} <span class="lv">Lv${p.level}</span></div>
      ${hpBar(pct)}
      <div class="s">${p.hp}/${p.maxHP} HP ${typesChips(GAME.speciesTypes[p.species])} ${statusChips(p.status, 0, p.hp === 0)}</div></button>`;
  }
  if (!any) html += `<div class="note" style="grid-column:1/-1">No other Pokémon in the party.</div>`;
  return html;
}

function renderField(st) {
  const foes = st.battlers.filter(b => b.foe);
  const players = st.battlers.filter(b => !b.foe);
  let html = `<h2>Your Pokémon in battle</h2><div class="grid2">`;
  for (const b of foes) {
    const pct = b.maxHP ? Math.round(b.hp * 100 / b.maxHP) : 0;
    const side = battlerLabel(b, st);
    html += `<div class="card mon ${b.present ? "" : "dim"}">
      <div class="top"><span class="name">${esc(speciesName(b.species))}</span><span class="lv">Lv${b.level}</span>${side ? `<span class="tag">${side}</span>` : ""}${b.id === st.reqBattler && st.reqType ? `<span class="tag" style="color:var(--accent);border-color:var(--accent)">choosing</span>` : ""}</div>
      ${hpBar(pct)}
      <div class="hptext"><span>${b.hp}/${b.maxHP} HP</span><span>${b.ability ? esc(GAME.abilities[b.ability]) : ""}${b.item ? " · " + esc(itemName(b.item)) : ""}</span></div>
      <div class="chips">${typesChips(b.types)}${gimmickChip(b)}${statusChips(b.status1, b.vol, b.hp === 0)}${stageChips(b.stages)}</div>
    </div>`;
  }
  html += `</div><h2>Opponent: player 1</h2><div class="grid2">`;
  for (const b of players) {
    const side = battlerLabel(b, st);
    html += `<div class="card mon ${b.present ? "" : "dim"}">
      <div class="top"><span class="name">${esc(speciesName(b.species))}</span><span class="lv">Lv${b.level}</span>${side ? `<span class="tag">${side}</span>` : ""}</div>
      ${hpBar(b.hpPct)}
      <div class="hptext"><span>${b.hpPct}% HP</span><span>${b.lastMove ? "last move: " + esc(moveData(b.lastMove).n) : ""}</span></div>
      <div class="chips">${typesChips(b.types)}${gimmickChip(b)}${statusChips(b.status1, b.vol, b.hpPct === 0)}${stageChips(b.stages)}</div>
    </div>`;
  }
  html += `</div>`;
  const pp = st.playerParty || [];
  html += `<div class="note" style="display:flex;align-items:center;gap:10px;margin-top:10px">Player 1's party <div class="balls">${pp.map(v => `<span class="ball ${["", "ok", "stat", "fnt"][v]}"></span>`).join("")}</div></div>`;
  const FIELD = [[1,"Rain"],[2,"Sun"],[4,"Sandstorm"],[8,"Hail"],[16,"Snow"],[32,"Fog"],[64,"Strong winds"],[128,"Electric Terrain"],[256,"Grassy Terrain"],[512,"Misty Terrain"],[1024,"Psychic Terrain"],[2048,"Trick Room"],[4096,"Gravity"],[8192,"Magic Room"],[16384,"Wonder Room"]];
  const SIDE = [[1,"Reflect"],[2,"Light Screen"],[4,"Aurora Veil"],[8,"Safeguard"],[16,"Mist"],[32,"Tailwind"],[64,"Spikes"],[128,"Toxic Spikes"],[256,"Stealth Rock"],[512,"Sticky Web"]];
  const names = (v, list) => list.filter(([b]) => v & b).map(([, n]) => n).join(", ");
  const extra = [];
  if (st.field) extra.push("Field: " + names(st.field, FIELD));
  if (st.sides && st.sides[1]) extra.push("Your side: " + names(st.sides[1], SIDE));
  if (st.sides && st.sides[0]) extra.push("Opponent's side: " + names(st.sides[0], SIDE));
  if (extra.length) html += `<div class="note">${extra.join(" · ")}</div>`;
  $("field").innerHTML = html;
}

function renderParty(st) {
  let html = `<h2>Your party</h2><div class="party">`;
  for (const p of st.party) {
    const pct = p.maxHP ? Math.round(p.hp * 100 / p.maxHP) : 0;
    const moves = p.moves.map((m, i) => m ? `<span class="mv">${esc(moveData(m).n)} ${p.pp[i]}/${p.maxPp[i]}</span>` : "").join("");
    html += `<div class="prow ${p.onField ? "field" : ""}">
      <div><b>${esc(p.egg ? "EGG" : speciesName(p.species))}</b> <span class="lv">Lv${p.level}</span> ${p.onField ? `<span class="tag">active</span>` : ""}</div>
      <div class="meta">${p.hp}/${p.maxHP} HP</div>
      <div style="grid-column:1/-1">${hpBar(pct)}</div>
      <div class="chips" style="grid-column:1/-1">${typesChips(GAME.speciesTypes[p.species])}${p.ability ? `<span class="mv">${esc(GAME.abilities[p.ability])}</span>` : ""}${statusChips(p.status, 0, p.hp === 0)}${p.item ? `<span class="mv">🎒 ${esc(itemName(p.item))}</span>` : ""}</div>
      <div class="moves">${moves}</div></div>`;
  }
  html += `</div>`;
  $("partyBox").innerHTML = html;
}

function selectionLabel() {
  if (!sel || !state) return "";
  const me = state.battlers.find(b => b.id === state.reqBattler);
  if (sel.kind === "ai") return "Let <b>the AI</b> decide";
  if (sel.kind === "move") {
    if (sel.struggle) return "Use <b>Struggle</b>";
    const m = moveData(me.moves[sel.a1]);
    const t = state.battlers.find(b => b.id === sel.a2);
    const target = state.battlersCount === 4 && sel.pickedTarget && t ? ` on <b>${esc(speciesName(t.species))}</b>` : "";
    const gim = gimmickOn && state.gimmick ? ` with <b>${GIMMICKS[state.gimmick]}</b>` : "";
    return `Use <b>${esc(m.n)}</b>${target}${gim}`;
  }
  if (sel.kind === "item") return `Use <b>${esc(itemName(state.trainerItems[sel.a1]))}</b>`;
  if (sel.kind === "switch") {
    const p = state.party.find(x => x.slot === sel.a1);
    return `Send out <b>${esc(speciesName(p.species))}</b>`;
  }
  return "";
}
function updateConfirm() {
  if (sel && state && state.reqType) {
    $("confirmWhat").innerHTML = selectionLabel();
    $("confirm").classList.add("show");
  } else hideConfirm();
}
function hideConfirm() { $("confirm").classList.remove("show"); }

function chooseTarget(moveSlot, options) {
  const st = state, me = st.battlers.find(b => b.id === st.reqBattler);
  const m = moveData(me.moves[moveSlot]);
  const root = $("modalRoot");
  root.innerHTML = `<div class="modal-bg" id="mbg"><div class="modal"><h3>Use ${esc(m.n)} on whom?</h3><div class="choices">
    ${options.map(b => `<button class="choice" data-target="${b.id}"><div class="t">${esc(speciesName(b.species))}</div>
      <div class="s">${b.id === me.id ? "itself" : b.foe ? "your partner" : "opponent, " + battlerLabel(b, st)} ${effChip(effectiveness(me.moves[moveSlot], b))}</div></button>`).join("")}
    </div><button class="ai-btn" id="mclose">Cancel</button></div></div>`;
  $("mbg").onclick = (e) => {
    const t = e.target.closest("[data-target]");
    if (t) { sel = { kind: "move", a1: moveSlot, a2: +t.dataset.target, pickedTarget: true }; root.innerHTML = ""; render(); }
    else if (e.target.id === "mbg" || e.target.id === "mclose") root.innerHTML = "";
  };
}

document.addEventListener("click", (e) => {
  const b = e.target.closest("button");
  if (!b || b.disabled || !state) return;
  if (b.dataset.tab) { tab = b.dataset.tab; render(); return; }
  if (b.dataset.ai) { sel = { kind: "ai" }; render(); return; }
  if (b.dataset.gimmick) {
    gimmickOn = !gimmickOn;
    if (gimmickOn && sel && sel.kind === "move" && state.gimmick === 3 && !((state.zMoveMask >> sel.a1) & 1)) sel = null;
    render(); return;
  }
  if (b.dataset.move !== undefined) {
    const slot = +b.dataset.move;
    if (b.dataset.struggle) { sel = { kind: "move", a1: 0, a2: 0, struggle: true }; render(); return; }
    const me = state.battlers.find(x => x.id === state.reqBattler);
    const m = moveData(me.moves[slot]);
    const others = state.battlers.filter(x => x.present && x.id !== me.id);
    const needsTarget = state.battlersCount === 4 && (m.tg === TARGET_SELECTED || m.tg === TARGET_SMART) && others.length > 1;
    if (needsTarget) { chooseTarget(slot, others); return; }
    if (state.battlersCount === 4 && m.tg === TARGET_USER_OR_ALLY && others.some(x => x.foe)) {
      chooseTarget(slot, [me, ...others.filter(x => x.foe)]); return;
    }
    const foe = state.battlers.find(x => !x.foe && x.present);
    sel = { kind: "move", a1: slot, a2: foe ? foe.id : 0 };
    render(); return;
  }
  if (b.dataset.item !== undefined) { sel = { kind: "item", a1: +b.dataset.item }; render(); return; }
  if (b.dataset.switch !== undefined) { sel = { kind: "switch", a1: +b.dataset.switch }; render(); return; }
});
$("sendBtn").onclick = send;
$("cancelBtn").onclick = () => { sel = null; render(); };
$("autoAi").onchange = async (e) => {
  try { await api("auto", "on=" + (e.target.checked ? 1 : 0)); } catch (err) { showToast("Failed"); }
};

let toastTimer = null;
function showToast(msg) {
  const t = $("toast");
  t.textContent = msg;
  t.classList.remove("hidden");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => t.classList.add("hidden"), 3500);
}

let audioCtx = null;
function notifyTurn() {
  if (navigator.vibrate) navigator.vibrate([120, 60, 120]);
  try {
    audioCtx = audioCtx || new (window.AudioContext || window.webkitAudioContext)();
    const o = audioCtx.createOscillator(), g = audioCtx.createGain();
    o.type = "square"; o.frequency.value = 880;
    g.gain.setValueAtTime(.05, audioCtx.currentTime);
    g.gain.exponentialRampToValueAtTime(.0001, audioCtx.currentTime + .25);
    o.connect(g); g.connect(audioCtx.destination); o.start(); o.stop(audioCtx.currentTime + .26);
  } catch (e) {}
  if (document.hidden) document.title = "⚡ Your turn! · Rival at the Wheel";
}
document.addEventListener("visibilitychange", () => { if (!document.hidden) document.title = "Rival at the Wheel · Emerald"; });

// ------------------------------------------------------------ login
function store(k, v) { try { v === null ? localStorage.removeItem(k) : localStorage.setItem(k, v); } catch (e) {} }
function load(k) { try { return localStorage.getItem(k); } catch (e) { return null; } }

async function tryLogin(c) {
  code = (c || "").trim().toUpperCase();
  if (!code) return false;
  try {
    const r = await fetch(`api/state?k=${encodeURIComponent(code)}&t=${Date.now()}`);
    if (r.status === 401) return false;
    store("rt_code", code);
    $("login").classList.add("hidden");
    $("app").classList.remove("hidden");
    onState(await r.json());
    poll();
    return true;
  } catch (e) {
    $("loginErr").textContent = "The server isn't responding. Does player 1 have mGBA and the tunnel running?";
    return false;
  }
}
function logout(msg) {
  store("rt_code", null);
  $("app").classList.add("hidden");
  $("login").classList.remove("hidden");
  $("loginErr").textContent = msg || "";
}
$("codeBtn").onclick = async () => { if (!(await tryLogin($("codeInput").value)) && !$("loginErr").textContent) $("loginErr").textContent = "Wrong code."; };
$("codeInput").addEventListener("keydown", (e) => { if (e.key === "Enter") $("codeBtn").click(); });

(async () => {
  const fromUrl = new URLSearchParams(location.search).get("k");
  const saved = fromUrl || load("rt_code");
  if (saved && await tryLogin(saved)) return;
  $("login").classList.remove("hidden");
  if (saved && !$("loginErr").textContent) $("loginErr").textContent = "The saved code is no longer valid.";
})();
</script>
</body>
</html>

]==========]

-- ---------------------------------------------------------------------------
local build = nil
local server = nil
local clients = {}
local autoAI = AUTO_AI
local lastSeq = -1
local lastP2Seen = 0
local p2Announced = false
local nextClientId = 1

local function log(msg) console:log("[Rival at the Wheel] " .. msg) end
local function logError(msg) console:error("[Rival at the Wheel] " .. msg) end

local function randomCode()
  local chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
  math.randomseed(os.time() + math.floor(os.clock() * 100000))
  local out = {}
  for i = 1, 6 do
    local n = math.random(1, #chars)
    out[i] = chars:sub(n, n)
  end
  return table.concat(out)
end

if CODE == nil or CODE == "" then CODE = randomCode() end
CODE = string.upper(CODE)

-- ------------------------------ JSON ---------------------------------------
local ARRAY = {}
local function arr(t) return setmetatable(t or {}, ARRAY) end

local function jsonString(s)
  s = s:gsub('[%c"\\]', function(c)
    if c == '"' then return '\\"' end
    if c == '\\' then return '\\\\' end
    if c == '\n' then return '\\n' end
    return string.format('\\u%04x', c:byte())
  end)
  return '"' .. s .. '"'
end

local function toJson(v)
  local t = type(v)
  if t == "nil" then return "null" end
  if t == "boolean" then return v and "true" or "false" end
  if t == "number" then
    if v ~= v or v == math.huge or v == -math.huge then return "null" end
    if math.type(v) == "integer" then return tostring(v) end
    return string.format("%.4f", v)
  end
  if t == "string" then return jsonString(v) end
  if t == "table" then
    local parts = {}
    if getmetatable(v) == ARRAY or v[1] ~= nil then
      for i = 1, #v do parts[#parts + 1] = toJson(v[i]) end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    for k, val in pairs(v) do
      parts[#parts + 1] = jsonString(tostring(k)) .. ":" .. toJson(val)
    end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return "null"
end

-- ------------------------------ GAME MEMORY --------------------------------
local function detectBuild()
  if not emu then return nil end
  for _, b in ipairs(BUILDS) do
    local ok, s = pcall(function() return emu:readRange(b.sig, #SIGNATURE) end)
    if ok and s == SIGNATURE then return b end
  end
  return nil
end

local function u8(s, o) return s:byte(o + 1) end
local function u16(s, o) return (string.unpack("<I2", s, o + 1)) end
local function u32(s, o) return (string.unpack("<I4", s, o + 1)) end
local function s8(s, o) return (string.unpack("<i1", s, o + 1)) end

local function decodeText(s, o, n)
  local out = {}
  for i = 0, n - 1 do
    local b = s:byte(o + i + 1)
    if b == nil or b == 0xFF then break end
    out[#out + 1] = CHARMAP[b] or "?"
  end
  return (table.concat(out):gsub("%s+$", ""))
end

local function readMailbox()
  if not build then return nil end
  local ok, s = pcall(function() return emu:readRange(build.rc, MAILBOX_SIZE) end)
  if not ok or not s or #s < MAILBOX_SIZE then return nil end
  if u32(s, 0) ~= REMOTE_MAGIC then return nil end
  return s
end

local function list4(s, o, size, reader)
  local t = arr()
  for i = 0, 3 do t[#t + 1] = reader(s, o + i * size) end
  return t
end

local function parseState(s)
  local st = {}
  st.reqSeq = u8(s, 0x04)
  st.reqType = u8(s, 0x05)
  st.reqBattler = u8(s, 0x06)
  st.respSeq = u8(s, 0x07)
  st.lastError = u8(s, 0x0B)
  st.battleType = u32(s, 0x0C)
  st.trainerId = u16(s, 0x10)
  st.battlersCount = u8(s, 0x12)
  st.inBattle = u8(s, 0x13) ~= 0
  st.trainerItems = list4(s, 0x14, 2, u16)
  st.trainerClass = decodeText(s, 0x1C, 14)
  st.trainerName = decodeText(s, 0x2A, 14)
  st.unusableMoves = u8(s, 0x38)
  st.canSwitch = u8(s, 0x39) ~= 0
  st.itemUsable = u8(s, 0x3A)
  st.switchable = u8(s, 0x3B)
  st.turn = u8(s, 0x3C)
  st.absent = u8(s, 0x3D)
  st.gimmick = u8(s, 0x3F)
  st.field = u32(s, 0x40)
  st.sides = arr({ u16(s, 0x44), u16(s, 0x46) })
  st.zMoveMask = u8(s, 0x4C)

  st.battlers = arr()
  for i = 0, 3 do
    local o = 0x50 + i * 0x40
    local species = u16(s, o)
    if i < st.battlersCount and species ~= 0 then
      local isFoe = (i % 2) == 1
      local b = {
        id = i,
        foe = isFoe,
        species = species,
        nickname = decodeText(s, o + 0x34, 12),
        level = u8(s, o + 0x2F),
        present = u8(s, o + 0x30) ~= 0,
        types = arr({ u8(s, o + 0x2C), u8(s, o + 0x2D), u8(s, o + 0x2E) }),
        status1 = u32(s, o + 0x14),
        vol = u32(s, o + 0x18),
        lastMove = u16(s, o + 0x0A),
        gimmick = u8(s, o + 0x33),
        teraType = u8(s, o + 0x32),
        stages = arr(),
      }
      for k = 0, 7 do b.stages[#b.stages + 1] = s8(s, o + 0x24 + k) end
      local hp, maxHP = u16(s, o + 0x02), u16(s, o + 0x04)
      if isFoe then
        b.hp = hp
        b.maxHP = maxHP
        b.item = u16(s, o + 0x06)
        b.ability = u16(s, o + 0x08)
        b.partyIndex = u8(s, o + 0x31)
        b.moves = list4(s, o + 0x0C, 2, u16)
        b.pp = list4(s, o + 0x1C, 1, u8)
        b.maxPp = list4(s, o + 0x20, 1, u8)
      else
        -- For player 1, only what the game itself would show
        b.hpPct = maxHP > 0 and math.floor(hp * 100 / maxHP + 0.5) or 0
        if hp > 0 and b.hpPct == 0 then b.hpPct = 1 end
      end
      st.battlers[#st.battlers + 1] = b
    end
  end

  st.party = arr()
  for i = 0, 5 do
    local o = 0x150 + i * 0x30
    local flags = u8(s, o + 0x1D)
    if (flags & 1) ~= 0 then
      st.party[#st.party + 1] = {
        slot = i,
        species = u16(s, o),
        nickname = decodeText(s, o + 0x20, 12),
        hp = u16(s, o + 0x02),
        maxHP = u16(s, o + 0x04),
        item = u16(s, o + 0x06),
        status = u32(s, o + 0x08),
        moves = list4(s, o + 0x0C, 2, u16),
        pp = list4(s, o + 0x14, 1, u8),
        maxPp = list4(s, o + 0x18, 1, u8),
        level = u8(s, o + 0x1C),
        ability = u16(s, o + 0x1E),
        teraType = u8(s, o + 0x2C),
        onField = (flags & 2) ~= 0,
        canSend = (flags & 4) ~= 0,
        egg = (flags & 8) ~= 0,
      }
    end
  end

  st.playerParty = arr()
  for i = 0, 5 do st.playerParty[#st.playerParty + 1] = u8(s, 0x270 + i) end
  return st
end

local function writeResponse(seq, rtype, a1, a2, flags)
  local s = readMailbox()
  if not s then return false, "No battle in progress" end
  local reqSeq, reqType = u8(s, 0x04), u8(s, 0x05)
  if reqType == 0 then return false, "It's not your turn" end
  if reqSeq ~= seq then return false, "Request expired, try again" end
  if u8(s, 0x07) == reqSeq then return false, "Choice already sent" end
  emu:write8(build.rc + 0x08, rtype)
  emu:write8(build.rc + 0x09, a1 & 0xFF)
  emu:write8(build.rc + 0x0A, a2 & 0xFF)
  emu:write8(build.rc + 0x3E, (flags or 0) & 0xFF)
  emu:write8(build.rc + 0x07, reqSeq)
  return true
end

-- ------------------------------- WEB SERVER ---------------------------------
local STATUS_TEXT = { [200] = "OK", [400] = "Bad Request", [401] = "Unauthorized", [404] = "Not Found" }

local function httpResponse(code, ctype, body)
  return table.concat({
    "HTTP/1.1 ", code, " ", STATUS_TEXT[code] or "OK", "\r\n",
    "Content-Type: ", ctype, "\r\n",
    "Content-Length: ", #body, "\r\n",
    "Cache-Control: no-store\r\n",
    "Connection: close\r\n\r\n",
    body,
  })
end

local function jsonResponse(code, t) return httpResponse(code, "application/json; charset=utf-8", toJson(t)) end

local function parseQuery(q)
  local t = {}
  for k, v in string.gmatch(q or "", "([^&=]+)=([^&]*)") do
    v = v:gsub("+", " "):gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
    t[k] = v
  end
  return t
end

local function buildState()
  local st = { ok = true, auto = autoAI, version = 2 }
  if not emu then
    st.game = "none"
    return st
  end
  if not build then build = detectBuild() end
  if not build then
    st.game = "wrong"
    return st
  end
  st.game = build.name
  local s = readMailbox()
  if not s then
    st.inBattle = false
    return st
  end
  local parsed = parseState(s)
  for k, v in pairs(parsed) do st[k] = v end
  if parsed.reqType ~= 0 and parsed.respSeq == parsed.reqSeq then
    st.reqType = 0 -- answer already sent, being processed
  end
  return st
end

local function handleRequest(method, path, body)
  local route, query = path:match("^([^?]*)%??(.*)$")
  local q = parseQuery(query)
  if route == "/" or route == "/index.html" then
    return httpResponse(200, "text/html; charset=utf-8", HTML)
  end
  if route == "/favicon.ico" then
    return httpResponse(404, "text/plain", "")
  end
  if route:sub(1, 5) == "/api/" then
    local key = string.upper(q.k or "")
    if key ~= CODE then
      return jsonResponse(401, { ok = false, error = "Wrong code" })
    end
    lastP2Seen = os.time()
    if not p2Announced then
      p2Announced = true
      log("Player 2 has connected!")
    end
    if route == "/api/state" then
      return jsonResponse(200, buildState())
    end
    if route == "/api/choose" and method == "POST" then
      local f = parseQuery(body)
      local seq, rtype = tonumber(f.seq), tonumber(f.type)
      local a1, a2 = tonumber(f.a1) or 0, tonumber(f.a2) or 0
      local g = tonumber(f.g) or 0
      if not seq or not rtype or rtype < 1 or rtype > 4 then
        return jsonResponse(400, { ok = false, error = "Invalid request" })
      end
      if not build then return jsonResponse(200, { ok = false, error = "Game not ready" }) end
      local ok, err = writeResponse(seq, rtype, a1, a2, g)
      return jsonResponse(200, { ok = ok, error = err })
    end
    if route == "/api/auto" and method == "POST" then
      local f = parseQuery(body)
      autoAI = f.on == "1"
      log(autoAI and "Auto AI turned ON by player 2" or "Auto AI turned off: player 2 decides")
      return jsonResponse(200, { ok = true, auto = autoAI })
    end
  end
  return httpResponse(404, "text/plain; charset=utf-8", "Page not found")
end

local function closeClient(c)
  if clients[c.id] then
    clients[c.id] = nil
    pcall(function() c.sock:close() end)
  end
end

local function tryHandle(c)
  if c.out then return end
  local headerEnd = c.buf:find("\r\n\r\n", 1, true)
  if not headerEnd then
    if #c.buf > 16384 then closeClient(c) end
    return
  end
  local header = c.buf:sub(1, headerEnd - 1)
  local method, path = header:match("^(%u+)%s+(%S+)")
  if not method then closeClient(c); return end
  local len = tonumber(header:match("[Cc]ontent%-[Ll]ength:%s*(%d+)")) or 0
  if len > 4096 then closeClient(c); return end
  local body = c.buf:sub(headerEnd + 4)
  if #body < len then return end
  body = body:sub(1, len)
  local ok, resp = pcall(handleRequest, method, path, body)
  if not ok then
    logError("internal error: " .. tostring(resp))
    resp = httpResponse(400, "text/plain", "Error")
  end
  c.out = resp
end

local function onClientData(c)
  while clients[c.id] do
    local data, err = c.sock:receive(4096)
    if data then
      c.buf = c.buf .. data
      c.last = os.time()
    else
      if err ~= socket.ERRORS.AGAIN then
        if not c.out then closeClient(c) end
      end
      break
    end
  end
  if clients[c.id] then tryHandle(c) end
end

local function flushClients()
  local now = os.time()
  for _, c in pairs(clients) do
    if c.out then
      if #c.out == 0 then
        closeClient(c)
      else
        local n, err = c.sock:send(c.out)
        if n and n > 0 then
          c.out = c.out:sub(n + 1)
          c.last = now
          if #c.out == 0 then closeClient(c) end
        elseif err and err ~= socket.ERRORS.AGAIN then
          closeClient(c)
        end
      end
    end
    if clients[c.id] and now - c.last > 15 then closeClient(c) end
  end
end

local function onAccept()
  while true do
    local sock, err = server:accept()
    if not sock then return end
    local c = { id = nextClientId, sock = sock, buf = "", last = os.time() }
    nextClientId = nextClientId + 1
    clients[c.id] = c
    sock:add("received", function() onClientData(c) end)
    sock:add("error", function() closeClient(c) end)
  end
end

local function startServer()
  local port = PORT
  for attempt = 0, 10 do
    local s, err = socket.bind(LOCAL_ONLY and "127.0.0.1" or nil, port + attempt)
    if s then
      local ok, lerr = s:listen(16)
      if ok then
        server = s
        server:add("received", onAccept)
        return port + attempt
      end
      s:close()
      logError("listen failed on port " .. (port + attempt) .. ": " .. tostring(lerr))
    elseif err ~= socket.ERRORS.ADDRESS_IN_USE then
      logError("cannot open port " .. (port + attempt) .. ": " .. tostring(err))
      return nil
    end
  end
  return nil
end

-- ------------------------------- MAIN LOOP ----------------------------------
local REQ_NAMES = { [1] = "choosing an action", [2] = "choosing a move", [3] = "choosing the next Pokemon" }

local function onFrame()
  flushClients()
  if not emu then return end
  if not build then
    build = detectBuild()
    if build then log("Patch detected: " .. build.name) end
    return
  end
  local s = readMailbox()
  if not s then return end
  local reqSeq, reqType, respSeq = u8(s, 0x04), u8(s, 0x05), u8(s, 0x07)
  if reqType ~= 0 and respSeq ~= reqSeq then
    if autoAI then
      writeResponse(reqSeq, 4, 0, 0, 0)
      return
    end
    if reqSeq ~= lastSeq then
      lastSeq = reqSeq
      local err = u8(s, 0x0B)
      if err ~= 0 then
        log("Invalid choice, player 2 must try again (" .. (REQ_NAMES[reqType] or "?") .. ")")
      else
        log("Waiting for player 2: " .. (REQ_NAMES[reqType] or "?"))
      end
    end
  end
end

local function onStart()
  build = detectBuild()
  if build then
    log("Patch detected: " .. build.name)
  elseif emu then
    logError("This ROM doesn't have the Rival at the Wheel patch (or it's a different build).")
  end
end

local port = startServer()
console:log("==============================================")
console:log("           RIVAL AT THE WHEEL - mGBA")
console:log("==============================================")
if port then
  log("Server started on port " .. port)
  log("CODE for player 2:  " .. CODE)
  log("Test locally:  http://127.0.0.1:" .. port .. "/?k=" .. CODE)
  log("For internet play, run the tunnel (start_tunnel.bat) and send player 2")
  log("the https://....trycloudflare.com link together with the code.")
else
  logError("Couldn't start the web server. Change PORT at the top of the script.")
end

callbacks:add("frame", onFrame)
callbacks:add("start", onStart)
if emu then onStart() end
