-- CI only: the actual SCT controller over explicit native boundaries, no client.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "SCT fixtures require the CI Lua 5.1 interpreter")
local passed = 0
local function Test(name, callback)
    local ok, failure = pcall(callback)
    assert(ok, name .. ": " .. tostring(failure))
    passed = passed + 1
    print("PASS " .. name)
end

local SCT = dofile("scripts/tests/fixtures/ui_sct_helpers.lua")

Test("numeric SCT keeps independent font ownership in both performance modes", function()
    for _, performance in ipairs({ false, true }) do
        local context = SCT(true, function(setup, env)
            setup.settings.performanceMode = performance
            local setFont = env.T.SetFont
            env.T.SetFont = function(object, size, flags, independent)
                assert(independent == true, "numeric SCT joined the Layout font registry")
                return setFont(object, size, flags)
            end
        end)
        context:Hit(1234)
        context:Tick(0.4)
        local label = assert(context:Labels()[1])
        context:SetSetting("uiFont", "arial")
        assert(label:GetFont() == "DEFAULT_TEST", "global choice changed SCT Default")
        context:SetSetting("sctFont", "diablo")
        context:SetSetting("uiFont", "friz")
        assert(label:GetFont() ~= "DEFAULT_TEST", "global choice changed the selected SCT font")
    end
end)

Test("styles migrate legacy choices and share preview, Confirm, profiles and resets", function()
    local context = H.New()
    context:Load("core/display.lua", "Display")
    local display = context.env.DFRL.display
    assert(display.Get("sctStyle") == "enemy", "the default must remain over enemies")
    assert(display.Copy({ sctMSBTStyle = true }).sctStyle == "msbt", "legacy scrolling was lost")
    assert(display.Copy({ sctMSBTStyle = "true" }).sctStyle == "enemy", "invalid legacy style was accepted")
    assert(display.Copy({ sctStyle = true }).sctStyle == "enemy", "invalid enum was accepted")
    assert(
        display.Copy({ sctStyle = "diablo", sctMSBTStyle = true }).sctStyle == "diablo",
        "legacy overrode the new choice"
    )
    for _, style in ipairs({ "msbt", "diablo", "enemy" }) do
        display.BeginEdit()
        display.Set("sctStyle", style)
        assert(display.Get("sctStyle") == style and not context.env.SurvivorsDragonUiDisplay, "preview was saved early")
        display.Set("sctStyle", "invalid")
        assert(display.Get("sctStyle") == style, "invalid edit replaced the preview")
        display.FinishEdit(false)
        assert(display.Get("sctStyle") == "enemy", "Cancel did not restore the default")
        display.BeginEdit()
        display.Set("sctStyle", style)
        display.FinishEdit(true)
        assert(context.env.SurvivorsDragonUiDisplay.sctStyle == style, "Confirm did not save the style")
        display.BeginEdit()
        display.Load({ sctMSBTStyle = true })
        assert(display.Get("sctStyle") == "msbt", "legacy profile did not migrate")
        display.FinishEdit(false)
        assert(display.Get("sctStyle") == style, "profile discard lost the saved style")
        display.Reset()
        assert(display.Get("sctStyle") == "enemy", "reset did not restore over-enemy text")
    end
    context.env.SurvivorsDragonUiDisplay = { sctMSBTStyle = true }
    assert(display.Get("sctStyle") == "msbt", "an installed legacy selection was not migrated")
    display.BeginEdit()
    display.FinishEdit(true)
    assert(context.env.SurvivorsDragonUiDisplay.sctStyle == "msbt", "Confirm lost the migrated style")
    assert(context.env.SurvivorsDragonUiDisplay.sctMSBTStyle == nil, "Confirm kept competing saved style keys")
end)

Test("font choice normalizes, previews, saves, discards, profiles and resets independently of style", function()
    local context = H.New()
    context:Load("core/display.lua", "Display")
    local display = context.env.DFRL.display
    assert(display.Get("sctFont") == "default", "missing font changed existing text")
    for _, value in ipairs({ true, 1, "PT Serif", "invalid" }) do
        assert(display.Copy({ sctFont = value }).sctFont == "default", "invalid saved font was accepted")
    end
    display.BeginEdit()
    display.Set("sctFont", "diablo")
    display.Set("sctFont", "invalid")
    assert(display.Get("sctFont") == "diablo" and not context.env.SurvivorsDragonUiDisplay, "font preview saved early")
    display.FinishEdit(false)
    assert(display.Get("sctFont") == "default", "Cancel did not restore font")
    display.BeginEdit()
    display.Set("sctFont", "diablo")
    display.FinishEdit(true)
    assert(context.env.SurvivorsDragonUiDisplay.sctFont == "diablo", "Confirm lost font")
    display.BeginEdit()
    display.Load({ sctFont = "default", sctStyle = "msbt" })
    assert(display.Get("sctFont") == "default" and display.Get("sctStyle") == "msbt", "profile did not load font")
    display.FinishEdit(false)
    assert(display.Get("sctFont") == "diablo", "profile discard lost saved font")
    display.Reset()
    assert(display.Get("sctFont") == "default", "reset retained custom font")
end)

local DIABLO_FONT = "Interface\\AddOns\\SurvivorsDragonUi\\media\\fonts\\PT_Serif-Web-Regular.ttf"
Test("font previews preserve active numbers and reuse the pool in all styles and performance modes", function()
    for _, style in ipairs({ "enemy", "msbt", "diablo" }) do
        for _, performance in ipairs({ false, true }) do
            local context = SCT(style == "msbt", function(setup)
                setup.settings.sctStyle, setup.settings.performanceMode = style, performance
            end)
            context:Hit(1234)
            context:Tick(0.4)
            local label = assert(context:Labels()[1])
            local holder, value = label.parent.parent, label:GetText()
            local anchor, alpha = holder.anchor, holder:GetAlpha()
            local allocated = #context.objects
            local width = label.GetStringWidth
            label.GetStringWidth = function(self) return width(self) * (self:GetFont() == DIABLO_FONT and 1.2 or 1) end
            local oldWidth = label:GetWidth()
            context:SetSetting("sctFont", "diablo")
            local face, size, flags = label:GetFont()
            assert(face == DIABLO_FONT and size == 18 and flags == "OUTLINE", "selected font/style was not applied")
            assert(label:GetWidth() > oldWidth, "font preview reused stale glyph width")
            assert(context:Labels()[1] == label and label:GetText() == value, "font preview replaced active value")
            assert(holder.anchor == anchor and holder:GetAlpha() == alpha, "font preview moved or restarted text")
            assert(#context.objects == allocated, "font preview allocated another view")
            context:ResetCounts()
            context:Tick(0)
            context:NoPresentationWrites()
            context:Tick(0.4)
            context:SetSetting("sctFont", "default")
            assert(label:GetFont() == "DEFAULT_TEST", "font Cancel did not restore active text")
            context:Tick(2)
            context:SetSetting("sctFont", "diablo")
            context:Hit(1234)
            context:Tick(0.4)
            assert(context:Labels()[1] == label and label:GetFont() == DIABLO_FONT, "pooled text retained an old font")
            assert(#context.objects == allocated, "font choice rebuilt pooled artwork")
        end
    end
end)

Test("native rounded font heights keep PT Serif bound without falling back or retrying", function()
    for _, offset in ipairs({ -0.000001, 0.000001 }) do
        local context = SCT(true)
        context:Hit(1234)
        context:Tick(0.1)
        local label = assert(context:Labels()[1])
        local getFont = label.GetFont
        label.GetFont = function(self)
            local face, size, flags = getFont(self)
            return face, size + offset, flags
        end
        context:SetSetting("sctFont", "diablo")
        local face, size, flags = label:GetFont()
        assert(face == DIABLO_FONT and size ~= 18 and flags == "OUTLINE", "rounded height triggered default fallback")
        context:ResetCounts()
        context:Tick(0.6)
        assert(not context.writes.SetFont, "successful rounded font load kept retrying")
        context:SetSetting("sctFont", "default")
        assert(label:GetFont() == "DEFAULT_TEST", "rounded default font could not be restored")
        context:SetSetting("sctFont", "diablo")
        context:Tick(2)
        context:ResetCounts()
        context:Hit(1234)
        context:Tick(0.1)
        assert(context:Labels()[1] == label and label:GetFont() == DIABLO_FONT, "pooled rounded font lost selection")
        assert(not context.writes.SetFont, "pooled rounded font was rebound")
    end
end)

Test("genuinely different returned font heights still fall back and retry", function()
    local context = SCT(true)
    context:Hit(1234)
    context:Tick(0.1)
    local label = assert(context:Labels()[1])
    local getFont, wrongSize = label.GetFont, true
    label.GetFont = function(self)
        local face, size, flags = getFont(self)
        return face, face == DIABLO_FONT and wrongSize and 17 or size, flags
    end
    context:SetSetting("sctFont", "diablo")
    assert(label:GetFont() == "DEFAULT_TEST", "different font height was accepted")
    wrongSize = false
    context:Tick(0.5)
    assert(label:GetFont() == DIABLO_FONT, "failed height verification was cached as success")
end)

Test("rejected font loads restore the game font, throttle retries and preserve expiry", function()
    local context = SCT(true)
    context:Hit(1234)
    context:Tick(0.1)
    local label = assert(context:Labels()[1])
    local nativeSetFont, reject, attempts = label.SetFont, true, 0
    label.SetFont = function(self, face, size, flags)
        if face == DIABLO_FONT then
            attempts = attempts + 1
            if reject then
                self.font = nil
                return false
            end
        end
        return nativeSetFont(self, face, size, flags)
    end
    context:SetSetting("sctFont", "diablo")
    assert(label:GetFont() == "DEFAULT_TEST" and label:GetText() ~= "", "rejection left an unusable label")
    context:Tick(0.1)
    assert(attempts == 1, "failed font retried every animation sample")
    reject = false
    context:Tick(0.4)
    assert(label:GetFont() == DIABLO_FONT and attempts == 2, "failed font was cached as successful")
    context:Tick(1)
    assert(#context:Labels() == 0, "font retry restarted the label's lifetime")
end)

Test("localized avoidance retains the native font while numeric damage uses PT Serif", function()
    local context = SCT(true, function(setup, env)
        setup.settings.sctFont = "diablo"
        env.DFRL.locale.CombatText = function() return "未命中" end
        env.T.ParseNameplateCombatEvent = function(_, message)
            return { kind = "miss", damageType = "autoattack", targetName = "Enemy", text = message }
        end
    end)
    context:Event(context.controller, "TEST_COMBAT", "Miss")
    context:Tick(0.1)
    local label = assert(context:Labels()[1])
    context:SetSetting("sctShortNumbers", true)
    assert(
        label:GetText() == "未命中" and label:GetFont() == "DEFAULT_TEST",
        "localized feedback lost glyph coverage"
    )
end)

Test("Diablo numbers preserve full amounts, native crit status, icons and filter ownership", function()
    local context = SCT(false, function(setup) setup.settings.sctStyle = "diablo" end)
    assert(context.backing and not context.scrollRoot, "Diablo style lost enemy tracking or allocated a stream owner")
    context:Hit(2500000000)
    context.critical = true
    context:Hit(123456)
    context:Tick(0.2)
    local values = {}
    for _, label in ipairs(context:Labels()) do
        values[label:GetText()] = label
        assert(label.parent.parent.anchor.point == "BOTTOMLEFT", "Diablo text lost enemy coordinates")
    end
    local normal, critical = assert(values["2,500,000,000"]), assert(values["123,456"])
    local r, g, b = normal:GetTextColor()
    assert(r == 0.92 and g == 0.90 and b == 0.82, "large normal damage was classified as a crit")
    r, g, b = critical:GetTextColor()
    assert(r == 1 and g == 0.90 and b == 0.32, "native crit did not use yellow")
    assert(critical.parent.scale > normal.parent.scale, "critical emphasis was lost")
    context:SetSetting("damageIcons", true)
    local icons = 0
    for _, object in ipairs(context.objects) do
        if object.kind == "Texture" and object:IsVisible() then icons = icons + 1 end
    end
    assert(icons == 2, "Diablo style bypassed the shared icon choice")
    context.env.T.GetPlayerClassColor = function() return { 0, 0.44, 0.87 } end
    context:SetSetting("sctClassColors", true)
    r, g, b = critical:GetTextColor()
    assert(r == 1 and g == 0.90 and b == 0.32, "class colors replaced Diablo's native critical palette")
    r, g, b = normal:GetTextColor()
    assert(r == 0.92 and g == 0.90 and b == 0.82, "class colors replaced Diablo's normal palette")
    assert(context.settings.sctClassColors, "Diablo erased the saved class-color choice")
    context:SetSetting("sctClassColors", false)
    r, g, b = critical:GetTextColor()
    assert(r == 1 and g == 0.90 and b == 0.32, "disabling class colors did not restore Diablo critical color")
    context:SetSetting("sctNormalHits", false)
    assert(#context:Labels() == 1 and context:Labels()[1] == critical, "normal filter did not retire the right label")
    context:SetSetting("sctCriticalHits", false)
    assert(#context:Labels() == 0, "critical filter did not retire active Diablo text")
end)

Test("abbreviation shares boolean preview, Confirm, Cancel, profiles and reset", function()
    local context = H.New()
    context:Load("core/display.lua", "Display")
    local display = context.env.DFRL.display
    assert(display.Get("sctShortNumbers") == false, "existing full values changed by default")
    assert(display.Copy({ sctShortNumbers = "true" }).sctShortNumbers == false, "invalid abbreviation was accepted")
    display.BeginEdit()
    display.Set("sctShortNumbers", true)
    assert(display.Get("sctShortNumbers") and not context.env.SurvivorsDragonUiDisplay, "preview saved early")
    display.FinishEdit(false)
    assert(not display.Get("sctShortNumbers"), "Cancel lost full values")
    display.BeginEdit()
    display.Set("sctShortNumbers", true)
    display.FinishEdit(true)
    assert(context.env.SurvivorsDragonUiDisplay.sctShortNumbers, "Confirm lost abbreviation")
    display.BeginEdit()
    display.Load({ sctShortNumbers = false })
    assert(not display.Get("sctShortNumbers"), "profile did not load full values")
    display.FinishEdit(false)
    assert(display.Get("sctShortNumbers"), "profile discard lost saved choice")
    display.Reset()
    assert(not display.Get("sctShortNumbers"), "reset retained abbreviation")
end)

Test("all styles abbreviate shared K M B T tiers without changing original hits", function()
    local cases = {
        { 999, "999" },
        { 1000, "1K" },
        { 1250, "1.2K" },
        { 999999, "999.9K" },
        { 1000000, "1M" },
        { 2500000, "2.5M" },
        { 1000000000, "1B" },
        { 1000000000000, "1T" },
        { 12800000000000, "12.8T" },
    }
    for _, style in ipairs({ "enemy", "msbt", "diablo" }) do
        local originals = {}
        local context = SCT(style == "msbt", function(setup, env)
            setup.settings.sctStyle, setup.settings.sctShortNumbers = style, true
            local parse = env.T.ParseNameplateCombatEvent
            env.T.ParseNameplateCombatEvent = function(...)
                local info = parse(...)
                table.insert(originals, info)
                return info
            end
        end)
        for _, row in ipairs(cases) do
            context:Hit(row[1])
        end
        context:Tick(0.2)
        local labels = context:Labels()
        assert(#labels == #cases, "abbreviation changed original grouping")
        local values = {}
        for _, label in ipairs(labels) do
            values[label:GetText()] = true
        end
        for index, row in ipairs(cases) do
            assert(values[row[2]], "missing compact value " .. row[2])
            assert(originals[index].amount == row[1], "abbreviation mutated a native hit")
        end
    end
end)

Test("abbreviation previews refit active totals without restarting motion, font or expiry", function()
    for _, performance in ipairs({ false, true }) do
        local originals = {}
        local context = SCT(false, function(setup, env)
            setup.settings.sctStyle, setup.settings.sctFont = "diablo", "diablo"
            setup.settings.performanceMode = performance
            local parse = env.T.ParseNameplateCombatEvent
            env.T.ParseNameplateCombatEvent = function(...)
                local info = parse(...)
                table.insert(originals, info)
                return info
            end
        end)
        context:Hit(1500000)
        context:Hit(1500000)
        context:Tick(0.4)
        local label = assert(context:Labels()[1])
        local full, compact = performance and "3,000,000" or "1,500,000", performance and "3M" or "1.5M"
        assert(#context:Labels() == 1 and label:GetText() == full, "original group semantics changed")
        local holder, allocated, width = label.parent.parent, #context.objects, label:GetWidth()
        local anchor, alpha, font = holder.anchor, holder:GetAlpha(), label:GetFont()
        context:SetSetting("sctShortNumbers", true)
        assert(context:Labels()[1] == label and label:GetText() == compact, "active group did not abbreviate")
        assert(label:GetWidth() < width, "abbreviation retained the old glyph width")
        assert(
            holder.anchor == anchor and holder:GetAlpha() == alpha and label:GetFont() == font,
            "preview restarted text"
        )
        assert(
            #context.objects == allocated and originals[1].amount == 1500000 and originals[2].amount == 1500000,
            "abbreviation allocated another view or mutated original hits"
        )
        context:ResetCounts()
        context:Tick(0)
        context:NoPresentationWrites()
        context:SetSetting("sctShortNumbers", false)
        assert(label:GetText() == full and holder.anchor == anchor, "Cancel did not restore the original total")
        context:Tick(1.11)
        assert(#context:Labels() == 0, "formatting restarted expiry")
        context:SetSetting("sctShortNumbers", true)
        context:Hit(2500000000)
        context:Tick(0.4)
        assert(context:Labels()[1] == label and label:GetText() == "2.5B", "pooled text replayed an old total")
    end
end)

Test("class colors remain available outside Diablo style", function()
    for _, scrolling in ipairs({ false, true }) do
        local context = SCT(scrolling, function(setup, env)
            setup.settings.sctClassColors = true
            env.T.GetPlayerClassColor = function() return { 0, 0.44, 0.87 } end
        end)
        context:Hit(1234)
        context:Tick(0.2)
        local r, g, b = context:Labels()[1]:GetTextColor()
        assert(r == 0 and g == 0.44 and b == 0.87, "Diablo palette leaked into another style")
    end
end)

local function CriticalScene(performance)
    return SCT(false, function(setup, env)
        setup.settings.sctStyle, setup.settings.performanceMode = "diablo", performance == true
        setup.settings.sctDirectDamage, setup.settings.sctPeriodicDamage, setup.settings.sctPetDamage = true, true, true
        env.DFRL.locale.code, env.DFRL.locale.data = "en", { en = {} }
        setup.critical, setup.originals, setup.variant = true, {}, {}
        local parse = env.T.ParseNameplateCombatEvent
        env.T.ParseNameplateCombatEvent = function(...)
            local info = parse(...)
            info.spell, info.damageType, info.school = "Strike", "ability", "Physical"
            for key, value in pairs(setup.variant) do
                info[key] = value
            end
            table.insert(setup.originals, info)
            return info
        end
    end)
end
local function CriticalLabel(context, value)
    for _, label in ipairs(context:Labels()) do
        if label:GetText() == value then return label end
    end
    error("missing displayed value " .. value)
end
local function CriticalColor(label, amber)
    local r, g, b = label:GetTextColor()
    assert(r == 1 and g == (amber and 0.62 or 0.90) and b == (amber and 0.18 or 0.32), "unexpected critical highlight")
end

Test("amber uses three earlier criticals and the prior average, never normal amounts", function()
    for _, amount in ipairs({ 1499, 1500 }) do
        local context = CriticalScene()
        for _ = 1, 3 do
            context:Hit(1000)
        end
        context:Tick(0.2)
        CriticalColor(CriticalLabel(context, "1,000"), false)
        context.critical = false
        context:Hit(1000000)
        context.critical = true
        context:Hit(amount)
        context:Tick(0.2)
        CriticalColor(CriticalLabel(context, amount == 1500 and "1,500" or "1,499"), amount == 1500)
        local r, g, b = CriticalLabel(context, "1,000,000"):GetTextColor()
        assert(r == 0.92 and g == 0.90 and b == 0.82, "large normal hit became an amber critical")
        assert(
            context.originals[5].amount == amount and context.originals[5].critical == true,
            "native hit was changed"
        )
    end
    local warmup = CriticalScene()
    warmup:Hit(1000)
    warmup:Hit(1000)
    warmup:Hit(1500)
    warmup:Tick(0.2)
    CriticalColor(CriticalLabel(warmup, "1,500"), false)
end)

Test("critical baselines remain separate for native attack/source/pet/type/school identity", function()
    for _, variant in ipairs({
        { spell = "Other Strike" },
        { sourceName = "Other Player" },
        { sourceIsPet = true },
        { damageType = "periodic" },
        { school = "Fire" },
    }) do
        local context = CriticalScene()
        for _ = 1, 3 do
            context:Hit(1000)
        end
        context:Tick(0.2)
        context.variant = variant
        context:Hit(1500)
        context:Tick(0.2)
        CriticalColor(CriticalLabel(context, "1,500"), false)
    end
end)

Test("summed totals cannot create amber but qualifying original members can", function()
    local ordinary = CriticalScene(true)
    for _ = 1, 8 do
        ordinary:Hit(1000)
    end
    ordinary:Tick(0.4)
    CriticalColor(CriticalLabel(ordinary, "8,000"), false)
    ordinary:Hit(1500)
    ordinary:Tick(0.4)
    local amber = CriticalLabel(ordinary, "1,500")
    CriticalColor(amber, true)
    ordinary:Hit(100000)
    ordinary:Tick(0.2)
    ordinary:SetSetting("sctShortNumbers", true)
    assert(amber:GetText() == "1.5K", "active amber number did not abbreviate")
    CriticalColor(amber, true)
    for index = 1, 8 do
        assert(ordinary.originals[index].amount == 1000, "summing rewrote a baseline input")
    end
    local mixed = CriticalScene(true)
    for _ = 1, 3 do
        mixed:Hit(1000)
    end
    mixed:Hit(1500)
    mixed:Tick(0.4)
    CriticalColor(CriticalLabel(mixed, "4,500"), true)
    assert(mixed.originals[1].amount == 1000 and mixed.originals[4].amount == 1500, "highlight rewrote group members")
end)

Test("critical history expires and resets on clock regression, style and world changes", function()
    local recent = CriticalScene()
    recent.now = 0
    for _ = 1, 3 do
        recent:Hit(1000)
    end
    recent:Tick(0.2)
    recent.now = 9.7
    recent:Hit(1500)
    recent:Tick(0.2)
    CriticalColor(CriticalLabel(recent, "1,500"), true)
    recent.now = 10
    recent:Hit(2000)
    recent:Tick(0.2)
    CriticalColor(CriticalLabel(recent, "2,000"), false)
    for _, boundary in ipairs({ "clock", "style", "world", "mode", "zone" }) do
        local context = CriticalScene()
        context.now = 5
        for _ = 1, 3 do
            context:Hit(1000)
        end
        context:Tick(0.2)
        if boundary == "clock" then
            context.now = 4
        elseif boundary == "style" then
            context:SetSetting("sctStyle", "enemy")
            context:SetSetting("sctStyle", "diablo")
        elseif boundary == "world" then
            context:Event(context.controller, "PLAYER_LEAVING_WORLD")
            context:Event(context.controller, "PLAYER_ENTERING_WORLD")
        elseif boundary == "zone" then
            context:Event(context.controller, "CHAT_MSG_ADDON", "AZSZONE")
        else
            context.env.DFRL.sct.BeginEdit()
            context.env.DFRL.sct.SetMode("off")
            context.env.DFRL.sct.SetMode("on")
            context.env.DFRL.sct.FinishEdit(false)
        end
        context:Hit(1500)
        context:Tick(0.2)
        CriticalColor(CriticalLabel(context, "1,500"), false)
    end
end)

Test("critical history evicts old identities without carrying their warmup into a reused row", function()
    local context = CriticalScene()
    for _ = 1, 3 do
        context:Hit(1000)
    end
    context:Tick(0.2)
    for index = 1, 64 do
        context.variant = { sourceName = "Source " .. index }
        context:Hit(1000)
        context:Tick(0.001)
    end
    context.variant = {}
    context:Hit(1500)
    context:Tick(0.2)
    CriticalColor(CriticalLabel(context, "1,500"), false)
end)

Test("Performance Mode preserves the critical baseline and non-Diablo styles keep their colors", function()
    local context = CriticalScene()
    for _ = 1, 3 do
        context:Hit(1000)
    end
    context:Tick(0.2)
    context:SetSetting("performanceMode", true)
    context:Hit(1500)
    context:Tick(0.4)
    CriticalColor(CriticalLabel(context, "1,500"), true)
    for _, style in ipairs({ "enemy", "msbt" }) do
        context:SetSetting("sctStyle", style)
        for _ = 1, 3 do
            context:Hit(1000)
        end
        context:Hit(1500)
        context:Tick(0.4)
        local r, g, b = context:Labels()[1]:GetTextColor()
        assert(r == 1 and g == 0.45 and b == 0.10, "cosmetic amber rule leaked into another style")
    end
end)

Test("Diablo motion bursts, settles, fades and retires on its own deadline", function()
    local context = SCT(false, function(setup) setup.settings.sctStyle = "diablo" end)
    context.critical = true
    context:Hit(111)
    context:Tick(0.2)
    local label = assert(context:Labels()[1])
    local holder, visual = label.parent.parent, label.parent
    local x, scale = holder.anchor.x, visual.scale
    context:Tick(0.06)
    assert(math.abs(holder.anchor.x - x) > 5 and visual.scale > scale, "missing compact launch and impact pop")
    context:Tick(0.15)
    local settledX, settledY = holder.anchor.x, holder.anchor.y
    context:Tick(0.4)
    assert(math.abs(holder.anchor.x - settledX) < 3, "settled text kept flying sideways")
    assert(holder.anchor.y > settledY and holder.anchor.y - settledY < 8, "settled text fell or scrolled too far")
    assert(holder:GetAlpha() == 1, "Diablo text faded before its readable hold")
    context:ResetCounts()
    context:Tick(0)
    context:NoPresentationWrites()
    assert((context.writes.SetScale or 0) == 0, "settled pop kept writing scale")
    context:Tick(0.3)
    assert(holder:GetAlpha() > 0 and holder:GetAlpha() < 1, "missing late fade")
    context:Tick(0.191)
    assert(#context:Labels() == 0 and label:GetText() == "", "Diablo text exceeded its 1.1-second lifetime")
    context:ResetCounts()
    context:Tick(0.2)
    context:NoPresentationWrites()
end)

Test("Diablo Performance Mode sums original hits and preserves active motion on transitions", function()
    local context = SCT(false, function(setup)
        setup.settings.sctStyle, setup.settings.performanceMode = "diablo", true
    end)
    context:Hit(1000)
    context:Tick(0.1)
    context:Hit(2000)
    context:Tick(0.201)
    local label = assert(context:Labels()[1])
    assert(#context:Labels() == 1 and label:GetText() == "3,000", "Diablo bypassed 300 ms damage summing")
    local holder = label.parent.parent
    local x = holder.anchor.x
    context:Tick(0.12)
    assert(holder.anchor.x ~= x, "Performance Mode replaced Diablo animation with static text")
    context:SetSetting("performanceMode", false)
    assert(context:Labels()[1] == label and label:GetText() == "3,000", "mode exit retired or rewrote the sum")
    context:Tick(0.981)
    assert(#context:Labels() == 0, "mode exit restarted the sum's lifetime")
    context:Hit(1000)
    context:Hit(2000)
    context:Tick(0.2)
    assert(#context:Labels() == 2, "normal Diablo mode summed distinct amounts")
end)

Test("all style transitions retire queued hits and reuse the same pool", function()
    local context = SCT(false, function(setup) setup.settings.sctStyle = "diablo" end)
    context:Hit(111)
    context:Tick(0.2)
    local label = assert(context:Labels()[1])
    for _, style in ipairs({ "enemy", "diablo", "msbt", "diablo" }) do
        context:Hit(222)
        context:SetSetting("sctStyle", style)
        assert(#context:Labels() == 0, "style change retained an active hit")
        context:Tick(0.2)
        assert(#context:Labels() == 0, "style change replayed an old queued hit")
        assert(context.backing == (style ~= "msbt"), "style change lost native tracking ownership")
        context:Hit(333)
        context:Tick(0.2)
        assert(context:Labels()[1] == label, "style change allocated replacement text")
    end
    context:Event(context.controller, "PLAYER_LEAVING_WORLD")
    assert(#context:Labels() == 0 and not context.backing, "world cleanup retained Diablo text or tracking")
    context:ResetCounts()
    context:Hit(444)
    context:Tick(0.2)
    context:NoPresentationWrites()
end)

Test("scrolling keeps native V ownership and default text keeps its native coordinate system", function()
    local scrolling = SCT(true)
    assert(not scrolling.backing and scrolling.env.NAMEPLATES_ON == nil, "scrolling forced V-on tracking")
    scrolling.env.ShowNameplates()
    assert(scrolling.backing, "V on did not show native plates")
    scrolling.env.HideNameplates()
    assert(not scrolling.backing, "V off did not release native plates")
    local enemy = SCT(false)
    assert(not enemy.scrollRoot, "default SCT allocated an unused scrolling owner")
    assert(enemy.backing and enemy.env.NAMEPLATES_ON == nil, "default SCT lost invisible tracking")
    enemy:Hit(111)
    enemy:Tick(0.2)
    local label = assert(enemy:Labels()[1], "default fallback damage was not displayed")
    assert(label.parent.parent.anchor.point == "BOTTOMLEFT", "default text changed coordinate systems")
end)

Test("fixed scrolling separates a burst and animates without enemy projection", function()
    local context = SCT(true)
    context:Hit(111)
    context:Hit(111)
    context:Hit(222)
    context:Hit(333)
    context:Tick(0.1)
    local labels = context:Labels()
    assert(#labels == 3, "distinct hits were dropped or merged")
    local rows = {}
    local values = {}
    for _, label in ipairs(labels) do
        local anchor = label.parent.parent.anchor
        assert(
            anchor.point == "CENTER" and anchor.relative == context.scrollRoot,
            "scrolling bypassed its Layout owner"
        )
        assert(context.scrollRoot.anchor.x == 160, "the default stream moved from the right of screen center")
        assert(not rows[anchor.y], "simultaneous scrolling labels share a row")
        rows[anchor.y] = true
        values[label:GetText()] = true
    end
    assert(values["111"] and values["222"] and values["333"], "grouping changed an original damage amount")
    local holder = labels[1].parent.parent
    local x, y = holder.anchor.x, holder.anchor.y
    context:Tick(0.2)
    assert(holder.anchor.x > x and holder.anchor.y < y, "the stream did not curve outward and scroll down")
end)

Test("scrolling Layout owner exists before combat and carries active hits through movement", function()
    local context = SCT(true)
    local root = assert(context.scrollRoot, "MSBT cannot be moved before its first hit")
    assert(root:IsShown() and context.scrollOptions.onlyWhenShown, "inactive style can expose a handle")
    assert(root:GetWidth() == 240 and root:GetHeight() == 220, "unexpected stream edit bounds")
    assert(root.anchor.y == 0, "the default vertical stream position changed")
    context:Hit(111)
    context:Tick(0.1)
    local label = assert(context:Labels()[1])
    local holder = label.parent.parent
    assert(holder:GetParent() == root, "hits do not inherit Layout visibility and scale")
    root:SetPoint("CENTER", context.env.WorldFrame, "CENTER", -300, 75)
    root:SetScale(1.5)
    context.scrollOptions.onResize()
    context:ResetCounts()
    context:Tick(0)
    assert(holder.anchor.relative == root and root.anchor.x == -300, "animation overwrote the moved owner")
    context:NoPresentationWrites()
    assert((context.writes.SetParent or 0) == 0, "animation reparents unchanged hits")
end)

Test("hidden scrolling clears active and queued hits and skips intake until new visible hits", function()
    local context = SCT(true)
    context:Hit(111)
    context:Tick(0.1)
    context:Hit(222)
    context:SetScrollHidden(true)
    assert(#context:Labels() == 0, "Layout hiding retained scrolling text")
    local allocated = #context.objects
    context:ResetCounts()
    context:Hit(333)
    context:Tick(0.2)
    context:NoPresentationWrites()
    assert(#context.objects == allocated, "hidden scrolling allocated text")
    context:SetScrollHidden(false)
    context:Tick(0.2)
    assert(#context:Labels() == 0, "unhiding replayed retired hits")
    context:Hit(444)
    context:Tick(0.1)
    assert(context:Labels()[1]:GetText() == "444", "new visible hits did not resume")
end)

Test("pooled hits leave the scrolling owner for enemy text and reuse it when scrolling resumes", function()
    local context = SCT(true)
    local root = context.scrollRoot
    context:Hit(111)
    context:Tick(0.1)
    local holder = context:Labels()[1].parent.parent
    context:SetSetting("sctStyle", "enemy")
    assert(not root:IsShown(), "over-enemy text retained an active scrolling owner")
    context:SetScrollHidden(true)
    context:Hit(222)
    context:Tick(0.2)
    local label = assert(context:Labels()[1], "scrolling visibility suppressed enemy text")
    assert(
        label.parent.parent == holder and holder:GetParent() ~= root,
        "enemy text did not reuse and reparent its pool"
    )
    assert(holder.anchor.relative == context.env.WorldFrame, "enemy coordinates inherited scrolling geometry")
    context:SetSetting("sctStyle", "msbt")
    context:SetScrollHidden(false)
    context:Hit(333)
    context:Tick(0.1)
    assert(
        context.scrollRoot == root and context:Labels()[1].parent.parent == holder,
        "switching allocated replacements"
    )
    assert(holder:GetParent() == root and holder.anchor.relative == root, "scrolling did not reclaim its pooled holder")
end)

Test("changing style retires active and queued hits without replay", function()
    local context = SCT(true)
    context:Hit(111)
    context:Tick(0.1)
    assert(#context:Labels() == 1, "missing initial scrolling label")
    context:Hit(222)
    context:SetSetting("sctStyle", "enemy")
    assert(#context:Labels() == 0 and context.backing, "switch did not clear labels and restore enemy tracking")
    context:Tick(0.3)
    assert(#context:Labels() == 0, "an old queued hit replayed in the new style")
    context:SetSetting("sctStyle", "msbt")
    assert(not context.backing and context.env.NAMEPLATES_ON == nil, "switch back changed the visible V preference")
end)

Test("Performance Mode changes grouping without retiring or restarting active SCT", function()
    for _, scrolling in ipairs({ false, true }) do
        local context = SCT(scrolling)
        context:Hit(111)
        context:Tick(0.2)
        local first = assert(context:Labels()[1], "normal SCT did not display its original hit")
        local holder = first.parent.parent
        local coordinateSystem = holder.anchor.point
        local allocated = #context.objects
        context:SetSetting("performanceMode", true)
        assert(
            context:Labels()[1] == first and #context.objects == allocated,
            "Performance Mode retired or replaced active text"
        )
        assert(holder.anchor.point == coordinateSystem, "Performance Mode changed SCT coordinates")
        context:Hit(222)
        context:Tick(0.1)
        context:Hit(222)
        context:Tick(0.101)
        assert(#context:Labels() == 1 and context:Labels()[1] == first, "wider intake displayed before 300 ms")
        context:SetSetting("performanceMode", false)
        assert(context:Labels()[1] == first, "Cancel retired active SCT")
        context:Tick(0.081)
        local values = {}
        for _, label in ipairs(context:Labels()) do
            values[label:GetText()] = label
        end
        assert(
            values["111"] == first and values["444"] and not values["222"],
            "mode change dropped queued text or lost its Performance Mode sum"
        )
        context:Tick(1.2)
        assert(
            #context:Labels() == 1 and context:Labels()[1]:GetText() == "444",
            "mode changes restarted an active hit's lifetime"
        )
        context:Tick(0.3)
        assert(#context:Labels() == 0, "settled queued text did not keep its original full display lifetime")
    end
end)

Test("Performance Mode renders summed damage while restored normal mode keeps exact-amount duplicates", function()
    for _, scrolling in ipairs({ false, true }) do
        local context = SCT(scrolling, function(setup) setup.settings.performanceMode = true end)
        context:Hit(20)
        context:Tick(0.1)
        context:Hit(100)
        context:Tick(0.201)
        local summed = assert(context:Labels()[1], "Performance Mode did not render a settled sum")
        assert(#context:Labels() == 1 and summed:GetText() == "120", "20 and 100 did not render as one 120")
        local holder = summed.parent.parent
        assert(holder.anchor.point == (scrolling and "CENTER" or "BOTTOMLEFT"), "summing changed SCT coordinates")
        context:Tick(0.2)
        context:SetSetting("performanceMode", false)
        assert(
            context:Labels()[1] == summed and summed:GetText() == "120",
            "normal-mode restoration rewrote active sum"
        )
        context:Hit(20)
        context:Hit(100)
        context:Hit(100)
        context:Tick(0.2)
        local values = {}
        for _, label in ipairs(context:Labels()) do
            values[label:GetText()] = label
        end
        assert(
            #context:Labels() == 3 and values["120"] == summed and values["20"] and values["100"] and not values["200"],
            "normal mode summed distinct amounts or stopped exact-amount duplicate suppression"
        )
        context:Tick(1.26)
        assert(#context:Labels() == 2 and not summed:IsVisible(), "sum lifetime was restarted by the mode transition")
        context:Tick(0.3)
        assert(#context:Labels() == 0, "normal groups lost their full original display lifetime")
    end
end)

Test("Performance Mode sums keep critical filters independent", function()
    for _, scrolling in ipairs({ false, true }) do
        local context = SCT(scrolling, function(setup) setup.settings.performanceMode = true end)
        context:Hit(20)
        context:Hit(100)
        context.critical = true
        context:Hit(40)
        context:Hit(60)
        context:Tick(0.301)
        local values = {}
        for _, label in ipairs(context:Labels()) do
            values[label:GetText()] = label
        end
        assert(
            #context:Labels() == 2 and values["120"] and values["100"] and not values["220"],
            "critical and normal sums merged"
        )
        context:SetSetting("sctNormalHits", false)
        assert(
            #context:Labels() == 1 and context:Labels()[1] == values["100"],
            "normal filter removed or retained the wrong sum"
        )
        context:SetSetting("sctNormalHits", true)
        assert(#context:Labels() == 1, "filter restoration replayed a retired sum")
        context:SetSetting("sctCriticalHits", false)
        assert(#context:Labels() == 0, "critical filter did not retire its active sum")
    end
end)

Test("scrolling mode previews reuse and retire the same Layout owner", function()
    local context = SCT(true)
    local sct, root = context.env.DFRL.sct, context.scrollRoot
    sct.BeginEdit()
    sct.SetMode("off")
    assert(not root:IsShown(), "Off preview retained the scrolling handle owner")
    sct.FinishEdit(false)
    assert(root:IsShown() and context.scrollRoot == root, "Cancel did not restore the same scrolling owner")
    sct.BeginEdit()
    sct.SetMode("off")
    sct.FinishEdit(true)
    assert(not root:IsShown() and context.env.SurvivorsDragonUiSctMode == "off", "Confirm did not retire scrolling")
end)

Test("scrolling expires, reuses its pool and remains idle with no active labels", function()
    local context = SCT(true)
    context.critical = true
    context:Hit(111)
    context:Tick(0.1)
    local label = assert(context:Labels()[1])
    local allocated = #context.objects
    context:Tick(1.5)
    assert(#context:Labels() == 0 and label:GetText() == "", "expired label was retained")
    context:ResetCounts()
    context:Tick(0.1)
    context:NoPresentationWrites()
    assert((context.writes.SetScale or 0) == 0, "empty scrolling animated a pooled label")
    context:Hit(222)
    context:Tick(0.1)
    assert(#context:Labels() == 1 and #context.objects == allocated, "scrolling did not reuse its pool")
    context:Event(context.controller, "PLAYER_LEAVING_WORLD")
    assert(#context:Labels() == 0 and not context.backing, "world cleanup retained text or forced tracking")
    assert(not context.scrollRoot:IsShown(), "world cleanup retained the scrolling handle owner")
    context:ResetCounts()
    context:Tick(0.2)
    context:NoPresentationWrites()
end)

Test("empty SCT queues skip remembered-size writes and resume for new hits", function()
    local context = SCT(true)
    local writes = 0
    local setn = context.env.table.setn
    context.env.table.setn = function(list, count)
        writes = writes + 1
        setn(list, count)
    end
    context:Tick(0.016)
    assert(writes == 0, "empty queue/text passes still rewrote remembered lengths")
    context:Hit(111)
    writes = 0
    context:Tick(0.1)
    assert(writes > 0 and context:Labels()[1]:GetText() == "111", "a new hit did not resume queue processing")
    context:Tick(1.5)
    writes = 0
    context:Tick(0.016)
    assert(writes == 0 and #context:Labels() == 0, "retired queues did not return to the idle path")
end)

Test("source lookup scans one spellbook per publication generation across SCT and meter callers", function()
    local context = SCT(true, function(current, env)
        env.DFRL.locale.code, env.DFRL.locale.data = "en", { en = {} }
        env.DFRL.locale.Native = function(value) return value end
        env.T.SpellIconCatalog = {
            game = {
                PassiveA = "Interface\\Icons\\Spell_Nature_Thorns",
                PassiveB = "Interface\\Icons\\Spell_Fire_Fire",
            },
        }
        current.bookName, current.bookTexture = "BookSpell", "Interface\\Icons\\Spell_Holy_HolyBolt"
        env.GetNumSpellTabs = function()
            current.bookScans = (current.bookScans or 0) + 1
            return 1
        end
        env.GetSpellTabInfo = function() return "Book", nil, 0, 1 end
        env.GetSpellName = function() return current.bookName end
        env.GetSpellTexture = function() return current.bookTexture end
    end)
    local source = context.env.DFRL.sct
    assert(not context.bookScans, "icons-off initialization scanned the spellbook")
    assert(source.GetSourceIcon("PassiveA") == "Interface\\Icons\\Spell_Nature_Thorns")
    assert(source.GetSourceIcon("PassiveB") == "Interface\\Icons\\Spell_Fire_Fire")
    assert(source.GetSourceIcon("BookSpell") == context.bookTexture)
    assert(context.bookScans == 1, "non-spellbook names each rebuilt the same book")
    source.BeginEdit()
    source.SetMode("off")
    source.FinishEdit(true)
    context.bookName, context.bookTexture = "NewSpell", nil
    context:Event(context.controller, "SPELLS_CHANGED")
    assert(context.bookScans == 1, "an inactive source publication scanned eagerly")
    assert(source.GetSourceIcon("NewSpell") == context.env.T.SourceIconFallback, "missing art was cached as ready")
    source.GetSourceIcon("PassiveA")
    assert(context.bookScans == 2, "incomplete metadata retried for every source name")
    context.bookTexture = "Interface\\Icons\\Spell_Frost_FrostBolt02"
    context:Tick(1.01)
    assert(source.GetSourceIcon("NewSpell") == context.bookTexture, "meter-only lookup did not retry missing art")
    source.GetSourceIcon("PassiveB")
    assert(context.bookScans == 3, "successful metadata retry did not settle the generation")
    context:Event(context.controller, "PLAYER_LEAVING_WORLD")
    context:Event(context.controller, "PLAYER_ENTERING_WORLD")
    source.GetSourceIcon("NewSpell")
    assert(context.bookScans == 4, "world retirement retained an accepted spellbook generation")
end)

Test("production combat parser reuses capture descriptors without sharing event results", function()
    local context = H.New()
    local env = context.env
    env.getglobal = function(name) return env[name] end
    env.UnitName = function(unit) return unit == "player" and "Player" or "Pet" end
    env.COMBATHITOTHEROTHER = "%s hits %s for %d."
    env.SPELLLOGSELFOTHER = "Your %s hits %s for %d."
    env.SPELLLOGOTHEROTHER = "%s's %s hits %s for %d."
    env.PERIODICAURADAMAGEOTHEROTHER = "%s takes %d %s damage from %s's %s."
    env.SPELL_SCHOOL3_CAP = "Nature"
    local copies, insert = 0, env.table.insert
    env.table.insert = function(...)
        copies = copies + 1
        return insert(...)
    end
    context:Load("modules/nameplates/parser.lua")
    local parse = env.DFRL.tools.ParseNameplateCombatEvent
    local player = assert(parse("CHAT_MSG_SPELL_SELF_DAMAGE", "Your Bolt hits Enemy for 11."))
    local first = assert(parse("CHAT_MSG_SPELL_PET_DAMAGE", "Pet's Bolt hits Enemy for 17."))
    local prepared = copies
    local second = assert(parse("CHAT_MSG_SPELL_PET_DAMAGE", "Pet's Bolt hits Other for 19."))
    assert(copies == prepared, "pet event rebuilt an unchanged source-prefix descriptor")
    assert(player.amount == 11 and not player.sourceIsPet, "pet descriptor changed the self-message fields")
    assert(first.sourceName == "Pet" and first.spell == "Bolt" and first.amount == 17 and first.sourceIsPet)
    assert(second.targetName == "Other" and second.amount == 19, "reused descriptor changed capture order")
    assert(first ~= second and first.targetName == "Enemy", "capture reuse aliased separate event results")
    local melee = assert(parse("CHAT_MSG_COMBAT_PET_HITS", "Pet hits Enemy for 23."))
    assert(melee.sourceIsPet and melee.amount == 23 and melee.damageType == "autoattack")
    local periodic =
        assert(parse("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE", "Enemy takes 29 Nature damage from Pet's Thorns."))
    assert(periodic.sourceIsPet and periodic.periodic and periodic.school == "Nature" and periodic.amount == 29)
    assert(
        not parse("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE", "Enemy takes 29 Nature damage from Stranger's Thorns."),
        "descriptor reuse lost periodic ownership validation"
    )
end)

Test("final icon cache preserves stronger metadata, ambiguity, language and native equipment", function()
    local context = SCT(true, function(current, env)
        current.settings.damageIcons = true
        current.settings.sctDirectDamage = true
        env.DFRL.locale.code = "en"
        env.DFRL.locale.data = {
            en = { spellNames = { Alias = { "Generated" } } },
            de = { spellNames = { Alias = { "Other" } } },
        }
        env.DFRL.locale.Native = function(value) return value end
        current.catalogReads = {}
        env.T.SpellIconCatalog = {
            locales = { enUS = { Ambiguous = false } },
            schools = {
                enUS = {
                    Nature = { Ambiguous = "Interface\\Icons\\Spell_Nature_Lightning" },
                    Fire = { Ambiguous = "Interface\\Icons\\Spell_Fire_FireBolt02" },
                },
            },
            game = setmetatable({}, {
                __index = function(_, name)
                    current.catalogReads[name] = (current.catalogReads[name] or 0) + 1
                    if name == "Generated" then return "Interface\\Icons\\Spell_Nature_Thorns" end
                    if name == "Other" then return "Interface\\Icons\\Spell_Fire_Fire" end
                end,
            }),
        }
        env.GetNumSpellTabs = function() return 0 end
        env.GetSpellTabInfo, env.GetSpellName, env.GetSpellTexture = function() end, function() end, function() end
        env.AZS_GetPhase = function() return "playing" end
        env.AZS_DEBUFFS, env.AZS_DEBUFFS_UPDATED = {}, current.now
        env.GetInventoryItemTexture = function(_, slot)
            assert(slot == 16, "known source triggered an equipment scan")
            return current.weapon
        end
        env.T.ParseNameplateCombatEvent = function(_, message)
            return {
                kind = "damage",
                damageType = "spell",
                spell = "Ambiguous",
                school = current.school,
                sourceName = "Player",
                targetName = "Enemy",
                amount = tonumber(message),
            }
        end
    end)
    local source = context.env.DFRL.sct
    assert(source.GetSourceIcon("Generated") == "Interface\\Icons\\Spell_Nature_Thorns")
    source.GetSourceIcon("Generated")
    assert(context.catalogReads.Generated == 1, "unchanged final icon repeated its catalog traversal")
    assert(source.GetSourceIcon("Ambiguous") == context.env.T.SourceIconFallback)
    context.school = "Nature"
    context:Hit(1)
    context:Tick(0.1)
    context.school = "Fire"
    context:Hit(2)
    context:Tick(0.1)
    local schoolIcons = {}
    for _, label in ipairs(context:Labels()) do
        for _, object in ipairs(context.objects) do
            if object.kind == "Texture" and object.parent == label.parent then
                schoolIcons[label:GetText()] = object:GetTexture()
            end
        end
    end
    assert(
        schoolIcons["1"] == "Interface\\Icons\\Spell_Nature_Lightning",
        "school-free ambiguity hid a refined Nature icon"
    )
    assert(schoolIcons["2"] == "Interface\\Icons\\Spell_Fire_FireBolt02", "cached Nature artwork crossed into Fire")
    assert(
        source.GetSourceIcon("Ambiguous") == context.env.T.SourceIconFallback,
        "school refinement leaked into the meter"
    )
    source.LearnSummonIcon("Generated", "Interface\\Icons\\Spell_Shadow_SummonImp")
    assert(
        source.GetSourceIcon("Generated") == "Interface\\Icons\\Spell_Shadow_SummonImp",
        "cached catalog outranked new summon metadata"
    )
    source.LearnSummonIcon("Generated", "Interface\\Icons\\Spell_Shadow_SummonVoidWalker")
    assert(source.GetSourceIcon("Generated") == context.env.T.SourceIconFallback, "cache lost summon ambiguity")
    context.env.AZS_DEBUFFS = { { name = "Generated", icon = "Interface\\Icons\\Spell_Holy_HolyBolt" } }
    context:Event(context.controller, "CHAT_MSG_ADDON", "AZSDEBUFFS")
    context:Tick(0.36)
    assert(
        source.GetSourceIcon("Generated") == "Interface\\Icons\\Spell_Holy_HolyBolt",
        "cached ambiguity overrode a stronger observed aura"
    )
    assert(source.GetSourceIcon("Alias") == "Interface\\Icons\\Spell_Nature_Thorns")
    context.env.DFRL.locale.code = "de"
    context:NotifyLocale()
    assert(
        source.GetSourceIcon("Alias") == "Interface\\Icons\\Spell_Fire_Fire",
        "language change retained an old alias result"
    )
    context.weapon = "Interface\\Icons\\INV_Sword_04"
    assert(source.GetSourceIcon("Melee") == context.weapon)
    context.weapon = "Interface\\Icons\\INV_Axe_01"
    assert(source.GetSourceIcon("Melee") == context.weapon, "cache retained an unequipped melee image")
    context:Event(context.controller, "PLAYER_LEAVING_WORLD")
    context:Event(context.controller, "PLAYER_ENTERING_WORLD")
    context.env.AZS_DEBUFFS = {}
    assert(
        source.GetSourceIcon("Generated") == "Interface\\Icons\\Spell_Nature_Thorns",
        "world retirement retained learned or resolved metadata"
    )
end)

Test("unknown icon retry remains one second and final cache evicts old identities", function()
    local context = SCT(true, function(current, env)
        env.DFRL.locale.code, env.DFRL.locale.data = "en", { en = {} }
        env.DFRL.locale.Native = function(value) return value end
        current.catalogReads = {}
        env.T.SpellIconCatalog = {
            game = setmetatable({}, {
                __index = function(_, name)
                    current.catalogReads[name] = (current.catalogReads[name] or 0) + 1
                    if string.find(name, "^Source%d+$") then return "Interface\\Icons\\Spell_Nature_Thorns" end
                end,
            }),
        }
        env.GetNumSpellTabs = function() return 0 end
        env.GetSpellTabInfo, env.GetSpellName, env.GetSpellTexture = function() end, function() end, function() end
        env.AZS_GetPhase = function() return "playing" end
        env.AZS_DEBUFFS, env.AZS_DEBUFFS_UPDATED = {}, current.now
        env.GetItemInfo = function(name)
            current.itemReads = (current.itemReads or 0) + 1
            if current.itemReady then
                return name, nil, nil, nil, nil, nil, nil, nil, "Interface\\Icons\\INV_Misc_Orb_01"
            end
            error("native item metadata is not ready")
        end
    end)
    local source = context.env.DFRL.sct
    assert(source.GetSourceIcon("Mystery") == context.env.T.SourceIconFallback)
    source.GetSourceIcon("Mystery")
    context:Tick(0.5)
    source.GetSourceIcon("Mystery")
    assert(context.itemReads == 1 and context.catalogReads.Mystery == 1, "unknown lookup repeated before retry time")
    context.itemReady = true
    context:Tick(0.51)
    assert(
        source.GetSourceIcon("Mystery") == "Interface\\Icons\\INV_Misc_Orb_01",
        "negative final cache blocked metadata retry"
    )
    source.GetSourceIcon("Mystery")
    assert(context.itemReads == 2, "settled item metadata repeated a native lookup")
    for index = 1, 257 do
        source.GetSourceIcon("Source" .. index)
    end
    source.GetSourceIcon("Source257")
    assert(context.catalogReads.Source257 == 1, "newest icon result was not retained")
    source.GetSourceIcon("Source1")
    assert(context.catalogReads.Source1 == 2, "resolved identity cache grew without eviction")
end)

print("PASS " .. passed .. " SCT lifecycle contracts")
