-- CI-only native setup shared by scrolling and nameplate lifecycle fixtures.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
-- CI can inspect lexical closures without exporting a runtime test API. Search
-- only function upvalues and require the production resolver's exact name.
local function FindCombatIcon(callback, visited)
    if visited[callback] then return end
    visited[callback] = true
    local index = 1
    while true do
        local name, value = debug.getupvalue(callback, index)
        if not name then return end
        if name == "CombatIcon" then
            assert(type(value) == "function", "production CombatIcon upvalue is not callable")
            return value
        end
        if type(value) == "function" then
            local found = FindCombatIcon(value, visited)
            if found then return found end
        end
        index = index + 1
    end
end
local function SCT(scrolling, setup)
    local context = H.New()
    local env = context.env
    context.settings.sctStyle = scrolling and "msbt" or "enemy"
    context.settings.sctScale = 1
    context.settings.sctFont = "default"
    context.settings.sctShortNumbers = false
    context.settings.sctNormalHits, context.settings.sctCriticalHits = true, true
    context.settings.sctAutoAttacks, context.settings.sctMisses = true, true
    context.settings.damageIcons, context.settings.nameplatesBossGuardiansOnly = false, false
    env.SurvivorsDragonUiSctMode = "on"
    env.GetCVar = function(name)
        assert(name == "CombatDamage", "unexpected native preference read")
        return "0"
    end
    env.SetCVar = function() error("a style change must not write native preferences") end
    env.ShowNameplates = function() context.backing = true end
    env.HideNameplates = function() context.backing = false end
    env.hooksecurefunc = function(name, callback)
        local native = assert(env[name])
        env[name] = function(...)
            native(...)
            callback(...)
        end
    end
    -- The controller compacts Lua 5.0 queues explicitly; insert/remove also
    -- update that remembered length on the real native boundary.
    local insert, remove = env.table.insert, env.table.remove
    env.table.insert = function(list, ...)
        insert(list, ...)
        env.table.setn(list, #list)
    end
    env.table.remove = function(list, index)
        local value = remove(list, index)
        env.table.setn(list, #list)
        return value
    end
    local create = env.CreateFrame
    env.CreateFrame = function(kind, name, parent)
        local object = create(kind, name, parent)
        local setPoint = object.SetPoint
        object.SetPoint = function(self, point, relative, relativePoint, x, y)
            setPoint(self, point, relative, relativePoint, x, y)
            self.anchor = { relative = relative, point = relativePoint, x = x, y = y }
        end
        object.SetScale = function(self, value)
            context.writes.SetScale = (context.writes.SetScale or 0) + 1
            self.scale = value
        end
        object.SetParent = function(self, value)
            context.writes.SetParent = (context.writes.SetParent or 0) + 1
            self.parent = value
            context:Visibility()
        end
        if kind == "Frame" and parent == env.WorldFrame then
            local setAllPoints = object.SetAllPoints
            object.SetAllPoints = function(self, relative)
                setAllPoints(self, relative)
                if relative == env.WorldFrame then context.textRoot = self end
            end
        end
        return object
    end
    env.WorldFrame = env.CreateFrame("Frame", "WorldFrame", env.UIParent)
    env.WorldFrame.width, env.WorldFrame.height = 1600, 900
    env.WorldFrame.GetNumChildren = function() return 0 end
    env.WorldFrame.GetChildren = function() end
    -- No enemy plates exist in this fixture. Position/mask methods must remain unused.
    local function NoPlateRead() error("fixed scrolling must not read or mask enemy plates") end
    env.WorldFrame.GetCenter = NoPlateRead
    env.WorldFrame.DisableDrawLayer, env.WorldFrame.EnableDrawLayer = NoPlateRead, NoPlateRead
    env.WorldFrame.GetHitRectInsets, env.WorldFrame.SetHitRectInsets = NoPlateRead, NoPlateRead
    function env.DFRL:GetInfoOrCons(kind)
        local root = "Interface\\AddOns\\SurvivorsDragonUi\\"
        return kind == "tex" and root .. "media\\tex\\" or root
    end
    env.T.SetFont = function(object, size, flags)
        object:SetFont("DEFAULT_TEST", size, flags)
        object.GetStringWidth = function(self) return string.len(self:GetText()) * 9 end
        return true
    end
    env.T.SourceIconFallback = "Interface\\Icons\\INV_Misc_QuestionMark"
    env.T.NameplateCombatEventHandlers = { TEST_COMBAT = true }
    env.T.ParseNameplateCombatEvent = function(_, message)
        return {
            kind = "damage",
            damageType = "autoattack",
            sourceName = "Player",
            targetName = "Enemy",
            amount = tonumber(message),
            critical = context.critical,
        }
    end
    local register, listen = env.DFRL.layout.Register, env.DFRL.layout.ListenVisibility
    env.DFRL.layout.Register = function(name, frame, anchor, options)
        assert(name == "sctMSBT", "unexpected scrolling Layout group")
        context.scrollRoot, context.scrollOptions = frame, options
        register(name, frame, anchor)
    end
    env.DFRL.layout.ListenVisibility = function(name, callback)
        context.scrollVisibility = callback
        listen(name, callback)
    end
    function context:SetScrollHidden(hidden)
        self:SetLayoutHidden(hidden)
        self.scrollVisibility(not hidden)
    end
    if setup then setup(context, env) end
    context:Load("core/widgets.lua")
    context:Load("modules/nameplates/sct.lua", "NameplateCombatText")
    context.controller = context:Controller("TEST_COMBAT")
    local combatIcon
    function context:LookupIcon(name, school, damageType)
        if not combatIcon then
            combatIcon = assert(
                FindCombatIcon(self.controller:GetScript("OnEvent"), {}),
                "production SCT controller has no reachable CombatIcon closure"
            )
        end
        return combatIcon({ spell = name, school = school, damageType = damageType })
    end
    function context:Hit(amount) self:Event(self.controller, "TEST_COMBAT", tostring(amount)) end
    function context:Tick(elapsed)
        self.now = self.now + elapsed
        self:Call(self.controller, "OnUpdate", elapsed)
    end
    function context:Labels()
        local labels = {}
        for _, object in ipairs(self.objects) do
            -- Native nameplate names are visible FontStrings too. Only the
            -- existing SCT holder/visual pool belongs to this assertion sink.
            local visual = object.parent
            local holder = visual and visual.parent
            local owner = holder and holder.parent
            if
                object.kind == "FontString"
                and owner
                and (owner == self.textRoot or owner == self.scrollRoot)
                and object:IsVisible()
                and object:GetText() ~= ""
            then
                table.insert(labels, object)
            end
        end
        return labels
    end
    return context
end

return SCT
