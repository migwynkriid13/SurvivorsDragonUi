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

Test("scrolling defaults, preview and discard use the existing display transaction", function()
    local context = H.New()
    context:Load("core/display.lua", "Display")
    local display = context.env.DFRL.display
    assert(display.Get("sctMSBTStyle") == false, "the default must remain over enemies")
    assert(display.Copy({ sctMSBTStyle = "true" }).sctMSBTStyle == false, "invalid saved style was accepted")
    display.BeginEdit()
    display.Set("sctMSBTStyle", true)
    assert(display.Get("sctMSBTStyle") and not context.env.SurvivorsDragonUiDisplay, "preview was saved early")
    display.FinishEdit(false)
    assert(display.Get("sctMSBTStyle") == false, "Cancel did not restore the default")
    display.BeginEdit()
    display.Set("sctMSBTStyle", true)
    display.FinishEdit(true)
    assert(context.env.SurvivorsDragonUiDisplay.sctMSBTStyle, "Confirm did not save scrolling")
    display.BeginEdit()
    display.Load({ sctMSBTStyle = false })
    assert(display.Get("sctMSBTStyle") == false, "profile preview ignored its style")
    display.FinishEdit(false)
    assert(display.Get("sctMSBTStyle"), "discarding a profile preview lost the saved style")
    display.Reset()
    assert(display.Get("sctMSBTStyle") == false, "reset did not restore over-enemy text")
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
    context:SetSetting("sctMSBTStyle", false)
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
    context:SetSetting("sctMSBTStyle", true)
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
    context:SetSetting("sctMSBTStyle", false)
    assert(#context:Labels() == 0 and context.backing, "switch did not clear labels and restore enemy tracking")
    context:Tick(0.3)
    assert(#context:Labels() == 0, "an old queued hit replayed in the new style")
    context:SetSetting("sctMSBTStyle", true)
    assert(not context.backing and context.env.NAMEPLATES_ON == nil, "switch back changed the visible V preference")
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

print("PASS " .. passed .. " SCT lifecycle contracts")
