-- Héritage RP checks (Heritage-RP/PRODUCTION-SERVER#82, #332). Run from the resource folder:
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

local listed = {}
for _, name in ipairs(M.ipl) do listed[name] = true end

-- 1. Every Exterior IPL of the three villas is removed, except the deliberately kept road piece.
local fromDlc = {}
for i = 1, 3 do
    local names = exteriorIpls(('dlc_mansions/mansion%d.lua'):format(i))
    check(('mansion%d.lua exterior list parsed'):format(i), #names > 0)
    for _, name in ipairs(names) do
        fromDlc[name] = true
        check(('mansion%d: %s removed or deliberately kept'):format(i, name), listed[name] or M.keep[name])
    end
end
for name in pairs(listed) do check(name .. ' comes from a dlc_mansions list', fromDlc[name]) end
check('the road piece is kept', M.keep.hei_ch1_roads_mansion == true and not listed.hei_ch1_roads_mansion)

-- 2. RemoveActive: only active IPLs, never a kept one.
do
    local active = { apa_ch2_04_mansion_shared = true, hei_ch1_09_mansion_shared = true, hei_ch1_roads_mansion = true }
    local removedCalls = {}
    local removed = M.RemoveActive(function(name) return active[name] == true end,
        function(name) removedCalls[#removedCalls + 1] = name end)
    check('two active villa IPLs removed', #removed == 2 and #removedCalls == 2)
    local set = {}
    for _, name in ipairs(removedCalls) do set[name] = true end
    check('removed the Vinewood and Tongva IPLs', set.apa_ch2_04_mansion_shared and set.hei_ch1_09_mansion_shared)
    check('road piece left alone', not set.hei_ch1_roads_mansion)
    check('nothing active, nothing removed', #M.RemoveActive(function() return false end, error) == 0)
end

-- 3. Sweep uses the natives and logs through HrpLog only when something was removed.
do
    local logs, removedCalls = {}, {}
    _G.HrpLog = { info = function(msg, attrs) logs[#logs + 1] = { msg = msg, attrs = attrs } end }
    _G.IsIplActive = function(name) return name == 'm25_2_mansion_props' end
    _G.RemoveIpl = function(name) removedCalls[#removedCalls + 1] = name end
    M.Sweep()
    check('Sweep removes through RemoveIpl', #removedCalls == 1 and removedCalls[1] == 'm25_2_mansion_props')
    check('Sweep logs the removal', #logs == 1 and logs[1].attrs.count == 1)
    _G.IsIplActive = function() return false end
    M.Sweep()
    check('Sweep stays silent when nothing is active', #logs == 1)
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
