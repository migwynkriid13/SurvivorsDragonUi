-- CI only: real action-bar ownership over explicit native frame boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "default action bar fixtures require CI Lua 5.1")

local function Test(name, callback)
    local ok, message = pcall(callback)
    assert(ok, name .. ": " .. tostring(message))
    print("PASS " .. name)
end

Test("SDUI action bar defaults and transactions preserve the selected native mode", function()
    local c = H.New()
    local env = c.env
    c:Load("core/display.lua", "Display")
    local display = env.DFRL.display
    assert(display.Get("customActionBar") == true, "new setups must retain the SDUI bar")
    for _, invalid in ipairs({ "true", "false", 0, 1, {} }) do
        assert(display.Copy({ customActionBar = invalid }).customActionBar == true)
    end
    assert(display.Copy({ customActionBar = false }).customActionBar == false)
    display.BeginEdit()
    display.Set("customActionBar", false)
    assert(not display.Get("customActionBar") and not env.SurvivorsDragonUiDisplay, "preview saved native mode")
    display.FinishEdit(false)
    assert(display.Get("customActionBar"), "Cancel retained the native bar preview")
    display.BeginEdit()
    display.Set("customActionBar", false)
    display.FinishEdit(true)
    assert(env.SurvivorsDragonUiDisplay.customActionBar == false)
    local function Copy(value)
        local result = {}
        for key, item in pairs(value) do
            result[key] = item
        end
        return result
    end
    env.DFRL.layout.Copy, env.DFRL.layout.Snapshot, env.DFRL.layout.Load =
        Copy, function() return {} end, function() end
    env.DFRL.runFont = { Copy = Copy, Snapshot = function() return {} end, Load = function() end }
    c:Load("core/profiles.lua", "Profiles")
    local profiles = env.DFRL.profiles
    env.DFRL.layout.ConfirmEdit = function()
        display.FinishEdit(true)
        profiles.FinishEdit(true)
        return true
    end
    display.BeginEdit()
    profiles.BeginEdit()
    assert(profiles.Save("Native bottom bar", false))
    assert(env.SurvivorsDragonUiProfiles["Native bottom bar"].display.customActionBar == false)
    display.Reset()
    assert(display.Get("customActionBar"), "full reset did not restore the SDUI default")
    display.BeginEdit()
    profiles.BeginEdit()
    assert(profiles.Load("Native bottom bar"))
    assert(not display.Get("customActionBar") and not env.SurvivorsDragonUiDisplay, "profile load committed early")
    profiles.FinishEdit(false)
    display.FinishEdit(false)
    assert(display.Get("customActionBar"), "discarded profile load changed the confirmed bar")
    display.BeginEdit()
    profiles.BeginEdit()
    assert(profiles.Load("Native bottom bar"))
    profiles.FinishEdit(true)
    display.FinishEdit(true)
    assert(not display.Get("customActionBar"))
    display.Reset()
    assert(display.Get("customActionBar"), "reset outside editing retained the native choice")
end)

local function Bar(custom, performance)
    local c = H.New()
    local env, create = c.env, c.Object
    local function Write(name) c.writes[name] = (c.writes[name] or 0) + 1 end
    function c:Object(...)
        local object = create(self, ...)
        object.points, object.regions = {}, {}
        function object:GetObjectType() return self.kind end
        function object:SetParent(parent)
            Write("SetParent")
            self.parent = parent
            c:Visibility()
        end
        function object:GetNumPoints() return #self.points end
        function object:GetPoint(index) return unpack(self.points[index or 1] or {}) end
        function object:ClearAllPoints()
            Write("ClearAllPoints")
            self.points = {}
        end
        function object:SetPoint(...)
            Write("SetPoint")
            local value = { ... }
            for index, point in ipairs(self.points) do
                if point[1] == value[1] then
                    self.points[index] = value
                    return
                end
            end
            table.insert(self.points, value)
        end
        function object:SetAllPoints(parent)
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", parent or self.parent, "TOPLEFT", 0, 0)
            self:SetPoint("BOTTOMRIGHT", parent or self.parent, "BOTTOMRIGHT", 0, 0)
        end
        function object:GetRegions() return unpack(self.regions) end
        function object:GetChildren()
            local children = {}
            for _, candidate in ipairs(c.objects) do
                if candidate.parent == self and candidate.kind ~= "Texture" and candidate.kind ~= "FontString" then
                    table.insert(children, candidate)
                end
            end
            return unpack(children)
        end
        function object:CreateTexture(name, layer)
            local texture = c:Object("Texture", name, self)
            texture.layer = layer or "ARTWORK"
            table.insert(self.regions, texture)
            return texture
        end
        function object:CreateFontString(name, layer)
            local label = c:Object("FontString", name, self)
            label.layer = layer or "OVERLAY"
            table.insert(self.regions, label)
            return label
        end
        function object:GetScale() return self.scale or 1 end
        function object:SetScale(value)
            Write("SetScale")
            self.scale = value
        end
        function object:GetFrameStrata() return self.strata or "MEDIUM" end
        function object:SetFrameStrata(value)
            Write("SetFrameStrata")
            self.strata = value
        end
        function object:IsMouseEnabled() return self.mouse ~= false end
        function object:EnableMouse(value)
            Write("EnableMouse")
            self.mouse = value
        end
        function object:IsKeyboardEnabled() return self.keyboard == true end
        function object:EnableKeyboard(value)
            Write("EnableKeyboard")
            self.keyboard = value
        end
        function object:IsEventRegistered(name) return self.events[name] == true end
        function object:RegisterForDrag(...) self.drag = { ... } end
        function object:RegisterForClicks(...) self.clicks = { ... } end
        function object:SetID(value) self.id = value end
        function object:GetID() return self.id end
        function object:SetClampedToScreen(value) self.clamped = value end
        function object:SetBlendMode(value) self.blend = value end
        function object:GetBlendMode() return self.blend or "BLEND" end
        function object:SetTexCoord(...)
            Write("SetTexCoord")
            self.coords = { ... }
        end
        function object:GetTexCoord() return unpack(self.coords or { 0, 1, 0, 1 }) end
        function object:SetVertexColor(...)
            Write("SetVertexColor")
            self.color = { ... }
        end
        function object:GetVertexColor() return unpack(self.color or { 1, 1, 1, 1 }) end
        function object:GetDrawLayer() return self.layer or "ARTWORK" end
        function object:SetDrawLayer(value) self.layer = value end
        function object:GetJustifyH() return self.justifyH or "CENTER" end
        function object:SetJustifyH(value)
            Write("SetJustifyH")
            self.justifyH = value
        end
        function object:GetJustifyV() return self.justifyV or "MIDDLE" end
        function object:SetJustifyV(value)
            Write("SetJustifyV")
            self.justifyV = value
        end
        function object:GetShadowColor() return unpack(self.shadowColor or { 0, 0, 0, 1 }) end
        function object:SetShadowColor(...)
            Write("SetShadowColor")
            self.shadowColor = { ... }
        end
        function object:GetShadowOffset() return unpack(self.shadowOffset or { 0, 0 }) end
        function object:SetShadowOffset(...)
            Write("SetShadowOffset")
            self.shadowOffset = { ... }
        end
        for _, name in ipairs({ "Normal", "Pushed", "Highlight", "Checked", "Disabled" }) do
            local key = name
            object["Get" .. key .. "Texture"] = function(self) return self[key] end
            object["Set" .. key .. "Texture"] = function(self, value)
                Write("Set" .. key .. "Texture")
                if type(value) == "table" or value == nil then
                    self[key] = value
                else
                    self[key] = self[key] or self:CreateTexture(nil, "ARTWORK")
                    self[key]:SetTexture(value)
                end
            end
        end
        return object
    end
    env.MainMenuBar = env.CreateFrame("Frame", "MainMenuBar", env.UIParent)
    env.MainMenuBarArtFrame = env.CreateFrame("Frame", "MainMenuBarArtFrame", env.MainMenuBar)
    for index = 1, 4 do
        local texture = env.MainMenuBarArtFrame:CreateTexture("MainMenuBarTexture" .. (index - 1), "BACKGROUND")
        texture:SetTexture("Native\\Bar" .. index)
    end
    for _, name in ipairs({
        "ActionBarUpButton",
        "ActionBarDownButton",
        "MainMenuBarPageNumber",
        "MultiBarBottomLeft",
        "MultiBarBottomRight",
        "MultiBarLeft",
        "MultiBarRight",
        "PetActionBarFrame",
        "ShapeshiftBarFrame",
        "BonusActionBarFrame",
        "PossessBarFrame",
        "ExhaustionTick",
        "CharacterMicroButton",
        "TalentMicroButton",
        "MainMenuMicroButton",
        "SpellbookMicroButton",
        "WorldMapMicroButton",
        "QuestLogMicroButton",
        "SocialsMicroButton",
        "HelpMicroButton",
        "MainMenuBarBackpackButton",
        "CharacterBag0Slot",
        "CharacterBag1Slot",
        "CharacterBag2Slot",
        "CharacterBag3Slot",
        "KeyRingButton",
    }) do
        local frame = env.CreateFrame("Frame", name, env.MainMenuBar)
        frame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
        frame:SetScript("OnEvent", function() c.nativeEvent = (c.nativeEvent or 0) + 1 end)
        local shownName = name
        frame.nativeOnShow = function() c.nativeShown = shownName end
        frame:SetScript("OnShow", frame.nativeOnShow)
    end
    for _, name in ipairs({
        "MainMenuBarLeftEndCap",
        "MainMenuBarRightEndCap",
        "SlidingActionBarTexture0",
        "SlidingActionBarTexture1",
        "BonusActionBarTexture0",
        "BonusActionBarTexture1",
        "ShapeshiftBarLeft",
        "ShapeshiftBarMiddle",
        "ShapeshiftBarRight",
    }) do
        env[name] = env.MainMenuBarArtFrame:CreateTexture(name, "BACKGROUND")
        env[name]:SetTexture("Native\\" .. name)
    end
    env.MicroButtonPortrait = env.MainMenuBarArtFrame:CreateTexture("MicroButtonPortrait", "ARTWORK")
    env.MicroButtonPortrait:SetTexture("Native\\MicroPortrait")
    c.native = { globals = {}, buttons = {}, textures = {} }
    for index = 1, 12 do
        local name = "ActionButton" .. index
        local button = env.CreateFrame("Button", name, env.MainMenuBarArtFrame)
        button.id, button.slot = index, index
        button:SetWidth(36)
        button:SetHeight(36)
        button:SetPoint("BOTTOMLEFT", env.MainMenuBarArtFrame, "BOTTOMLEFT", index * 40, 7)
        button:SetFrameStrata("MEDIUM")
        button:SetFrameLevel(8)
        button:SetScale(0.9)
        button:SetAlpha(0.8)
        button:RegisterForDrag("LeftButton")
        button:SetScript("OnClick", function() c.nativeClick = index end)
        button:SetScript("OnDragStart", function() c.nativeDrag = index end)
        button:SetScript("OnReceiveDrag", function() c.nativeDrop = index end)
        local hotkey = button:CreateFontString(name .. "HotKey", "OVERLAY")
        hotkey:SetText("Key" .. index)
        hotkey:SetFont("NATIVE_FONT", 9, "OUTLINE")
        local macro = button:CreateFontString(name .. "Name", "OVERLAY")
        macro:SetText("Native macro " .. index)
        macro:SetPoint("BOTTOM", button, "BOTTOM", 1, 2)
        macro:SetFont("NATIVE_FONT", 10, "")
        for _, kind in ipairs({ "Normal", "Pushed", "Highlight", "Checked" }) do
            button["Set" .. kind .. "Texture"](button, "Native\\" .. name .. kind)
        end
        local cooldown = env.CreateFrame("Model", name .. "Cooldown", button)
        cooldown.start, cooldown.duration, cooldown.stopping = 1, 10, 0
        cooldown:SetScript("OnUpdateModel", function() c.nativeModel = index end)
        c.native.buttons[index] = {
            parent = button:GetParent(),
            point = { button:GetPoint() },
            click = button:GetScript("OnClick"),
            drag = button:GetScript("OnDragStart"),
            drop = button:GetScript("OnReceiveDrag"),
            highlight = button:GetHighlightTexture(),
            highlightPath = button:GetHighlightTexture():GetTexture(),
            model = cooldown:GetScript("OnUpdateModel"),
        }
    end
    for _, name in ipairs({
        "ChangeActionBarPage",
        "ActionBar_PageUp",
        "ActionBar_PageDown",
        "MultiActionBar_Update",
        "ShowBonusActionBar",
        "HideBonusActionBar",
        "ActionButtonDown",
        "ActionButtonUp",
        "ActionButton_UpdateHotkeys",
        "MultiActionButtonDown",
        "MultiActionButtonUp",
        "BonusActionButtonDown",
        "BonusActionButtonUp",
        "PetActionButtonDown",
        "PetActionButtonUp",
        "ShapeshiftBar_ChangeForm",
    }) do
        local key = name
        env[key] = function(id)
            c.nativeFunction, c.nativeFunctionId = key, id
            return "native-" .. key
        end
        c.native.globals[name] = env[name]
    end
    c.native.globals.ActionButton_GetPagedID = env.ActionButton_GetPagedID
    env.CURRENT_ACTIONBAR_PAGE = 2
    env.ActionButton_Update = function() c.nativeUpdates = (c.nativeUpdates or 0) + 1 end
    env.UseAction = function(slot) c.used = slot end
    env.ActionButton_UpdateState = function() c.nativeState = true end
    env.IsShiftKeyDown = function() return false end
    env.ReloadUI = function() c.reloaded = true end
    c.settings = {
        customActionBar = custom ~= false,
        performanceMode = performance == true,
        lockActionButtons = true,
        cooldownNumbers = false,
        showGryphons = false,
        attachJewelry = true,
        attachTally = true,
        attachXP = true,
    }
    env.DFRL.layout.IsHidden = function() return false end
    c:Load("modules/bars/bars.lua", "Bars")
    function c:World(event)
        local listeners = {}
        for _, object in ipairs(self.objects) do
            if object.events[event] then table.insert(listeners, object) end
        end
        for _, object in ipairs(listeners) do
            if object.events[event] then self:Event(object, event) end
        end
    end
    return c, env
end

local function NativeButtons(c, env)
    for index = 1, 12 do
        local button, original = env["ActionButton" .. index], c.native.buttons[index]
        local point = { button:GetPoint() }
        assert(button:GetParent() == original.parent, "native button retained the custom parent")
        for component = 1, 5 do
            assert(point[component] == original.point[component], "native button retained custom anchors")
        end
        assert(button:GetWidth() == 36 and button:GetHeight() == 36 and button:GetScale() == 0.9)
        assert(button:GetAlpha() == 0.8 and button:GetFrameStrata() == "MEDIUM" and button:GetFrameLevel() == 8)
        assert(button:GetScript("OnClick") == original.click and button:GetScript("OnDragStart") == original.drag)
        assert(button:GetScript("OnReceiveDrag") == original.drop, "native drag/drop handler did not restore")
        assert(
            button:GetHighlightTexture():GetTexture() == original.highlightPath,
            "native highlight artwork did not restore"
        )
        assert(env[button:GetName() .. "HotKey"]:GetText() == "Key" .. index)
        local face, size, flags = env[button:GetName() .. "Name"]:GetFont()
        assert(face == "NATIVE_FONT" and size == 10 and flags == "", "native macro font did not restore")
        assert(env.ActionButton_GetPagedID(button) == index, "native slot mapping retained the SDUI slot remap")
        assert(env[button:GetName() .. "Cooldown"]:GetScript("OnUpdateModel") == original.model)
    end
    assert(env.MainMenuBar:IsMouseEnabled() and env.MainMenuBarArtFrame:IsMouseEnabled())
    assert(env.ActionBarUpButton.events.ACTIONBAR_PAGE_CHANGED, "bar ownership removed native event registration")
    assert(
        env.ActionBarUpButton:GetScript("OnShow") == env.ActionBarUpButton.nativeOnShow,
        "native bar retained an addon visibility guard"
    )
    for index = 0, 3 do
        local texture = env["MainMenuBarTexture" .. index]
        assert(texture:IsShown() and texture:GetTexture() == "Native\\Bar" .. (index + 1), "native bar art was lost")
    end
    assert(env.MainMenuBarLeftEndCap:GetTexture() == "Native\\MainMenuBarLeftEndCap")
    assert(
        env.CharacterMicroButton:IsShown() and env.TalentMicroButton:IsShown() and env.MicroButtonPortrait:IsShown(),
        "native mode retained suppression of the default micro-button row"
    )
    for _, name in ipairs({
        "MainMenuBarBackpackButton",
        "CharacterBag0Slot",
        "CharacterBag1Slot",
        "CharacterBag2Slot",
        "CharacterBag3Slot",
        "KeyRingButton",
    }) do
        local button = env[name]
        assert(button:IsShown() and button:IsMouseEnabled(), "native bar did not restore bag input: " .. name)
        assert(
            button:GetScript("OnShow") == button.nativeOnShow,
            "native bag retained a custom visibility guard: " .. name
        )
        assert(button.events.ACTIONBAR_PAGE_CHANGED, "bar ownership removed native bag events: " .. name)
    end
end

Test("native action bar selection restores stock buttons art input and default paging", function()
    for _, performance in ipairs({ false, true }) do
        local c, env = Bar(false, performance)
        NativeButtons(c, env)
        assert(
            not env.DFRL_ActionBar and not env.ActionButton1.DFRL_BorderOverlay,
            "initial native mode prepared custom action-bar skins"
        )
        for name, callback in pairs(c.native.globals) do
            assert(env[name] == callback, "initial native mode replaced " .. name)
        end
        c:Call(env.ActionButton7, "OnClick", "LeftButton")
        assert(c.nativeClick == 7, "native action bar used the addon click handler")
        env.ActionButtonDown(12)
        assert(c.nativeFunction == "ActionButtonDown" and c.nativeFunctionId == 12)
        env.ActionBar_PageUp()
        assert(c.nativeFunction == "ActionBar_PageUp", "native paging was still forced to page one")
        assert(not env.DFRL.ActionBarAttached("attachJewelry") and not env.DFRL.ActionBarAttached("attachTally"))
        assert(c.settings.attachJewelry and c.settings.attachTally, "native selection rewrote saved attachment choices")
        local allocated = #c.objects
        c:ResetCounts()
        c:SetSetting("customActionBar", false)
        c:NoPresentationWrites()
        assert(#c.objects == allocated, "unchanged native choice allocated new artwork")
    end
end)

Test("preview switching reuses the custom bar and restores native state on every exit", function()
    for _, performance in ipairs({ false, true }) do
        local c, env = Bar(true, performance)
        assert(env.DFRL.mainBar:IsVisible(), "SDUI action bar was not enabled by default")
        assert(env.ActionButton_GetPagedID(env.ActionButton7) == 12 and env.ActionButton7:GetID() == 7)
        assert(env.DFRL.ActionBarAttached("attachJewelry") and env.DFRL.ActionBarAttached("attachTally"))
        c:SetSetting("customActionBar", false)
        NativeButtons(c, env)
        assert(not env.DFRL.mainBar:IsShown(), "native mode left custom action-bar artwork visible")
        assert(not env.DFRL.ActionBarAttached("attachJewelry") and not env.DFRL.ActionBarAttached("attachTally"))
        local allocated = #c.objects
        c:SetSetting("customActionBar", true)
        assert(env.DFRL.mainBar:IsVisible() and env.ActionButton_GetPagedID(env.ActionButton7) == 12)
        assert(#c.objects == allocated, "returning to SDUI recreated its artwork or button pool")
        c:Call(env.ActionButton7, "OnClick", "LeftButton")
        assert(c.used == 12, "restored SDUI bar lost the permanent native action slot")
        c:SetSetting("customActionBar", false)
        NativeButtons(c, env)
        assert(#c.objects == allocated, "repeated native previews grew the bar pool")
    end
end)

Test("action-bar frame snapshots restore nil handlers and textures without allocating", function()
    local c, env = Bar(false)
    local owner = env.T.NewActionBarState()
    local frame = env.CreateFrame("Frame", "NativeStateProbe", env.UIParent)
    frame:SetPoint("CENTER", env.UIParent, "CENTER", 11, 22)
    frame:SetWidth(77)
    frame:SetHeight(23)
    frame:SetScale(0.8)
    frame:SetAlpha(0.7)
    frame:EnableMouse(false)
    local texture = frame:CreateTexture(nil, "ARTWORK")
    texture:SetTexture(nil)
    texture:SetTexCoord(0.1, 0.9, 0.2, 0.8)
    local onShow = function() c.probeShown = true end
    frame:SetScript("OnShow", onShow)
    owner.Track(frame)
    local state, allocated = owner.Capture(), #c.objects
    frame:SetParent(env.MainMenuBar)
    frame:ClearAllPoints()
    frame:SetPoint("TOP", env.MainMenuBar, "TOP", 1, 2)
    frame:SetWidth(999)
    frame:SetScale(2)
    frame:SetAlpha(1)
    frame:EnableMouse(true)
    frame:SetScript("OnShow", function() error("stale custom OnShow was invoked during restore") end)
    frame:SetScript("OnHide", function() end)
    texture:SetTexture("Custom\\Wrong")
    texture:SetTexCoord(0, 1, 0, 1)
    frame:Hide()
    owner.Apply(state)
    assert(frame:GetParent() == env.UIParent and frame:GetWidth() == 77 and frame:GetHeight() == 23)
    assert(frame:GetScale() == 0.8 and frame:GetAlpha() == 0.7 and not frame:IsMouseEnabled())
    assert(frame:GetScript("OnShow") == onShow and frame:GetScript("OnHide") == nil)
    assert(texture:GetTexture() == nil and frame:IsShown(), "snapshot could not restore a nil texture or shown state")
    local _, _, _, x, y = frame:GetPoint()
    assert(x == 11 and y == 22 and #c.objects == allocated)
end)

Test("native bar keeps its native cooldown completion in both Performance Mode states", function()
    for _, performance in ipairs({ false, true }) do
        local c, env = Bar(true, performance)
        c:SetSetting("customActionBar", false)
        c.now = 20
        for index = 1, 7 do
            local model = env["ActionButton" .. index .. "Cooldown"]
            model.start, model.duration, model.stopping = 1, 1, 0
            model:Show()
        end
        c:SetSetting("performanceMode", not performance)
        c:SetSetting("performanceMode", performance)
        for index = 1, 7 do
            local model = env["ActionButton" .. index .. "Cooldown"]
            assert(model:IsShown(), "native mode suppressed the game's completion Model")
            assert(
                model.start == 1 and model.duration == 1 and model.stopping == 0,
                "bar mode rewrote native cooldown timing"
            )
            c:Call(model, "OnUpdateModel")
            assert(c.nativeModel == index, "native mode retained a custom cooldown callback")
        end
    end
end)

Test("native frame snapshots leave the separate XP owner's frames and descendants alone", function()
    local c, env = Bar(false)
    local parent = env.CreateFrame("Frame", "BarSnapshotParent", env.UIParent)
    local xp = env.CreateFrame("Frame", "SeparateXPProbe", parent)
    local text = xp:CreateFontString(nil, "OVERLAY")
    text:SetText("Initial XP")
    local owner = env.T.NewActionBarState({ [xp] = true })
    owner.Track(parent)
    local state = owner.Capture()
    parent:SetAlpha(0.4)
    xp:SetAlpha(0.25)
    text:SetText("New native XP")
    owner.Apply(state)
    assert(parent:GetAlpha() == 1)
    assert(xp:GetAlpha() == 0.25 and text:GetText() == "New native XP", "bar snapshot overwrote the XP owner's state")
end)

Test("world retirement and reload release the custom bar without changing the saved selection", function()
    local c, env = Bar(true)
    c:World("PLAYER_LEAVING_WORLD")
    NativeButtons(c, env)
    assert(c.settings.customActionBar and not env.DFRL.mainBar:IsShown(), "world cleanup changed the bar preference")
    c:World("PLAYER_ENTERING_WORLD")
    assert(env.DFRL.mainBar:IsVisible() and env.ActionButton_GetPagedID(env.ActionButton7) == 12)
    env.ReloadUI()
    assert(c.reloaded and c.settings.customActionBar)
    NativeButtons(c, env)
    assert(not env.DFRL.mainBar:IsShown(), "reload left SDUI action-bar artwork visible")
end)

Test("native ownership recaptures changed button geometry and handlers", function()
    local c, env = Bar(false)
    local click = function() c.latestNativeClick = true end
    env.ActionButton1:SetScript("OnClick", click)
    env.ActionButton1:ClearAllPoints()
    env.ActionButton1:SetPoint("BOTTOMLEFT", env.MainMenuBarArtFrame, "BOTTOMLEFT", 123, 45)
    c:SetSetting("customActionBar", true)
    c:SetSetting("customActionBar", false)
    assert(env.ActionButton1:GetScript("OnClick") == click, "native return replaced a newer native handler")
    local _, _, _, x, y = env.ActionButton1:GetPoint()
    assert(x == 123 and y == 45, "native return used stale original button geometry")
end)

Test("retained external input wrappers reach native behavior after handback", function()
    local c, env = Bar(true)
    local oldDown, oldPage = env.ActionButtonDown, env.ActionBar_PageUp
    local down = function(id)
        c.externalDown = true
        return oldDown(id)
    end
    local page = function()
        c.externalPage = true
        return oldPage()
    end
    env.ActionButtonDown, env.ActionBar_PageUp = down, page
    c:SetSetting("customActionBar", false)
    assert(
        env.ActionButtonDown == down and env.ActionBar_PageUp == page,
        "bar handback replaced a newer external owner"
    )
    env.ActionButtonDown(12)
    assert(
        c.externalDown and c.nativeFunction == "ActionButtonDown" and c.nativeFunctionId == 12,
        "retained wrapper kept the SDUI seven-button restriction"
    )
    env.ActionBar_PageUp()
    assert(c.externalPage and c.nativeFunction == "ActionBar_PageUp", "retained wrapper kept SDUI page locking")
end)

return { Bar = Bar }
