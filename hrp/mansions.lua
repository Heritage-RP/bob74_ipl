-- Fork patch (PATCHES.md): the villas of the DLC "A Safehouse in the Hills" (build 3717+) can be left out of the map.
--
-- Replicated convar `bob74_ipl_mansions`: "villas" (default, as upstream: client.lua loads the three villas) or
-- "original" (`setr bob74_ipl_mansions "original"`: the lots show the pre-DLC map). With "original", client.lua does not
-- load the villas, and from build 3717 the base map has no ground of its own on the three lots: the terrain is either
-- the villa (*_mansion_shared/_generic…) or the pre-DLC map (*_mansion_original, *_props_original,
-- hei_ch1_roads_original). Loading neither leaves a hole (Heritage-RP/PRODUCTION-SERVER#367: Richman, -1749, 211). So
-- this file does what the game's own building_controller.c script does when it puts the old map back for the story
-- missions (decompiled scripts, legacy builds 3725 and 3889, same IPL names): remove every villa IPL, request every
-- "original" IPL, hide the villa minimap overlays. Checked at start then every 30 s, in case the game or another
-- resource switches the villas on again.

HrpMansions = {
    minBuild = 3717,
    checkIntervalMs = 30000,
    convar = "bob74_ipl_mansions",

    --- What the server wants on the villa lots: "villas" (default, upstream) or "original" (the pre-DLC map).
    --- @param getConvar fun(name: string, default: string): string
    --- @return "villas" | "original"
    Mode = function(getConvar)
        local value = getConvar(HrpMansions.convar, "villas")
        if value == "original" then return "original" end
        if value ~= "villas" and HrpLog then
            HrpLog.warn("unknown value of " .. HrpMansions.convar .. ", the villas stay", { value = value })
        end
        return "villas"
    end,

    -- Minimap overlays of the villas (building_controller.c: shown with the villas, hidden with the original map).
    minimapComponents = { 20, 21, 22 },

    -- The villas: removed whenever active (the list of building_controller.c, in its order).
    remove = {
        "m25_2_mansion_gym",
        "m25_2_tongva_mansion_gym",
        "m25_2_east_mansion_gym",
        "m25_2_tongva_dog_house",
        "m25_2_east_dog_house",
        "m25_2_dog_house",
        "m25_2_mansion_props",
        "hei_ch1_09_mansion_player_bounds",
        "hei_ch1_06e_mansion_player_bounds",
        "apa_Ch2_04_Mansion_Player_Bounds",
        "apa_ch2_04_mansion_railings_p",
        "hei_ch1_06e_mansion_railings_p",
        "hei_ch1_09_mansion_railings_p",
        "apa_ch2_04_mansion_firepit",
        "hei_ch1_06e_mansion_firepit",
        "hei_ch1_09_mansion_firepit",
        "hei_ch1_06e_mansion_furniture",
        "hei_ch1_09_mansion_furniture",
        "apa_ch2_04_mansion_furniture",
        "hei_ch1_09_mansion_private",
        "hei_ch1_06e_mansion_private",
        "apa_ch2_04_mansion_private",
        "m25_2_ch1_06e_mansion_interior_c",
        "m25_2_ch2_04_mansion_interior_c",
        "m25_2_ch1_09_mansion_interior_c",
        "m25_2_ch1_09_mansion_interior_b",
        "m25_2_ch1_06e_mansion_interior_b",
        "m25_2_ch2_04_mansion_interior_b",
        "m25_2_ch1_06e_mansion_interior_a",
        "m25_2_ch2_04_mansion_interior_a",
        "m25_2_ch1_09_mansion_interior_a",
        "hei_ch1_09_mansion_shared_lodlights",
        "hei_ch1_09_mansion_shared_distantlights",
        "hei_ch1_09_mansion_private_lodlights",
        "hei_ch1_09_mansion_private_distantlights",
        "hei_ch1_09_mansion_firepit_lodlights",
        "hei_ch1_09_mansion_firepit_distantlights",
        "hei_ch1_06e_mansion_shared_lodlights",
        "hei_ch1_06e_mansion_shared_distantlights",
        "hei_ch1_06e_mansion_private_lodlights",
        "hei_ch1_06e_mansion_private_distantlights",
        "hei_ch1_06e_mansion_firepit_lodlights",
        "hei_ch1_06e_mansion_firepit_distantlights",
        "apa_ch2_04_mansion_shared_lodlights",
        "apa_ch2_04_mansion_shared_distantlights",
        "apa_ch2_04_mansion_private_lodlights",
        "apa_ch2_04_mansion_private_distantlights",
        "apa_ch2_04_mansion_firepit_lodlights",
        "apa_ch2_04_mansion_firepit_distantlights",
        "hei_ch1_roads_mansion", -- replaced by hei_ch1_roads_original below
        "hei_ch1_09_mansion_shared",
        "hei_ch1_09_mansion_generic",
        "apa_ch2_04_mansion_shared",
        "apa_ch2_04_mansion_generic",
        "hei_ch1_06f_mansion_shared",
        "hei_ch1_06e_mansion_shared",
        "hei_ch1_06e_mansion_generic",
    },

    -- The pre-DLC map of the three lots (terrain, collision, props, road): requested whenever inactive.
    restore = {
        -- The Richman Villa lot: -1630.434, 470.852, 128.0
        "hei_ch1_06e_mansion_original",
        "hei_ch1_06f_mansion_Original",
        "hei_ch1_06e_props_original",
        -- The road piece shared by the lots
        "hei_ch1_roads_original",
        -- The Vinewood Residence lot: 543.852, 712.754, 201.0
        "apa_ch2_04_mansion_original",
        "apa_ch2_04_props_original",
        -- The Tongva Estate lot: -2601.712, 1874.826, 166.0
        "hei_ch1_09_mansion_original",
        "hei_ch1_09_props_original",
        "hei_ch1_09_mansion_original_distantlights",
        "hei_ch1_09_mansion_original_lodlights",
        "hei_ch1_09_props_original_distantlights",
        "hei_ch1_09_props_original_lodlights",
    },

    --- Removes every active villa IPL and requests every inactive original IPL. Returns both lists of names.
    --- @param isActive fun(name: string): boolean
    --- @param request fun(name: string)
    --- @param remove fun(name: string)
    Apply = function(isActive, request, remove)
        local removed, requested = {}, {}
        for _, name in ipairs(HrpMansions.remove) do
            if isActive(name) then
                remove(name)
                removed[#removed + 1] = name
            end
        end
        for _, name in ipairs(HrpMansions.restore) do
            if not isActive(name) then
                request(name)
                requested[#requested + 1] = name
            end
        end
        return removed, requested
    end,

    --- Hides the villa minimap overlays.
    --- @param setComponent fun(id: integer, toggle: boolean, hudColor: integer)
    HideMinimap = function(setComponent)
        for _, id in ipairs(HrpMansions.minimapComponents) do
            setComponent(id, false, -1)
        end
    end,

    --- One pass with the game natives; logs what changed.
    Sweep = function()
        local removed, requested = HrpMansions.Apply(IsIplActive, RequestIpl, RemoveIpl)
        if #removed > 0 or #requested > 0 then
            HrpLog.info("A Safehouse in the Hills: pre-DLC map restored on the villa lots", {
                removed = #removed,
                requested = #requested,
                ipl = table.concat(removed, ","),
                original = table.concat(requested, ","),
            })
        end
        return removed, requested
    end,
}

if CreateThread and GetGameBuildNumber and GetGameBuildNumber() >= HrpMansions.minBuild
    and HrpMansions.Mode(GetConvar) == "original" then
    CreateThread(function()
        HrpMansions.HideMinimap(SetMinimapComponent)
        while true do
            HrpMansions.Sweep()
            Wait(HrpMansions.checkIntervalMs)
        end
    end)
end
