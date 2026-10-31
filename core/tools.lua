setfenv(1, DFRL:GetEnv())

-- Native screen-unit setters now round through 24-bit floats. Their getters
-- need not return the exact Lua number that was set, even at a fixed viewport.
function DFRL.tools.NearlyEqual(a, b)
    return type(a) == "number"
        and type(b) == "number"
        and a - a == 0
        and b - b == 0
        and math.abs(a - b) <= 0.000001 * math.max(1, math.abs(a), math.abs(b))
end

-- Native setters can return a flag or rely on an extension-stripped readback.
-- Callers retain their own binding caches, probes, cleanup and retry cadence.
function DFRL.tools.TextureAssigned(loaded, assigned, wanted)
    if loaded == false or wanted == nil then return false end
    if loaded == true or loaded == 1 then return true end
    if assigned == wanted then return true end
    return type(wanted) == "string" and assigned == string.gsub(wanted, "%.[^%.]*$", "")
end

-- Native unit maxima pass through ceiling/uint32 fields and float32 storage.
-- Share these exact encodings between cosmetic target and nameplate matching.
local function UnitMaximumFloat(value)
    local _, exponent = math.frexp(value)
    if exponent > 128 then return end
    local step = math.ldexp(1, math.max(exponent, -125) - 24)
    local scaled = value / step
    local integer = math.floor(scaled)
    local fraction = scaled - integer
    if fraction > 0.5 or (fraction == 0.5 and math.mod(integer, 2) == 1) then integer = integer + 1 end
    if integer == 0 or (exponent == 128 and integer == 16777216) then return end
    return integer * step
end
local function AddUnitMaximum(maxima, maximum, value)
    if not maximum or maxima[maximum] == false then return end
    local previous = maxima[maximum]
    if previous ~= nil and previous ~= value then
        maxima[maximum] = false
    else
        maxima[maximum] = value
    end
end
function DFRL.tools.IndexUnitMaximum(maxima, maximum, value)
    AddUnitMaximum(maxima, maximum, value)
    AddUnitMaximum(maxima, UnitMaximumFloat(maximum), value)
    local unitMaximum = math.min(4294967295, math.ceil(maximum))
    AddUnitMaximum(maxima, unitMaximum, value)
    AddUnitMaximum(maxima, UnitMaximumFloat(unitMaximum), value)
    -- AZSUNITS serializes float32 maxima to zero decimal places, while waking
    -- guardians publish ceilf(maximum) to UNIT_FIELD_MAXHEALTH. Only these
    -- whole-number publications can encode a fractional value just above them.
    if maximum == math.floor(maximum) and (maximum < 4194304 or (maximum < 8388608 and math.mod(maximum, 2) == 0)) then
        AddUnitMaximum(maxima, maximum + 1, value)
    end
end

local function EncounterNumber(value) return type(value) == "number" and value >= 0 and value - value == 0 end

-- Check the cheap publication envelope before reusing an unchanged roster.
function DFRL.tools.EncounterRosterSize(source, stamp)
    if type(source) ~= "table" or not EncounterNumber(stamp) then return end
    local count = table.getn(source)
    if count <= 40 then return count end
end

-- Consumers retain their own receipt gates, indexes and kind representations.
function DFRL.tools.ValidateEncounterEntries(source, seen)
    for id in pairs(seen) do
        seen[id] = nil
    end
    for _, entry in ipairs(source) do
        if
            type(entry) ~= "table"
            or (entry.kind ~= "final" and entry.kind ~= "boss" and entry.kind ~= "guardian" and entry.kind ~= "elite")
            or not EncounterNumber(entry.id)
            or entry.id <= 0
            or entry.id ~= math.floor(entry.id)
            or seen[entry.id]
            or type(entry.name) ~= "string"
            or entry.name == ""
            or not EncounterNumber(entry.hp)
            or not EncounterNumber(entry.hpm)
            or entry.hpm <= 0
            or entry.hp > entry.hpm
        then
            return false
        end
        seen[entry.id] = true
    end
    return true
end

function DFRL.tools.SetTextIfChanged(label, text)
    local language = DFRL.locale
    local binding = language and language.labels[label]
    local value = text
    if binding then
        binding.source = text
        if type(text) == "string" then value = language.Text(text) end
    end
    if type(value) == "number" then value = tostring(value) end
    if (label:GetText() or "") == (value or "") then return false end
    if binding then
        binding.original(label, value)
    else
        label:SetText(text)
    end
    return true
end

local function EdgeExtent(first, last)
    if type(first) == "number" and type(last) == "number" then
        local extent = last - first
        if extent > 0 and extent - extent == 0 then return extent end
    end
end

-- Native size getters return an authored local size when set, but an already
-- scaled span for anchor-only axes. Edges consistently use the frame's own
-- units. Keep the raw getter as a fallback while edge geometry is unresolved.
function DFRL.tools.GetLocalSize(frame)
    local left, right = frame:GetLeft(), frame:GetRight()
    local bottom, top = frame:GetBottom(), frame:GetTop()
    local width, height = EdgeExtent(left, right), EdgeExtent(bottom, top)
    if not width then width = frame:GetWidth() end
    if not height then height = frame:GetHeight() end
    return width, height
end

-- Bar ownership snapshots only objects registered before SDUI prepares artwork.
function DFRL.tools.NewActionBarState(ignored)
    local owner, objects, visited = {}, {}, {}
    local properties = {
        { "GetParent", "SetParent", 1, true },
        { "GetWidth", "SetWidth", 1 },
        { "GetHeight", "SetHeight", 1 },
        { "GetScale", "SetScale", 1 },
        { "GetAlpha", "SetAlpha", 1 },
        { "GetFrameStrata", "SetFrameStrata", 1 },
        { "GetFrameLevel", "SetFrameLevel", 1 },
        { "IsMouseEnabled", "EnableMouse", 1, true },
        { "IsKeyboardEnabled", "EnableKeyboard", 1, true },
        { "GetTexture", "SetTexture", 1, true },
        { "GetTexCoord", "SetTexCoord", 4 },
        { "GetVertexColor", "SetVertexColor", 4 },
        { "GetBlendMode", "SetBlendMode", 1 },
        { "GetFont", "SetFont", 3 },
        { "GetText", "SetText", 1, true },
        { "GetTextColor", "SetTextColor", 4 },
        { "GetShadowColor", "SetShadowColor", 4 },
        { "GetShadowOffset", "SetShadowOffset", 2 },
    }
    local scripts = { "OnShow", "OnHide", "OnClick", "OnDragStart", "OnReceiveDrag", "OnUpdateModel" }
    local function Read(object, method, argument)
        local getter = object[method]
        if type(getter) ~= "function" then return end
        local ok, a, b, c, d, e, f, g, h
        if argument ~= nil then
            ok, a, b, c, d, e, f, g, h = pcall(getter, object, argument)
        else
            ok, a, b, c, d, e, f, g, h = pcall(getter, object)
        end
        if ok then return { a, b, c, d, e, f, g, h } end
    end
    local function Children(object, method)
        local getter = object[method]
        if type(getter) ~= "function" then return end
        local ok, children = pcall(function() return { getter(object) } end)
        if ok then return children end
    end
    function owner.Track(object)
        local kind = type(object)
        if (kind ~= "table" and kind ~= "userdata") or visited[object] then return end
        if ignored then
            local ancestor, parents = object, {}
            while ancestor and not parents[ancestor] do
                if ignored[ancestor] then return end
                parents[ancestor] = true
                local parent = Read(ancestor, "GetParent")
                ancestor = parent and parent[1]
            end
        end
        visited[object] = true
        table.insert(objects, object)
        for _, method in ipairs({ "GetRegions", "GetChildren" }) do
            for _, child in ipairs(Children(object, method) or {}) do
                owner.Track(child)
            end
        end
    end
    function owner.Capture()
        local snapshot = {}
        for _, object in ipairs(objects) do
            local record = { object = object, values = {}, scripts = {}, methods = {} }
            for _, property in ipairs(properties) do
                if type(object[property[2]]) == "function" then
                    local values = Read(object, property[1])
                    if values and (values[1] ~= nil or property[4]) then record.values[property[1]] = values end
                end
            end
            local points = Read(object, "GetNumPoints")
            if
                points
                and type(points[1]) == "number"
                and points[1] - points[1] == 0
                and points[1] >= 0
                and points[1] == math.floor(points[1])
            then
                local anchors, complete = {}, true
                for index = 1, points[1] do
                    local anchor = Read(object, "GetPoint", index)
                    if not anchor or anchor[1] == nil then
                        complete = false
                        break
                    end
                    anchors[index] = anchor
                end
                if complete then record.points = anchors end
            end
            for _, script in ipairs(scripts) do
                local callback = Read(object, "GetScript", script)
                if callback then table.insert(record.scripts, { name = script, callback = callback[1] }) end
            end
            for _, name in ipairs({ "Show", "Hide" }) do
                if type(object[name]) == "function" then record.methods[name] = object[name] end
            end
            local shown = Read(object, "IsShown")
            if shown then record.shown = shown[1] ~= nil and shown[1] ~= false and shown[1] ~= 0 end
            table.insert(snapshot, record)
        end
        return snapshot
    end
    local function Set(object, method, values, count)
        local setter = object[method]
        if type(setter) ~= "function" then return false end
        if count == 1 then return pcall(setter, object, values[1]) end
        if count == 2 then return pcall(setter, object, values[1], values[2]) end
        if count == 3 then return pcall(setter, object, values[1], values[2], values[3]) end
        if count == 4 then return pcall(setter, object, values[1], values[2], values[3], values[4]) end
        return pcall(
            setter,
            object,
            values[1],
            values[2],
            values[3],
            values[4],
            values[5],
            values[6],
            values[7],
            values[8]
        )
    end
    function owner.Apply(snapshot)
        if type(snapshot) ~= "table" then return false end
        local complete, records, applied, applying = true, {}, {}, {}
        -- Restore every script before any reparenting or visibility transition.
        for _, record in ipairs(snapshot) do
            local object = record.object
            records[object] = record
            for name, method in pairs(record.methods) do
                if object[name] ~= method then
                    local ok = pcall(function() object[name] = method end)
                    if not ok then complete = false end
                end
            end
            for _, script in ipairs(record.scripts) do
                local current = Read(object, "GetScript", script.name)
                if not current or current[1] ~= script.callback then
                    local setter = object.SetScript
                    local ok = type(setter) == "function" and pcall(setter, object, script.name, script.callback)
                    if not ok then complete = false end
                end
            end
        end
        local function ApplyRecord(record)
            local object = record.object
            if applied[object] or applying[object] then return end
            applying[object] = true
            local parent = record.values.GetParent
            if parent and records[parent[1]] then ApplyRecord(records[parent[1]]) end
            for _, property in ipairs(properties) do
                local values = record.values[property[1]]
                if values then
                    local current = Read(object, property[1])
                    local count = property[1] == "GetTexCoord" and values[5] ~= nil and 8 or property[3]
                    local same = current ~= nil
                    for index = 1, count do
                        if not current or current[index] ~= values[index] then same = false end
                    end
                    if not same and not Set(object, property[2], values, count) then complete = false end
                end
            end
            if record.points and type(object.ClearAllPoints) == "function" and type(object.SetPoint) == "function" then
                local size = Read(object, "GetNumPoints")
                local same = size and size[1] == table.getn(record.points)
                for index, point in ipairs(record.points) do
                    local current = Read(object, "GetPoint", index)
                    for field = 1, 5 do
                        if not current or current[field] ~= point[field] then same = false end
                    end
                end
                if not same then
                    local ok = pcall(object.ClearAllPoints, object)
                    if not ok then complete = false end
                    for _, point in ipairs(record.points) do
                        ok = pcall(object.SetPoint, object, point[1], point[2], point[3], point[4], point[5])
                        if not ok then complete = false end
                    end
                end
            end
            applying[object], applied[object] = nil, true
        end
        for _, record in ipairs(snapshot) do
            ApplyRecord(record)
        end
        -- Children retain their own shown state even under a hidden parent.
        for _, record in ipairs(snapshot) do
            if record.shown ~= nil then
                local current = Read(record.object, "IsShown")
                local shown = current and current[1] ~= nil and current[1] ~= false and current[1] ~= 0
                if shown ~= record.shown then
                    local method = record.shown and record.object.Show or record.object.Hide
                    local ok = type(method) == "function" and pcall(method, record.object)
                    if not ok then complete = false end
                end
            end
        end
        return complete
    end
    return owner
end

-- Original 1.12.1 FrameXML/Fonts.xml RAID_CLASS_COLORS:
-- https://github.com/MOUZU/Blizzard-WoW-Interface/blob/master/1.12.1/FrameXML/Fonts.xml
local classColors = {
    HUNTER = { 0.67, 0.83, 0.45 },
    WARLOCK = { 0.58, 0.51, 0.79 },
    PRIEST = { 1, 1, 1 },
    PALADIN = { 0.96, 0.55, 0.73 },
    MAGE = { 0.41, 0.8, 0.94 },
    ROGUE = { 1, 0.96, 0.41 },
    DRUID = { 1, 0.49, 0.04 },
    SHAMAN = { 0, 112 / 255, 221 / 255 }, -- User-requested blue #0070DD.
    WARRIOR = { 0.78, 0.61, 0.43 },
}

function DFRL.tools.GetClassColor(class) return type(class) == "string" and classColors[string.upper(class)] or nil end

function DFRL.tools.GetUnitClassColor(unit)
    if type(UnitClass) ~= "function" then return end
    local _, class = UnitClass(unit)
    return T.GetClassColor(class)
end

function DFRL.tools.GetPlayerClassColor() return T.GetUnitClassColor("player") end

-- Match live native aliases; player names are not party identity.
local playerAndPartyUnits = { "player", "party1", "party2", "party3", "party4" }
function DFRL.tools.IsPlayerOrPartyUnit(unit)
    if not UnitExists(unit) then return false end
    for _, candidate in ipairs(playerAndPartyUnits) do
        if UnitExists(candidate) then
            local same = UnitIsUnit(unit, candidate)
            if same == true or same == 1 then return true end
        end
    end
    return false
end

function KillFrame(frame)
    if not frame then return end
    frame:Hide()
    if frame.UnregisterAllEvents then frame:UnregisterAllEvents() end
    for _, script in ipairs({
        "OnShow",
        "OnHide",
        "OnEnter",
        "OnLeave",
        "OnMouseDown",
        "OnMouseUp",
        "OnClick",
        "OnDragStart",
        "OnDragStop",
        "OnUpdate",
        "OnEvent",
    }) do
        pcall(function() frame:SetScript(script, nil) end)
    end
    if frame.EnableMouse then frame:EnableMouse(false) end
    if frame.EnableKeyboard then frame:EnableKeyboard(false) end
end

function PermanentlyDisableFrame(frame)
    if not frame then return end
    KillFrame(frame)
    -- Native updates may try to show omitted widgets again.
    frame.Show = frame.Hide
    frame:SetScript("OnShow", function() frame:Hide() end)
end

function HideFrameTextures(frame)
    if not frame then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:GetObjectType() == "Texture" then region:Hide() end
    end
end

function HookScript(frame, script, handler)
    if not frame then return end
    local previous = frame:GetScript(script)
    frame:SetScript(script, function(a1, a2, a3, a4, a5, a6, a7, a8, a9)
        if previous then previous(a1, a2, a3, a4, a5, a6, a7, a8, a9) end
        handler(a1, a2, a3, a4, a5, a6, a7, a8, a9)
    end)
end

function hooksecurefunc(name, handler)
    local previous = _G[name]
    if type(previous) ~= "function" then return end
    _G[name] = function(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
        previous(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
        handler(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
    end
end
