-- Keep the 1.12 native dropdown pool while paging oversized entry lists.
-- Startup recovery uses native UI initializers only; it never changes video settings.
setfenv(1, DFRL:GetEnv())

-- Shared with the error handler; suppress only the exact reported diagnostic.
function DFRL.tools.IsSuppressedDropdownError(message)
    if type(message) ~= "string" then return false end
    local normalized = string.gsub(string.gsub(message, "/", "\\"), string.char(96), "'")
    local prefix = "Interface\\FrameXML\\UIDropDownMenu.lua:156: attempt to concatenate global "
    return normalized == prefix .. "'UIDROPDOWNMENU_OPEN_MENU' (a nil value)"
        or normalized == prefix .. '"UIDROPDOWNMENU_OPEN_MENU" (a nil value)'
end

local native = {
    initialize = _G.UIDropDownMenu_Initialize,
    add = _G.UIDropDownMenu_AddButton,
    refresh = _G.UIDropDownMenu_Refresh,
    selected = _G.UIDropDownMenu_GetSelectedID,
}
local CAPACITY, MAX_ENTRIES, MAX_FRAMES = 32, 512, 4096
local states, capture = {}, nil
local function NativePool() return _G.UIDROPDOWNMENU_MAXBUTTONS == CAPACITY and _G.UIDROPDOWNMENU_MAXLEVELS == 3 end

-- Other dropdown libraries and partial native kits retain their own behavior.
if
    not NativePool()
    or type(native.initialize) ~= "function"
    or type(native.add) ~= "function"
    or type(native.refresh) ~= "function"
    or type(native.selected) ~= "function"
then
    return
end
for level = 1, 3 do
    local frame = _G["DropDownList" .. level]
    if
        not frame
        or type(frame.GetScript) ~= "function"
        or type(frame.SetScript) ~= "function"
        or type(frame.EnableMouseWheel) ~= "function"
        or type(frame.IsMouseWheelEnabled) ~= "function"
    then
        return
    end
    local buttons = {}
    for slot = 1, CAPACITY do
        local button = _G["DropDownList" .. level .. "Button" .. slot]
        if not button or type(button.SetID) ~= "function" or type(button.GetID) ~= "function" then return end
        buttons[slot] = button
    end
    states[level] = { frame = frame, buttons = buttons, level = level, count = 0, offset = 0 }
end

local function RestoreWheel(state)
    if not state.ownsWheel then return end
    if state.frame:GetScript("OnMouseWheel") == state.wheel then
        state.frame:SetScript("OnMouseWheel", state.previousWheel)
        if state.frame:IsMouseWheelEnabled() then state.frame:EnableMouseWheel(state.previousWheelEnabled) end
    end
    state.ownsWheel, state.previousWheel, state.previousWheelEnabled = nil, nil, nil
end

local function Clear(state)
    RestoreWheel(state)
    if state.count > CAPACITY then
        for slot, button in ipairs(state.buttons) do
            button:SetID(slot)
        end
    end
    state.owner, state.rows, state.count, state.offset, state.menuValue = nil, nil, 0, 0, nil
    state.selectionPrepared, state.selectedName, state.selectedValue, state.selectedIndex = nil, nil, nil, nil
end

local function SelectedIndex(state, owner)
    if owner.selectedID then return owner.selectedID end
    if
        state.selectionPrepared
        and state.selectedName == owner.selectedName
        and state.selectedValue == owner.selectedValue
    then
        return state.selectedIndex
    end
    state.selectionPrepared, state.selectedName, state.selectedValue, state.selectedIndex =
        true, owner.selectedName, owner.selectedValue, nil
    for index, row in ipairs(state.rows) do
        local caption = type(row.info.text) == "number" and tostring(row.info.text) or row.info.text
        if
            (owner.selectedName and caption == owner.selectedName)
            or (owner.selectedValue and (row.info.value or row.info.text) == owner.selectedValue)
        then
            state.selectedIndex = index
            return index
        end
    end
end

local function Paint(state, offset)
    offset = math.max(0, math.min(state.count - CAPACITY, offset))
    local frame = state.frame
    local oldMenu, oldLevel = _G.UIDROPDOWNMENU_INIT_MENU, _G.UIDROPDOWNMENU_MENU_LEVEL
    _G.UIDROPDOWNMENU_INIT_MENU, _G.UIDROPDOWNMENU_MENU_LEVEL = state.owner:GetName(), state.level
    frame.numButtons, frame.maxWidth = 0, 0
    for slot, button in ipairs(state.buttons) do
        button:Hide()
        button:SetID(slot)
    end
    local function Populate()
        for slot = 1, math.min(CAPACITY, state.count - offset) do
            local index = offset + slot
            local row, button = state.rows[index], state.buttons[slot]
            -- The native builder positions by physical ID. Callbacks and Refresh
            -- receive the original logical ID only after that placement.
            row.info.checked = row.checked
            native.add(row.info, state.level)
            button:SetID(index)
        end
        native.refresh(state.owner, nil, state.level)
        local selected = SelectedIndex(state, state.owner)
        -- Refresh handles selected IDs after placement. Explicit native checkbox
        -- flags still belong to their received entry, including multi-check lists.
        for slot = 1, math.min(CAPACITY, state.count - offset) do
            local row, button = state.rows[offset + slot], state.buttons[slot]
            button.checked = row.checked or (selected == offset + slot and 1 or nil)
            if row.checked then
                local check = _G[button:GetName() .. "Check"]
                if check then
                    button:LockHighlight()
                    check:Show()
                    button.checked = row.checked
                end
            end
        end
    end
    local ok, failure = pcall(Populate)
    _G.UIDROPDOWNMENU_INIT_MENU, _G.UIDROPDOWNMENU_MENU_LEVEL = oldMenu, oldLevel
    if not ok then
        Clear(state)
        error(failure, 0)
    end
    state.offset = offset
end

local function Wheel(state)
    if
        not NativePool()
        or state.count <= CAPACITY
        or not state.owner
        or not state.frame:IsVisible()
        or _G.UIDROPDOWNMENU_OPEN_MENU ~= state.owner:GetName()
        or type(arg1) ~= "number"
        or arg1 - arg1 ~= 0
        or arg1 == 0
    then
        if state.previousWheel then return state.previousWheel() end
        return
    end
    local offset = math.max(0, math.min(state.count - CAPACITY, state.offset + (arg1 > 0 and -3 or 3)))
    if offset == state.offset then return end
    for slot, button in ipairs(state.buttons) do
        if button.keepShownOnClick then state.rows[state.offset + slot].checked = button.checked end
    end
    if type(_G.CloseDropDownMenus) == "function" then _G.CloseDropDownMenus(state.level + 1) end
    _G.UIDROPDOWNMENU_MENU_LEVEL, _G.UIDROPDOWNMENU_MENU_VALUE = state.level, state.menuValue
    Paint(state, offset)
end

local function AcquireWheel(state)
    if state.count <= CAPACITY then return end
    if state.ownsWheel and state.frame:GetScript("OnMouseWheel") == state.wheel then return end
    state.previousWheel = state.frame:GetScript("OnMouseWheel")
    state.previousWheelEnabled = state.frame:IsMouseWheelEnabled() and true or false
    if not state.wheel then state.wheel = function() return Wheel(state) end end
    state.frame:SetScript("OnMouseWheel", state.wheel)
    if not state.previousWheelEnabled then state.frame:EnableMouseWheel(true) end
    state.ownsWheel = true
    if not state.hide or state.frame:GetScript("OnHide") ~= state.hide then
        local previous = state.frame:GetScript("OnHide")
        state.hide = function()
            if previous then previous() end
            RestoreWheel(state)
        end
        state.frame:SetScript("OnHide", state.hide)
    end
end

_G.UIDropDownMenu_AddButton = function(info, level)
    local current = capture
    level = level or 1
    if not current or current.level ~= level or type(info) ~= "table" or not NativePool() then
        return native.add(info, level)
    end
    current.count = current.count + 1
    if current.count > MAX_ENTRIES then error("SurvivorsDragonUi: native dropdown exceeds 512 entries", 0) end
    local copy = {}
    for key, value in pairs(info) do
        copy[key] = value
    end
    current.rows[current.count] = { info = copy, checked = info.checked }
    if current.count <= CAPACITY then return native.add(info, level) end
end

_G.UIDropDownMenu_GetSelectedID = function(frame)
    local state = states[_G.UIDROPDOWNMENU_MENU_LEVEL or 1]
    if NativePool() and state and state.owner == frame and state.count > CAPACITY then
        return SelectedIndex(state, frame)
    end
    return native.selected(frame)
end

_G.UIDropDownMenu_Refresh = function(frame, useValue, level)
    frame = frame or _G.this
    local state = states[level or _G.UIDROPDOWNMENU_MENU_LEVEL or 1]
    if NativePool() and state and state.owner == frame and state.count > CAPACITY then
        local selected = SelectedIndex(state, frame)
        if
            type(selected) == "number"
            and selected >= 1
            and selected <= state.count
            and (selected <= state.offset or selected > state.offset + CAPACITY)
        then
            Paint(state, math.floor((selected - 1) / CAPACITY) * CAPACITY)
        end
    end
    return native.refresh(frame, useValue, level)
end

_G.UIDropDownMenu_Initialize = function(frame, initialize, mode, level)
    frame = frame or _G.this
    if not NativePool() then
        for _, state in ipairs(states) do
            Clear(state)
        end
        return native.initialize(frame, initialize, mode, level)
    end
    if not frame or type(frame.GetName) ~= "function" then return native.initialize(frame, initialize, mode, level) end
    local sameOwner = frame:GetName() == _G.UIDROPDOWNMENU_OPEN_MENU
    local first = sameOwner and (_G.UIDROPDOWNMENU_MENU_LEVEL or 1) or 1
    for index = first, 3 do
        Clear(states[index])
    end
    local previous = capture
    local current = { rows = {}, level = level or 1, count = 0, menuValue = _G.UIDROPDOWNMENU_MENU_VALUE }
    capture = current
    local ok, failure = pcall(native.initialize, frame, initialize, mode, level)
    capture = previous
    if not ok then
        local state = states[current.level]
        if state then Clear(state) end
        error(failure, 0)
    end
    local state = states[current.level]
    if current.count > CAPACITY and state then
        state.owner, state.rows, state.count, state.menuValue = frame, current.rows, current.count, current.menuValue
        local selected = SelectedIndex(state, frame)
        local offset = type(selected) == "number"
                and selected >= 1
                and selected <= state.count
                and math.floor((selected - 1) / CAPACITY) * CAPACITY
            or 0
        Paint(state, offset)
        AcquireWheel(state)
    end
end

local function MatchingPopup()
    local popup, label = _G.ScriptErrors, _G.ScriptErrors_Message
    if
        not popup
        or not label
        or type(popup.IsShown) ~= "function"
        or type(popup.Hide) ~= "function"
        or type(label.GetText) ~= "function"
    then
        return
    end
    if not popup:IsShown() then return end
    local text = label:GetText()
    if T.IsSuppressedDropdownError(text) then return text end
end

-- A failed stock OnLoad retains its initializer. Replay only known, UI-only
-- setup paths whose received choices actually exceed the native capacity.
local originalText = _G.UIDROPDOWNMENU_OPEN_MENU == nil and MatchingPopup()
if originalText then
    local repaired, failed = 0, false
    local function Fail(failure)
        failed = true
        if type(_G.geterrorhandler) == "function" then
            local handler = _G.geterrorhandler()
            if type(handler) == "function" then handler(failure) end
        end
    end
    local function Replay(callback, first, second, dropdown)
        local oldThis = _G.this
        _G.this = first
        local ok, failure = pcall(callback, first, second)
        _G.this = oldThis
        local state = states[1]
        if ok and state.owner == dropdown and state.count > CAPACITY then
            repaired = repaired + 1
        elseif not ok then
            Fail(failure)
        else
            failed = true
        end
    end
    local function Stock(frameName, initializeName, onLoadName, getterName, stride)
        local frame, initialize, onLoad, getter = _G[frameName], _G[initializeName], _G[onLoadName], _G[getterName]
        if
            not frame
            or type(initialize) ~= "function"
            or frame.initialize ~= initialize
            or type(onLoad) ~= "function"
            or type(getter) ~= "function"
        then
            return
        end
        local values = { pcall(getter) }
        if not values[1] then
            Fail(values[2])
            return
        end
        local count = (table.getn(values) - 1) / stride
        if count > CAPACITY and count <= MAX_ENTRIES and count == math.floor(count) then
            Replay(onLoad, frame, nil, frame)
        end
    end
    Stock(
        "OptionsFrameResolutionDropDown",
        "OptionsFrameResolutionDropDown_Initialize",
        "OptionsFrameResolutionDropDown_OnLoad",
        "GetScreenResolutions",
        1
    )
    Stock(
        "OptionsFrameRefreshDropDown",
        "OptionsFrameRefreshDropDown_Initialize",
        "OptionsFrameRefreshDropDown_OnLoad",
        "GetRefreshRates",
        1
    )
    Stock(
        "OptionsFrameMultiSampleDropDown",
        "OptionsFrameMultiSampleDropDown_Initialize",
        "OptionsFrameMultiSampleDropDown_OnLoad",
        "GetMultisampleFormats",
        3
    )
    local setup, initialize = _G.BenillaOptionsDropdownRow_Setup, _G.BenillaOptionsDropdownRow_InitMenu
    if type(setup) == "function" and type(initialize) == "function" and type(_G.EnumerateFrames) == "function" then
        local frame, complete
        for _ = 1, MAX_FRAMES do
            local ok, nextFrame = pcall(_G.EnumerateFrames, frame)
            if not ok then
                Fail(nextFrame)
                break
            end
            if not nextFrame then
                complete = true
                break
            end
            if nextFrame == frame then break end
            frame = nextFrame
            if frame.initialize == initialize and type(frame.GetParent) == "function" then
                local row = frame:GetParent()
                local count = row and type(row.entries) == "table" and table.getn(row.entries) or 0
                if count > CAPACITY and count <= MAX_ENTRIES then Replay(setup, row, row.entries, frame) end
            end
        end
        if not complete then failed = true end
    end
    if repaired > 0 and not failed and MatchingPopup() == originalText then _G.ScriptErrors:Hide() end
end
