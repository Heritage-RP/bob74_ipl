-- Héritage RP: the villas of the DLC "A Safehouse in the Hills" (build 3717+) are not part of the map
-- (Heritage-RP/PRODUCTION-SERVER#82, #332).
--
-- bob74_ipl no longer loads them (dlc_mansions/*.lua are out of fxmanifest.lua and client.lua). Upstream only shows
-- them through RequestIpl (EnableIpl in lib/common.lua), so they are inactive by default; this file also removes them
-- explicitly in case the game build or another resource activates them: "not loaded" is not "removed".
--
-- The lists are the Exterior IPLs of dlc_mansions/mansion1-3.lua (the basements are interiors inside them: no IPL of
-- their own). Kept on purpose: "hei_ch1_roads_mansion" (a road piece shared by the three villas — removing it could
-- leave a hole in the road; without the villas it is only a driveway) and "m25_2_knoway_sign" (a sign, not a villa).

HrpMansions = {
    minBuild = 3717,
    checkIntervalMs = 30000,

    ipl = {
        -- The Vinewood Residence: 543.852, 712.754, 201.0
        "m25_2_ch2_04_mansion_interior_a",
        "m25_2_ch2_04_mansion_interior_b",
        "m25_2_ch2_04_mansion_interior_c",
        "apa_ch2_04_mansion_shared",
        "apa_ch2_04_mansion_private",
        "apa_ch2_04_mansion_furniture",
        "apa_ch2_04_mansion_firepit",
        "apa_ch2_04_mansion_railings_p",
        "m25_2_east_mansion_gym",
        "m25_2_east_dog_house",

        -- The Richman Villa: -1630.434, 470.852, 128.0
        "hei_ch1_06e_mansion_shared",
        "hei_ch1_06f_mansion_shared",
        "m25_2_ch1_06e_mansion_interior_a",
        "m25_2_ch1_06e_mansion_interior_b",
        "m25_2_ch1_06e_mansion_interior_c",
        "hei_ch1_06e_mansion_private",
        "hei_ch1_06e_mansion_furniture",
        "hei_ch1_06e_mansion_firepit",
        "hei_ch1_06e_mansion_railings_p",
        "m25_2_mansion_gym",
        "m25_2_dog_house",

        -- The Tongva Estate: -2601.712, 1874.826, 166.0
        "hei_ch1_09_mansion_shared",
        "m25_2_ch1_09_mansion_interior_a",
        "m25_2_ch1_09_mansion_interior_b",
        "m25_2_ch1_09_mansion_interior_c",
        "hei_ch1_09_mansion_private",
        "hei_ch1_09_mansion_furniture",
        "hei_ch1_09_mansion_firepit",
        "hei_ch1_09_mansion_railings_p",
        "m25_2_tongva_mansion_gym",
        "m25_2_tongva_dog_house",

        -- Shared by the three villas
        "m25_2_mansion_props",
    },

    -- IPLs of the DLC's lists deliberately left alone (see above).
    keep = {
        hei_ch1_roads_mansion = true,
    },

    --- Removes every listed IPL that is active. Returns the names removed.
    --- @param isActive fun(name: string): boolean
    --- @param remove fun(name: string)
    RemoveActive = function(isActive, remove)
        local removed = {}
        for _, name in ipairs(HrpMansions.ipl) do
            if not HrpMansions.keep[name] and isActive(name) then
                remove(name)
                removed[#removed + 1] = name
            end
        end
        return removed
    end,

    --- One pass with the game natives; logs what was removed.
    Sweep = function()
        local removed = HrpMansions.RemoveActive(IsIplActive, RemoveIpl)
        if #removed > 0 then
            HrpLog.info("A Safehouse in the Hills: active villa IPLs removed", { count = #removed, ipl = table.concat(removed, ",") })
        end
        return removed
    end,
}

if CreateThread and GetGameBuildNumber and GetGameBuildNumber() >= HrpMansions.minBuild then
    CreateThread(function()
        while true do
            HrpMansions.Sweep()
            Wait(HrpMansions.checkIntervalMs)
        end
    end)
end
