-- CI only: drive the production panel through mocked native feeds and Layout.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "rarity odds fixtures require CI Lua 5.1")

for _, performance in ipairs({ false, true }) do
    local context = H.New()
    local env, phase, top, hidden, failReadback = context.env, "playing", false, false, false
    local layout = env.DFRL.layout
    local anchor, resize, placed
    local create, register = env.CreateFrame, layout.Register
    env.CreateFrame = function(kind, name, parent)
        local frame = create(kind, name, parent)
        if name == "SurvivorsDragonUiRarityOdds" then
            local setPoint = frame.SetPoint
            function frame:SetScale(scale) self.scale = scale end
            function frame:SetPoint(point, relative, target, x, y)
                setPoint(self, point, relative, target, x, y)
                self.point = { point, relative, target, x, y }
            end
        end
        return frame
    end
    env.UIParent:SetHeight(768)
    env.DFRL_GuardianTracker = {
        GetHeight = function() return 172 end,
        GetWidth = function() return 240 end,
        GetScale = function() return 0.85 end,
    }
    env.DFRL.guardianTrackerDefaults = { top = 252, right = -1.2 }
    env.DFRL.damageMeterDefaults = { width = 255, scale = 0.8, header = 32, row = 32, footer = 32 }
    layout.Register = function(key, frame, default, options)
        assert(options.refreshDefault, "viewport changes must recompute the default gap")
        assert(options.edgeWidth and options.minWidth == 240 and options.maxWidth == 960)
        anchor = function() default(frame) end
        resize = options.onResize
        register(key, frame, default)
    end
    layout.IsPlaced = function() return placed end
    layout.Place = function(key)
        assert(key == "rarityOdds")
        anchor()
    end
    layout.IsHidden = function() return hidden end
    local listen, visibility = layout.ListenVisibility
    layout.ListenVisibility = function(key, callback)
        assert(key == "rarityOdds")
        visibility = callback
        listen(key, callback)
    end
    env.AZS_GetPhase = function()
        context.reads.phase = (context.reads.phase or 0) + 1
        return phase
    end
    env.AZS_SetOnTopOfScreens = function(frame, value)
        assert(frame == env.SurvivorsDragonUiRarityOdds, "touched a foreign overlay")
        top = value
        context.writes.top = (context.writes.top or 0) + 1
    end
    env.AZS_IsOnTopOfScreens = function()
        if failReadback then error("injected overlay readback failure") end
        return top
    end
    env.AZS_RUN = { lvl = 10, t = 8 }
    env.AZS_STATS = { luck = 0.2 }
    env.AZS_RUN_UPDATED, env.AZS_ZONE_UPDATED = 10, 1
    context:Load("core/display.lua", "Display")
    local display = env.DFRL.display
    context:Load("modules/ui/rarity_odds.lua", "RarityOdds")
    local reader = context:Controller("PLAYER_ENTERING_WORLD")
    local panel = assert(env.SurvivorsDragonUiRarityOdds)
    local function Tick() context:Call(reader, "OnUpdate", 0.25) end
    local function Captions()
        local text, regions = {}, {}
        for _, object in ipairs(context.objects) do
            if object.kind == "FontString" and object.parent == panel then
                table.insert(text, object:GetText())
                table.insert(regions, object)
            end
        end
        return text, regions
    end

    Tick()
    assert(not context.reads.phase and not panel:IsShown() and #Captions() == 0, "off setting read or drew the panel")
    assert(not display.Copy({ rarityOdds = "true" }).rarityOdds, "invalid odds preference enabled the panel")
    display.BeginEdit()
    display.Set("performanceMode", performance)
    display.Set("rarityOdds", true)
    Tick()
    assert(panel:IsShown() and not env.SurvivorsDragonUiDisplay, "preview did not show or saved too early")
    local text, regions = Captions()
    assert(#text == 20 and text[1] == "Rarity odds" and text[5] == "Spells / cache jewelry", "compact table changed")
    assert(text[13] == "Cache amulets" and text[17] == "Guardian amulets")
    local _, titleSize, titleFlags = regions[1]:GetFont()
    local r, g, b = regions[1]:GetTextColor()
    assert(env.T.NearlyEqual(titleSize * panel.scale, 10.4) and titleFlags == "", "meter title font changed")
    assert(r == 1 and g == 0.82 and b == 0, "meter title color changed")
    assert(text[6] == "14.0%" and text[7] == "7.3%" and text[8] == "2.4%")
    assert(text[10] == "16.7%" and text[14] == "18.9%" and text[18] == "20.5%")
    assert(
        regions[6]:GetWidth() >= 45 and regions[7]:GetWidth() >= 45 and regions[8]:GetWidth() >= 56,
        "compact odds columns lost their percentage width"
    )
    local art = {}
    for _, object in ipairs(context.objects) do
        if object.kind == "Texture" and object.parent == panel then table.insert(art, object:GetTexture()) end
    end
    assert(#art == 4 and string.find(art[1], "guardians\\Header.blp", 1, true))
    assert(string.find(art[2], "guardians\\Header_2.blp", 1, true), "the second header strip was not reused")
    assert(panel:GetWidth() == 240 and panel.scale == 0.85 and panel.point[1] == "RIGHT")
    assert(env.T.NearlyEqual(panel.point[4] * panel.scale, -1.2), "odds were not aligned with the tracker")
    assert(env.T.NearlyEqual(panel.point[5] * panel.scale, 287.3), "odds were not centered in the default gap")
    panel:SetWidth(360)
    resize(panel, 360)
    assert(regions[5]:GetWidth() == 136 and regions[6]:GetWidth() == 65 and regions[6]:GetText() == "14.0%")
    panel:SetWidth(240)
    resize(panel, 240)
    assert(regions[5]:GetWidth() == 76 and regions[6]:GetWidth() == 45, "reset did not restore compact columns")
    env.UIParent:SetHeight(640)
    layout.Place("rarityOdds")
    assert(env.T.NearlyEqual(panel.point[4] * panel.scale, -213.2), "short viewport overlapped the right HUD stack")
    placed = true
    local customPoint = panel.point
    env.DFRL.RefreshRarityOddsPlacement()
    assert(panel.point == customPoint, "a tracker reflow moved confirmed rarity odds geometry")
    placed = false
    env.UIParent:SetHeight(768)
    layout.Place("rarityOdds")
    display.FinishEdit(false)
    assert(not panel:IsShown() and not reader:GetScript("OnUpdate"), "Cancel retained the preview")
    display.BeginEdit()
    display.Set("rarityOdds", true)
    display.FinishEdit(true)
    Tick()
    assert(panel:IsShown() and env.SurvivorsDragonUiDisplay.rarityOdds, "Confirm lost the setting")
    context:ResetCounts()
    Tick()
    context:NoPresentationWrites()
    env.AZS_RUN.lvl = 30
    Tick()
    local capped = Captions()[6]
    env.AZS_RUN.lvl = 60
    context:ResetCounts()
    Tick()
    context:NoPresentationWrites()
    assert(Captions()[6] == capped and capped ~= text[6], "the level bonus did not change and then cap the odds")

    phase = "paused"
    Tick()
    assert(panel:IsShown() and not top, "pause hid valid odds or registered an overlay")
    phase = "dead"
    Tick()
    assert(not panel:IsShown(), "death retained the panel")
    phase = "playing"
    Tick()
    assert(panel:IsShown(), "same-run revival needed a new stats publication")
    phase = "choosing"
    failReadback = true
    Tick()
    assert(not panel:IsShown() and not top, "failed overlay verification left the panel over the cards")
    failReadback = false
    Tick()
    assert(panel:IsShown() and top, "overlay registration did not recover")
    context:ResetCounts()
    Tick()
    assert(not context.writes.top, "unchanged choice rewrote native registration")
    display.BeginEdit()
    display.Set("rarityOddsOverCards", false)
    Tick()
    assert(not panel:IsShown() and not top)
    display.FinishEdit(false)
    Tick()
    assert(panel:IsShown() and top)
    hidden = true
    visibility(false)
    context:ResetCounts()
    Tick()
    assert(not context.reads.phase and not panel:IsShown() and not top, "Layout hiding retained work or ownership")
    hidden = false
    visibility(true)
    Tick()
    assert(panel:IsShown() and top, "Layout recovery lost current odds")

    phase = "playing"
    env.AZS_RUN, env.AZS_RUN_UPDATED, env.AZS_ZONE_UPDATED = { lvl = 1, t = 0 }, 11, 11
    Tick()
    assert(not panel:IsShown() and not top, "new run reused retired Luck or kept the card layer")
    env.AZS_STATS = { luck = 0 / 0 }
    Tick()
    assert(not panel:IsShown(), "malformed Luck displayed odds")
    env.AZS_STATS = { luck = 0 }
    Tick()
    assert(panel:IsShown() and Captions()[6] == "10.1%", "zero Luck failed to recover")
    context:Event(reader, "PLAYER_LEAVING_WORLD")
    context:Event(reader, "PLAYER_ENTERING_WORLD")
    Tick()
    assert(not panel:IsShown(), "world reentry displayed retired data")
    env.AZS_RUN_UPDATED, env.AZS_STATS = 12, { luck = 0.1 }
    Tick()
    assert(panel:IsShown())
    display.Reset()
    assert(not panel:IsShown() and not reader:GetScript("OnUpdate"), "default reset retained the odds panel")
end

print("PASS rarity odds inputs, reward modifiers, caps, previews, overlay recovery and run retirement")
