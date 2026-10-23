-- Named addon setups share the editor's confirmation and discard lifecycle.
DFRL:NewMod("Profiles", 1, function()
    local profiles, draft, listeners = {}, nil, {}
    DFRL.profiles = profiles

    local function Name(value)
        if type(value) ~= "string" then return end
        value = string.gsub(value, "^%s*(.-)%s*$", "%1")
        if value == "" or string.len(value) > 192 or string.find(value, "[%c|]") then return end
        return value
    end
    local function Saved()
        local saved = _G.SurvivorsDragonUiProfiles
        return type(saved) == "table" and saved or {}
    end
    local function Valid(profile)
        return type(profile) == "table"
            and type(profile.layout) == "table"
            and type(profile.display) == "table"
            and type(profile.runFont) == "table"
    end
    local function Copy(profile)
        if not Valid(profile) then return end
        return {
            layout = DFRL.layout.Copy(profile.layout),
            display = DFRL.display.Copy(profile.display),
            runFont = DFRL.runFont.Copy(profile.runFont),
            sctMode = DFRL.sct and DFRL.sct.NormalizeMode(profile.sctMode) or nil,
        }
    end
    local function Notify()
        for _, callback in ipairs(listeners) do
            callback()
        end
    end
    function profiles.BeginEdit()
        if draft then return end
        draft = {}
        for name, profile in pairs(Saved()) do
            if Name(name) == name then draft[name] = Copy(profile) end
        end
        Notify()
    end
    function profiles.FinishEdit(save)
        if not draft then return end
        if save then _G.SurvivorsDragonUiProfiles = draft end
        draft = nil
        Notify()
    end
    function profiles.List()
        local names = {}
        for name, profile in pairs(draft or Saved()) do
            if Name(name) == name and Valid(profile) then table.insert(names, name) end
        end
        table.sort(names)
        return names
    end
    function profiles.Save(name, overwrite)
        if not draft then return false, "Open the editor first." end
        name = Name(name)
        if not name then return false, "Enter a valid profile name." end
        if draft[name] and not overwrite then return false, "That name already exists. Use Overwrite profile." end
        if overwrite and not draft[name] then return false, "Select a profile first." end
        local geometry = DFRL.layout.Snapshot()
        if not geometry then return false, "Check the Layout values first." end
        draft[name] = {
            layout = geometry,
            display = DFRL.display.Snapshot(),
            runFont = DFRL.runFont.Snapshot(),
            sctMode = DFRL.sct and DFRL.sct.GetMode() or nil,
        }
        Notify()
        return true, "Profile saved. Confirm to keep it.", name
    end
    function profiles.Load(name)
        if not draft then return false, "Open the editor first." end
        local profile = Copy(draft[name])
        if not profile then return false, "Select a profile first." end
        DFRL.display.Load(profile.display)
        DFRL.runFont.Load(profile.runFont)
        if DFRL.sct then DFRL.sct.SetMode(profile.sctMode) end
        DFRL.layout.Load(profile.layout)
        return true, "Profile loaded. Confirm to use it."
    end
    function profiles.Delete(name)
        if not draft or not draft[name] then return false, "Select a profile first." end
        draft[name] = nil
        Notify()
        return true, "Profile deleted. Confirm to keep the change."
    end

    local actions = { "Load profile", "Overwrite profile", "Delete profile" }
    function profiles.MinimumWidth(measure)
        local buttonWidth = 0
        for _, caption in ipairs(actions) do
            buttonWidth = math.max(buttonWidth, measure(caption) + 24)
        end
        return math.max(
            buttonWidth * 3 + 16,
            measure("Save new profile") + 192,
            measure("Save and load named setups.") + 24
        )
    end
    function profiles.CreateControls(parent, width)
        local function Label(text, y, size, height)
            local label = parent:CreateFontString(nil, "OVERLAY")
            DFRL.locale.Bind(label)
            T.SetFont(label, size or 12, "")
            label:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
            label:SetWidth(width)
            label:SetHeight(height or 16)
            label:SetJustifyH("LEFT")
            label:SetJustifyV("TOP")
            label:SetTextColor(0.88, 0.87, 0.83)
            label:SetShadowColor(0, 0, 0, 1)
            label:SetShadowOffset(1, -1)
            label:SetText(text)
            return label
        end
        Label("Save and load named setups.", 0, 12, 28)
        Label("Profile name", -34, 10)
        local measure = Label("", 0)
        measure:Hide()
        local saveWidth = DFRL.locale.Width(measure, "Save new profile") + 24
        local input = T.CreateEditorInput(parent, width - saveWidth - 8, 26)
        input:SetMaxLetters(48)
        input:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -52)
        Label("Saved profiles", -90, 10)
        local status = Label("Changes are saved with Confirm.", -340, 10, 44)
        local selected, offset = nil, 0
        local rows, buttons = {}, {}
        local pageSize = 5
        local previous = T.CreateEditorButton(parent, "<", 30, 26)
        previous:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -260)
        local nextPage = T.CreateEditorButton(parent, ">", 30, 26)
        nextPage:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -260)
        local page = Label("", -266, 10)
        page:SetJustifyH("CENTER")

        local function Refresh(followSelection)
            local names = profiles.List()
            local count = table.getn(names)
            local found
            for index, name in ipairs(names) do
                if name == selected then found = index end
            end
            if not found then selected = nil end
            if found and followSelection then offset = math.floor((found - 1) / pageSize) * pageSize end
            offset = math.max(0, math.min(offset, math.floor(math.max(0, count - 1) / pageSize) * pageSize))
            for index, row in ipairs(rows) do
                local name = names[offset + index]
                row.profileName = name
                if name then
                    row.label:SetText(name)
                    row:SetSelected(name == selected)
                    row:Show()
                else
                    row:Hide()
                end
            end
            page:SetText(string.format("%d / %d", offset / pageSize + 1, math.max(1, math.ceil(count / pageSize))))
            previous:SetAlpha(offset > 0 and 1 or 0.45)
            nextPage:SetAlpha(offset + pageSize < count and 1 or 0.45)
            for _, button in ipairs(buttons) do
                button:SetAlpha(selected and 1 or 0.45)
            end
            if count == 0 then status:SetText("No saved profiles.") end
        end
        local function Result(ok, message, name)
            if ok and name then
                selected = name
                input:SetText(name)
            end
            Refresh(ok and name ~= nil)
            status:SetText(message)
            input:ClearFocus()
        end
        for index = 1, pageSize do
            local row = T.CreateEditorButton(parent, "", width, 26)
            row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -112 - (index - 1) * 28)
            -- User names stay literal, including names that match a translated caption.
            row.label:Hide()
            row.label = row:CreateFontString(nil, "OVERLAY")
            T.SetFont(row.label, 12, "")
            row.label:SetPoint("LEFT", row, "LEFT", 10, 0)
            row.label:SetWidth(width - 20)
            row.label:SetHeight(16)
            row.label:SetJustifyH("LEFT")
            row.label:SetShadowColor(0, 0, 0, 1)
            row.label:SetShadowOffset(1, -1)
            row:SetScript("OnClick", function()
                selected = row.profileName
                input:SetText(selected or "")
                input:ClearFocus()
                status:SetText("Changes are saved with Confirm.")
                Refresh()
            end)
            table.insert(rows, row)
        end
        local save = T.CreateEditorButton(parent, "Save new profile", saveWidth, 26)
        save:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -52)
        save:SetScript("OnClick", function() Result(profiles.Save(input:GetText(), false)) end)
        input:SetScript("OnEnterPressed", function() Result(profiles.Save(input:GetText(), false)) end)
        input:SetScript("OnEscapePressed", function() input:ClearFocus() end)
        previous:SetScript("OnClick", function()
            offset = math.max(0, offset - pageSize)
            Refresh()
        end)
        nextPage:SetScript("OnClick", function()
            offset = offset + pageSize
            Refresh()
        end)
        local buttonWidth = (width - 16) / 3
        for index, caption in ipairs(actions) do
            local action = caption
            local button = T.CreateEditorButton(parent, caption, buttonWidth, 28)
            button:SetPoint("TOPLEFT", parent, "TOPLEFT", (index - 1) * (buttonWidth + 8), -300)
            button:SetScript("OnClick", function()
                if not selected then
                    status:SetText("Select a profile first.")
                elseif action == "Load profile" then
                    Result(profiles.Load(selected))
                elseif action == "Overwrite profile" then
                    Result(profiles.Save(selected, true))
                else
                    Result(profiles.Delete(selected))
                end
            end)
            table.insert(buttons, button)
        end
        parent:SetScript("OnShow", function()
            status:SetText("Changes are saved with Confirm.")
            Refresh()
        end)
        parent:SetScript("OnHide", function() input:ClearFocus() end)
        table.insert(listeners, Refresh)
        DFRL.locale.Listen(Refresh)
        Refresh()
    end
end)
