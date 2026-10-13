#!/usr/bin/env python3
"""Build gamedata.json for pokeemerald-expansion from a runtime table dump.

Usage: gen_gamedata.py <rom.gba> <dump.bin> <charmap.txt> <out.json>

dump.bin is written by the test build (REMOTE_TEST_BOOT, RemoteTestDumpData):
a header of u32 counts/offsets followed by name pointers and move data.
"""
import json
import re
import struct
import sys

ROM_BASE = 0x08000000


def parse_charmap(path):
    table = {}
    for line in open(path, encoding="utf-8"):
        line = line.split("@")[0].strip()
        m = re.match(r"^'(.+)'\s*=\s*([0-9A-Fa-f]{2})$", line)
        if not m or m.group(1).startswith("\\"):
            continue
        byte = int(m.group(2), 16)
        table.setdefault(byte, m.group(1))
    table[0x00] = " "
    return table


def main():
    rom_path, dump_path, charmap_path, out_path = sys.argv[1:5]
    rom = open(rom_path, "rb").read()
    dump = open(dump_path, "rb").read()
    cmap = parse_charmap(charmap_path)

    hdr = struct.unpack_from("<16I", dump, 0)
    assert hdr[0] == 0x504D5544, "bad dump magic"
    n_species, n_moves, n_items, n_abilities, n_types = hdr[1:6]
    o_species, o_moves, o_items, o_abilities, o_types = hdr[6:11]

    def text(ptr, maxlen=32):
        if not ptr:
            return ""
        off = ptr - ROM_BASE
        if off < 0 or off >= len(rom):
            return "?"
        out = []
        for b in rom[off:off + maxlen]:
            if b == 0xFF:
                break
            if b == 0xFC:  # control code, stop
                break
            out.append(cmap.get(b, ""))
        return "".join(out).strip()

    species, species_types = [], []
    for i in range(n_species):
        ptr, t0, t1 = struct.unpack_from("<IBB", dump, o_species + i * 8)
        species.append(text(ptr, 13))
        species_types.append([t0, t1])
    moves = []
    for i in range(n_moves):
        ptr, t, cat, power, acc, pp, tg, pr = struct.unpack_from("<IBBHBBBb", dump, o_moves + i * 12)
        moves.append({"n": text(ptr, 20), "t": t, "c": cat, "p": power, "a": acc, "pp": pp, "tg": tg, "pr": pr})
    items = [text(struct.unpack_from("<I", dump, o_items + i * 4)[0], 20) for i in range(n_items)]
    abilities = [text(struct.unpack_from("<I", dump, o_abilities + i * 4)[0], 20) for i in range(n_abilities)]
    types = [text(struct.unpack_from("<I", dump, o_types + i * 4)[0], 12) for i in range(n_types)]

    assert species[1].upper() == "BULBASAUR", species[1]
    assert moves[1]["n"].upper() == "POUND" and moves[1]["p"] == 40, moves[1]
    assert types[19].upper() == "FAIRY", types

    data = {
        "species": species, "speciesTypes": species_types, "moves": moves,
        "items": items, "abilities": abilities, "types": types,
        "charmap": {str(k): v for k, v in sorted(cmap.items())},
    }
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
    print("ok", n_species, n_moves, n_items, n_abilities, n_types)


if __name__ == "__main__":
    main()
