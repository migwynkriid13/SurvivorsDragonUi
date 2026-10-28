-- CI runner: real source bodies, explicit fake native boundaries, no game.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "the CI fixture runner must use its pinned Lua 5.1 interpreter")
local passed = 0
local function Test(name, callback)
    local ok, failure = pcall(callback)
    assert(ok, name .. ": " .. tostring(failure))
    passed = passed + 1
    print("PASS " .. name)
end

local function Cooldowns(setup)
    local context = H.New()
    local env = context.env
    context.settings.cooldownNumbers = true
    local bar = env.CreateFrame("Frame", nil, env.UIParent)
    env.DFRL.actionButtons = {}
    for index = 1, 7 do
        local button = env.CreateFrame("Button", "TestActionButton" .. index, bar)
        button.slot = index
        env.DFRL.actionButtons[index] = button
    end
    if setup then setup(context, env) end
    local chunk = assert(loadfile(assert(arg[1], "missing extracted cooldown source")))
    setfenv(chunk, env)
    chunk()(bar)
    return context, bar, context:Controller("ACTIONBAR_UPDATE_COOLDOWN")
end

local function Loot(settings, nativeShown)
    local context = H.New()
    local env = context.env
    if nativeShown ~= nil then context.nativeShown = nativeShown end
    env.DFRL.actionBarDefaults = { bottom = 55, height = 36, topInset = 14 }
    env.DFRL.CleanerChat = {
        ParseLootMessage = function(name)
            if type(name) == "table" then return name end
            return { name = name, icon = "Interface\\Icons\\Test", iconSource = "native" }
        end,
    }
    env.SurvivorsDragonUiDisplay = settings
    context:Load("core/display.lua", "Display")
    context:Load("core/hud.lua")
    context:Load("modules/ui/loot.lua", "LootNotifications")
    context:Load("modules/ui/loot_view.lua", "LootView")
    local animation
    for _, object in ipairs(context.objects) do
        if object.kind == "Frame" and not object.name and not object.parent and not next(object.events) then
            animation = object
        end
    end
    assert(animation, "missing independent loot animator")
    return context, context:Controller("CVAR_UPDATE"), animation
end

local function Deliver(context, service, name)
    context.env.DFRL.loot.Observe(name, "CHAT_MSG_LOOT")
    context:Call(service, "OnUpdate", 0.2)
end

Test("unchanged cooldowns do no presentation writes or allocations", function()
    local context, _, controller = Cooldowns()
    local allocated = table.getn(context.objects)
    context:ResetCounts()
    context:Event(controller, "ACTIONBAR_UPDATE_COOLDOWN")
    context:NoPresentationWrites()
    assert(context.reads.cooldown == 7, "the native cooldown read must still run")
    assert(table.getn(context.objects) == allocated, "cooldown objects were reallocated")
end)

Test("cooldown captions cache only their displayed unit, value and language", function()
    local context, _, controller = Cooldowns(function(current, env)
        current.duration = 120
        env.DFRL.locale.code = "en"
        env.DFRL.locale.Text = function(unit)
            current.reads.captions = (current.reads.captions or 0) + 1
            return unit == "m" and env.DFRL.locale.code == "de" and "Min" or unit
        end
        env.GetActionCooldown = function()
            current.reads.cooldown = (current.reads.cooldown or 0) + 1
            return 1, current.duration, 1
        end
    end)
    local overlay = context.env.DFRL.actionButtons[1].DFRL_cooldownNumber
    assert(overlay.text:GetText() == "2m" and context.reads.captions == 7)
    context:ResetCounts()
    context.now = 2.05
    context:Event(controller, "ACTIONBAR_UPDATE_COOLDOWN")
    assert(
        context.reads.cooldown == 7 and not context.reads.captions,
        "cached captions skipped timing or repeated formatting"
    )
    context:NoPresentationWrites()
    overlay.text.text, overlay.text.textColor = "native reset", { 0, 0, 0, 1 }
    context:ResetCounts()
    context:Event(controller, "ACTIONBAR_UPDATE_COOLDOWN")
    assert(
        not context.reads.captions and context.writes.SetText == 1 and context.writes.SetTextColor == 1,
        "caption reuse hid actual native text or color restoration"
    )
    context.env.DFRL.locale.code = "de"
    context:ResetCounts()
    context:Event(controller, "ACTIONBAR_UPDATE_COOLDOWN")
    assert(overlay.text:GetText() == "2Min" and context.reads.captions == 7, "language change reused an old suffix")
    context.duration = 7200
    context:ResetCounts()
    context:Event(controller, "ACTIONBAR_UPDATE_COOLDOWN")
    assert(overlay.text:GetText() == "2h" and context.reads.captions == 7, "the same rounded value reused another unit")
    context.duration = 61
    context:ResetCounts()
    context:Event(controller, "ACTIONBAR_UPDATE_COOLDOWN")
    assert(overlay.text:GetText() == "60" and context.reads.captions == 7, "unit transition reused a minute caption")
    context.duration = 10
    context:Event(controller, "ACTIONBAR_SLOT_CHANGED", 1)
    assert(overlay.text:GetText() == "9", "native replacement retained a cached numeric caption")
    context:SetSetting("cooldownNumbers", false)
    assert(overlay.cooldownText == nil and overlay.cooldownValue == nil, "disable retained caption state")
    context:ResetCounts()
    context:SetSetting("cooldownNumbers", true)
    assert(
        context.reads.cooldown == 7 and context.reads.captions == 7,
        "reenabling did not reread and rebuild captions"
    )
end)

Test("cached cooldown captions retry failed native text writes", function()
    local context, _, controller = Cooldowns(function(current, env)
        env.DFRL.locale.code = "en"
        env.DFRL.locale.Text = function(unit)
            current.reads.captions = (current.reads.captions or 0) + 1
            return unit == "m" and env.DFRL.locale.code == "de" and "Min" or unit
        end
        env.GetActionCooldown = function()
            current.reads.cooldown = (current.reads.cooldown or 0) + 1
            return 1, 120, 1
        end
    end)
    local overlay = context.env.DFRL.actionButtons[1].DFRL_cooldownNumber
    context.env.DFRL.locale.code, context.failText = "de", "2Min"
    local success = pcall(function() context:Event(controller, "ACTIONBAR_UPDATE_COOLDOWN") end)
    assert(not success and overlay.text:GetText() == "2m", "injected native setter failure did not reach the caption")
    context:ResetCounts()
    context:Event(controller, "ACTIONBAR_UPDATE_COOLDOWN")
    assert(
        overlay.text:GetText() == "2Min" and context.reads.cooldown == 7 and context.reads.captions == 6,
        "a failed native write prevented retry or repeated successful formatting"
    )
end)

Test("cooldown caption reuse retains every-frame final-window reads and exact zero threshold", function()
    local context, _, controller = Cooldowns(function(current, env)
        current.now = 1
        env.GetActionCooldown = function()
            current.reads.cooldown = (current.reads.cooldown or 0) + 1
            return 1, 0.1, 1
        end
    end)
    local overlay = context.env.DFRL.actionButtons[1].DFRL_cooldownNumber
    assert(overlay.text:GetText() == "1", "exactly100ms no longer displayed1")
    context:ResetCounts()
    context:Call(controller, "OnUpdate", 0.001)
    assert(context.reads.cooldown == 7, "the final-window refresh was throttled by caption reuse")
    context.now = 1.001
    context:Call(controller, "OnUpdate", 0.001)
    assert(overlay.text:GetText() == "0" and context.reads.cooldown == 14, "positive final-zero sampling changed")
    context.now = 1.2
    context:Call(controller, "OnUpdate", 0.001)
    assert(not overlay:IsShown() and context.reads.cooldown == 21, "expiration lost its final native sample")
end)

Test("hidden and disabled cooldowns skip reads and painting", function()
    local context, bar, controller = Cooldowns()
    bar:Hide()
    context:ResetCounts()
    context:Call(controller, "OnUpdate", 1)
    context:NoPresentationWrites()
    assert(not context.reads.cooldown, "hidden cooldowns were read")
    bar:Show()
    context:SetSetting("cooldownNumbers", false)
    context:ResetCounts()
    context:Call(controller, "OnUpdate", 1)
    context:NoPresentationWrites()
    assert(not context.reads.cooldown, "disabled cooldowns were read")
end)

Test("world cleanup clears cooldown overlays and suspends reads", function()
    local context, _, controller = Cooldowns()
    context:Event(controller, "PLAYER_LEAVING_WORLD")
    for _, button in ipairs(context.env.DFRL.actionButtons) do
        assert(not button.DFRL_cooldownNumber:IsShown(), "retired overlay stayed shown")
    end
    context:ResetCounts()
    context:Call(controller, "OnUpdate", 1)
    context:NoPresentationWrites()
    assert(not context.reads.cooldown, "retired cooldowns were read")
    context:Event(controller, "PLAYER_ENTERING_WORLD")
    assert(context.reads.cooldown == 7, "world entry did not resume native reads")
end)

Test("range indicators reuse their texture and never restart an unchanged fade", function()
    local context = H.New()
    local env = context.env
    local bar = env.CreateFrame("Frame", nil, env.UIParent)
    local button = env.CreateFrame("Button", nil, bar)
    button.slot = 1
    env.DFRL.mainBar, env.DFRL.actionButtons = bar, { button }
    context:Load("modules/bars/range.lua", "RangeIndicator")
    local controller = context:Controller("PLAYER_TARGET_CHANGED")
    context:Event(controller, "PLAYER_TARGET_CHANGED")
    local texture, allocated = button.rangeIndicator, table.getn(context.objects)
    context:ResetCounts()
    context:Event(controller, "PLAYER_TARGET_CHANGED")
    context:NoPresentationWrites()
    assert(button.rangeIndicator == texture and table.getn(context.objects) == allocated, "range texture was replaced")
    bar:Hide()
    assert(controller:GetScript("OnUpdate") == nil, "hidden bar kept range polling")
    assert(not texture:IsShown() and not texture.showing, "hidden range effect was not cleared")
end)

Test("loot cards reuse the bounded pool and clear retired bindings", function()
    local context, service, animation = Loot()
    Deliver(context, service, "First")
    local first
    for _, object in ipairs(context.objects) do
        if object.entry and object.entry.name == "First" then first = object end
    end
    assert(first, "loot did not reach a card")
    local allocated = table.getn(context.objects)
    context.now = context.now + 5.56
    context:Call(animation, "OnUpdate", 5.56)
    assert(
        first.entry == nil and first.icon:GetTexture() == nil and first.name:GetText() == "",
        "retired card retained content"
    )
    assert(not first:IsShown() and animation:GetScript("OnUpdate") == nil, "empty pool kept an animator")
    Deliver(context, service, "Second")
    assert(first.entry and first.entry.name == "Second", "the free card was not reused")
    assert(table.getn(context.objects) == allocated, "loot pool grew on reuse")
end)

Test("loot defaults and all three modes use shared preview profiles Confirm Cancel and reset", function()
    local context = H.New()
    context:Load("core/display.lua", "Display")
    local display = context.env.DFRL.display
    assert(display.Get("lootMode") == "sdui" and display.Get("lootShowMarks") == true, "loot defaults changed")
    local invalid = display.Copy({ lootMode = true, lootShowMarks = "false" })
    assert(invalid.lootMode == "sdui" and invalid.lootShowMarks == true, "invalid loot preferences were accepted")
    for _, mode in ipairs({ "game", "off", "sdui" }) do
        display.BeginEdit()
        display.Set("lootMode", mode)
        display.Set("lootShowMarks", false)
        assert(display.Get("lootMode") == mode and not context.env.SurvivorsDragonUiDisplay, "preview saved early")
        display.FinishEdit(false)
        assert(display.Get("lootMode") == "sdui" and display.Get("lootShowMarks"), "Cancel lost defaults")
    end
    display.BeginEdit()
    display.Set("lootMode", "game")
    display.Set("lootShowMarks", false)
    display.Set("lootMode", "invalid")
    assert(display.Get("lootMode") == "game", "invalid mode replaced the draft")
    display.FinishEdit(true)
    assert(context.env.SurvivorsDragonUiDisplay.lootMode == "game", "Confirm did not save the mode")
    assert(context.env.SurvivorsDragonUiDisplay.lootShowMarks == false, "Confirm did not save marks")
    display.BeginEdit()
    display.Load({ lootMode = "off", lootShowMarks = true })
    assert(display.Get("lootMode") == "off" and display.Get("lootShowMarks"), "profile preview lost loot settings")
    display.FinishEdit(false)
    assert(display.Get("lootMode") == "game" and not display.Get("lootShowMarks"), "profile Cancel lost saved loot")
    display.Reset()
    assert(display.Get("lootMode") == "sdui" and display.Get("lootShowMarks"), "full reset lost loot defaults")
end)

Test("Game and Off retire custom loot stop intake and preserve native preference through Cancel", function()
    local context, service, animation = Loot()
    local env, display = context.env, context.env.DFRL.display
    Deliver(context, service, "Before mode change")
    local parsed, metadata = 0, 0
    env.DFRL.CleanerChat.ParseLootMessage = function() parsed = parsed + 1 end
    env.GetItemInfo = function() metadata = metadata + 1 end
    display.BeginEdit()
    for _, mode in ipairs({ "game", "off", "game" }) do
        display.Set("lootMode", mode)
        assert(context.nativeShown == (mode == "game"), "native loot visibility differs from selected mode")
        assert(not env.DFRL.loot.IsActive(), "native/off mode retained custom intake")
        assert(not service:GetScript("OnUpdate") and not animation:GetScript("OnUpdate"), "settled mode kept polling")
        for _, object in ipairs(context.objects) do
            assert(not object.entry, "retired custom loot remained visible or queued")
        end
        context:ResetCounts()
        env.DFRL.loot.Observe("Ignored", "CHAT_MSG_LOOT")
        context:Call(service, "OnUpdate", 1)
        context:NoPresentationWrites()
    end
    assert(parsed == 0 and metadata == 0, "native/off mode parsed or resolved custom loot")
    display.FinishEdit(false)
    assert(env.DFRL.loot.IsActive() and context.nativeShown == false, "Cancel did not restore SDUI ownership")
    context:Event(service, "PLAYER_LEAVING_WORLD")
    assert(context.nativeShown == true, "preview changed the native preference restored on world leave")
end)

Test("initial native/off modes defer card artwork and reuse it after first SDUI selection", function()
    for _, mode in ipairs({ "game", "off" }) do
        local context, service = Loot({ lootMode = mode })
        for _, object in ipairs(context.objects) do
            assert(object.kind ~= "Texture" and object.kind ~= "FontString", "native/off mode allocated popup artwork")
        end
        assert(context.nativeShown == (mode == "game") and not service:GetScript("OnUpdate"))
        local display = context.env.DFRL.display
        display.BeginEdit()
        display.Set("lootMode", "sdui")
        Deliver(context, service, "First SDUI item")
        local allocated = table.getn(context.objects)
        display.Set("lootMode", mode)
        display.Set("lootMode", "sdui")
        Deliver(context, service, "Reused SDUI item")
        assert(table.getn(context.objects) == allocated, "switching modes rebuilt the popup pool")
    end
end)

Test("Game preview enables a previously hidden native box without changing Cancel cleanup", function()
    local context, service = Loot(nil, false)
    local display = context.env.DFRL.display
    display.BeginEdit()
    display.Set("lootMode", "game")
    assert(context.nativeShown == true, "Game mode did not explicitly enable native loot")
    display.FinishEdit(false)
    context:Event(service, "PLAYER_LEAVING_WORLD")
    assert(context.nativeShown == false, "Cancel leaked a preview into the original hidden native preference")
end)

Test("native handoff failures retry only until accepted and preserve later external preferences", function()
    local context, service = Loot()
    local env, display = context.env, context.env.DFRL.display
    local write, fail = env.AZS_SetHudShown, true
    env.AZS_SetHudShown = function(part, shown)
        if fail then return false end
        write(part, shown)
        context:Event(service, "CVAR_UPDATE", "hudLoot")
    end
    display.BeginEdit()
    display.Set("lootMode", "game")
    assert(not context.nativeShown and service:GetScript("OnUpdate"), "failed Game handoff stopped retrying")
    fail = false
    context:Call(service, "OnUpdate", 0.21)
    assert(context.nativeShown and not service:GetScript("OnUpdate"), "successful native handoff retained polling")
    context.nativeShown = false
    context:Event(service, "CVAR_UPDATE", "hudLoot")
    assert(context.nativeShown, "external change defeated the explicit Game choice")
    context:Event(service, "PLAYER_LEAVING_WORLD")
    assert(context.nativeShown == false, "cleanup lost the latest external native preference")
end)

Test("positive collected-item marks reuse the loot card and checkbox off rejects duplicates", function()
    local context, service, animation = Loot()
    local reward =
        { name = "Footpad's Cover", collection = "collected", marks = "1", icon = "Test", iconSource = "native" }
    Deliver(context, service, reward)
    local card
    for _, object in ipairs(context.objects) do
        if object.entry then card = object end
    end
    assert(card and card.name:GetText() == "Footpad's Cover → +1 Mark", "conversion reward was not shown")
    assert(card.entry.collection == "collected", "conversion masqueraded as a new item")
    context.now = context.now + 0.5
    context:Call(animation, "OnUpdate", 0.5)
    context:ResetCounts()
    context:Call(animation, "OnUpdate", 0.1)
    context:NoPresentationWrites()
    local allocated = table.getn(context.objects)
    local display = context.env.DFRL.display
    display.BeginEdit()
    display.Set("lootShowMarks", false)
    Deliver(context, service, reward)
    assert(not card.entry and not animation:GetScript("OnUpdate"), "marks off retained or replayed a reward")
    display.FinishEdit(false)
    for _, marks in ipairs({ "0", "-1", "1.5", "abc" }) do
        Deliver(context, service, { name = "Duplicate", collection = "collected", marks = marks })
        assert(not card.entry, "invalid marks produced a loot card")
    end
    Deliver(context, service, { name = "Duplicate", collection = "collected" })
    assert(not card.entry, "zero-reward duplicate became a popup")
    reward.marks = "002"
    Deliver(context, service, reward)
    assert(card.entry and card.name:GetText() == "Footpad's Cover → +002 Marks", "marks amount/plural changed")
    assert(table.getn(context.objects) == allocated, "marks rewards allocated another popup pool")
end)

Test("unchanged settled loot writes nothing and a full pool never allocates a fourth card", function()
    local context, service, animation = Loot()
    Deliver(context, service, "First")
    context.now = context.now + 0.5
    context:Call(animation, "OnUpdate", 0.5)
    local allocated = table.getn(context.objects)
    context:ResetCounts()
    context.now = context.now + 0.1
    context:Call(animation, "OnUpdate", 0.1)
    context:NotifyLocale()
    context:NoPresentationWrites()
    Deliver(context, service, "Second")
    Deliver(context, service, "Third")
    Deliver(context, service, "Queued fourth")
    local active = 0
    for _, object in ipairs(context.objects) do
        if object.entry then active = active + 1 end
    end
    assert(active == 3, "loot pool did not preserve its three-card bound")
    assert(table.getn(context.objects) == allocated, "a full loot pool allocated more regions")
end)

Test("a full loot pool defers queued metadata resolution until delivery", function()
    local context, service, animation = Loot()
    local reads = 0
    context.env.GetItemInfo = function()
        reads = reads + 1
        return "Native item", nil, 3, nil, nil, nil, nil, "INVTYPE_HEAD", "Interface\\Icons\\NativeItem"
    end
    for index = 1, 3 do
        Deliver(context, service, { name = "Item " .. index, itemReference = "item:" .. index })
    end
    assert(reads == 3, "accepted cards did not resolve their native metadata")
    local queued = { name = "Queued item", itemReference = "item:4" }
    Deliver(context, service, queued)
    for _ = 1, 5 do
        context:Call(service, "OnUpdate", 0.2)
    end
    assert(reads == 3, "a full pool repeatedly resolved its waiting head")
    assert(queued.icon == nil, "resolution mutated the intake entry")
    context.now = context.now + 10
    context:Call(animation, "OnUpdate", 0.1)
    context:Call(service, "OnUpdate", 0.2)
    assert(reads == 4, "freed capacity did not resolve the queued item exactly once")
end)

Test("hidden loot stops cosmetic writes but expires before being shown again", function()
    local context, service, animation = Loot()
    context:SetLayoutHidden(true)
    Deliver(context, service, "Hidden")
    context:ResetCounts()
    context.now = context.now + 1
    context:Call(animation, "OnUpdate", 1)
    context:NoPresentationWrites()
    context.now = context.now + 5
    context:Call(animation, "OnUpdate", 5)
    assert(animation:GetScript("OnUpdate") == nil, "hidden notices never retired")
    context:SetLayoutHidden(false)
    assert(not context.layoutFrame:IsShown(), "expired hidden notice was replayed")
end)

Test("failed optional icons retry on refresh and successful bindings stay cached", function()
    local context, service = Loot()
    local iconPath = "Interface\\Icons\\Test"
    context.failTexture = iconPath
    Deliver(context, service, "Retry icon")
    local card
    for _, object in ipairs(context.objects) do
        if object.entry then card = object end
    end
    assert(card and card.iconPath == nil and not card.icon:IsShown(), "failed icon was treated as bound")
    context.failTexture = nil
    context:NotifyLocale()
    assert(card.iconPath == iconPath and card.icon:IsShown(), "the required refresh did not retry the icon")
    context:ResetCounts()
    context:NotifyLocale()
    context:NoPresentationWrites()
end)

Test("a failed loot draw releases native ownership and every active card", function()
    local context, service, animation = Loot()
    Deliver(context, service, "First")
    assert(context.nativeShown == false, "custom loot did not capture the native HUD")
    context.failText = "Broken"
    Deliver(context, service, "Broken")
    assert(
        context.nativeShown == true and not context.env.DFRL.loot.IsActive(),
        "failed renderer kept native ownership"
    )
    assert(
        service:GetScript("OnUpdate") == nil and animation:GetScript("OnUpdate") == nil,
        "failed renderer kept polling"
    )
    for _, object in ipairs(context.objects) do
        if object.parent == context.layoutFrame then
            assert(object.entry == nil and not object:IsShown(), "a pooled card survived failure")
            assert(object.icon:GetTexture() == nil and object.name:GetText() == "", "failed card retained content")
        end
    end
end)

print(tostring(passed) .. " production UI lifecycle contracts passed")
