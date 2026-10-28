-- CI only: the extracted production affix view and shared tooltip registry.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
local passed = 0
local function Test(name, callback)
    local ok, failure = pcall(callback)
    assert(ok, name .. ": " .. tostring(failure))
    passed = passed + 1
    print("PASS " .. name)
end

local function Affixes()
    local c = H.New()
    local env = c.env
    local create = c.Object
    function c:Object(...)
        local object = create(self, ...)
        local setPoint, setUV, setColor = object.SetPoint, object.SetTexCoord, object.SetVertexColor
        function object:SetPoint(...)
            self.point = { ... }
            setPoint(self, ...)
        end
        function object:SetTexCoord(...)
            self.uv = { ... }
            setUV(self, ...)
        end
        function object:SetVertexColor(...)
            self.color = { ... }
            setColor(self, ...)
        end
        return object
    end
    c.owner = env.CreateFrame("Frame", nil, env.UIParent)
    c.owner:SetWidth(296)
    local tooltip = env.CreateFrame("GameTooltip", nil, env.UIParent)
    env.GameTooltip = tooltip
    tooltip:Hide()
    function tooltip:IsOwned(owner) return self.owner == owner end
    function tooltip:SetOwner(owner)
        self.owner = owner
        c.writes.owner = (c.writes.owner or 0) + 1
    end
    function tooltip:AddLine(text) self.description = text end
    env.DFRL.layout.IsEditing = function() return c.editing end
    env.DFRL.layout.IsHidden = function(key) return key == "tooltip" and c.tooltipHidden end
    c:Load("core/tooltips.lua")
    c:Load("localization/data.lua")
    env.DFRL.locale.code = "en"
    env.DFRL.locale.Native = function(key)
        c.reads.labels = (c.reads.labels or 0) + 1
        return env.DFRL.locale.data[env.DFRL.locale.code].native[key] or key
    end
    local chunk = assert(loadfile(assert(arg[1], "missing extracted affix source")))
    setfenv(chunk, env)
    c.view = chunk()(c.owner)
    c.view.onBounds = function() c.bounds = (c.bounds or 0) + 1 end
    function c:Publish(text, rank)
        self.env.AZS_ZONE = { heroic = rank or 3, affixes = text }
        self.env.AZS_ZONE_UPDATED = 2
    end
    function c:Update(retry) self.view:Update(true, retry) end
    return c
end

Test("native order centers two passive icons with the exact neutral jewelry rim and red tint", function()
    local c = Affixes()
    local objects = #c.objects
    assert(c.view.count == 0 and #c.view.rows == 0, "construction allocated affix artwork")
    c:Publish("sanguine,explosive")
    c:Update(true)
    assert(c.view.count == 2 and c.view.width == 49 and c.view.inset == 25)
    assert(#c.objects == objects + 6, "each affix must add one hover frame and two textures")
    local first, second = c.view.rows[1], c.view.rows[2]
    assert(first.key == "sanguine" and second.key == "explosive", "native affix order changed")
    assert(
        first.point[4] == -13.5 and second.point[4] == 13.5 and first.point[5] == -3,
        "row is not centered under the timer"
    )
    assert(first.rim.uv[1] == 664 / 1024 and first.rim.uv[2] == 736 / 1024, "rim differs from the jewelry quality crop")
    assert(first.rim.color[1] == 237 / 255 and first.rim.color[2] == 35 / 255 and first.rim.color[3] == 38 / 255)
    assert(first.icon.uv[1] == 64 / 256 and second.icon.uv[1] == 128 / 256)
    c:ResetCounts()
    c:Update(true)
    c:NoPresentationWrites()
    assert(not c.reads.labels, "unchanged publication rebuilt tooltip text")
end)

Test("hidden views allocate and paint nothing and resume the current publication", function()
    local c = Affixes()
    c.owner:Hide()
    local objects = #c.objects
    c:Publish("bolstering")
    c:ResetCounts()
    c:Update(true)
    c:NoPresentationWrites()
    assert(#c.objects == objects and #c.view.rows == 0, "hidden view allocated affix artwork")
    c:Publish("explosive,sanguine")
    c.owner:Show()
    c:Update(true)
    assert(c.view.rows[1].key == "explosive" and c.view.rows[2].key == "sanguine", "show replayed hidden-time data")
end)

Test("missing stamps, empty lists and non-Heroic snapshots hide the row without invented affixes", function()
    local c = Affixes()
    c:Publish("bolstering,sanguine")
    c.env.AZS_ZONE_UPDATED = nil
    c:Update(true)
    assert(c.view.count == 0 and #c.view.rows == 0, "unstamped snapshot was accepted")
    c:Publish("bolstering,sanguine")
    c:Update(true)
    local objects = #c.objects
    for _, packet in ipairs({
        { heroic = 0, affixes = "bolstering" },
        { heroic = 1.5, affixes = "sanguine" },
        { heroic = 3, affixes = "" },
        { heroic = 3 },
    }) do
        c.env.AZS_ZONE = packet
        c:Update(true)
        assert(c.view.count == 0 and c.view.inset == 0 and not c.view.rows[1]:IsShown())
    end
    c:Publish("bolstering")
    c:Update(true)
    assert(
        #c.objects == objects and c.view.rows[1]:IsShown() and not c.view.rows[2]:IsShown(),
        "valid data did not reuse the pool"
    )
end)

Test("unknown keys retain native order and labels without borrowing a known affix description", function()
    local c = Affixes()
    c:Publish("future_affix,bolstering,future_affix")
    c:Update(true)
    assert(c.view.count == 2 and c.view.rows[1].title == "future_affix" and c.view.rows[1].hint == nil)
    assert(c.view.rows[1].icon:GetTexture() == "Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
    assert(c.view.rows[2].key == "bolstering", "unknown native key was dropped or reordered")
end)

Test("retirement blocks retained tables and a fresh same-table receipt reopens the current snapshot", function()
    local c = Affixes()
    c:Publish("bolstering")
    c:Update(true)
    c.view:Clear(true)
    c:ResetCounts()
    c:Update(true)
    c:NoPresentationWrites()
    assert(c.view.count == 0, "retired zone replayed before a fresh publication")
    c.view:ZoneChanged()
    assert(c.view.count == 0, "packet callback accepted data synchronously")
    c.view:Update(false, true)
    assert(c.view.count == 0, "pending new-run handshake admitted affixes")
    c:Update(true)
    assert(c.view.count == 1 and c.view.rows[1].key == "bolstering")
    c:Publish("sanguine")
    c.view:ZoneChanged()
    c:Update(true)
    assert(c.view.rows[1].key == "sanguine", "parser-before-handler publication was lost")
end)

Test("failed artwork retries only on the existing retry cadence and reuses successful bindings", function()
    local c = Affixes()
    c:Publish("bolstering")
    c.failTexture = "Interface\\AddOns\\SurvivorsDragonUi\\media\\tex\\timer\\Affixes.blp"
    c:Update(true)
    assert(c.view.retry and not c.view.rows[1]:IsShown(), "partial artwork became visible")
    local objects = #c.objects
    c:ResetCounts()
    c:Update(false)
    c:NoPresentationWrites()
    c.failTexture = nil
    c:Update(true)
    assert(not c.view.retry and c.view.rows[1]:IsShown() and #c.objects == objects)
    assert(c.writes.SetTexture == 1, "retry rebound the successful jewelry rim")
end)

Test("shared hovers obey editing/hiding and cleanup never hides a foreign tooltip", function()
    local c = Affixes()
    c:Publish("bolstering")
    c:Update(true)
    local row, tooltip = c.view.rows[1], c.env.GameTooltip
    c.editing = true
    c:Call(row, "OnEnter")
    assert(not tooltip:IsShown(), "Layout editing opened a hover")
    c.editing, c.tooltipHidden = false, true
    c:Call(row, "OnEnter")
    assert(not tooltip:IsShown(), "hidden Tooltip group opened a hover")
    c.tooltipHidden = false
    c:Call(row, "OnEnter")
    assert(tooltip:IsOwned(row) and tooltip:GetText() == "Bolstering")
    assert(tooltip.description == "A death makes the enemies near it tougher and stronger, stacking.")
    c.owner:Hide()
    assert(not tooltip:IsShown(), "shared registry retained a hidden icon's hover")
    tooltip.owner = c.env.UIParent
    tooltip:Show()
    c.view:Clear(true)
    assert(tooltip:IsShown() and tooltip:IsOwned(c.env.UIParent), "retirement hid a foreign tooltip")
end)

Test("all fourteen native catalogs supply names and descriptions without changing affix keys", function()
    local c = Affixes()
    c:Publish("bolstering,sanguine,explosive")
    local languages = 0
    for code in pairs(c.env.DFRL.locale.data) do
        c.env.DFRL.locale.code = code
        c:Update(true)
        for index, key in ipairs({ "bolstering", "sanguine", "explosive" }) do
            local row = c.view.rows[index]
            assert(
                row.key == key
                    and type(row.title) == "string"
                    and row.title ~= ""
                    and type(row.hint) == "string"
                    and row.hint ~= "",
                "localized data changed identity or lost a caption"
            )
        end
        assert(c.view.rows[2].title == c.env.DFRL.locale.data[code].native.Sanguine)
        languages = languages + 1
    end
    assert(languages == 14, "native caption coverage is incomplete")
end)

print("PASS run affix UI contracts: " .. passed)
