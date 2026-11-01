-- CI only: production spell metadata and SCT over explicit fake native boundaries.
assert(_VERSION == "Lua 5.1", "SCT area fixtures require CI Lua 5.1")
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
local SCT = dofile("scripts/tests/fixtures/ui_sct_helpers.lua")
local passed = 0
local function Test(name, callback)
    callback()
    passed = passed + 1
    print("PASS " .. name)
end

local function Scene(style, performance)
    return SCT(style == "msbt", function(context, env)
        context.settings.sctStyle, context.settings.performanceMode = style, performance
        context.settings.sctDirectDamage, context.settings.sctPeriodicDamage = true, true
        context.settings.sctPetDamage = true
        context.spell, context.spellId = "Consecration", 26573
        env.T.ParseNameplateCombatEvent = function(_, message)
            return {
                kind = "damage",
                damageType = context.periodic and "periodic" or "spell",
                spell = context.spell,
                spellId = context.spellId,
                critical = context.critical,
                sourceIsPet = context.pet,
                sourceName = "Player",
                targetName = "Enemy",
                amount = tonumber(message),
            }
        end
    end)
end

Test("area defaults, explicit saved off, profiles and discard share display normalization", function()
    local context = H.New()
    context:Load("core/display.lua", "Display")
    local display = context.env.DFRL.display
    assert(display.Get("sctAreaDamage") == true, "missing area preference did not default on")
    assert(display.Copy({ sctAreaDamage = "false" }).sctAreaDamage == true, "invalid area string defaulted off")
    assert(display.Copy({ sctAreaDamage = 0 }).sctAreaDamage == true, "invalid area number defaulted off")
    context.env.SurvivorsDragonUiDisplay = { sctAreaDamage = false }
    assert(display.Get("sctAreaDamage") == false, "explicit saved off was lost")
    display.BeginEdit()
    display.Set("sctAreaDamage", true)
    assert(display.Get("sctAreaDamage") and not context.env.SurvivorsDragonUiDisplay.sctAreaDamage)
    display.FinishEdit(false)
    assert(not display.Get("sctAreaDamage"), "Cancel lost the saved off choice")
    display.BeginEdit()
    display.Load({})
    assert(display.Get("sctAreaDamage"), "an older profile did not default area damage on")
    display.FinishEdit(false)
    assert(not display.Get("sctAreaDamage"), "profile discard lost the saved choice")
    display.BeginEdit()
    display.Set("sctAreaDamage", true)
    display.FinishEdit(true)
    assert(context.env.SurvivorsDragonUiDisplay.sctAreaDamage == true, "Confirm did not save area on")
    display.BeginEdit()
    display.Load({ sctAreaDamage = false })
    display.FinishEdit(true)
    assert(not display.Get("sctAreaDamage"), "an explicit profile choice was lost")
    display.Reset()
    assert(display.Get("sctAreaDamage"), "display reset did not restore area on")
end)

Test("native spell data distinguishes area geometry, cones and pulses from target counts", function()
    local context = H.New()
    context:Load("modules/nameplates/spell_data.lua")
    local data = context.env.DFRL.tools.SctSpellData
    assert(data.byId[26573] == true and data.byName.Consecration == true)
    assert(data.byId[120] == true and data.byName["Mind Flay"] == true, "cone casts were lost")
    assert(data.byId[8187] == true and data.byId[8190] == true, "area totem pulse identity was lost")
    assert(data.byId[3606] == false and data.byId[3599] == false, "targeted totem became an area")
    assert(data.byId[133] == false and data.byId[421] == false, "projectiles or chain hops became area damage")
    assert(
        data.byName.Stormstrike == false and data.byName["Rockbiter Weapon"] == false,
        "new native records were omitted"
    )
end)

for _, style in ipairs({ "enemy", "diablo", "msbt" }) do
    for _, performance in ipairs({ false, true }) do
        Test(
            style .. " area filtering preserves crit/category gates and live pool retirement " .. tostring(performance),
            function()
                local context = Scene(style, performance)
                context.critical = true
                context:SetSetting("sctNormalHits", false)
                context:SetSetting("sctCriticalHits", true)
                context:SetSetting("sctPeriodicDamage", false)
                context:Hit(111)
                context.spell, context.spellId = "Fireball", 133
                context:Hit(222)
                context:Tick(0.4)
                local labels = context:Labels()
                assert(#labels == 2, "default-on area damage changed existing critical presentation")
                local direct = labels[2]
                assert(direct:GetText() == "222")
                local allocated = #context.objects
                context:SetSetting("sctAreaDamage", false)
                assert(
                    #context:Labels() == 1 and context:Labels()[1] == direct,
                    "area preview lost direct critical damage"
                )
                context.spell, context.spellId = "Consecration", 26573
                context:Hit(333)
                context.periodic = true
                context:Hit(444)
                context.spell, context.spellId = "Fireball", 133
                context.periodic, context.critical = false, false
                context:Hit(555)
                context:Tick(0.4)
                assert(
                    #context:Labels() == 1 and direct:GetText() == "222",
                    "a disabled area/category/result bypassed filtering"
                )
                context:SetSetting("sctAreaDamage", true)
                context:Tick(0)
                assert(#context:Labels() == 1 and context:Labels()[1] == direct, "area restoration replayed old hits")
                assert(#context.objects == allocated, "filter previews allocated replacement drawing objects")
                context:Tick(2)
                assert(#context:Labels() == 0, "area preview extended a direct hit's lifetime")
                context:Event(context.controller, "PLAYER_LEAVING_WORLD")
            end
        )

        Test(
            style .. " area choice applies to queued hits and keeps mixed grouping separate " .. tostring(performance),
            function()
                local context = Scene(style, performance)
                -- Hold the received caption/attack constant while native IDs select
                -- different data. The area identity must still keep labels separate.
                context.spell = "Shared caption"
                context:Hit(20)
                context.spellId = 133
                context:Hit(100)
                context:SetSetting("sctAreaDamage", false)
                context:Tick(0.4)
                local labels = context:Labels()
                assert(
                    #labels == 1 and labels[1]:GetText() == "100",
                    "queued area damage entered a direct label or sum"
                )
                context:Tick(2)
                context.spell, context.spellId = "Consecration", 26573
                context:Hit(30)
                context:SetSetting("sctAreaDamage", true)
                context:Tick(0.4)
                assert(
                    #context:Labels() == 1 and context:Labels()[1]:GetText() == "30",
                    "queued area did not use restored current choice"
                )
            end
        )
    end
end

Test("exact legacy aliases retain conflicts and unknown native IDs do not borrow spell names", function()
    local context = Scene("enemy", false)
    context:SetSetting("sctAreaDamage", false)
    context.env.DFRL.locale.code = "de"
    context.env.DFRL.locale.data.de = {
        spellNames = {
            Boden = { "Consecration" },
            Conflict = { "Consecration", "Fireball" },
        },
    }
    context.spell, context.spellId = "Boden", nil
    context:Hit(111)
    context.spell = "Conflict"
    context:Hit(222)
    context.spell, context.spellId = "Consecration", 999999
    context:Hit(333)
    context.spellId = 133
    context:Hit(444)
    context:Tick(0.2)
    local values = {}
    for _, label in ipairs(context:Labels()) do
        values[label:GetText()] = true
    end
    assert(
        #context:Labels() == 3 and not values["111"] and values["222"] and values["333"] and values["444"],
        "area resolution ignored exact metadata conflicts or replaced a received native ID"
    )
end)

print("PASS " .. passed .. " SCT area contracts")
