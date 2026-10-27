-- CI-only native setup shared by scrolling and nameplate lifecycle fixtures.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
local function SCT(scrolling, setup)
    local context = H.New()
    local env = context.env
    context.settings.sctMSBTStyle = scrolling
    context.settings.sctScale = 1
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
    if setup then setup(context, env) end
    context:Load("modules/nameplates/sct.lua", "NameplateCombatText")
    context.controller = context:Controller("TEST_COMBAT")
    function context:Hit(amount) self:Event(self.controller, "TEST_COMBAT", tostring(amount)) end
    function context:Tick(elapsed)
        self.now = self.now + elapsed
        self:Call(self.controller, "OnUpdate", elapsed)
    end
    function context:Labels()
        local labels = {}
        for _, object in ipairs(self.objects) do
            if object.kind == "FontString" and object:IsVisible() and object:GetText() ~= "" then
                table.insert(labels, object)
            end
        end
        return labels
    end
    return context
end

return SCT
