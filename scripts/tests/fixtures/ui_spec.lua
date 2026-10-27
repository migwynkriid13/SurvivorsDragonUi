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

local function Cooldowns()
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
    local chunk = assert(loadfile(assert(arg[1], "missing extracted cooldown source")))
    setfenv(chunk, env)
    chunk()(bar)
    return context, bar, context:Controller("ACTIONBAR_UPDATE_COOLDOWN")
end

local function Loot()
    local context = H.New()
    local env = context.env
    env.DFRL.actionBarDefaults = { bottom = 55, height = 36, topInset = 14 }
    env.DFRL.CleanerChat = {
        ParseLootMessage = function(name)
            return { name = name, icon = "Interface\\Icons\\Test", iconSource = "native" }
        end,
    }
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
