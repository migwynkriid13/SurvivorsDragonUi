-- CI only: shared production rules over explicit fake native boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "shared-rule fixtures require CI Lua 5.1")
local passed = 0
local function Test(name, callback)
    local ok, failure = pcall(callback)
    assert(ok, name .. ": " .. tostring(failure))
    passed = passed + 1
    print("PASS " .. name)
end

Test("HUD restoration retains capture until native readback accepts the original preference", function()
    local c = H.New()
    c:Load("core/hud.lua")
    local owner = c.env.T.NewHudOwner("levels")
    assert(owner.Acquire() and not c.nativeShown and owner.IsCaptured())
    local write = c.env.AZS_SetHudShown
    c.env.AZS_SetHudShown = function() end
    assert(not owner.Release(true) and owner.IsCaptured(), "a no-op setter discarded the restore target")
    c.env.AZS_SetHudShown = write
    assert(owner.Release(true) and c.nativeShown and not owner.IsCaptured(), "restoration did not retry")
    c.nativeShown = false
    assert(owner.Acquire() and owner.Release(true) and not c.nativeShown, "originally hidden HUD was enabled")
end)

Test("HUD explicit opt-out stays deferred and synchronous callbacks cannot replace its preference", function()
    local c = H.New()
    c:Load("core/hud.lua")
    local owner = c.env.T.NewHudOwner("clock", "hudClock")
    c.nativeShown = false
    local write = c.env.AZS_SetHudShown
    c.env.AZS_SetHudShown = function(part, shown)
        assert(owner.IsApplying(), "native writes lost their callback guard")
        write(part, shown)
        assert(not owner.Observe("hudClock"), "a synchronous callback replaced our restore target")
    end
    owner.SetRestorePreference(true)
    assert(not c.nativeShown and owner.IsCaptured(), "requesting an opt-out wrote native state early")
    assert(owner.Release(true) and c.nativeShown and not owner.IsApplying())
    assert(owner.Acquire())
    c.nativeShown = true
    assert(owner.Observe("HUDCLOCK"))
    assert(owner.Acquire() and owner.Release() and c.nativeShown, "latest external preference was lost")
    c.env.AZS_SetHudShown = function() error("unavailable setter") end
    owner.SetRestorePreference(false)
    assert(not owner.Release(true) and owner.IsCaptured() and not owner.IsApplying())
    c.env.AZS_SetHudShown = write
    assert(owner.Release(true) and not c.nativeShown)
end)

Test("HUD owners share native flag encodings and reject unknown parts", function()
    local c = H.New()
    c:Load("core/hud.lua")
    local owner = c.env.T.NewHudOwner("flag")
    for _, shown in ipairs({ true, 1, "1" }) do
        c.nativeShown = shown
        assert(owner.Acquire() and c.nativeShown == false)
        assert(owner.Release(true) and c.nativeShown == true)
    end
    for _, hidden in ipairs({ false, 0, "0" }) do
        c.nativeShown = hidden
        assert(owner.Acquire() and owner.Release(true) and c.nativeShown == hidden)
    end
    c.nativeShown = nil
    assert(not owner.Acquire() and not owner.IsCaptured())
    assert(not owner.Observe("hudFlag"), "an owner without a CVar accepted an observation")
end)

Test("run HUD adapters retain native-on opt-out and captured-preference cleanup", function()
    local c = H.New()
    local env = c.env
    local shown = { clock = false, bosses = false, tally = true }
    env.AZS_IsHudShown = function(part) return shown[part] end
    env.AZS_SetHudShown = function(part, value) shown[part] = value end
    c:Load("core/hud.lua")
    local chunk = assert(loadfile(assert(arg[1], "missing extracted run HUD source")))
    setfenv(chunk, env)
    local run = chunk()
    env.ReleaseClock = function() run.Restore("clock") end
    env.ClearRows = function() end
    c.settings.customRunTimer, c.settings.customBossBars = true, true
    run.Sync()
    assert(run.TakeOver("clock") and run.TakeOver("bosses") and run.TakeOver("tally"))
    assert(not shown.clock and not shown.bosses and not shown.tally)
    c.settings.customRunTimer, c.settings.customBossBars = false, false
    run.Sync()
    assert(shown.clock and shown.bosses, "explicit opt-out restored the original hidden state")
    run.Restore("tally")
    assert(shown.tally, "tally cleanup lost its captured preference")
    c.settings.customRunTimer, c.settings.customBossBars = true, true
    run.Sync()
    assert(run.TakeOver("clock") and run.TakeOver("bosses"))
    run.Restore("clock")
    run.Restore("bosses")
    assert(shown.clock and shown.bosses, "ordinary cleanup lost the recaptured preferences")
end)

Test("encounter entry validation rejects duplicates atomically and reuses scratch IDs", function()
    local c = H.New()
    local tools, seen = c.env.T, {}
    local first = { id = 1, kind = "guardian", name = "Guardian", hp = 10, hpm = 20 }
    local second = { id = 2, kind = "elite", name = "Guardian", hp = 0, hpm = 20 }
    local rows = { first, second }
    assert(tools.EncounterRosterSize(rows, 0) == 2 and tools.ValidateEncounterEntries(rows, seen))
    second.id = 1
    assert(not tools.ValidateEncounterEntries(rows, seen), "duplicate positive IDs were accepted")
    second.id = 2
    assert(tools.ValidateEncounterEntries(rows, seen), "a rejected publication poisoned the next receipt")
    for _, invalid in ipairs({ "unknown", false, 3 }) do
        second.kind = invalid
        assert(not tools.ValidateEncounterEntries(rows, seen))
    end
    second.kind, second.hp = "final", 21
    assert(not tools.ValidateEncounterEntries(rows, seen))
    second.hp, second.hpm = 0, 0
    assert(not tools.ValidateEncounterEntries(rows, seen))
    second.hpm = 20
    assert(tools.ValidateEncounterEntries(rows, seen))
    assert(tools.EncounterRosterSize({}, 0) == 0, "valid empty rosters were rejected")
    assert(tools.EncounterRosterSize(rows, -1) == nil and tools.EncounterRosterSize(rows, 0 / 0) == nil)
    assert(tools.EncounterRosterSize(nil, 1) == nil)
    local oversized = {}
    for index = 1, 41 do
        oversized[index] = first
    end
    assert(tools.EncounterRosterSize(oversized, 1) == nil)
end)

Test("display copies derive membership from defaults and preserve normalization and drafts", function()
    local c = H.New()
    local env = c.env
    env.DFRL.tallyStyleDefault, env.DFRL.tallyStyleById = "silver", { silver = true }
    env.SurvivorsDragonUiRunFont = { showText = false }
    c:Load("core/display.lua", "Display")
    local display = env.DFRL.display
    local copy = display.Copy({
        meterEnabled = true,
        cooldownNumbers = false,
        meterRows = 100,
        nameplateFontSize = 10.6,
        sctScale = 0 / 0,
        lootMode = "game",
        tallyStyle = "invalid",
        unknown = true,
    })
    assert(copy.meterEnabled and copy.cooldownNumbers == false and copy.meterRows == 10)
    assert(copy.nameplateFontSize == 11 and copy.sctScale == 1 and copy.lootMode == "game")
    assert(copy.tallyStyle == "silver" and copy.unknown == nil)
    assert(copy.runTextRegular == false and copy.runTextEndless == false, "legacy visibility fallback changed")
    display.BeginEdit()
    display.Load(copy)
    local snapshot = display.Snapshot()
    snapshot.meterEnabled = false
    assert(display.Get("meterEnabled"), "a snapshot aliased the active draft")
    display.FinishEdit(false)
    assert(not display.Get("meterEnabled") and env.SurvivorsDragonUiDisplay == nil)
    display.BeginEdit()
    display.Load(copy)
    display.FinishEdit(true)
    copy.meterEnabled = false
    assert(display.Get("meterEnabled") and env.SurvivorsDragonUiDisplay.cooldownNumbers == false)
end)

local function Circular(size, minimumParts)
    local c = H.New()
    c:Load("core/widgets.lua")
    local parent = c.env.CreateFrame("Frame", nil, c.env.UIParent)
    function parent:GetEffectiveScale()
        c.reads.scale = (c.reads.scale or 0) + 1
        return 1
    end
    local portrait = parent:CreateTexture("SharedCirclePortrait", "ARTWORK")
    portrait:SetWidth(size)
    portrait:SetHeight(size)
    portrait:Hide()
    local image = c.env.T.NewCircularIcon(portrait, size, minimumParts)
    function c:Parts()
        local parts = {}
        for _, object in ipairs(self.objects) do
            if object.kind == "Texture" and object ~= portrait then table.insert(parts, object) end
        end
        return parts
    end
    return c, image, portrait
end

Test("circular native binding accepts stripped paths and skips unchanged work", function()
    local c, image, portrait = Circular(34)
    c.env.SetPortraitToTexture = function(name)
        c.reads.portrait = (c.reads.portrait or 0) + 1
        c.env[name]:SetTexture("Interface\\Icons\\Test")
    end
    assert(image.Bind("Interface\\Icons\\Test.blp") and portrait:IsShown() and #c:Parts() == 0)
    c:ResetCounts()
    assert(image.Bind("Interface\\Icons\\Test.blp", 2))
    c:NoPresentationWrites()
    assert(not c.reads.portrait and not c.reads.scale)
    image.Clear()
    assert(not portrait:IsShown() and portrait:GetTexture() == nil)
    assert(image.Bind("Interface\\Icons\\Test.blp") and c.reads.portrait == 1)
end)

Test("circular fallback retries texture failures and reuses its pixel-strip pool", function()
    for _, geometry in ipairs({ { 34, 2, 32 }, { 26, 4, 24 } }) do
        local c, image, portrait = Circular(geometry[1], geometry[2])
        c.env.SetPortraitToTexture = function() c.reads.portrait = (c.reads.portrait or 0) + 1 end
        local icon = "Interface\\Icons\\Fallback.blp"
        c.failTexture = icon
        assert(not image.Bind(icon) and not portrait:IsShown())
        local parts = c:Parts()
        assert(#parts == geometry[3], "fallback clipping density changed")
        for _, part in ipairs(parts) do
            assert(not part:IsShown(), "a partial fallback was shown")
        end
        c.failTexture = nil
        assert(image.Bind(icon) and c.reads.portrait == 1, "native failure was retried or fallback did not recover")
        local allocated = #c.objects
        c:ResetCounts()
        assert(image.Bind(icon))
        c:NoPresentationWrites()
        assert(#c.objects == allocated and not c.reads.portrait)
        image.Clear()
        for _, part in ipairs(parts) do
            assert(not part:IsShown() and part:GetTexture() == nil)
        end
        assert(image.Bind(icon) and #c.objects == allocated and c.reads.portrait == 1)
        assert(image.Bind(icon, 0 / 0) == false, "invalid fallback scale was accepted")
    end
end)

print("PASS shared rule contracts: " .. passed)
