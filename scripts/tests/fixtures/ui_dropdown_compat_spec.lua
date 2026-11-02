-- CI only: production dropdown compatibility over explicit 1.12 native boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "dropdown fixtures require CI Lua 5.1")

local ERROR =
    "Interface\\FrameXML\\UIDropDownMenu.lua:156: attempt to concatenate global 'UIDROPDOWNMENU_OPEN_MENU' (a nil value)"
local function Test(name, callback)
    local ok, failure = pcall(callback)
    assert(ok, name .. ": " .. tostring(failure))
    print("PASS " .. name)
end

local function Kit()
    local c = H.New()
    local env = c.env
    local create = c.Object
    function c:Object(...)
        local object = create(self, ...)
        function object:GetID() return self.id end
        function object:SetID(id) self.id = id end
        function object:IsMouseWheelEnabled() return self.mouseWheel end
        function object:EnableMouseWheel(enabled) self.mouseWheel = enabled end
        function object:LockHighlight() self.highlightLocked = true end
        return object
    end
    env.UIDROPDOWNMENU_MAXBUTTONS, env.UIDROPDOWNMENU_MAXLEVELS = 32, 3
    env.UIDROPDOWNMENU_MENU_LEVEL = 1
    for level = 1, 3 do
        local list = env.CreateFrame("Button", "DropDownList" .. level, env.UIParent)
        list.id, list.numButtons, list.maxWidth = level, 0, 0
        list:Hide()
        for slot = 1, 32 do
            local button = list:CreateTexture("DropDownList" .. level .. "Button" .. slot)
            -- Explicit native button shape; production owns paging and IDs.
            button.kind, button.id = "Button", slot
            button:CreateTexture(button:GetName() .. "Check")
            button:Hide()
        end
    end
    env.UIDropDownMenu_GetSelectedID = function(frame)
        if frame.selectedID ~= nil then return frame.selectedID end
        local list = env["DropDownList" .. env.UIDROPDOWNMENU_MENU_LEVEL]
        for slot = 1, 32 do
            local button = env[list:GetName() .. "Button" .. slot]
            if
                (frame.selectedName and button:GetText() == frame.selectedName)
                or (frame.selectedValue and button.value == frame.selectedValue)
            then
                return slot
            end
        end
    end
    env.UIDropDownMenu_AddButton = function(info, level)
        level = level or 1
        local list = env["DropDownList" .. level]
        local slot = list.numButtons + 1
        if slot > 32 then error(ERROR, 0) end
        c.adds = (c.adds or 0) + 1
        local button = env[list:GetName() .. "Button" .. slot]
        -- The stock placement uses GetID before the callback reads that ID.
        button.nativeRow = button:GetID()
        button:SetText(info.text or "")
        button.value, button.func, button.arg1, button.arg2 = info.value or info.text, info.func, info.arg1, info.arg2
        button.checked = info.checked
        button:Show()
        list.numButtons = slot
    end
    env.UIDropDownMenu_Refresh = function(frame, useValue, level)
        frame = frame or env.this
        local list = env["DropDownList" .. (level or env.UIDROPDOWNMENU_MENU_LEVEL)]
        local selected = env.UIDropDownMenu_GetSelectedID(frame)
        for slot = 1, 32 do
            local button = env[list:GetName() .. "Button" .. slot]
            local check = env[button:GetName() .. "Check"]
            if button:GetID() == selected then
                check:Show()
                frame.caption = useValue and button.value or button:GetText()
            else
                check:Hide()
            end
        end
    end
    env.UIDropDownMenu_Initialize = function(frame, initialize, mode, level)
        frame = frame or env.this
        if frame:GetName() ~= env.UIDROPDOWNMENU_OPEN_MENU then env.UIDROPDOWNMENU_MENU_LEVEL = 1 end
        env.UIDROPDOWNMENU_INIT_MENU = frame:GetName()
        for index = 1, 3 do
            if index >= env.UIDROPDOWNMENU_MENU_LEVEL or frame:GetName() ~= env.UIDROPDOWNMENU_OPEN_MENU then
                local list = env["DropDownList" .. index]
                list.numButtons, list.maxWidth = 0, 0
                for slot = 1, 32 do
                    env[list:GetName() .. "Button" .. slot]:Hide()
                end
            end
        end
        if initialize then
            frame.initialize = initialize
            initialize(level)
        end
        frame.displayMode = mode
    end
    env.UIDropDownMenu_SetSelectedID = function(frame, id, useValue)
        frame.selectedID, frame.selectedName, frame.selectedValue = id, nil, nil
        env.UIDropDownMenu_Refresh(frame, useValue)
    end
    env.CloseDropDownMenus = function(first)
        for level = first, 3 do
            env["DropDownList" .. level]:Hide()
        end
    end
    env.ScriptErrors = env.CreateFrame("Frame", "ScriptErrors", env.UIParent)
    env.ScriptErrors_Message = env.ScriptErrors:CreateFontString("ScriptErrors_Message")
    env.ScriptErrors:Hide()
    c.reported = {}
    env.geterrorhandler = function()
        return function(message) table.insert(c.reported, message) end
    end
    function c:Menu(count, name)
        local menu = env.CreateFrame("Frame", name or "NativeMenu", env.UIParent)
        local info = {}
        menu.initialize = function(level)
            for index = 1, count do
                -- Reused native info tables must be copied before the next row.
                info.text, info.value = "Choice " .. index, "value:" .. index
                info.arg1, info.arg2 = index, menu
                info.func = function(first, second)
                    assert(second == menu and first == env.this:GetID(), "callback arguments exchanged rows")
                    env.UIDropDownMenu_SetSelectedID(menu, env.this:GetID(), 1)
                end
                env.UIDropDownMenu_AddButton(info, level)
            end
        end
        return menu
    end
    function c:Open(menu, level)
        level = level or 1
        env.UIDROPDOWNMENU_OPEN_MENU, env.UIDROPDOWNMENU_MENU_LEVEL = menu:GetName(), level
        env.UIDropDownMenu_Initialize(menu, menu.initialize, nil, level)
        env["DropDownList" .. level]:Show()
    end
    function c:LoadCompat() self:Load("core/dropdowns.lua") end
    function c:Startup(count)
        local menu = self:Menu(count, "OptionsFrameResolutionDropDown")
        env.OptionsFrameResolutionDropDown_Initialize = menu.initialize
        local ok, failure = pcall(env.UIDropDownMenu_Initialize, menu, menu.initialize)
        assert(not ok and failure == ERROR, "startup fixture did not reproduce the native overflow")
        local choices = {}
        for index = 1, count do
            choices[index] = "mode:" .. index
        end
        env.GetScreenResolutions = function() return unpack(choices) end
        env.OptionsFrameResolutionDropDown_OnLoad = function()
            assert(env.this == menu, "startup recovery lost the native this")
            env.UIDropDownMenu_Initialize(env.this, env.OptionsFrameResolutionDropDown_Initialize)
            env.UIDropDownMenu_SetSelectedID(env.this, 57, 1)
            env.this:SetWidth(90)
        end
        env.ScriptErrors_Message:SetText(ERROR)
        env.ScriptErrors:Show()
        return menu
    end
    return c, env
end

Test("short native dropdowns keep their original selection behavior and input handlers", function()
    local c, env = Kit()
    local wheel = function() end
    env.DropDownList1:SetScript("OnMouseWheel", wheel)
    env.DropDownList1:EnableMouseWheel(true)
    c:LoadCompat()
    local menu = c:Menu(6)
    c:Open(menu)
    env.UIDropDownMenu_SetSelectedID(menu, 5, 1)
    assert(menu.caption == "value:5" and env.DropDownList1.numButtons == 6)
    assert(env.DropDownList1:GetScript("OnMouseWheel") == wheel and env.DropDownList1:IsMouseWheelEnabled())
    assert(not env.DropDownList1:GetScript("OnUpdate"), "compatibility installed an updater")
end)

Test("oversized menus reuse 32 buttons and preserve logical IDs, values, callbacks and row positions", function()
    local c, env = Kit()
    c:LoadCompat()
    local menu = c:Menu(80)
    local objects = #c.objects
    c:Open(menu)
    assert(env.DropDownList1.numButtons == 32 and env.UIDROPDOWNMENU_MAXBUTTONS == 32)
    env.UIDropDownMenu_SetSelectedID(menu, 57, 1)
    assert(menu.caption == "value:57", "offscreen native selection lost its caption")
    local selected
    for slot = 1, 32 do
        local button = env["DropDownList1Button" .. slot]
        assert(button.nativeRow == slot, "logical ID changed native row placement")
        if button:GetID() == 57 then selected = button end
    end
    assert(selected and selected.checked and selected.value == "value:57")
    env.this = selected
    selected.func(selected.arg1, selected.arg2)
    assert(env.UIDropDownMenu_GetSelectedID(menu) == 57)
    c:Call(env.DropDownList1, "OnMouseWheel", 1)
    assert(env.DropDownList1Button1:GetID() == 30, "wheel did not reveal retained choices")
    menu.selectedID, menu.selectedValue = nil, "value:60"
    assert(env.UIDropDownMenu_GetSelectedID(menu) == 60, "value selection returned its physical slot")
    menu.selectedValue, menu.selectedName = nil, "Choice 65"
    assert(env.UIDropDownMenu_GetSelectedID(menu) == 65, "name selection returned its physical slot")
    assert(#c.objects == objects, "paging allocated native buttons or regions")
    env.DropDownList1:Hide()
    assert(not env.DropDownList1:IsMouseWheelEnabled(), "wheel ownership survived hiding")
    local small = c:Menu(3, "AnotherNativeMenu")
    c:Open(small)
    for slot = 1, 32 do
        assert(env["DropDownList1Button" .. slot]:GetID() == slot)
    end
end)

Test("explicit checked entries remain visible across native refresh and paging", function()
    local c, env = Kit()
    c:LoadCompat()
    local menu = c:Menu(50)
    menu.initialize = function(level)
        for index = 1, 50 do
            env.UIDropDownMenu_AddButton({ text = "Choice " .. index, checked = index == 37 and 1 or nil }, level)
        end
    end
    c:Open(menu)
    for _ = 1, 3 do
        c:Call(env.DropDownList1, "OnMouseWheel", -1)
    end
    assert(env.DropDownList1Button28:GetID() == 37 and env.DropDownList1Button28.checked)
    assert(env.DropDownList1Button28Check:IsShown(), "native refresh removed an explicit checkbox")
end)

Test("parent scrolling closes submenus and preserves later foreign wheel ownership", function()
    local c, env = Kit()
    c:LoadCompat()
    local parent, child = c:Menu(50), c:Menu(40, "NativeSubmenu")
    c:Open(parent)
    env.UIDROPDOWNMENU_MENU_LEVEL = 2
    env.UIDropDownMenu_Initialize(parent, child.initialize, nil, 2)
    env.DropDownList2:Show()
    assert(env.DropDownList2:IsShown())
    c:Call(env.DropDownList1, "OnMouseWheel", -1)
    assert(
        not env.DropDownList2:IsShown() and env.UIDROPDOWNMENU_MENU_LEVEL == 1,
        "parent scroll retained an obsolete submenu"
    )
    local foreign = function() end
    env.DropDownList1:SetScript("OnMouseWheel", foreign)
    env.DropDownList1:EnableMouseWheel(false)
    env.DropDownList1:Hide()
    assert(env.DropDownList1:GetScript("OnMouseWheel") == foreign and not env.DropDownList1:IsMouseWheelEnabled())
end)

Test("known startup overflow is replayed before retiring only its matching popup", function()
    local c, env = Kit()
    local menu = c:Startup(80)
    local previousThis = {}
    env.this = previousThis
    c:LoadCompat()
    assert(not env.ScriptErrors:IsShown(), "repaired startup overflow retained its popup")
    assert(menu:GetWidth() == 90 and menu.selectedID == 57 and menu.caption == "value:57")
    assert(env.this == previousThis and #c.reported == 0, "recovery changed unrelated context or errors")
end)

Test("Benilla entry rows recover through their own setup and retain their native values", function()
    local c, env = Kit()
    local row = env.CreateFrame("Frame", "BenillaOptionsTestRow", env.UIParent)
    row.entries = {}
    for index = 1, 40 do
        row.entries[index] = { text = "Native " .. index, value = index * 2 }
    end
    local dropdown = env.CreateFrame("Frame", "BenillaOptionsTestRowDropdown", row)
    env.BenillaOptionsDropdownRow_InitMenu = function()
        for _, entry in ipairs(row.entries) do
            env.UIDropDownMenu_AddButton(entry)
        end
    end
    dropdown.initialize = env.BenillaOptionsDropdownRow_InitMenu
    env.BenillaOptionsDropdownRow_Setup = function(owner, entries)
        assert(owner == row and entries == row.entries)
        env.UIDropDownMenu_Initialize(dropdown, env.BenillaOptionsDropdownRow_InitMenu)
        row.hoverReady = true
    end
    env.EnumerateFrames = function(previous)
        if not previous then return dropdown end
    end
    env.ScriptErrors_Message:SetText(ERROR)
    env.ScriptErrors:Show()
    c:LoadCompat()
    assert(row.hoverReady and not env.ScriptErrors:IsShown(), "Benilla setup was not completed")
    env.UIDROPDOWNMENU_OPEN_MENU = dropdown:GetName()
    env.DropDownList1:Show()
    c:Call(env.DropDownList1, "OnMouseWheel", -1)
    assert(env.DropDownList1Button32.value == 70, "Benilla native choice values were remapped")
end)

Test("unrelated, unrecognized and failed startup errors remain visible", function()
    for _, kind in ipairs({ "unrelated", "unknown", "failure", "incomplete", "replaced", "foreign" }) do
        local c, env = Kit()
        c:Startup(80)
        if kind == "unrelated" then env.ScriptErrors_Message:SetText("Another native error") end
        if kind == "unknown" then env.OptionsFrameResolutionDropDown_Initialize = function() end end
        if kind == "foreign" then env.UIDROPDOWNMENU_OPEN_MENU = "ForeignMenu" end
        if kind == "failure" then env.OptionsFrameResolutionDropDown_OnLoad = function() error("other failure") end end
        if kind == "incomplete" then env.OptionsFrameResolutionDropDown_OnLoad = function() end end
        if kind == "replaced" then
            local onLoad = env.OptionsFrameResolutionDropDown_OnLoad
            env.OptionsFrameResolutionDropDown_OnLoad = function()
                onLoad()
                env.ScriptErrors_Message:SetText("New unrelated error")
            end
        end
        c:LoadCompat()
        assert(env.ScriptErrors:IsShown(), "compatibility dismissed an unrepaired error")
        if kind == "failure" then assert(#c.reported == 1 and string.find(c.reported[1], "other failure", 1, true)) end
    end
end)

Test("partial native kits stay untouched and unrelated initializer failures still propagate", function()
    local c, env = Kit()
    local original = env.UIDropDownMenu_Initialize
    env.DropDownList2.IsMouseWheelEnabled = false
    c:LoadCompat()
    assert(env.UIDropDownMenu_Initialize == original, "partial kit was wrapped")
    c, env = Kit()
    c:LoadCompat()
    local menu = c:Menu(50)
    local initialize = menu.initialize
    local ok, failure = pcall(env.UIDropDownMenu_Initialize, menu, function() error("initializer failed") end)
    assert(not ok and string.find(failure, "initializer failed", 1, true), "initializer failure was swallowed")
    menu.initialize = initialize
    c:Open(menu)
    assert(env.DropDownList1.numButtons == 32, "failed initialization poisoned the next dropdown")
end)

Test("only the exact reported error is suppressed in chat and the native popup", function()
    local c, env = Kit()
    local messages, shown = {}, 0
    env.DEFAULT_CHAT_FRAME = {
        AddMessage = function(_, message) table.insert(messages, message) end,
    }
    env.seterrorhandler = function(handler) c.handler = handler end
    local nativeShow = env.ScriptErrors.Show
    env.ScriptErrors:SetScript("OnShow", function()
        assert(env.this == env.ScriptErrors, "popup filter changed native callback context")
        shown = shown + 1
    end)
    env.ScriptErrors_Message:SetText(ERROR)
    env.ScriptErrors:Show()
    c:Load("core/error.lua")
    c:LoadCompat()
    assert(env.ScriptErrors:IsShown(), "suppression ran before existing startup recovery")
    local controller = c:Controller("ADDON_LOADED")
    c:Event(controller, "ADDON_LOADED", "SurvivorsDragonUi")
    assert(not env.ScriptErrors:IsShown(), "pre-addon matching popup remained visible")
    local before = shown
    for _, message in ipairs({
        ERROR,
        (string.gsub(ERROR, "\\", "/")),
        (string.gsub(ERROR, "'", '"')),
        (string.gsub(ERROR, "'UIDROPDOWNMENU_OPEN_MENU", string.char(96) .. "UIDROPDOWNMENU_OPEN_MENU")),
    }) do
        for _ = 1, 4 do
            c.handler(message)
        end
        env.ScriptErrors_Message:SetText(message)
        nativeShow(env.ScriptErrors)
        assert(not env.ScriptErrors:IsShown(), "retained native Show exposed the matching error")
    end
    assert(#messages == 0 and shown == before, "suppressed error reached chat or popup presentation")
    for _, message in ipairs({
        (string.gsub(ERROR, ":156:", ":157:")),
        (string.gsub(ERROR, "UIDropDownMenu%.lua", "AnotherFile.lua")),
        (string.gsub(ERROR, "UIDROPDOWNMENU_OPEN_MENU", "UIDROPDOWNMENU_OTHER")),
        (string.gsub(ERROR, "concatenate", "index")),
        (string.gsub(ERROR, "a nil value", "a string value")),
        "Other addon: " .. ERROR,
        ERROR .. "\nAnother failure",
    }) do
        local count = #messages
        for _ = 1, 4 do
            c.handler(message)
        end
        assert(#messages == count + 3, "unrelated error lost its two messages and throttle notice")
        assert(string.find(messages[count + 1], message, 1, true), "unrelated diagnostic was rewritten")
        assert(string.find(messages[count + 3], "ERROR SPAM THROTTLED", 1, true))
        env.ScriptErrors_Message:SetText(message)
        nativeShow(env.ScriptErrors)
        assert(env.ScriptErrors:IsShown(), "near-match error popup was suppressed")
        env.ScriptErrors:Hide()
        before = before + 1
    end
    assert(shown == before, "unrelated popup lost its previous OnShow callback")
    local hook = env.ScriptErrors:GetScript("OnShow")
    c:ResetCounts()
    c:Event(controller, "ADDON_LOADED", "AnotherAddon")
    c:NoPresentationWrites()
    assert(env.ScriptErrors:GetScript("OnShow") == hook, "repeated addon loads stacked popup hooks")
    local foreign = 0
    env.ScriptErrors:SetScript("OnShow", function() foreign = foreign + 1 end)
    c:Event(controller, "ADDON_LOADED", "LaterAddon")
    env.ScriptErrors_Message:SetText("A later unrelated error")
    nativeShow(env.ScriptErrors)
    assert(env.ScriptErrors:IsShown() and foreign == 1, "later popup callback was discarded")
end)

Test("exact suppression does not require the native dropdown pool or a popup frame", function()
    local c, env = Kit()
    env.UIDROPDOWNMENU_MAXBUTTONS, env.ScriptErrors, env.ScriptErrors_Message = nil, nil, nil
    local messages = {}
    env.DEFAULT_CHAT_FRAME = {
        AddMessage = function(_, message) table.insert(messages, message) end,
    }
    env.seterrorhandler = function(handler) c.handler = handler end
    c:Load("core/error.lua")
    c:LoadCompat()
    c:Event(c:Controller("ADDON_LOADED"), "ADDON_LOADED", "SurvivorsDragonUi")
    c.handler(ERROR)
    c.handler("An unrelated error")
    assert(#messages == 1 and string.find(messages[1], "An unrelated error", 1, true))
    assert(not env.T.IsSuppressedDropdownError(nil) and not env.T.IsSuppressedDropdownError({}))
end)
