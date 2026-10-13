-- Saves the name/move tables written by a REMOTE_TEST_BOOT build to dump.bin.
-- Usage: load the test ROM in mGBA (or mgba-headless) with this script.
-- Set HEAP to the address of gHeap from the test build's .map file.
local HEAP = 0x02014e3c
local OUT = "dump.bin"
local done = false
callbacks:add("frame", function()
  if done then return end
  if emu:read32(HEAP) == 0x504D5544 then -- "DUMP"
    local size = emu:read32(HEAP + 44)
    local f = assert(io.open(OUT, "wb"))
    f:write(emu:readRange(HEAP, size))
    f:close()
    console:log("Wrote " .. OUT .. " (" .. size .. " bytes)")
    done = true
  end
end)
