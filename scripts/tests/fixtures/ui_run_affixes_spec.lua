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
    c.settings.attachAffixes = true
    c.runWidth, c.bossWidth = 160, 90
    local create = c.Object
    function c:Object(...)
        local object = create(self, ...)
        function object:GetScale() return self.scale or 1 end
        function object:SetScale(scale)
            c.writes.SetScale = (c.writes.SetScale or 0) + 1
            self.scale = scale
        end
        function object:GetEffectiveScale()
            return self:GetScale() * (self.parent and self.parent:GetEffectiveScale() or 1)
        end
        function object:SetParent(parent)
            c.writes.SetParent = (c.writes.SetParent or 0) + 1
            self.parent = parent
            c:Visibility()
        end
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
    function env.UIParent:GetEffectiveScale() return 1 end
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
    env.DFRL.layout.IsHidden = function(key)
        if key == "tooltip" then return c.tooltipHidden end
        if key == "heroicAffixes" then return c.layoutMask and not c.layoutMask:IsShown() end
        return false
    end
    env.DFRL.layout.IsPlaced = function() return c.customPosition end
    local register = env.DFRL.layout.Register
    env.DFRL.layout.Register = function(key, frame, anchor, options)
        c.defaultAnchor, c.layoutOptions = anchor, options
        register(key, frame, function() anchor(frame) end)
    end
    env.DFRL.layout.Place = function()
        if c.defaultAnchor and not c.customPosition then c.defaultAnchor(c.view.detached) end
    end
    c:Load("core/tooltips.lua")
    c:Load("localization/data.lua")
    env.DFRL.locale.code = "en"
    env.DFRL.locale.Native = function(key)
        c.reads.labels = (c.reads.labels or 0) + 1
        return env.DFRL.locale.data[env.DFRL.locale.code].native[key] or key
    end
    local chunk = assert(loadfile(assert(arg[1], "missing extracted affix source")))
    setfenv(chunk, env)
    local api = chunk()
    c.view = api.New(c.owner)
    env.run, env.currentFont = c.owner, { size = 14 }
    env.run.affixes = c.view
    env.runClock, env.bossClock = { visible = true, pixel = 1 }, { visible = false, pixel = 1 }
    env.runText, env.bossText = c.owner:CreateFontString(), c.owner:CreateFontString()
    function env.runText:GetStringWidth() return c.runWidth end
    function env.bossText:GetStringWidth() return c.bossWidth end
    env.runMoveRegion = env.CreateFrame("Frame", nil, c.owner)
    c.view.onBounds = function()
        c.bounds = (c.bounds or 0) + 1
        api.Bounds()
    end
    c.refreshBounds = api.Bounds
    c.view:RegisterLayout()
    function c:Publish(text, rank)
        self.env.AZS_ZONE = { heroic = rank or 3, affixes = text }
        self.env.AZS_ZONE_UPDATED = 2
    end
    function c:Update(retry)
        self.view:SyncAttachment()
        self.view:Update(true, retry)
    end
    return c
end

Test("native order places icons left of the run text with the shadow-free rim and red tint", function()
    local c = Affixes()
    local objects = #c.objects
    assert(c.view.count == 0 and #c.view.rows == 0, "construction allocated affix artwork")
    c:Publish("sanguine,explosive")
    c:Update(true)
    assert(c.view.count == 2 and c.view.width == 49)
    assert(#c.objects == objects + 6, "each affix must add one hover frame and two textures")
    local first, second = c.view.rows[1], c.view.rows[2]
    assert(first.key == "sanguine" and second.key == "explosive", "native affix order changed")
    assert(
        first.point[4] == 0 and second.point[4] == 27 and first.point[5] == 0,
        "icon spacing or native order changed"
    )
    assert(
        c.view.root.point[1] == "BOTTOMLEFT"
            and c.view.root.point[3] == "TOPLEFT"
            and c.view.root.point[4] == 0
            and c.view.root.point[5] == 2,
        "default icons are not above the bar on its left"
    )
    assert(first.rim.uv[1] == 576 / 1024 and first.rim.uv[2] == 648 / 1024, "rim differs from the shadow-free crop")
    assert(first.rim.color[1] == 237 / 255 and first.rim.color[2] == 35 / 255 and first.rim.color[3] == 38 / 255)
    assert(first.icon.uv[1] == 64 / 256 and second.icon.uv[1] == 128 / 256)
    c:ResetCounts()
    c:Update(true)
    c:NoPresentationWrites()
    assert(not c.reads.labels, "unchanged publication rebuilt tooltip text")
end)

Test("both captions center the attached row and reserve a gap even with wide labels", function()
    local c = Affixes()
    c.env.bossClock.visible = true
    c.runWidth, c.bossWidth = 220, 190
    c:Publish("bolstering,sanguine,explosive")
    c:Update(true)
    local root, runLabel, bossLabel = c.view.root, c.env.runText, c.env.bossText
    assert(
        root.point[1] == "BOTTOM" and root.point[3] == "TOP" and root.point[4] == 0,
        "two captions did not center the affixes"
    )
    local first = (296 - c.view.width) / 2
    local last = (296 + c.view.width) / 2
    assert(runLabel.point[4] + c.runWidth <= first - 8, "run text overlaps the affixes")
    assert(296 + bossLabel.point[4] - c.bossWidth >= last + 8, "boss countdown overlaps the affixes")
    c:ResetCounts()
    c.refreshBounds()
    c:NoPresentationWrites()
    c.env.bossClock.visible = false
    c.refreshBounds()
    assert(
        root.point[1] == "BOTTOMLEFT" and root.point[3] == "TOPLEFT",
        "single caption did not restore left placement"
    )
    assert(root.point[4] + c.view.width <= (296 - c.runWidth) / 2 - 8, "wide run text overlaps left affixes")
end)

Test("detached geometry survives reattachment and stays visible independently of the run timer", function()
    local c = Affixes()
    c:Publish("bolstering,sanguine")
    c:Update(true)
    local objects = #c.objects
    c.settings.attachAffixes = false
    c:Update(true)
    assert(
        c.view.root:GetParent() == c.view.detached and c.view.detached:IsShown(),
        "detach did not expose its Layout owner"
    )
    assert(
        c.layoutOptions.onlyWhenShown and c.layoutOptions.refreshDefault,
        "detached group lost shared Layout behavior"
    )
    c.customPosition = true
    local point = { "CENTER", c.env.UIParent, "CENTER", 80, -60 }
    c.view.detached.point = point
    c.view.detached:SetScale(1.4)
    c.owner:Hide()
    c:Publish("explosive")
    c:Update(true)
    assert(
        c.view.root:IsVisible() and c.view.rows[1].key == "explosive",
        "hiding the timer stopped detached data or presentation"
    )
    assert(
        c.view.detached.point == point and c.view.detached:GetScale() == 1.4,
        "native publication overwrote detached geometry"
    )
    c:SetLayoutHidden(true)
    c:ResetCounts()
    c:Update(true)
    c:NoPresentationWrites()
    c:SetLayoutHidden(false)
    c:Update(true)
    assert(c.view.root:IsVisible(), "detached Hide frame lost current presentation")
    c.settings.attachAffixes = true
    c:Update(true)
    assert(c.view.root:GetParent() == c.owner and not c.view.detached:IsShown() and not c.view.root:IsVisible())
    c.settings.attachAffixes = false
    c:Update(true)
    assert(c.view.root:IsVisible() and c.view.detached.point == point and c.view.detached:GetScale() == 1.4)
    assert(#c.objects == objects, "attachment changes allocated another icon pool")
end)

Test("attachment defaults, preview, Cancel, Confirm and resets use the production display owner", function()
    local c = H.New()
    c.env.DFRL.tallyStyleDefault = "gothic01"
    c.env.DFRL.tallyStyleById = { gothic01 = {} }
    c:Load("core/display.lua", "Display")
    local display = c.env.DFRL.display
    assert(display.Get("attachAffixes") == true and display.Copy({ attachAffixes = "invalid" }).attachAffixes == true)
    display.BeginEdit()
    display.Set("attachAffixes", false)
    assert(display.Get("attachAffixes") == false and c.env.SurvivorsDragonUiDisplay == nil)
    display.FinishEdit(false)
    assert(display.Get("attachAffixes") == true, "Cancel saved the attachment preview")
    display.BeginEdit()
    display.Set("attachAffixes", false)
    display.FinishEdit(true)
    assert(
        c.env.SurvivorsDragonUiDisplay.attachAffixes == false
            and display.Copy({ attachAffixes = false }).attachAffixes == false
    )
    display.Reset()
    assert(display.Get("attachAffixes") == true, "reset lost the default attachment")
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
        assert(c.view.count == 0 and c.view.width == 0 and not c.view.rows[1]:IsShown())
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
