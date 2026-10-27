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

local function SCT(scrolling)
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
        assert(anchor.point == "CENTER" and anchor.x > 0, "outgoing text is not right of screen center")
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
    context:ResetCounts()
    context:Tick(0.2)
    context:NoPresentationWrites()
end)

print("PASS " .. passed .. " SCT lifecycle contracts")
