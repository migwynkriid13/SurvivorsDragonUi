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
        if draft[name] and not overwrite then return false, "That name already exists. Use Overwrite and close." end
        if overwrite and not draft[name] then return false, "Select a profile first." end
        local geometry = DFRL.layout.Snapshot()
        if not geometry then return false, "Check the Layout values first." end
        local previous = draft[name]
        draft[name] = {
            layout = geometry,
            display = DFRL.display.Snapshot(),
            runFont = DFRL.runFont.Snapshot(),
            sctMode = DFRL.sct and DFRL.sct.GetMode() or nil,
        }
        -- Save the profile and the active setup through the same transaction as
        -- Confirm. A named snapshot must not look saved while still a draft.
        if not DFRL.layout.ConfirmEdit() then
            if draft then draft[name] = previous end
            return false, "Check the Layout values first."
        end
        return true, "Profile and current setup saved.", name
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

    -- Share strings: "SDUI1:" then the profile as plain tokens, so nothing pasted is ever run as code.
    -- s<text>; and n<number>; with every non-alphanumeric byte as %XX, t/f, and { key value ... }.
    local SHARE_PREFIX, MAX_DEPTH, MAX_ENTRIES, MAX_SHARE_BYTES = "SDUI1:", 16, 20000, 131072
    local function EscapeByte(c) return string.format("%%%02X", string.byte(c)) end
    local function UnescapeByte(hex) return string.char(tonumber(hex, 16)) end
    local function Append(out, text, budget)
        budget.bytes = budget.bytes + string.len(text)
        if budget.bytes > MAX_SHARE_BYTES then return false end
        table.insert(out, text)
        return true
    end
    local function Encode(value, out, depth, budget)
        local kind = type(value)
        if kind == "boolean" then
            return Append(out, value and "t" or "f", budget)
        elseif kind == "number" then
            -- Lua 5.0 has no math.huge: NaN fails value == value, and infinity survives value - value only as NaN.
            if value - value ~= 0 then return false end
            return Append(out, "n" .. string.format("%.17g", value) .. ";", budget)
        elseif kind == "string" then
            if string.len(value) > MAX_SHARE_BYTES then return false end
            return Append(out, "s" .. string.gsub(value, "[^A-Za-z0-9]", EscapeByte) .. ";", budget)
        elseif kind == "table" and depth < MAX_DEPTH then
            if not Append(out, "{", budget) then return false end
            local keys = {}
            for key in pairs(value) do
                local keyKind = type(key)
                if keyKind ~= "string" and keyKind ~= "number" then return false end
                budget.left = budget.left - 1
                if budget.left < 0 then return false end
                table.insert(keys, key)
            end
            table.sort(keys, function(a, b)
                if type(a) == type(b) then return a < b end
                return type(a) == "number"
            end)
            for _, key in ipairs(keys) do
                if not Encode(key, out, depth + 1, budget) or not Encode(value[key], out, depth + 1, budget) then
                    return false
                end
            end
            return Append(out, "}", budget)
        else
            return false
        end
    end
    -- Returns ok, value, next position; a malformed string fails rather than guessing.
    local function Decode(text, pos, depth, budget)
        local c = string.sub(text, pos, pos)
        if c == "t" then return true, true, pos + 1 end
        if c == "f" then return true, false, pos + 1 end
        if c == "s" or c == "n" then
            local stop = string.find(text, ";", pos + 1, true)
            if not stop then return false end
            local body = string.sub(text, pos + 1, stop - 1)
            if c == "n" then
                if string.len(body) > 64 then return false end
                local number = tonumber(body)
                if not number or number - number ~= 0 then return false end
                return true, number, stop + 1
            end
            if string.find(body, "[^A-Za-z0-9%%]") then return false end
            local cursor = 1
            while cursor <= string.len(body) do
                if string.sub(body, cursor, cursor) == "%" then
                    if not string.find(string.sub(body, cursor + 1, cursor + 2), "^%x%x$") then return false end
                    cursor = cursor + 3
                else
                    cursor = cursor + 1
                end
            end
            return true, (string.gsub(body, "%%(%x%x)", UnescapeByte)), stop + 1
        end
        if c ~= "{" or depth >= MAX_DEPTH then return false end
        local result = {}
        pos = pos + 1
        while true do
            if string.sub(text, pos, pos) == "}" then return true, result, pos + 1 end
            budget.left = budget.left - 1
            if budget.left < 0 then return false end
            local okKey, key, afterKey = Decode(text, pos, depth + 1, budget)
            if not okKey or (type(key) ~= "string" and type(key) ~= "number") then return false end
            local okValue, entry, afterValue = Decode(text, afterKey, depth + 1, budget)
            if not okValue or result[key] ~= nil then return false end
            result[key], pos = entry, afterValue
        end
    end
    function profiles.Export(name)
        local profile = Copy((draft or Saved())[name])
        if not profile then return false, "Select a profile first." end
        local out = {}
        if not Encode(profile, out, 0, { left = MAX_ENTRIES, bytes = string.len(SHARE_PREFIX) }) then
            return false, "This profile can't be exported."
        end
        return true, SHARE_PREFIX .. table.concat(out)
    end
    function profiles.Import(text, name)
        if not draft then return false, "Open the editor first." end
        name = Name(name)
        if not name then return false, "Enter a valid profile name." end
        if draft[name] then return false, "That name already exists." end
        if type(text) ~= "string" or string.len(text) > MAX_SHARE_BYTES then
            return false, "That profile string is damaged or incomplete."
        end
        text = string.gsub(text, "%s", "")
        if string.sub(text, 1, string.len(SHARE_PREFIX)) ~= SHARE_PREFIX then
            return false, "Paste a SurvivorsDragonUi profile string (it starts with SDUI1:)."
        end
        local ok, decoded, stop = Decode(text, string.len(SHARE_PREFIX) + 1, 0, { left = MAX_ENTRIES })
        local profile = ok and stop == string.len(text) + 1 and Copy(decoded)
        if not profile then return false, "That profile string is damaged or incomplete." end
        draft[name] = profile
        Notify()
        return true, "Profile imported. Load it to use it, and Confirm to keep it.", name
    end

    local captions = {
        summary = {
            label = "Save and load named setups.",
            description = "Save and overwrite close the editor and keep your setup. Load and delete need Confirm.",
            offset = 0,
        },
        name = { label = "Profile name", offset = 34 },
        saved = { label = "Saved profiles", offset = 90 },
        save = { label = "Save profile and close", offset = 52 },
        share = { label = "Share a profile", offset = 392 },
    }
    local shareActions = {
        { label = "Export profile", offset = 444 },
        { label = "Import profile", offset = 444 },
    }
    local actions = {
        { label = "Load profile", offset = 300 },
        { label = "Overwrite and close", offset = 300 },
        { label = "Delete profile", offset = 300 },
    }
    profiles.search = {
        captions.summary,
        captions.name,
        captions.saved,
        captions.save,
        actions[1],
        actions[2],
        actions[3],
        captions.share,
        shareActions[1],
        shareActions[2],
    }
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
            T.SetChatShadow(label)
            label:SetText(text)
            return label
        end
        Label(captions.summary.label, 0, 12, 28)
        Label(captions.name.label, -34, 10)
        local measure = Label("", 0)
        measure:Hide()
        local saveWidth = DFRL.locale.Width(measure, captions.save.label, true) + 24
        local save
        local input = T.CreateEditorInput(parent, width - saveWidth - 8, 26)
        input:SetMaxLetters(48)
        input:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -52)
        Label(captions.saved.label, -90, 10)
        local status = Label(captions.summary.description, -340, 9, 44)
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
            if not parent:IsVisible() then return end
            local measured = DFRL.locale.Width(measure, captions.save.label, true) + 24
            if measured ~= saveWidth then
                saveWidth = measured
                input:SetWidth(width - saveWidth - 8)
                save:SetWidth(saveWidth)
                save.label:SetWidth(saveWidth - 12)
            end
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
                    T.SetTextIfChanged(row.label, name)
                    row:SetSelected(name == selected)
                    if not row:IsShown() then row:Show() end
                elseif row:IsShown() then
                    row:Hide()
                end
            end
            T.SetTextIfChanged(
                page,
                string.format("%d / %d", offset / pageSize + 1, math.max(1, math.ceil(count / pageSize)))
            )
            local previousAlpha, nextAlpha = offset > 0 and 1 or 0.45, offset + pageSize < count and 1 or 0.45
            if previous:GetAlpha() ~= previousAlpha then previous:SetAlpha(previousAlpha) end
            if nextPage:GetAlpha() ~= nextAlpha then nextPage:SetAlpha(nextAlpha) end
            local alpha = selected and 1 or 0.45
            for _, button in ipairs(buttons) do
                if button:GetAlpha() ~= alpha then button:SetAlpha(alpha) end
            end
            if count == 0 then T.SetTextIfChanged(status, "No saved profiles.") end
        end
        local function Result(ok, message, name)
            if ok and name then selected = name end
            if not parent:IsVisible() then return end
            if ok and name then input:SetText(name) end
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
            T.SetChatShadow(row.label)
            row:SetScript("OnClick", function()
                selected = row.profileName
                input:SetText(selected or "")
                input:ClearFocus()
                status:SetText(captions.summary.description)
                Refresh()
            end)
            table.insert(rows, row)
        end
        save = T.CreateEditorButton(parent, captions.save.label, saveWidth, 26)
        save:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -52)
        save:SetScript("OnClick", function() Result(profiles.Save(input:GetText(), false)) end)
        input:SetScript("OnEnterPressed", function() Result(profiles.Save(input:GetText(), false)) end)
        input:SetScript("OnEscapePressed", function() DFRL.layout.CancelEdit() end)
        previous:SetScript("OnClick", function()
            offset = math.max(0, offset - pageSize)
            Refresh()
        end)
        nextPage:SetScript("OnClick", function()
            offset = offset + pageSize
            Refresh()
        end)
        local buttonWidth = (width - 16) / 3
        for index, entry in ipairs(actions) do
            local action = entry
            local button = T.CreateEditorButton(parent, entry.label, buttonWidth, 28)
            button:SetPoint("TOPLEFT", parent, "TOPLEFT", (index - 1) * (buttonWidth + 8), -300)
            button:SetScript("OnClick", function()
                if not selected then
                    status:SetText("Select a profile first.")
                elseif action == actions[1] then
                    Result(profiles.Load(selected))
                elseif action == actions[2] then
                    Result(profiles.Save(selected, true))
                else
                    Result(profiles.Delete(selected))
                end
            end)
            table.insert(buttons, button)
        end
        -- Share: export puts the selected profile's string in the box to copy; import reads the box.
        Label(captions.share.label, -captions.share.offset, 10)
        local shareBox = T.CreateEditorInput(parent, width, 26)
        shareBox:SetMaxLetters(MAX_SHARE_BYTES)
        shareBox:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -410)
        shareBox:SetScript("OnEscapePressed", function() shareBox:ClearFocus() end)
        shareBox:SetScript("OnEditFocusGained", function() shareBox:HighlightText() end)
        local shareWidth = (width - 8) / 2
        local export = T.CreateEditorButton(parent, shareActions[1].label, shareWidth, 28)
        export:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -shareActions[1].offset)
        export:SetScript("OnClick", function()
            if not selected then
                status:SetText("Select a profile first.")
                return
            end
            local ok, result = profiles.Export(selected)
            if not ok then
                status:SetText(result)
                return
            end
            shareBox:SetText(result)
            shareBox:SetFocus()
            shareBox:HighlightText()
            status:SetText("Profile string selected below. Press Ctrl+C to copy it.")
        end)
        local import = T.CreateEditorButton(parent, shareActions[2].label, shareWidth, 28)
        import:SetPoint("TOPLEFT", parent, "TOPLEFT", shareWidth + 8, -shareActions[2].offset)
        import:SetScript("OnClick", function()
            Result(profiles.Import(shareBox:GetText(), input:GetText()))
            shareBox:ClearFocus()
        end)
        if (parent:GetHeight() or 0) < 480 then parent:SetHeight(480) end
        parent:SetScript("OnShow", function()
            status:SetText(captions.summary.description)
            Refresh(true)
            if selected then T.SetTextIfChanged(input, selected) end
        end)
        parent:SetScript("OnHide", function()
            input:ClearFocus()
            shareBox:ClearFocus()
            if shareBox:GetText() ~= "" then shareBox:SetText("") end
        end)
        table.insert(listeners, Refresh)
        DFRL.locale.Listen(Refresh)
        Refresh()
    end
end)
