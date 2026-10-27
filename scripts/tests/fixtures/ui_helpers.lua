-- CI-only native boundaries. Unsupported methods fail instead of becoming no-ops.
local H = {}
local nativeSetEnv = setfenv
local methods = {}

local function Write(object, name)
    local counts = object.context.writes
    counts[name] = (counts[name] or 0) + 1
end

function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:GetParent() return self.parent end
function methods:GetName() return self.name end
function methods:GetWidth() return self.width or 36 end
function methods:GetHeight() return self.height or 36 end
function methods:GetFrameLevel() return self.level or 1 end
function methods:GetAlpha() return self.alpha or 1 end
function methods:GetText() return self.text or "" end
function methods:GetTexture() return self.texture end
function methods:GetFont() return unpack(self.font or {}) end
function methods:GetTextColor() return unpack(self.textColor or { 1, 1, 1, 1 }) end
function methods:GetScript(name) return self.scripts[name] end
function methods:SetScript(name, callback)
    Write(self, "SetScript")
    assert(callback == nil or type(callback) == "function", "invalid mock script callback")
    self.scripts[name] = callback
end
function methods:RegisterEvent(name) self.events[name] = true end
function methods:UnregisterEvent(name) self.events[name] = nil end
function methods:UnregisterAllEvents() self.events = {} end

function methods:Show()
    Write(self, "Show")
    self.shown = true
    self.context:Visibility()
end
function methods:Hide()
    Write(self, "Hide")
    self.shown = false
    self.context:Visibility()
end
function methods:SetText(value)
    Write(self, "SetText")
    if self.context.failText == value and value ~= "" then
        self.context.failText = nil
        error("injected native text failure")
    end
    self.text = value
end
function methods:SetTexture(value)
    Write(self, "SetTexture")
    if self.context.failTexture == value and value ~= nil then return false end
    self.texture = value
    return true
end
function methods:SetFont(face, size, flags)
    Write(self, "SetFont")
    self.font = { face, size, flags }
    return true
end
function methods:SetTextColor(r, g, b, a)
    Write(self, "SetTextColor")
    self.textColor = { r, g, b, a or 1 }
end
function methods:SetAlpha(value)
    Write(self, "SetAlpha")
    self.alpha = value
end
function methods:SetWidth(value)
    Write(self, "SetWidth")
    self.width = value
end
function methods:SetHeight(value)
    Write(self, "SetHeight")
    self.height = value
end
function methods:SetFrameLevel(value)
    Write(self, "SetFrameLevel")
    self.level = value
end
function methods:CreateTexture(name) return self.context:Object("Texture", name, self) end
function methods:CreateFontString(name) return self.context:Object("FontString", name, self) end

for _, name in ipairs({
    "SetAllPoints",
    "ClearAllPoints",
    "SetPoint",
    "SetTexCoord",
    "SetVertexColor",
    "SetFrameStrata",
    "EnableMouse",
    "SetJustifyH",
    "SetJustifyV",
    "SetShadowColor",
    "SetShadowOffset",
}) do
    local method = name
    methods[method] = function(object) Write(object, method) end
end

function H.New()
    local context = { objects = {}, writes = {}, reads = {}, now = 2, nativeShown = true, modules = {}, settings = {} }
    local env = {
        assert = assert,
        error = error,
        ipairs = ipairs,
        pairs = pairs,
        next = next,
        pcall = pcall,
        type = type,
        tonumber = tonumber,
        tostring = tostring,
        unpack = unpack,
        math = math,
        string = string,
        setfenv = nativeSetEnv,
    }
    env._G = env
    -- Model the explicit Lua 5.0 sizes used by the queue/pool code. This is not
    -- a general emulator of Lua 5.0 or a substitute for the packaged client.
    local sizes = setmetatable({}, { __mode = "k" })
    env.table = {}
    for name, value in pairs(table) do
        env.table[name] = value
    end
    env.table.setn = function(list, size) sizes[list] = size end
    env.table.getn = function(list) return sizes[list] or table.getn(list) end
    env.getfenv = function() return env end
    context.env = env

    function context:Call(object, script, value)
        local callback = object:GetScript(script)
        if not callback then return end
        local oldThis, oldArg = env.this, env.arg1
        env.this, env.arg1 = object, value
        local ok, failure = pcall(callback)
        env.this, env.arg1 = oldThis, oldArg
        assert(ok, failure)
    end
    function context:Visibility()
        if self.changingVisibility then return end
        self.changingVisibility = true
        local changed, passes = true, 0
        while changed do
            passes = passes + 1
            assert(passes < 1000, "mock visibility callbacks did not settle")
            changed = false
            for _, object in ipairs(self.objects) do
                local visible = object:IsVisible()
                if object.wasVisible ~= visible then
                    object.wasVisible = visible
                    changed = true
                    self:Call(object, visible and "OnShow" or "OnHide")
                end
            end
        end
        self.changingVisibility = false
    end
    function context:Object(kind, name, parent)
        local object = setmetatable({
            context = self,
            kind = kind,
            name = name,
            parent = parent,
            shown = true,
            scripts = {},
            events = {},
        }, { __index = methods })
        object.wasVisible = object:IsVisible()
        table.insert(self.objects, object)
        if name then env[name] = object end
        return object
    end
    function context:Load(path, module)
        local chunk = assert(loadfile(path))
        nativeSetEnv(chunk, env)
        chunk()
        if module then
            assert(type(self.modules[module]) == "function", "missing module " .. module)
            self.modules[module]()
        end
    end
    function context:Event(object, eventName, value)
        assert(object.events[eventName], "fixture sent an unregistered event")
        local old = env.event
        env.event = eventName
        self:Call(object, "OnEvent", value)
        env.event = old
    end
    function context:Controller(eventName)
        for _, object in ipairs(self.objects) do
            if object.events[eventName] then return object end
        end
        error("missing controller for " .. eventName)
    end
    function context:ResetCounts()
        self.writes, self.reads = {}, {}
    end
    function context:NoPresentationWrites()
        for _, name in ipairs({
            "SetText",
            "SetFont",
            "SetTextColor",
            "SetTexture",
            "SetTexCoord",
            "SetVertexColor",
            "SetAlpha",
            "SetWidth",
            "SetHeight",
            "SetPoint",
            "ClearAllPoints",
            "Show",
            "Hide",
            "SetAllPoints",
            "SetFrameLevel",
            "SetFrameStrata",
            "EnableMouse",
            "SetScript",
            "SetJustifyH",
            "SetJustifyV",
            "SetShadowColor",
            "SetShadowOffset",
            "UIFrameFadeIn",
            "UIFrameFadeOut",
        }) do
            assert((self.writes[name] or 0) == 0, name .. " wrote unchanged or hidden presentation")
        end
    end

    env.CreateFrame = function(kind, name, parent) return context:Object(kind, name, parent) end
    env.UIParent = context:Object("Frame", "UIParent")
    env.GetTime = function() return context.now end
    env.ActionButton_GetPagedID = function(button) return button.slot end
    env.HasAction = function() return true end
    env.GetActionCooldown = function()
        context.reads.cooldown = (context.reads.cooldown or 0) + 1
        return 1, 10, 1
    end
    env.UnitExists = function() return true end
    env.UnitCanAttack = function() return true end
    env.IsActionInRange = function() return context.inRange and 1 or 0 end
    env.UIFrameFadeIn = function(object)
        Write(object, "UIFrameFadeIn")
        object:Show()
    end
    env.UIFrameFadeOut = function(object) Write(object, "UIFrameFadeOut") end
    env.UIFrameFadeRemoveFrame = function(object) Write(object, "UIFrameFadeRemoveFrame") end
    env.AZS_IsHudShown = function() return context.nativeShown end
    env.AZS_SetHudShown = function(_, shown)
        context.nativeShown = shown
        context.writes.hud = (context.writes.hud or 0) + 1
    end

    local listeners, localeListeners, visibility = {}, {}, {}
    local dfrl = { tools = {}, locale = { labels = {} }, layout = {}, display = {} }
    env.DFRL, env.T = dfrl, dfrl.tools
    function dfrl:GetEnv() return env end
    function dfrl:GetInfoOrCons() return "Interface\\AddOns\\SurvivorsDragonUi\\media\\tex\\" end
    function dfrl:NewMod(name, _, callback) context.modules[name] = callback end
    dfrl.tools.SetFont = function(object, size, flags) object:SetFont("DEFAULT_TEST", size, flags) end
    dfrl.locale.Text = function(value) return value end
    dfrl.locale.Listen = function(callback) table.insert(localeListeners, callback) end
    dfrl.display.Get = function(name) return context.settings[name] end
    dfrl.display.Listen = function(callback) table.insert(listeners, callback) end
    dfrl.layout.ListenVisibility = function(name, callback)
        visibility[name] = callback
        callback(true)
    end
    dfrl.layout.Register = function(name, frame, anchor)
        context.layoutFrame = frame
        context.layoutMask = context:Object("Frame", nil, env.UIParent)
        frame.parent = context.layoutMask
        if anchor then anchor() end
        if visibility[name] then visibility[name](true) end
    end
    function context:SetSetting(name, value)
        self.settings[name] = value
        for _, callback in ipairs(listeners) do
            callback()
        end
    end
    function context:SetLayoutHidden(hidden)
        if hidden then
            self.layoutMask:Hide()
        else
            self.layoutMask:Show()
        end
    end
    function context:NotifyLocale()
        for _, callback in ipairs(localeListeners) do
            callback()
        end
    end
    context:Load("core/tools.lua")
    return context
end

return H
