-- Héritage RP checks (Heritage-RP/PRODUCTION-SERVER#82, #332, #367). Run from the resource folder:
--   docker run --rm -v "$PWD":/w -w /w nickblah/lua:5.4 lua tests/lua/mansions_spec.lua
-- (or any Lua 5.4: `lua tests/lua/mansions_spec.lua`).

local failures = 0
local function check(name, cond)
    if cond then io.write('ok   ', name, '\n') else failures = failures + 1; io.write('FAIL ', name, '\n') end
end

local function read(path)
    local f = assert(io.open(path, 'r'))
    local content = f:read('a')
    f:close()
    return content
end

-- Exterior IPL names of a dlc_mansions script (the `ipl = { ... }` table of Ipl.Exterior).
local function exteriorIpls(path)
    local block = read(path):match('Exterior%s*=%s*{%s*ipl%s*=%s*(%b{})')
    local names = {}
    for name in (block or ''):gmatch('"([^"]+)"') do names[#names + 1] = name end
    return names
end

-- Load hrp/mansions.lua without the game: no CreateThread, so no sweep thread.
_G.CreateThread, _G.GetGameBuildNumber = nil, nil
dofile('hrp/mansions.lua')
local M = HrpMansions

local function set(list)
    local out = {}
    for _, name in ipairs(list) do out[name:lower()] = true end
    return out
end
local removeSet, restoreSet = set(M.remove), set(M.restore)

-- 1. Every Exterior IPL of the three villas is removed (the road piece too: hei_ch1_roads_original replaces it).
local fromDlc = {}
for i = 1, 3 do
    local names = exteriorIpls(('dlc_mansions/mansion%d.lua'):format(i))
    check(('mansion%d.lua exterior list parsed'):format(i), #names > 0)
    for _, name in ipairs(names) do
        fromDlc[name] = true
        check(('mansion%d: %s removed'):format(i, name), removeSet[name:lower()])
    end
end
check('nothing kept on the side any more', M.keep == nil)

-- 2. #367: the removed list holds no terrain of the pre-DLC map, the restored list holds the terrain of every lot.
--    Lists of building_controller.c (game script, legacy builds 3725 and 3889): 57 villa IPLs out, 12 original IPLs in.
check('57 villa IPLs removed', #M.remove == 57)
check('12 original IPLs restored', #M.restore == 12)
for name in pairs(removeSet) do
    check(name .. ' is a villa IPL, not an original one', not name:find('original', 1, true))
end
for name in pairs(restoreSet) do
    check(name .. ' is an original IPL', name:find('original', 1, true) ~= nil)
    check(name .. ' is not removed too', not removeSet[name])
end
for _, lot in ipairs({
    'hei_ch1_06e_mansion_original', -- the Richman Villa lot (#367)
    'hei_ch1_06f_mansion_original',
    'apa_ch2_04_mansion_original', -- the Vinewood Residence lot
    'hei_ch1_09_mansion_original', -- the Tongva Estate lot
    'hei_ch1_roads_original', -- the road in place of hei_ch1_roads_mansion
}) do
    check(lot .. ' restored', restoreSet[lot])
end
check('the generic (locked) villas are removed',
    removeSet.hei_ch1_06e_mansion_generic and removeSet.apa_ch2_04_mansion_generic and removeSet.hei_ch1_09_mansion_generic)
check('the villa road piece is removed', removeSet.hei_ch1_roads_mansion)

-- 3. Apply: removes only active villa IPLs, requests only inactive original IPLs.
do
    local function run(active)
        local removedCalls, requestedCalls = {}, {}
        local removed, requested = M.Apply(function(name) return active[name] == true end,
            function(name) requestedCalls[#requestedCalls + 1] = name; active[name] = true end,
            function(name) removedCalls[#removedCalls + 1] = name; active[name] = nil end)
        check('Apply returns what it did', #removed == #removedCalls and #requested == #requestedCalls)
        return set(removedCalls), set(requestedCalls), removedCalls, requestedCalls
    end

    -- State deployed when #367 was reported: villas not loaded, nothing else either -> hole. Now the old map comes back.
    local state = {}
    local removed, requested, removedList, requestedList = run(state)
    check('#367: nothing to remove when the villas are off', #removedList == 0)
    check('#367: every original IPL requested', #requestedList == #M.restore)
    check('#367: the Richman Villa lot gets its ground back', requested.hei_ch1_06e_mansion_original)

    -- Second pass: steady state, nothing to do.
    local _, _, removedList2, requestedList2 = run(state)
    check('steady state: no call', #removedList2 == 0 and #requestedList2 == 0)

    -- The game or another resource switches a villa back on.
    state.hei_ch1_06e_mansion_generic, state.hei_ch1_roads_mansion = true, true
    state.hei_ch1_roads_original = nil
    removed, requested = run(state)
    check('villa switched on again: removed', removed.hei_ch1_06e_mansion_generic and removed.hei_ch1_roads_mansion)
    check('villa switched on again: road restored', requested.hei_ch1_roads_original)
end

-- 3b. Minimap overlays of the villas hidden, as the game does with the original map.
do
    local calls = {}
    M.HideMinimap(function(id, toggle, color) calls[#calls + 1] = { id, toggle, color } end)
    check('three minimap components hidden', #calls == 3)
    local ok = true
    for i, id in ipairs({ 20, 21, 22 }) do
        ok = ok and calls[i][1] == id and calls[i][2] == false and calls[i][3] == -1
    end
    check('minimap components 20, 21, 22 off', ok)
end

-- 3c. Sweep uses the natives and logs through HrpLog only when something changed.
do
    local logs, removedCalls, requestedCalls = {}, {}, {}
    local active = { m25_2_mansion_props = true }
    for _, name in ipairs(M.restore) do active[name] = true end
    _G.HrpLog = { info = function(msg, attrs) logs[#logs + 1] = { msg = msg, attrs = attrs } end }
    _G.IsIplActive = function(name) return active[name] == true end
    _G.RemoveIpl = function(name) removedCalls[#removedCalls + 1] = name; active[name] = nil end
    _G.RequestIpl = function(name) requestedCalls[#requestedCalls + 1] = name; active[name] = true end
    M.Sweep()
    check('Sweep removes through RemoveIpl', #removedCalls == 1 and removedCalls[1] == 'm25_2_mansion_props')
    check('Sweep requests nothing already active', #requestedCalls == 0)
    check('Sweep logs the change', #logs == 1 and logs[1].attrs.removed == 1 and logs[1].attrs.requested == 0)
    M.Sweep()
    check('Sweep stays silent when nothing changed', #logs == 1)
    active.hei_ch1_06e_mansion_original = nil
    M.Sweep()
    check('Sweep requests through RequestIpl', #requestedCalls == 1 and requestedCalls[1] == 'hei_ch1_06e_mansion_original')
    check('Sweep logs the restore', #logs == 2 and logs[2].attrs.requested == 1)
end

-- 4. Manifest and loader: the DLC scripts are not loaded, the removal and HrpLog are.
do
    local manifest = read('fxmanifest.lua')
    local active = {}
    for line in manifest:gmatch('[^\n]+') do
        local code = line:gsub('%-%-.*$', '')
        active[#active + 1] = code
    end
    local code = table.concat(active, '\n')
    check('no dlc_mansions script in the manifest', not code:find('dlc_mansions/', 1, true))
    check('hrp/mansions.lua in the manifest', code:find('"hrp/mansions.lua"', 1, true) ~= nil)
    local first = code:match('client_scripts%s*{%s*"([^"]+)"')
    check('HrpLog is the first client script', first == '@hrp-metrics/lib/log.lua')

    local client = read('client.lua')
    check('client.lua does not load the villas', not client:find('Mansion%w*%.LoadDefault'))
end

-- 5. No print left (HRP rule: third-party Lua logs through @hrp-metrics/lib/log.lua).
do
    local pipe = assert(io.popen("find . -name '*.lua' -not -path './tests/*'"))
    for path in pipe:lines() do
        local n = 0
        for line in read(path):gmatch('[^\n]+') do
            local code = line:gsub('%-%-.*$', '')
            if code:find('%f[%w_]print%s*%(') then n = n + 1 end
        end
        if n > 0 then check(path .. ' has no print()', false) end
    end
    pipe:close()
    check('print scan done', true)
end

if failures > 0 then
    io.write(failures, ' failure(s)\n')
    os.exit(1)
end
io.write('all passed\n')
