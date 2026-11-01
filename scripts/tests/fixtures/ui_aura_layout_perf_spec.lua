-- CI only: exact aura layout and full timer owner with native aura boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1")
local context = H.New()
local env = context.env
env.container = env.CreateFrame("Frame", nil, env.UIParent)
env.nativeFrames, env.entries = {}, {}
env.iconSize, env.gap, env.rowGap, env.columns = 28, 3, 14, 6
env.width, env.flipped, env.editing, env.layoutDirty = 183, false, false, true
local reads, sizes = 0, 0
for index = 1, 2 do
    local native = env.CreateFrame("Frame", nil, env.container)
    function native:GetNumPoints() return self.point and 1 or 0 end
    function native:GetPoint() return unpack(self.point or {}) end
    function native:ClearAllPoints() self.point = nil end
    function native:SetPoint(...) self.point = { ... } end
    env.nativeFrames[index] = native
    local button = env.CreateFrame("Button", nil, env.container)
    local shown = button.IsShown
    function button:IsShown()
        reads = reads + 1
        return shown(self)
    end
    env.entries[index] = { button = button }
end
env.SizeButton = function() sizes = sizes + 1 end
env.DFRL.layout.Place = function(key) assert(key == "buffs") end
local chunk = assert(loadfile(assert(arg[1])))
setfenv(chunk, env)
local layout = chunk()
layout(false)
assert(reads == 2 and sizes == 2 and env.entries[2].slot == 1 and not env.layoutDirty)
reads, sizes = 0, 0
env.nativeFrames[1].point = { "CENTER", env.UIParent, "CENTER", 20, 30 }
layout(false)
assert(reads == 0 and sizes == 0, "settled native anchor repair rescanned aura slots")
assert(env.nativeFrames[1].point[1] == "TOPLEFT" and env.nativeFrames[1].point[2] == env.container)
env.entries[1].button:Hide()
env.layoutDirty = true
layout(false)
assert(env.entries[1].slot == nil and env.entries[2].slot == 0 and sizes == 1)
reads, sizes = 0, 0
layout(true)
assert(reads == 2 and sizes == 1, "forced native layout stopped repairing current artwork")
env.container:Hide()
env.layoutDirty = true
reads, sizes = 0, 0
layout(false)
assert(reads == 0 and sizes == 0 and env.layoutDirty, "hidden layout consumed pending presentation")
env.container:Show()
layout(false)
assert(reads == 2 and not env.layoutDirty)
reads = 0
env.editing = true
layout(false)
assert(reads == 2, "editing skipped current aura bounds")

local function AuraOwner(performance)
    local current = H.New()
    local native = current.env
    local state = { helpful = {}, harmful = {}, remaining = {}, nativeUpdates = 0, registered = {} }
    current.settings.flipBuffs, current.settings.performanceMode = false, performance
    local create = current.Object
    function current:Object(...)
        local object = create(self, ...)
        function object:GetNumPoints() return self.point and 1 or 0 end
        function object:GetPoint() return unpack(self.point or {}) end
        function object:ClearAllPoints() self.point = nil end
        function object:SetPoint(...) self.point = { ... } end
        function object:SetScale(value) self.scale = value end
        function object:SetParent(parent)
            self.parent = parent
            current:Visibility()
        end
        function object:GetID() return self.id end
        function object:SetID(id)
            state.idWrites = (state.idWrites or 0) + 1
            self.id = id
        end
        function object:SetBackdrop(value) self.backdrop = value end
        function object:SetBackdropBorderColor(...) self.borderColor = { ... } end
        return object
    end
    native.Minimap = native.CreateFrame("Frame", "Minimap", native.UIParent)
    native.BuffFrame = native.CreateFrame("Frame", "BuffFrame", native.UIParent)
    native.TemporaryEnchantFrame = native.CreateFrame("Frame", "TemporaryEnchantFrame", native.UIParent)
    native.GameTooltip = native.CreateFrame("Frame", "GameTooltip", native.UIParent)
    function native.GameTooltip:SetOwner(owner) self.owner = owner end
    function native.GameTooltip:IsOwned(owner) return self.owner == owner end
    function native.GameTooltip:ClearLines() self.lines = {} end
    function native.GameTooltip:AddLine(text) table.insert(self.lines, text) end
    native.T.RegisterTooltipIcon = function(button) state.registered[button] = true end
    native.GetPlayerBuff = function(index, filter)
        state.buffReads = (state.buffReads or 0) + 1
        local record = (filter == "HARMFUL" and state.harmful or state.helpful)[index]
        if record then return record.id, record.persistent end
        return -1, 0
    end
    native.GetPlayerBuffTimeLeft = function(id)
        state.timeReads = (state.timeReads or 0) + 1
        return state.remaining[id] or 0
    end
    native.SecondsToTimeAbbrev = function(remaining)
        if remaining > 0 and remaining < 1 then return "0s" end
        return remaining == 0 and "0s" or tostring(remaining)
    end
    native.BuffFrame_UpdateDuration = function(button, remaining)
        state.durationFormats = (state.durationFormats or 0) + 1
        local duration = native[button:GetName() .. "Duration"]
        duration:SetText(native.SecondsToTimeAbbrev and native.SecondsToTimeAbbrev(remaining) or tostring(remaining))
        duration:Show()
    end
    native.BuffButton_OnUpdate = function()
        state.nativeUpdates = state.nativeUpdates + 1
        local button = native.this
        local remaining = native.GetPlayerBuffTimeLeft(button.buffIndex)
        native.BuffFrame_UpdateDuration(button, remaining)
        button:SetAlpha(remaining < 1 and 0.25 or 1)
        if remaining == 0 and button.untilCancelled ~= true and button.untilCancelled ~= 1 then button:Hide() end
    end
    native.BuffButton_Update = function() end
    state.nativeDuration, state.nativeUpdate, state.nativeButtonUpdate =
        native.BuffFrame_UpdateDuration, native.BuffButton_OnUpdate, native.BuffButton_Update
    native.BuffButtons_UpdatePositions = function() end
    native.UIParent_ManageFramePositions = function() end
    native.BuffFrame_Enchant_OnUpdate = function()
        native.BuffFrame_UpdateDuration(native.TempEnchant1, state.enchantText and 0 or 10)
    end
    native.GetWeaponEnchantInfo = function() return true, 10000, 0, false, 0, 0 end
    local function Button(name, parent, id, buffIndex)
        local button = native.CreateFrame("Button", name, parent)
        button.id, button.buffIndex = id, buffIndex
        button:CreateTexture(name .. "Icon", "ARTWORK")
        button:CreateTexture(name .. "Border", "OVERLAY")
        button:CreateFontString(name .. "Duration", "OVERLAY")
        button:CreateFontString(name .. "Count", "OVERLAY")
        button:SetScript("OnUpdate", function() native.BuffButton_OnUpdate(native.arg1) end)
        local enter = function() state.tooltipId = native.this.buffIndex end
        local click = function() state.cancelId = native.this.buffIndex end
        button:SetScript("OnEnter", enter)
        button:SetScript("OnClick", click)
        button.nativeEnter, button.nativeClick, button.nativeUpdate = enter, click, button:GetScript("OnUpdate")
        return button
    end
    current.timed = Button("BuffButton0", native.BuffFrame, 0, 7)
    current.persistent = Button("BuffButton1", native.BuffFrame, 1, 3)
    current.zeroTimed = Button("BuffButton2", native.BuffFrame, 2, 11)
    current.debuff = Button("BuffButton16", native.BuffFrame, 16, 33)
    current.weapon = Button("TempEnchant1", native.TemporaryEnchantFrame, 71, 71)
    current.persistent.untilCancelled = true
    state.helpful[0], state.helpful[1], state.helpful[2] =
        { id = 7, persistent = 0 }, { id = 3, persistent = true }, { id = 11, persistent = 0 }
    state.harmful[0] = { id = 33, persistent = 0 }
    state.remaining[7], state.remaining[3], state.remaining[11], state.remaining[33] = 30, 0, 0.1, 20
    native.AZS_GetPhase = function()
        state.phaseReads = (state.phaseReads or 0) + 1
        return "playing"
    end
    native.AZS_GetRunTime = function()
        state.runReads = (state.runReads or 0) + 1
        return 10
    end
    native.AZS_RUN, native.AZS_RUN_UPDATED = { t = 10 }, current.now
    native.AZS_TIMERS, native.AZS_TIMERS_UPDATED = {}, current.now
    state.timers = {
        {
            name = "Ready summon",
            kind = "summon",
            duration = 10,
            remaining = 0,
            ready = true,
            icon = "Spell_Nature_Thorns",
        },
        {
            name = "Jewelry cooldown",
            kind = "cooldown",
            duration = 20,
            remaining = 5,
            ready = false,
            icon = "INV_Jewelry_TrinketPVP_01",
        },
        {
            name = "Waiting summon",
            kind = "summon",
            duration = 90,
            remaining = 60,
            ready = false,
            icon = "Spell_Shadow_SummonImp",
        },
    }
    native.AZS_GetTimers = function()
        state.timerReads = (state.timerReads or 0) + 1
        return state.timers
    end
    native.DFRL.layout.Place = function(key, frame)
        assert(key == "buffs" and frame == native.DFRL_PlayerAuras, "aura layout placed an unexpected owner")
        state.placements = (state.placements or 0) + 1
    end
    current:Load("modules/unit/auras.lua", "Player Auras")
    assert(state.placements > 0, "aura layout did not publish its initial bounds")
    current.controller = current:Controller("CHAT_MSG_ADDON")
    current.root = native.DFRL_PlayerAuras
    function current:NativeUpdate(button)
        self.now = self.now + 0.1
        self:Call(button, "OnUpdate", 0.1)
    end
    function current:Tick()
        self.now = self.now + 0.11
        self:Call(self.controller, "OnUpdate", 0.11)
    end
    return current, state, native
end

local function At(button, slot, flipped)
    local point, _, relative, x, y = button:GetPoint()
    assert(point == (flipped and "TOPLEFT" or "TOPRIGHT") and relative == point)
    assert(x == (flipped and 1 or -1) * math.mod(slot, 6) * 31 and y == -math.floor(slot / 6) * 42)
end

local function TimerIcon(current, button)
    local icon
    for _, object in ipairs(current.objects) do
        if object:GetParent() == button then
            assert(object.kind ~= "FontString", "API timer allocated text beneath its icon")
            if object.kind == "Texture" then icon = object end
        end
    end
    assert(icon and icon:GetAlpha() == 1 and button:GetAlpha() == 1, "API timer was dimmed")
    return icon
end

local function HasLine(tooltip, caption)
    for _, line in ipairs(tooltip.lines) do
        if line == caption then return true end
    end
    return false
end

for _, performance in ipairs({ false, true }) do
    local current, state, native = AuraOwner(performance)
    current:Tick()
    local buttons = {}
    for _, object in ipairs(current.objects) do
        if state.registered[object] and not object:GetName() and object:GetParent() == current.root then
            table.insert(buttons, object)
        end
    end
    assert(#buttons == 3, "API timers did not enter the existing aura pool")
    for index, button in ipairs(buttons) do
        assert(button:IsShown())
        TimerIcon(current, button)
        At(button, index - 1, false)
    end
    At(current.timed, 3, false)
    At(current.persistent, 4, false)
    At(current.zeroTimed, 5, false)
    At(current.debuff, 6, false)
    At(current.weapon, 7, false)
    assert(native.BuffFrame_UpdateDuration == state.nativeDuration and native.BuffButton_OnUpdate == state.nativeUpdate)
    assert(
        native.BuffButton_Update == state.nativeButtonUpdate,
        "API timer styling hooked native aura identity updates"
    )
    local updates, formats = state.nativeUpdates, state.durationFormats or 0
    for _ = 1, 3 do
        current:NativeUpdate(current.persistent)
        assert(current.persistent:IsShown() and current.persistent:GetAlpha() == 0.25)
        assert(native.BuffButton1Duration:GetText() == "0s" and native.BuffButton1Duration:IsShown())
    end
    assert(state.nativeUpdates == updates + 3 and state.durationFormats == formats + 3)
    assert(current.persistent:GetScript("OnUpdate") == current.persistent.nativeUpdate)
    current:Call(current.persistent, "OnEnter")
    current:Call(current.persistent, "OnClick")
    assert(state.tooltipId == 3 and state.cancelId == 3 and not state.idWrites)
    assert(current.persistent:GetScript("OnEnter") == current.persistent.nativeEnter)
    assert(current.persistent:GetScript("OnClick") == current.persistent.nativeClick)
    current:Call(buttons[1], "OnEnter")
    assert(native.GameTooltip:GetText() == "Ready summon" and HasLine(native.GameTooltip, "Ready"))
    assert(HasLine(native.GameTooltip, "Full wait: 10.0 sec") and native.GameTooltip:IsOwned(buttons[1]))
    current:Call(buttons[1], "OnLeave")
    current:Call(buttons[2], "OnEnter")
    assert(HasLine(native.GameTooltip, "Cooldown") and HasLine(native.GameTooltip, "Remaining: 5.0 sec"))
    assert(HasLine(native.GameTooltip, "Full wait: 20.0 sec"))
    current:SetSetting("flipBuffs", true)
    for index, button in ipairs(buttons) do
        At(button, index - 1, true)
    end
    At(current.timed, 3, true)
    At(current.persistent, 4, true)
    At(current.weapon, 7, true)
    state.timers[1].remaining, state.timers[1].ready = 8, false
    state.timers[2].remaining, state.timers[2].ready = 0, true
    current:Event(current.controller, "CHAT_MSG_ADDON", "AZSTIMERS")
    current:Tick()
    assert(HasLine(native.GameTooltip, "Ready") and not HasLine(native.GameTooltip, "Remaining: 5.0 sec"))
    current:Call(buttons[2], "OnLeave")
    for index, button in ipairs(buttons) do
        TimerIcon(current, button)
        At(button, index - 1, true)
    end
    current:Call(buttons[1], "OnEnter")
    assert(HasLine(native.GameTooltip, "Next summon") and HasLine(native.GameTooltip, "Remaining: 8.0 sec"))
    current:Call(buttons[1], "OnLeave")
    current:SetSetting("flipBuffs", false)
    for index, button in ipairs(buttons) do
        At(button, index - 1, false)
    end
    current:NativeUpdate(current.timed)
    assert(native.BuffButton0Duration:GetText() == "30" and native.BuffButton0Duration:IsShown())
    state.remaining[7] = 0.3
    current:NativeUpdate(current.timed)
    assert(current.timed:IsShown() and current.timed:GetAlpha() == 0.25)
    assert(native.BuffButton0Duration:GetText() == "0s" and native.BuffButton0Duration:IsShown())
    state.remaining[7] = 0
    current:NativeUpdate(current.timed)
    assert(not current.timed:IsShown() and current.timed:GetAlpha() == 0.25)
    assert(native.BuffButton0Duration:GetText() == "0s" and native.BuffButton0Duration:IsShown())
    assert(current.persistent:GetID() == 1 and current.zeroTimed:GetID() == 2 and not state.idWrites)
    assert(current.persistent.buffIndex == 3 and current.zeroTimed.buffIndex == 11)
    state.enchantText = "0s"
    native.BuffFrame_Enchant_OnUpdate()
    assert(native.TempEnchant1Duration:GetText() == "0s" and native.TempEnchant1Duration:IsShown())
    local allocated = #current.objects
    current.root:Hide()
    local phaseReads, runReads, timerReads = state.phaseReads, state.runReads, state.timerReads
    current:ResetCounts()
    native.BuffButtons_UpdatePositions()
    current:Tick()
    assert(state.phaseReads == phaseReads and state.runReads == runReads and state.timerReads == timerReads)
    assert(not current.controller:GetScript("OnUpdate"))
    current:NoPresentationWrites()
    current.root:Show()
    current:Tick()
    assert(#current.objects == allocated)
    for index, button in ipairs(buttons) do
        assert(button:IsShown())
        TimerIcon(current, button)
        At(button, index - 1, false)
    end
    state.timers[1], state.timers[3] = state.timers[3], state.timers[1]
    current:Event(current.controller, "CHAT_MSG_ADDON", "AZSTIMERS")
    current:Tick()
    current:Call(buttons[1], "OnEnter")
    assert(native.GameTooltip:GetText() == "Waiting summon", "API timer display reordered the received list")
    current:Call(buttons[1], "OnLeave")
    current:Call(buttons[3], "OnEnter")
    assert(native.GameTooltip:GetText() == "Ready summon")
    current:Call(buttons[3], "OnLeave")
    for index, button in ipairs(buttons) do
        TimerIcon(current, button)
        At(button, index - 1, false)
    end
    assert(#current.objects == allocated and not state.buffReads)
    assert(state.timeReads == state.nativeUpdates, "API timer styling added a native aura-time getter")
end
print(
    "PASS API timer icons stay bright without text, retain received order and tooltips, and reuse their hidden pool in both modes"
)
print(
    "PASS native aura duration, dimming, updates, input and expiry remain native while layout repairs anchors only when needed"
)
