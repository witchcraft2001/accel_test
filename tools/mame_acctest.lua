-- mame_acctest.lua -- MAME "sprinter" driver for ACCTEST.EXE (started by run_mame.sh).
-- Types B:\ACCTEST.EXE <ACC_ARGS> in the DSS file manager, takes a screenshot of every
-- visual screen while it is held (vis_held), waits for at_state (1 pass, 2 fail) and
-- writes ACC_OUT/report.txt ending with "RESULT: PASS|FAIL".
-- Environment: ACC_SYM (symbol file), ACC_OUT (output directory), ACC_ARGS (options).

if _G.__acctest_loaded then return end   -- MAME executes -autoboot_script twice
_G.__acctest_loaded = true

local machine = manager.machine
local cpu = machine.devices[":maincpu"]
local prog = cpu.spaces["program"]
local screen = machine.screens[":screen"]

local SYM = os.getenv("ACC_SYM") or "build/ACCTEST.sym"
local OUT = os.getenv("ACC_OUT") or "build/mame"
local ARGS = os.getenv("ACC_ARGS") or "/A /Q /L=B:\\ACCTEST.LOG"
local TIMEOUT = tonumber(os.getenv("ACC_TIMEOUT") or "1700")
local HEARTBEAT = tonumber(os.getenv("ACC_HEARTBEAT") or "0")   -- emulated s between progress lines
local WALL = tonumber(os.getenv("ACC_WALL") or "3600")          -- real-time limit, s
local TRACE_FROM = tonumber(os.getenv("ACC_TRACE_FROM") or "0")  -- log PC every frame from here

local out = assert(io.open(OUT .. "/report.txt", "w"))
local function log(fmt, ...)
  local s = string.format(fmt, ...)
  print(s)
  out:write(s, "\n")
  out:flush()
end
local function now() return machine.time:as_double() end
local function frames(n) for _ = 1, n do coroutine.yield() end end

local sym = {}
for line in io.lines(SYM) do
  local name, hex = line:match("^([%w_%.]+):%s*EQU%s+0x(%x+)")
  if name then sym[name] = tonumber(hex, 16) end
end
local function S(name) return assert(sym[name], "symbol " .. name .. " missing in " .. SYM) end

-- Side-effect-free reads.  In the sprinter driver a read of the program space at
-- #0000..#FFFF is an M1 fetch (it drives the accelerator's opcode decoder and prefix
-- flag) and a read at #1xxxx goes through the accelerator tap and the memory wait:
-- either one corrupts a running test.  Read the RAM buffer itself instead, at the
-- physical page currently in WIN1 (all the symbols we read are in the hot segment).
local ram_item, win1_bank
for k, v in pairs(machine.devices[":ram"].items) do
  if k:match("m_pointer") then ram_item = emu.item(v) end
end
local bank_tags = {}
for tag, b in pairs(machine.memory.banks) do
  bank_tags[#bank_tags + 1] = tag
  if tag:match("ram") and tag:match("1$") then win1_bank = b end
end
assert(ram_item, "RAM device buffer not found")
assert(win1_bank, "WIN1 bank not found; banks: " .. table.concat(bank_tags, ", "))
local function rd8(addr) return ram_item:read(win1_bank.entry * 0x4000 + (addr & 0x3fff)) end
local function u8(name) return rd8(S(name)) end
local function u16(name) return rd8(S(name)) + 256 * rd8(S(name) + 1) end

-- ---------------------------------------------------------------- keyboard
local fields = {}
for tag, port in pairs(machine.ioport.ports) do
  if tag:find("^:kbd:") then for fname, f in pairs(port.fields) do fields[fname] = f end end
end
local shifted = { [":"] = ";", ["_"] = "-", ["+"] = "=", ["?"] = "/" }
local named = { [" "] = "Space", ["\n"] = "Enter" }
local HOLD = 3
local function press(ch)
  local name, sh = ch, false
  if ch:match("%l") then name = ch:upper()
  elseif named[ch] then name = named[ch]
  elseif shifted[ch] then name, sh = shifted[ch], true end
  local f = fields[name]
  if not f then
    local list = {}
    for k in pairs(fields) do list[#list + 1] = k end
    error("no key field for '" .. ch .. "'; fields: " .. table.concat(list, ", "))
  end
  if sh then fields["Left Shift"]:set_value(1); frames(HOLD) end
  f:set_value(1); frames(HOLD)
  f:set_value(0)
  if sh then frames(HOLD); fields["Left Shift"]:set_value(0) end
  frames(HOLD)
end
local function type_line(s)
  for i = 1, #s do press(s:sub(i, i)) end
  press("\n")
end

-- ---------------------------------------------------------------- scenario
local result = "FAIL"
local function scenario()
  log("mame_acctest.lua: %s, args %s", SYM:match("[^/]+$"), ARGS)
  while now() < 10 do frames(1) end        -- DSS boot to the file manager
  type_line("b:\\acctest.exe " .. ARGS:lower())
  local t0 = now()
  local held, shots, started = 0, 0, false
  local hb, w0 = now(), os.time()
  while now() - t0 < TIMEOUT do
    frames(1)
    if TRACE_FROM > 0 and now() >= TRACE_FROM then
      local extra = ""
      for w in (os.getenv("ACC_TRACE_VARS") or ""):gmatch("[%w_%.]+") do
        extra = extra .. string.format(" %s=%04X", w, u16(w))
      end
      log("  trace t=%.3f pc=%04X sp=%04X%s", now(), cpu.state["PC"].value, cpu.state["SP"].value, extra)
    end
    if HEARTBEAT > 0 and now() - hb >= HEARTBEAT then
      hb = now()
      log("  t=%.1f s (wall %d s) pc=%04X pass=%d fail=%d vis=%d", now(), os.time() - w0,
          cpu.state["PC"].value, u16("at_pass"), u16("at_fail"), u8("vis_held"))
      screen:snapshot("progress.png")
    end
    if os.time() - w0 > WALL then log("wall-clock limit %d s reached", WALL); return end
    -- the program is running while its WIN1 page holds our code; read the flags then
    local sig, a = "ACCTEST-COLD", S("cold_magic_ref")
    local mine = true
    for i = 1, #sig do if rd8(a + i - 1) ~= sig:byte(i) then mine = false; break end end
    if mine and not started then started = true; log("program started at %.1f s", now()) end
    local st = mine and u8("at_state") or 0
    if st == 1 or st == 2 then
      local pass, fail = u16("at_pass"), u16("at_fail")
      log("program finished after %.1f s emulated: passed %d, failed %d", now() - t0, pass, fail)
      if st == 1 and fail == 0 and pass > 0 then result = "PASS" end
      frames(2)
      screen:snapshot("result.png")
      -- wait for the exit (our page leaves WIN1), then for DSS to finish the floppy
      local te = now()
      while now() - te < 120 do
        frames(1)
        local still = true
        for i = 1, #sig do if rd8(a + i - 1) ~= sig:byte(i) then still = false; break end end
        if not still then break end
      end
      log("program exited %.1f s after the result", now() - te)
      te = now()
      while now() - te < 3 do frames(1) end
      return
    end
    local h = u8("vis_held")
    if h ~= held then
      held = h
      if h ~= 0 and h < 16 then
        frames(2)
        screen:snapshot(string.format("visual%d.png", h))
        shots = shots + 1
      end
    end
  end
  log("timeout after %d s emulated", TIMEOUT)
end

local co = coroutine.create(function()
  local ok, err = pcall(scenario)
  if not ok then log("SCRIPT ERROR: %s", tostring(err)) end
  screen:snapshot("final.png")
  log("RESULT: %s", result)
  out:close()
  machine:exit()
end)

emu.register_frame_done(function()
  if coroutine.status(co) == "suspended" then
    local ok, err = coroutine.resume(co)
    if not ok then print("coroutine error: " .. tostring(err)); machine:exit() end
  end
end)
