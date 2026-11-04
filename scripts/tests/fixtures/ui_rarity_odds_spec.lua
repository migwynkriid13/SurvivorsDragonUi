-- CI only: drive the production panel through mocked native feeds and Layout.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "rarity odds fixtures require CI Lua 5.1")

for _, performance in ipairs({ false, true }) do
    local context = H.New()
    local env, phase, hidden = context.env, "playing", false
    local layout = env.DFRL.layout
    local anchor, resize, placed
    local create, register = env.CreateFrame, layout.Register
    env.CreateFrame = function(kind, name, parent)
        local frame = create(kind, name, parent)
        if name == "SurvivorsDragonUiRarityOdds" then
            local setPoint, createFontString = frame.SetPoint, frame.CreateFontString
            function frame:SetScale(scale) self.scale = scale end
            function frame:SetPoint(point, relative, target, x, y)
                setPoint(self, point, relative, target, x, y)
                self.point = { point, relative, target, x, y }
            end
            function frame:CreateFontString(...)
                local label = createFontString(self, ...)
                function label:GetStringWidth()
                    context.reads.glyphs = (context.reads.glyphs or 0) + 1
                    local _, size = self:GetFont()
                    local text = self:GetText()
                    return (text == "Legendary" and 64 or string.len(text) * 5.5) * size / 10
                end
                return label
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
    env.AZS_SetOnTopOfScreens = function() context.writes.top = (context.writes.top or 0) + 1 end
    env.AZS_IsOnTopOfScreens = function() return true end
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
    assert(#text == 20 and text[1] == "Rarity odds" and text[5] == "Spells / cache", "compact table changed")
    assert(text[4] == "Legendary" and regions[4]:GetStringWidth() <= regions[4]:GetWidth())
    assert(regions[4]:GetWidth() > regions[3]:GetWidth(), "the longest rarity heading did not get more room")
    for _, index in ipairs({ 5, 9, 13, 17 }) do
        assert(regions[index]:GetStringWidth() <= regions[index]:GetWidth(), "a reward label cannot fit on one line")
    end
    assert(text[13] == "Cache amulets" and text[17] == "Guardian amulets")
    local _, titleSize, titleFlags = regions[1]:GetFont()
    local r, g, b = regions[1]:GetTextColor()
    assert(env.T.NearlyEqual(titleSize * panel.scale, 10.4) and titleFlags == "", "meter title font changed")
    assert(r == 1 and g == 0.82 and b == 0, "meter title color changed")
    assert(text[6] == "14.0%" and text[7] == "7.3%" and text[8] == "2.4%")
    assert(text[10] == "16.7%" and text[14] == "18.9%" and text[18] == "20.5%")
    assert(
        regions[6]:GetWidth() >= 39 and regions[7]:GetWidth() >= 39 and regions[8]:GetWidth() >= 60,
        "compact odds columns lost their percentage width"
    )
    local art = {}
    for _, object in ipairs(context.objects) do
        if object.kind == "Texture" and object.parent == panel then table.insert(art, object:GetTexture()) end
    end
    assert(#art == 3 and string.find(art[1], "guardians\\Header.blp", 1, true))
    assert(string.find(art[2], "guardians\\Header_2.blp", 1, true), "the second header strip was not reused")
    assert(string.find(art[3], "rarity\\BonusObjectiveStar.blp", 1, true), "the header lost its transparent star")
    assert(panel:GetWidth() == 240 and panel.scale == 0.85 and panel.point[1] == "RIGHT")
    assert(panel:GetHeight() == 127, "compact rows reserved extra vertical space")
    assert(env.T.NearlyEqual(panel.point[4] * panel.scale, -1.2), "odds were not aligned with the tracker")
    assert(env.T.NearlyEqual(panel.point[5] * panel.scale, 287.3), "odds were not centered in the default gap")
    panel:SetWidth(360)
    resize(panel, 360)
    Tick()
    local _, wideHeadingSize = regions[4]:GetFont()
    assert(wideHeadingSize == 10, "widening did not restore the standard heading size")
    assert(regions[5]:GetWidth() == 148 and regions[6]:GetWidth() == 59 and regions[6]:GetText() == "14.0%")
    panel:SetWidth(240)
    resize(panel, 240)
    Tick()
    assert(regions[5]:GetWidth() == 88 and regions[6]:GetWidth() == 39, "reset did not restore compact columns")
    assert(regions[4]:GetStringWidth() <= regions[4]:GetWidth(), "shrinking clipped the longest heading")
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

    local cursorX, cursorY, focus, editing = 120, 490, env.UIParent, false
    local tip = { opens = 0 }
    env.GameTooltip = tip
    layout.IsEditing = function() return editing end
    env.GetMouseFocus = function() return focus end
    env.GetCursorPosition = function()
        context.reads.cursor = (context.reads.cursor or 0) + 1
        return cursorX * panel.scale, cursorY * panel.scale
    end
    function panel:GetLeft() return 100 end
    function panel:GetTop() return 500 end
    function panel:GetEffectiveScale() return self.scale end
    function tip:IsOwned(owner) return self.owner == owner end
    function tip:IsVisible() return self.visible end
    function tip:SetOwner(owner)
        self.owner, self.lines = owner, {}
        self.opens = self.opens + 1
    end
    function tip:SetText(value) self.title = value end
    function tip:AddLine(value) self.subtitle = value end
    function tip:AddDoubleLine(label, value) self.lines[label] = value end
    function tip:Show() self.visible = true end
    function tip:Hide()
        self.owner, self.visible = nil, false
    end

    Tick()
    assert(tip:IsOwned(panel) and tip.title == "Rarity odds")
    assert(tip.lines["Character luck"] == "20.0%" and tip.lines["Level bonus"] == "+10%")
    assert(tip.lines["Effective luck"] == "30.0%")
    Tick()
    assert(tip.opens == 1, "an unchanged hover rebuilt the tooltip")
    env.AZS_STATS.luck, env.AZS_RUN.lvl = 0.25, 5
    Tick()
    assert(tip.lines["Character luck"] == "25.0%" and tip.lines["Level bonus"] == "+5%")
    env.AZS_STATS.luck, env.AZS_RUN.lvl = 0.2, 10
    cursorY = 440
    Tick()
    assert(tip.title == "Spells / cache jewelry" and tip.subtitle == "Chance per roll")
    assert(tip.lines.Legendary == "1 in 42", "spell odds used rounded percentages")
    cursorY = 415
    Tick()
    assert(tip.title == "Guardian jewelry" and tip.lines.Legendary == "1 in 25", "lost the guardian bonus on hover")
    cursorY = 374
    Tick()
    assert(not tip:IsVisible(), "bottom padding counted as a reward row")
    cursorY = 415
    Tick()
    editing = true
    Tick()
    assert(not tip:IsVisible(), "layout editing retained a gameplay tooltip")
    editing, focus = false, reader
    Tick()
    assert(not tip:IsVisible(), "an overlapping frame exposed the odds tooltip")
    tip:SetOwner(reader)
    tip:Show()
    focus = env.UIParent
    Tick()
    assert(tip:IsOwned(reader), "stole another frame's tooltip")
    tip:Hide()
    Tick()
    assert(tip:IsOwned(panel))
    phase = "choosing"
    Tick()
    assert(not panel:IsShown() and not tip:IsVisible(), "upgrade cards retained the odds or their tooltip")
    phase = "playing"
    Tick()
    assert(tip:IsOwned(panel))
    hidden = true
    visibility(false)
    assert(not tip:IsVisible(), "Layout hiding retained the tooltip")
    context:ResetCounts()
    Tick()
    assert(not context.reads.cursor, "Layout hiding sampled the cursor")
    hidden, cursorX = false, 0
    visibility(true)
    Tick()

    context:ResetCounts()
    Tick()
    context:NoPresentationWrites()
    assert(not context.reads.glyphs, "unchanged odds remeasured captions")
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
    assert(panel:IsShown(), "pause hid valid odds")
    phase = "dead"
    Tick()
    assert(not panel:IsShown(), "death retained the panel")
    phase = "playing"
    Tick()
    assert(panel:IsShown(), "same-run revival needed a new stats publication")
    phase = "choosing"
    Tick()
    assert(not panel:IsShown() and not context.writes.top, "odds stayed over reward cards")
    env.AZS_STATS.luck = 0.5
    context:ResetCounts()
    Tick()
    context:NoPresentationWrites()
    assert(not context.reads.cursor and not context.writes.top and Captions()[6] == capped, "choice kept painting odds")
    display.BeginEdit()
    display.Set("rarityOdds", false)
    Tick()
    assert(not panel:IsShown() and not reader:GetScript("OnUpdate"))
    display.FinishEdit(false)
    Tick()
    assert(not panel:IsShown(), "Cancel showed the panel during card selection")
    hidden = true
    visibility(false)
    context:ResetCounts()
    Tick()
    assert(not context.reads.phase and not panel:IsShown(), "Layout hiding retained work")
    hidden = false
    visibility(true)
    Tick()
    assert(not panel:IsShown(), "Layout recovery showed odds during card selection")

    phase = "playing"
    Tick()
    assert(panel:IsShown() and Captions()[6] ~= capped, "closing cards did not refresh current odds")
    env.AZS_RUN, env.AZS_RUN_UPDATED, env.AZS_ZONE_UPDATED = { lvl = 1, t = 0 }, 11, 11
    Tick()
    assert(not panel:IsShown(), "new run reused retired Luck")
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

print("PASS rarity odds inputs, reward modifiers, caps, previews, card suppression and run retirement")
