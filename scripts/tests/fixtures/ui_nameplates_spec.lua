-- CI only: full production filter, masking and skin over explicit native plates.
assert(_VERSION == "Lua 5.1", "nameplate fixtures require CI Lua 5.1")
local SCT = dofile("scripts/tests/fixtures/ui_sct_helpers.lua")
local function Plates(setup)
    local context = SCT(false, function(context, env)
        context.settings.nameplatesNamesOnly = true
        context.settings.nameplateFontSize = 9
        context.settings.nameplatesBossGuardiansOnly = true
        env.NAMEPLATES_ON = true
        env.AZS_GetPhase = function() return context.phase or "playing" end
        env.AZS_RUN, env.AZS_RUN_UPDATED = { t = 10 }, context.now
        local function Write(object, name)
            context.writes[name] = (context.writes[name] or 0) + 1
            object.calls[name] = (object.calls[name] or 0) + 1
        end
        local function Native(object)
            object.calls, object.layers = {}, {}
            function object:GetObjectType() return self.kind end
            function object:IsShown()
                self.shownReads = (self.shownReads or 0) + 1
                return self.shown
            end
            function object:GetEffectiveScale() return 1 end
            function object:GetLeft() return 0 end
            function object:GetBottom() return 0 end
            function object:GetCenter() return self.centerX or 200, self.centerY or 200 end
            function object:GetTop() return self.top or 205 end
            function object:GetChildren()
                self.childrenReads = (self.childrenReads or 0) + 1
                local children = {}
                for _, child in ipairs(context.objects) do
                    if child.parent == self and child.kind ~= "Texture" and child.kind ~= "FontString" then
                        table.insert(children, child)
                    end
                end
                return unpack(children)
            end
            function object:GetNumChildren()
                local count = 0
                for _, child in ipairs(context.objects) do
                    if child.parent == self and child.kind ~= "Texture" and child.kind ~= "FontString" then
                        count = count + 1
                    end
                end
                return count
            end
            function object:GetRegions() return unpack(self.regions or {}) end
            function object:GetHitRectInsets() return unpack(self.insets or { 0, 0, 0, 0 }) end
            function object:SetHitRectInsets(...)
                Write(self, "SetHitRectInsets")
                self.insets = { ... }
            end
            function object:DisableDrawLayer(layer)
                Write(self, "DisableDrawLayer")
                self.layers[layer] = false
            end
            function object:EnableDrawLayer(layer)
                Write(self, "EnableDrawLayer")
                self.layers[layer] = true
            end
            function object:IsDrawLayerEnabled(layer) return self.layers[layer] ~= false end
            function object:GetMinMaxValues()
                self.rangeReads = (self.rangeReads or 0) + 1
                return self.minimum or 0, self.maximum or 100
            end
            function object:SetMinMaxValues(low, high)
                Write(self, "SetMinMaxValues")
                self.minimum, self.maximum = low, high
            end
            function object:GetValue()
                self.valueReads = (self.valueReads or 0) + 1
                return self.value or 0
            end
            function object:SetValue(value)
                Write(self, "SetValue")
                self.value = value
            end
            function object:GetStatusBarColor() return unpack(self.color or { 1, 0, 0, 1 }) end
            function object:SetStatusBarColor(...)
                Write(self, "SetStatusBarColor")
                self.color = { ... }
            end
            function object:SetStatusBarTexture(path)
                self.fill = self.fill or self:CreateTexture(nil, "ARTWORK")
                return self.fill:SetTexture(path)
            end
            function object:GetStatusBarTexture() return self.fill end
            function object:GetTexCoord() return unpack(self.coords or { 0, 1, 0, 1 }) end
            function object:SetTexCoord(...)
                Write(self, "SetTexCoord")
                self.coords = { ... }
            end
            return object
        end
        local create = context.Object
        function context:Object(...) return Native(create(self, ...)) end
        Native(env.WorldFrame)
        function context:MakePlate(name, maximum)
            local plate = env.CreateFrame("Frame", nil, env.WorldFrame)
            plate:SetWidth(100)
            plate:SetHeight(10)
            local regions = {}
            for index = 1, 6 do
                regions[index] = index == 3 and plate:CreateFontString(nil, "OVERLAY")
                    or plate:CreateTexture(nil, "ARTWORK")
            end
            plate.regions = regions
            regions[1]:SetTexture("Interface\\Tooltips\\Nameplate-Border")
            regions[3]:SetText(name)
            regions[6]:Hide()
            local bar = env.CreateFrame("StatusBar", nil, plate)
            bar.minimum, bar.maximum, bar.value = 0, maximum, maximum
            bar:SetStatusBarTexture("NativeHealth")
            plate.nativeBar = bar
            return plate
        end
        context.guardian = context:MakePlate("Hogger", 4294967296)
        context.boss = context:MakePlate("Boss", 16777216)
        context.boss.layers.HIGHLIGHT = false
        context.ordinary = context:MakePlate("Ordinary", 4294967296)
        context:Load("modules/nameplates/style.lua", "NameplateStyle")
        local attach = env.T.NameplateStyle.Attach
        env.T.NameplateStyle.Attach = function(plate, data)
            attach(plate, data)
            plate.fixture = data
        end
        if setup then setup(context, env) end
    end)
    function context:Publish(entries)
        self:Event(self.controller, "CHAT_MSG_ADDON", "AZSUNITS")
        self.env.AZS_UNITS, self.env.AZS_UNITS_UPDATED = entries, self.now
        self:Tick(0.21)
    end
    return context
end
local function Entries()
    return {
        { id = 10, kind = "guardian", name = "Hogger", hp = 70e12, hpm = 70e12 },
        { id = 11, kind = "boss", name = "Boss", hp = 16777217, hpm = 16777217 },
    }
end

local context = Plates()
local aliases = {}
context.env.T.IndexUnitMaximum(aliases, 16777217, "guardian")
context.env.T.IndexUnitMaximum(aliases, 16777217, "guardian")
assert(aliases[16777216] == "guardian", "same-kind float32 alias became ambiguous")
context.env.T.IndexUnitMaximum(aliases, 16777216, "boss")
assert(aliases[16777216] == false, "different kinds sharing float32 storage were not rejected")
assert(aliases[16777217] == "guardian", "collision erased an unrelated exact maximum")
context.env.T.IndexUnitMaximum(aliases, 16777217, "guardian")
assert(aliases[16777216] == false, "same-kind reinsertion reclaimed a collided alias")
context.env.T.IndexUnitMaximum(aliases, 70e12, "guardian")
context.env.T.IndexUnitMaximum(aliases, 80e12, "boss")
assert(aliases[4294967295] == false and aliases[4294967296] == false, "clamped kind aliases lost ambiguity")
print("PASS shared maximum aliases preserve kind conflicts across native float32 and clamped representations")
context:Tick(0.21)
assert(not context.guardian.fixture.style.name:IsVisible(), "unpublished guardian bypassed the filter")
context.env.WorldFrame.childrenReads, context.guardian.childrenReads = 0, 0
context:Event(context.controller, "PLAYER_TARGET_CHANGED")
assert(context.env.WorldFrame.childrenReads == 0, "target change forced a complete native child enumeration")
assert(context.guardian.childrenReads == 0, "target change recursively revisited an unchanged plate mask")
context.extra = context:MakePlate("Late", 1000)
context:Event(context.controller, "PLAYER_TARGET_CHANGED")
assert(context.extra.fixture, "incremental target discovery missed a newly allocated native plate")
assert(context.env.WorldFrame.childrenReads == 1, "new native children were not discovered incrementally")
print("PASS target changes refresh current plates without forcing unchanged discovery or recursive masks")
context:Publish(Entries())
local guardian, boss = context.guardian.fixture.style, context.boss.fixture.style
assert(
    guardian.name:IsVisible() and guardian.name:GetText() == "Hogger",
    "capped guardian disappeared in names-only mode"
)
assert(boss.name:IsVisible(), "float-rounded boss maximum did not match")
assert(not context.ordinary.fixture.style.name:IsVisible(), "ordinary enemy bypassed the filter")
assert(
    not guardian.health and not guardian.shadow and not guardian.background and not guardian.raid,
    "names-only allocated unused bar artwork"
)
assert(context.guardian.nativeBar.maximum == 4294967296, "filter/style rewrote the native health range")
assert(context.guardian.regions[3]:IsShown(), "layer suppression changed native name shown-state")
assert(context.guardian.regions[1]:GetAlpha() == 1, "layer suppression still used transparent native quads")
assert(context.guardian.nativeBar.fill:GetAlpha() == 1, "native fill still used alpha-only suppression")
assert(context.guardian.layers.ARTWORK == false and context.guardian.nativeBar.layers.ARTWORK == false)
assert(guardian.visual.layers.ARTWORK ~= false, "native layer suppression disabled the custom child")
context:ResetCounts()
context:Tick(0.21)
context:NoPresentationWrites()
assert(not context.writes.SetValue and not context.writes.SetMinMaxValues and not context.writes.SetStatusBarColor)
print("PASS both nameplate options preserve eligible names without bar allocation or unchanged writes")

context.guardian.nativeBar.rangeReads, context.guardian.nativeBar.valueReads = 0, 0
context:Tick(0.21)
assert(context.guardian.nativeBar.rangeReads == 1, "filter and SCT sampled the same native range twice")
assert(context.guardian.nativeBar.valueReads == 1, "SCT health sampling lost its native value")
context:SetSetting("sctStyle", "msbt")
context.guardian.nativeBar.rangeReads, context.guardian.nativeBar.valueReads = 0, 0
context:Tick(0.21)
assert(context.guardian.nativeBar.rangeReads == 1, "names-only filtering did not use its one required range")
assert(context.guardian.nativeBar.valueReads == 0, "names-only scrolling added unnecessary native health reads")
context:SetSetting("sctStyle", "enemy")
print("PASS one synchronous sample supplies filter, skin and matching without adding disabled reads")

local waking = Entries()
waking[1].hp, waking[1].hpm, waking[1].state = 1234, 1234, 0
context.guardian.nativeBar.maximum, context.guardian.nativeBar.value = 1234, 1234
context:Publish(waking)
assert(guardian.name:IsVisible(), "sleeping guardian did not match its published maximum")
-- The actor's 1234.25 maximum serializes as 1234, while engagement writes ceilf=1235.
context.guardian.nativeBar.maximum, context.guardian.nativeBar.value = 1235, 1200
context:Tick(0.21)
assert(guardian.name:IsVisible(), "native wake conversion hid a guardian before the next publication")
waking[1].hp, waking[1].state = 1200, 1
context:Publish(waking)
assert(guardian.name:IsVisible(), "awake guardian lost its rounded/ceiling health match")
assert(not guardian.health and not guardian.shadow, "combat allocated unused names-only bar artwork")
context:ResetCounts()
context:Tick(0.21)
context:NoPresentationWrites()

for _, representation in ipairs({
    { 1234.25, 1235, true },
    { 4194304, 4194305, true }, -- 4194304.5 rounds to the even integer, then ceilings up.
    { 4194305, 4194306, false }, -- The upper float32 half-tie rounds away from this odd integer.
    { 8388608, 8388609, false }, -- No float32 fractional values remain at this magnitude.
    { 1234, 1236, false },
    { 1234, 100, false },
}) do
    local publication = Entries()
    publication[1].hp, publication[1].hpm, publication[1].state = 1000, representation[1], 1
    context.guardian.nativeBar.maximum = representation[2]
    context:Publish(publication)
    assert(guardian.name:IsVisible() == representation[3], "wake conversion accepted an invalid native encoding")
end
waking[3] = { id = 12, kind = "elite", name = "Hogger", hp = 1200, hpm = 1235 }
context.guardian.nativeBar.maximum = 1235
context:Publish(waking)
assert(not guardian.name:IsVisible(), "wake conversion bypassed a known elite ambiguity")
waking[3] = nil
context:Publish(waking)
assert(guardian.name:IsVisible(), "guardian did not recover after a converted-signature ambiguity retired")
context.guardian.nativeBar.maximum, context.guardian.nativeBar.value = 4294967296, 4294967296
context:Publish(Entries())
print("PASS sleeping-to-awake guardians retain exact serialized/ceiling signatures without fuzzy or percentage matches")

context.guardian.nativeBar.maximum = 4294967295
context:Tick(0.21)
assert(guardian.name:IsVisible(), "integer uint32 clamp did not match the published guardian")
context.guardian.nativeBar.maximum = 4294967296
context.boss.nativeBar.maximum = 16777220
local rounded = Entries()
rounded[2].hp, rounded[2].hpm = 16777219, 16777219
context:Publish(rounded)
assert(boss.name:IsVisible(), "float32 odd halfway rounding did not match")
context.boss.nativeBar.maximum = 100
context:Tick(0.21)
assert(not boss.name:IsVisible(), "percentage-only bars were guessed as absolute health")
context.boss.nativeBar.maximum = 16777216
context:Publish(Entries())
print("PASS native health representations preserve ties and reject guessed percentage matches")

context:SetSetting("nameplatesNamesOnly", false)
context:Tick(0.21)
assert(
    guardian.health and guardian.health:IsVisible() and guardian.shadow:IsVisible(),
    "normal bars did not allocate on demand"
)
local allocated = #context.objects
local writes = guardian.health.calls.SetValue or 0
context.guardian.nativeBar.rangeReads, context.guardian.nativeBar.valueReads = 0, 0
context:Tick(0.21)
assert(
    context.guardian.nativeBar.rangeReads == 1 and context.guardian.nativeBar.valueReads == 1,
    "regular skin and matching duplicated native health reads"
)
local raidSource, textureReads, coordinateReads = context.guardian.regions[6], 0, 0
raidSource:SetTexture("NativeRaid")
raidSource.coords = { 0.1, 0.2, 0.3, 0.4 }
raidSource:Show()
local getTexture, getTexCoord = raidSource.GetTexture, raidSource.GetTexCoord
function raidSource:GetTexture()
    textureReads = textureReads + 1
    return getTexture(self)
end
function raidSource:GetTexCoord()
    coordinateReads = coordinateReads + 1
    return getTexCoord(self)
end
context:Tick(0.21)
assert(textureReads == 1 and coordinateReads == 1, "native raid icon was sampled repeatedly in one frame")
assert(guardian.raid.texture == "NativeRaid" and #guardian.raid.coords == 4)
raidSource.coords = { 0, 0, 0, 1, 1, 0, 1, 1 }
context:Tick(0.21)
assert(#guardian.raid.coords == 8 and guardian.raid.coords[8] == 1, "rotated native raid UVs lost their arity")
guardian.raid.texture = "native reset"
context:Tick(0.21)
assert(guardian.raid.texture == "NativeRaid", "native icon sampling hid texture restoration")
context:SetSetting("nameplatesNamesOnly", true)
context:Tick(0.21)
assert(
    guardian.name:IsVisible()
        and not guardian.health:IsVisible()
        and not guardian.shadow:IsVisible()
        and not guardian.background:IsVisible()
)
assert(
    not guardian.raid:IsVisible() and #context.objects == allocated,
    "names-only added artwork or retained a raid icon"
)
assert((guardian.health.calls.SetValue or 0) == writes, "names-only updated the cosmetic health fill")
context:SetSetting("nameplatesNamesOnly", false)
context:Tick(0.21)
assert(#context.objects == allocated and guardian.health:IsVisible(), "normal mode did not reuse the pooled skin")
print("PASS names-only transitions hide actual regions and reuse lazily allocated bars")

local entries = Entries()
entries[2].id = entries[1].id
context:Publish(entries)
assert(not guardian.name:IsVisible() and not boss.name:IsVisible(), "duplicate IDs leaked a partial roster")
context:Publish(Entries())
assert(guardian.name:IsVisible() and boss.name:IsVisible(), "valid receipt did not recover after duplicate IDs")
print("PASS nameplates share target roster rejection and recover on a valid publication")

entries = Entries()
entries[3] = { id = 12, kind = "elite", name = "Hogger", hp = 80e12, hpm = 80e12 }
context:Publish(entries)
assert(not guardian.name:IsVisible(), "ambiguous capped elite signature exposed a guardian name")
context:Publish(Entries())
assert(guardian.name:IsVisible(), "guardian did not recover after ambiguity was removed")
context:SetSetting("nameplatesNamesOnly", true)
context:SetSetting("nameplatesBossGuardiansOnly", false)
context:Tick(0.21)
assert(context.ordinary.fixture.style.name:IsVisible(), "disabling the filter did not restore ordinary names")
context.env.HideNameplates()
context:Tick(0.21)
assert(not guardian.name:IsVisible(), "V-off leaked a custom guardian name")
context.env.ShowNameplates()
context:Tick(0.21)
assert(guardian.name:IsVisible(), "V-on did not restore names-only mode")
assert(context.guardian.layers.ARTWORK == false, "V unmask restored native artwork behind the skin")
assert(context.guardian.nativeBar.layers.ARTWORK == false, "V unmask restored the native health image")
print("PASS ambiguity, filter preview and native V masking retain their lifecycles")

context.ordinary:Hide()
context.ordinary.shownReads = 0
context:Tick(0.21)
context:Tick(0.21)
assert(context.ordinary.shownReads == 0, "per-frame sampling still traversed a hidden pooled plate")
local ordinarySkin = context.ordinary.fixture.style
context.ordinary:Show()
context:Tick(0.21)
assert(
    context.ordinary.fixture.style == ordinarySkin and ordinarySkin.name:IsVisible(),
    "shown plate did not rejoin its existing skin"
)
print("PASS hidden native plates leave the sampling set and rejoin through the existing show hook")

context:SetSetting("nameplatesBossGuardiansOnly", true)
context:Tick(0.21)
context:Event(context.controller, "CHAT_MSG_ADDON", "AZSZONE")
context:Tick(0.21)
assert(not guardian.name:IsVisible(), "zone retirement reused an old guardian classification")
context:Event(context.controller, "CHAT_MSG_ADDON", "AZSRUN")
context:Publish(Entries())
assert(
    guardian.name:IsVisible() and not guardian.health:IsVisible(),
    "fresh publications lost the names-only/filter combination"
)
print("PASS nameplate filter retirement waits for fresh run/unit publications")

context:Event(context.controller, "PLAYER_LEAVING_WORLD")
assert(context.guardian.layers.ARTWORK == true, "world cleanup retained the native plate layer mask")
assert(context.guardian.nativeBar.layers.ARTWORK == true, "world cleanup retained the native fill mask")
assert(context.boss.layers.HIGHLIGHT == false, "cleanup enabled a previously disabled native layer")
assert(context.guardian.regions[3]:IsShown(), "cleanup changed native shown-state")
context:Event(context.controller, "PLAYER_ENTERING_WORLD")
context:Tick(0.21)
assert(context.guardian.layers.ARTWORK == false, "world recovery did not reacquire native layer suppression")
print("PASS native-owner layers suppress extraction and restore their captured state without hiding source regions")

do
    local matching = Plates(function(current, env)
        env.T.ParseNameplateCombatEvent = function(_, message)
            return {
                kind = "damage",
                damageType = "autoattack",
                sourceName = "Player",
                targetName = current.targetName,
                amount = tonumber(message),
            }
        end
    end)
    local function DamageLabel(amount)
        local found, count = nil, 0
        for _, label in ipairs(matching:Labels()) do
            if label:GetText() == tostring(amount) then
                found, count = label, count + 1
            end
        end
        return found, count
    end
    local shared, unrelated = {}, {}
    for index = 1, 3 do
        shared[index] = matching:MakePlate("Shared", 1000)
        shared[index].centerX = index == 1 and 1024 or 1e-13
        for other = 1, 12 do
            local name = index == 1 and other == 1 and "dirty" or "Other" .. index .. ":" .. other
            table.insert(unrelated, matching:MakePlate(name, 1000))
        end
    end
    matching:Tick(0)
    local first, second, third = shared[1].fixture.origin, shared[2].fixture.origin, shared[3].fixture.origin
    local master, named, masterReads, namedReads = nil, nil, 0, 0
    local firstMaster, secondMaster = matching.guardian.fixture.origin, matching.boss.fixture.origin
    local getn = matching.env.table.getn
    matching.env.table.getn = function(list)
        if list[1] == firstMaster and list[2] == secondMaster then
            master, masterReads = list, masterReads + 1
        elseif list[1] == first and list[2] == second then
            named, namedReads = list, namedReads + 1
        end
        return getn(list)
    end
    matching.targetName = "Shared"
    matching:Hit(211)
    matching:Tick(0.17)
    assert(masterReads == 1 and namedReads == 1, "one hit still scanned the unrelated origin catalog")
    assert(named[1] == first and named[2] == second and named[3] == third, "same-name creation order changed")
    assert(
        DamageLabel(211).parent.parent.anchor.x == ((1024 + 1e-13) + 1e-13) / 3,
        "ambiguous centroid arithmetic changed order"
    )
    shared[1].nativeBar.value = 900
    matching:Call(shared[1].nativeBar, "OnValueChanged")
    matching:Hit(100)
    matching:Tick(0.09)
    assert(DamageLabel(100).parent.parent.anchor.x == 1024, "unique exact loss did not keep its own origin")
    assert(first.lossRemaining == 0, "the matched original hit did not consume its loss")
    shared[1].nativeBar.value, shared[2].nativeBar.value = 800, 900
    matching:Call(shared[1].nativeBar, "OnValueChanged")
    matching:Call(shared[2].nativeBar, "OnValueChanged")
    matching:Hit(100)
    matching:Tick(0.09)
    local _, count = DamageLabel(100)
    assert(count == 1, "ambiguous loss resolved before the original fallback deadline")
    matching:Tick(0.08)
    local label
    label, count = DamageLabel(100)
    assert(count == 2 and label.parent.parent.anchor.x == (1024 + 1e-13) / 2, "loss ambiguity changed")
    print("PASS SCT matching visits only exact-name origins and preserves ordered centroids, loss and deadlines")

    local liveReads = 0
    for _, origin in ipairs(master) do
        local live = origin.live
        origin.live = nil
        setmetatable(origin, {
            __index = function(_, key)
                if key == "live" then
                    liveReads = liveReads + 1
                    return live
                end
            end,
            __newindex = function(object, key, value)
                if key == "live" then
                    live = value
                else
                    rawset(object, key, value)
                end
            end,
        })
    end
    matching:Tick(0.016)
    assert(liveReads == 0, "idle SCT still traversed the live-origin catalog for retirement")

    -- Zero is exact here so the strict 0.65-second retention boundary is tested
    -- without adding two nonzero floating-point timestamps first.
    matching.now = 0
    matching:Tick(0)
    assert(liveReads == 0, "new retirement scanned origins before any retention deadline")
    shared[2]:Hide()
    shared[2].regions[3]:SetText("Renamed")
    shared[2]:Show()
    assert(shared[2].fixture.origin ~= second and second.name == "Shared" and not second.live)
    liveReads = 0
    for index, plate in ipairs(unrelated) do
        if math.mod(index, 2) == 1 then plate:Hide() end
    end
    matching:Tick(0)
    local originalCount, expected = getn(master), {}
    for _, origin in ipairs(master) do
        if origin.live then table.insert(expected, origin) end
    end
    liveReads = 0
    local remove = matching.env.table.remove
    matching.env.table.remove = function(list, index)
        assert(list ~= master and list ~= named, "origin retirement shifted a tail with table.remove")
        return remove(list, index)
    end
    matching:Tick(0.65)
    assert(liveReads == 0, "inclusive retirement boundary still traversed the full origin catalog")
    assert(getn(master) == originalCount and getn(named) == 3, "recent incarnations retired at the inclusive boundary")
    matching:Tick(0.001)
    assert(liveReads > 0, "expired origins were not reconsidered after their strict retention boundary")
    assert(getn(master) == #expected and master[#expected + 1] == nil, "master origins retained a stale tail or size")
    for index, origin in ipairs(expected) do
        assert(master[index] == origin, "mixed mass retirement changed surviving creation order")
    end
    assert(named[1] == first and named[2] == third and named[3] == nil and getn(named) == 2)
    matching.targetName = "dirty"
    matching:Hit(399)
    matching:Tick(0.17)
    assert(DamageLabel(399).parent.parent.anchor.x == 800, "an emptied native-name bucket retained an old origin")

    shared[1].centerX = 500
    shared[3].regions[3]:SetText("Other occupant")
    matching:SetSetting("sctStyle", "msbt")
    matching:SetSetting("sctStyle", "enemy")
    matching.targetName = "Shared"
    matching:Hit(401)
    matching:Tick(0.09)
    assert(DamageLabel(401).parent.parent.anchor.x == 500, "style reset retained a previous origin index")
    matching:Event(matching.controller, "PLAYER_LEAVING_WORLD")
    shared[1].regions[3]:SetText("New world occupant")
    matching:Event(matching.controller, "PLAYER_ENTERING_WORLD")
    matching:Hit(402)
    matching:Tick(0.17)
    assert(DamageLabel(402).parent.parent.anchor.x == 800, "world cleanup retained an origin-name index")
    print("PASS SCT mass retirement is stable, keeps recent reuse and clears name indices on style/world retirement")
end

do
    local cached = Plates(function(current, env)
        env.DFRL.locale.CombatText = function(value) return value end
        env.T.ParseNameplateCombatEvent = function(_, message)
            return {
                kind = current.hitKind or "damage",
                damageType = "autoattack",
                sourceName = "Player",
                targetName = current.targetName,
                amount = tonumber(message),
                text = current.hitKind == "miss" and "MISS" or nil,
            }
        end
    end)
    local function Label(value)
        local found, count = nil, 0
        for _, label in ipairs(cached:Labels()) do
            if label:GetText() == tostring(value) then
                found, count = label, count + 1
            end
        end
        return found, count
    end
    local first, second = cached:MakePlate("Cache", 1000), cached:MakePlate("Cache", 1000)
    first.centerX, second.centerX = 100, 300
    cached:Tick(0)
    local firstOrigin, secondOrigin = first.fixture.origin, second.fixture.origin
    local scans, widths = 0, 0
    local getn, getWidth = cached.env.table.getn, cached.env.WorldFrame.GetWidth
    cached.env.table.getn = function(list)
        if list[1] == firstOrigin and list[2] == secondOrigin then scans = scans + 1 end
        return getn(list)
    end
    cached.env.WorldFrame.GetWidth = function(self)
        widths = widths + 1
        return getWidth(self)
    end
    cached.targetName = "Missing"
    for _ = 1, 20 do
        cached:Hit(201)
    end
    cached:Tick(0.17)
    assert(
        widths == 2 and Label(201).parent.parent.anchor.x == 800,
        "repeated no-match hits repeated native fallback reads"
    )
    local before = widths
    cached:Hit(201)
    cached:Tick(0.17)
    assert(widths - before == 2, "another matching pass reused the previous fallback query")
    cached.targetName = "Cache"
    for _ = 1, 20 do
        cached:Hit(202)
    end
    cached:Tick(0.17)
    assert(
        scans == 1 and Label(202).parent.parent.anchor.x == 200,
        "identical ambiguous hits repeated their candidate scan"
    )

    before = scans
    cached:Hit(203)
    cached:Hit(204)
    cached.hitKind = "miss"
    cached:Hit(204)
    cached.hitKind = nil
    cached:Tick(0.17)
    assert(
        scans - before == 3 and Label(203) and Label(204) and Label("MISS"),
        "amount or kind queries shared an answer"
    )
    cached.targetName = "Missing"
    cached:Hit(205)
    cached.targetName = "Cache"
    cached:Hit(205)
    cached:Tick(0.17)
    assert(Label(205).parent.parent.anchor.x == 500, "distinct native names shared a cached fallback")

    cached:Hit(206)
    cached.now = cached.now + 0.09
    cached:Hit(206)
    before = scans
    cached:Tick(0.09)
    local _, count = Label(206)
    assert(scans - before == 2 and count == 1, "fallback-enabled and waiting queries shared an answer")
    before = scans
    cached:Tick(0.08)
    _, count = Label(206)
    assert(scans - before == 1 and count == 2, "a cached nil result survived into the next matching pass")

    first.nativeBar.value, second.nativeBar.value = 900, 800
    cached:Call(first.nativeBar, "OnValueChanged")
    cached:Call(second.nativeBar, "OnValueChanged")
    for _ = 1, 3 do
        cached:Hit(100)
    end
    before = scans
    cached:Tick(0.09)
    assert(scans - before == 3, "consumed loss reused an already stale matching result")
    assert(
        firstOrigin.lossRemaining == 0 and secondOrigin.lossRemaining == 0,
        "an original hit skipped loss consumption"
    )
    assert(
        Label(100).parent.parent.anchor.x == (100 + 300 + 300) / 3,
        "loss invalidation changed the original centroid"
    )

    before = widths
    for index = 1, 65 do
        cached.targetName = "Missing" .. index
        cached:Hit(207)
    end
    cached:Hit(207)
    cached.targetName = "Missing1"
    cached:Hit(207)
    cached:Tick(0.17)
    assert(widths - before == 67, "query capacity changed fallback behavior or omitted the first cached name")
    assert(Label(207).parent.parent.anchor.x == 800, "cache capacity dropped or moved an original hit")
    print(
        "PASS SCT pass-local queries reuse no-match/ambiguity, separate exact keys and retire at loss/pass boundaries"
    )
end

-- Enemy styles follow one matched native incarnation without rematching.
local function FollowingPlates(performance, style)
    return Plates(function(current, env)
        current.settings.sctStyle = style
        current.settings.performanceMode = performance
        current.settings.nameplatesBossGuardiansOnly = false
        env.NAMEPLATES_ON = nil
        -- Both production controllers get identical launch choices, allowing a
        -- stationary reference without copying any production motion equation.
        local nativeMath = env.math
        env.math = {}
        for key, value in pairs(nativeMath) do
            env.math[key] = value
        end
        env.math.random = function(low) return low end
        env.T.ParseNameplateCombatEvent = function(_, message)
            return {
                kind = "damage",
                damageType = "autoattack",
                sourceName = "Player",
                targetName = current.targetName,
                amount = tonumber(message),
            }
        end
    end)
end

local function Near(actual, expected, message) assert(math.abs(actual - expected) < 0.00000001, message) end

for _, style in ipairs({ "diablo", "enemy" }) do
    for _, performance in ipairs({ false, true }) do
        local moving, stationary = FollowingPlates(performance, style), FollowingPlates(performance, style)
        local plate, reference = moving:MakePlate("Moving", 1000), stationary:MakePlate("Moving", 1000)
        for _, item in ipairs({ plate, reference }) do
            item.centerX, item.top = 280, 320
        end
        for _, current in ipairs({ moving, stationary }) do
            current:Tick(0)
            current.targetName = "Moving"
            current:Hit(17)
            current:Hit(performance and 19 or 17)
            current:Tick(performance and 0.301 or 0.17)
            assert(#current:Labels() == 1, "same-origin originals stopped sharing a displayed group")
        end
        local label, referenceLabel = assert(moving:Labels()[1]), assert(stationary:Labels()[1])
        local holder, referenceHolder = label.parent.parent, referenceLabel.parent.parent
        local allocated = #moving.objects
        moving:ResetCounts()
        local points = { { 950, 650 }, { 80, 120 }, { 850, 550 }, { 150, 700 }, { 280, 320 } }
        for index = 1, 48 do
            local point = points[math.mod(index - 1, #points) + 1]
            plate.centerX, plate.top = point[1], point[2]
            moving:Tick(1 / 60)
            stationary:Tick(1 / 60)
            assert(plate.fixture.origin.x == point[1], "follow lost required native matching samples")
            assert(moving:Labels()[1] == label, "native movement replaced the active number")
            Near(holder.anchor.x - referenceHolder.anchor.x, point[1] - 280, "text lost horizontal plate movement")
            Near(holder.anchor.y - referenceHolder.anchor.y, point[2] - 320, "text lost vertical plate movement")
            assert(
                label:GetText() == (performance and "36" or "17") and holder:GetAlpha() == referenceHolder:GetAlpha(),
                "following changed the group amount or lifetime/fade"
            )
            assert(label.parent.scale == referenceLabel.parent.scale, "following restarted the scale animation")
            if index == 24 then
                local x, y = holder.anchor.x, holder.anchor.y
                moving:SetSetting("performanceMode", not performance)
                stationary:SetSetting("performanceMode", not performance)
                assert(
                    moving:Labels()[1] == label and holder.anchor.x == x and holder.anchor.y == y,
                    "Performance Mode transition restarted active following text"
                )
            end
        end
        assert(
            not moving.writes.SetText and not moving.writes.Show and not moving.writes.Hide,
            "native movement flickered active text visibility"
        )
        assert(#moving.objects == allocated, "native movement allocated replacement text")
        assert(moving.backing and moving.env.NAMEPLATES_ON == nil, "following changed native V ownership")

        local x, y = holder.anchor.x, holder.anchor.y
        plate.centerX = math.huge
        moving:Tick(0)
        assert(holder.anchor.x == x and holder.anchor.y == y, "invalid projection lost the last usable position")
        local origin = plate.fixture.origin
        plate:Hide()
        plate.centerX, plate.top = 700, 500
        plate.regions[3]:SetText("Other occupant")
        plate:Show()
        moving:Tick(0)
        assert(
            not origin.live and plate.fixture.origin ~= origin,
            "frame reuse retained the retired native incarnation"
        )
        assert(holder.anchor.x == x and holder.anchor.y == y, "frame retirement/reuse moved an active number")
        moving:SetSetting("performanceMode", performance)
        moving:Tick(0)
        assert(
            moving:Labels()[1] == label and holder.anchor.x == x and holder.anchor.y == y,
            "Performance Mode restarted or repositioned retired-origin text"
        )
        moving:Tick(0.7)
        assert(#moving:Labels() == 0, "native movement extended the original style lifetime")

        plate:Hide()
        plate.regions[3]:SetText("Moving")
        plate:Show()
        moving.targetName = "Moving"
        moving:Hit(23)
        moving:Tick(0.301)
        assert(
            moving:Labels()[1] == label and holder.anchor.x == 700,
            "a new number did not reuse the pool at its own current origin"
        )
        plate.centerX, plate.top = 450, 250
        moving:Tick(0)
        assert(
            holder.anchor.x == 450 and holder.anchor.y == 262,
            "pooled text kept the old origin instead of following its new incarnation"
        )
        moving:Event(moving.controller, "PLAYER_LEAVING_WORLD")
        stationary:Event(stationary.controller, "PLAYER_LEAVING_WORLD")
        assert(#moving:Labels() == 0 and not moving.backing, "world cleanup retained following text")
        moving:ResetCounts()
        moving:Tick(0.2)
        moving:NoPresentationWrites()
    end
end
print(
    "PASS enemy and Diablo groups follow native movement in both modes, preserve animation and freeze on retirement/reuse"
)

for _, style in ipairs({ "diablo", "enemy" }) do
    for _, performance in ipairs({ false, true }) do
        local current = FollowingPlates(performance, style)
        local plate = current:MakePlate("Moving", 1000)
        plate.centerX, plate.top = 280, 320
        current:Tick(0)
        current.targetName = "Moving"
        current:Hit(17)
        current:Tick(0.04)
        current:Hit(performance and 19 or 17)
        current:Tick(0.05)
        assert(#current:Labels() == 0, "a group displayed before every original finished settling")
        plate.centerX, plate.top = 700, 500
        current:Tick(0.041)
        if performance then
            assert(#current:Labels() == 0, "a summed group displayed before its intake closed")
            plate.centerX, plate.top = 900, 650
            current:Tick(0.17)
        end
        local label = assert(current:Labels()[1])
        local holder = label.parent.parent
        assert(
            holder.anchor.x == plate.centerX and holder.anchor.y == plate.top + 12,
            "a group launched from stale resolved coordinates instead of its latest common origin"
        )
        current:Event(current.controller, "PLAYER_LEAVING_WORLD")
    end
end
print("PASS settled groups launch at their common origin's latest position in either style or mode")

for _, style in ipairs({ "diablo", "enemy" }) do
    for _, performance in ipairs({ false, true }) do
        for _, targets in ipairs({
            { "First", "Second", "First" },
            { "First", "Missing", "First" },
            { "Missing", "First", "First" },
        }) do
            local moving, stationary = FollowingPlates(performance, style), FollowingPlates(performance, style)
            local first = moving:MakePlate("First", 1000)
            local second = moving:MakePlate("Second", 1000)
            local referenceFirst = stationary:MakePlate("First", 1000)
            local referenceSecond = stationary:MakePlate("Second", 1000)
            for _, item in ipairs({ first, referenceFirst }) do
                item.centerX, item.top = 100, 200
            end
            for _, item in ipairs({ second, referenceSecond }) do
                item.centerX, item.top = 500, 600
            end
            for _, current in ipairs({ moving, stationary }) do
                current:Tick(0)
                for index, target in ipairs(targets) do
                    current.targetName = target
                    current:Hit(performance and (index * 2 + 15) or 17)
                end
                current:Tick(performance and 0.301 or 0.17)
                assert(#current:Labels() == 1, "mixed-origin originals lost their grouped presentation")
            end
            local label, referenceLabel = moving:Labels()[1], stationary:Labels()[1]
            local holder, referenceHolder = label.parent.parent, referenceLabel.parent.parent
            local secondX, secondY = targets[2] == "Second" and 500 or 800, targets[2] == "Second" and 600 or 522
            if targets[1] == "Missing" then
                secondX, secondY = 800, 522
            end
            Near(holder.anchor.x, (100 + secondX + 100) / 3, "mixed group changed its original hit centroid")
            Near(holder.anchor.y, (200 + secondY + 200) / 3 + 12, "mixed group changed its vertical hit centroid")
            -- A later plate with a previously unmatched name must not claim an
            -- active fallback label, nor may a later member restore following.
            local late = moving:MakePlate("Missing", 1000)
            late.centerX, late.top = 1200, 700
            first.centerX, first.top = 900, 800
            second.centerX, second.top = 50, 100
            for _ = 1, 12 do
                moving:Tick(1 / 60)
                stationary:Tick(1 / 60)
                Near(
                    holder.anchor.x,
                    referenceHolder.anchor.x,
                    "mixed or nil origins acquired a live horizontal follow"
                )
                Near(holder.anchor.y, referenceHolder.anchor.y, "mixed or nil origins acquired a live vertical follow")
                assert(label:GetText() == (performance and "57" or "17"), "mixed follow changed displayed totals")
            end
            moving:Event(moving.controller, "PLAYER_LEAVING_WORLD")
            stationary:Event(stationary.controller, "PLAYER_LEAVING_WORLD")
        end
    end
end
print("PASS mixed and nil-origin groups keep their original centroid without rematching in either style or mode")

-- CI-only native camera boundary: freelook releases the old plate capture
-- synchronously, then routes the later physical release to WorldFrame.
local function CameraPlates(performance, missing)
    return Plates(function(current, env)
        current.settings.performanceMode = performance
        current.settings.nameplatesBossGuardiansOnly = false
        local camera = { starts = 0, stops = 0, queries = 0, looking = false, worldUps = {}, reloads = 0 }
        current.camera = camera
        local function NativeInput(plate)
            plate.nativeDown, plate.nativeUp = {}, {}
            plate:SetScript("OnMouseDown", function()
                local button = env.arg1
                plate.nativeDown[button] = (plate.nativeDown[button] or 0) + 1
                if button == "LeftButton" then current.nativeTarget = plate end
            end)
            plate:SetScript("OnMouseUp", function()
                local button = env.arg1
                plate.nativeUp[button] = (plate.nativeUp[button] or 0) + 1
            end)
        end
        for _, plate in ipairs({ current.guardian, current.boss, current.ordinary }) do
            NativeInput(plate)
        end
        local make = current.MakePlate
        function current:MakePlate(...)
            local plate = make(self, ...)
            NativeInput(plate)
            return plate
        end
        env.WorldFrame:SetScript("OnMouseUp", function()
            local button = env.arg1
            camera.worldUps[button] = (camera.worldUps[button] or 0) + 1
        end)
        env.WorldFrame:SetScript("OnHide", function() camera.worldHides = (camera.worldHides or 0) + 1 end)
        env.MouselookStart = function()
            camera.starts, camera.looking = camera.starts + 1, true
            local previous = camera.capture
            camera.capture, camera.focus = nil, env.WorldFrame
            if previous then current:Call(previous, "OnMouseUp", "RightButton") end
            if camera.onStart then camera.onStart() end
        end
        env.MouselookStop = function()
            camera.stops, camera.looking, camera.focus = camera.stops + 1, false, nil
        end
        env.IsMouselooking = function()
            camera.queries = camera.queries + 1
            if performance then return camera.looking end
            return camera.looking and 1 or 0
        end
        env.TurnOrActionStart = function() error("binding-only TurnOrActionStart called from a plate script") end
        env.TurnOrActionStop = function() error("binding-only TurnOrActionStop called from a plate script") end
        env.ReloadUI = function() camera.reloads = camera.reloads + 1 end
        if missing then env[missing] = nil end
        function current:Press(plate, button)
            camera.capture = plate
            self:Call(plate, "OnMouseDown", button)
        end
        function current:Release(button)
            local recipient = camera.focus or camera.capture
            camera.capture = nil
            if recipient then self:Call(recipient, "OnMouseUp", button) end
        end
    end)
end

for _, performance in ipairs({ false, true }) do
    local current = CameraPlates(performance)
    current:Tick(0)
    local plate, camera = current.ordinary, current.camera
    local down, up = plate:GetScript("OnMouseDown"), plate:GetScript("OnMouseUp")
    local worldUp = current.env.WorldFrame:GetScript("OnMouseUp")
    local allocated = #current.objects
    for _, button in ipairs({ "LeftButton", "MiddleButton" }) do
        current:Press(plate, button)
        current:Release(button)
        assert(plate.nativeDown[button] == 1 and plate.nativeUp[button] == 1, "original non-right input was lost")
    end
    assert(current.nativeTarget == plate and camera.starts == 0 and camera.stops == 0, "left-click targeting changed")
    current:Press(plate, "RightButton")
    assert(camera.starts == 1 and camera.looking and camera.stops == 0, "synthetic plate release stopped camera entry")
    assert(
        plate.nativeDown.RightButton == 1 and plate.nativeUp.RightButton == 1,
        "original right-button handlers were lost"
    )
    current:Release("LeftButton")
    assert(camera.looking and camera.stops == 0, "another mouse button ended the held right-button camera")
    current:Release("RightButton")
    assert(
        not camera.looking and camera.stops == 1 and camera.worldUps.RightButton == 1,
        "WorldFrame release lost camera stop"
    )
    current:Release("RightButton")
    assert(camera.stops == 1, "an unowned repeated release called native camera stop")

    current:Press(plate, "RightButton")
    plate:Hide()
    plate.regions[3]:SetText("Reused enemy")
    plate:Show()
    current:Tick(0)
    assert(camera.looking and camera.stops == 1, "plate death or frame reuse interrupted a held camera")
    current:Release("RightButton")
    assert(not camera.looking and camera.stops == 2, "reused plate lost the WorldFrame release")
    current:Press(plate, "RightButton")
    current:Call(plate, "OnMouseUp", "RightButton")
    assert(not camera.looking and camera.stops == 3, "real plate release did not end its owned camera hold")

    local starts = camera.starts
    current.env.HideNameplates()
    current:Call(plate, "OnMouseDown", "RightButton")
    assert(camera.starts == starts, "V-off tracking plate started camera input")
    current.env.ShowNameplates()
    current:SetSetting("nameplatesBossGuardiansOnly", true)
    current:Call(plate, "OnMouseDown", "RightButton")
    assert(camera.starts == starts, "filtered plate started camera input")
    current:SetSetting("nameplatesBossGuardiansOnly", false)
    current:Tick(0)
    plate:Hide()
    current:Call(plate, "OnMouseDown", "RightButton")
    plate:Show()
    plate.nativeBar.color = { 0, 1, 0, 1 }
    current:Call(plate, "OnMouseDown", "RightButton")
    plate.nativeBar.color = { 1, 0, 0, 1 }
    assert(camera.starts == starts, "hidden or friendly plate started hostile camera input")

    assert(#current.objects == allocated, "camera input allocated another frame or region")
    current.env.DFRL.sct.BeginEdit()
    for _, mode in ipairs({ "off", "default", "on" }) do
        current.env.DFRL.sct.SetMode(mode)
        for _, style in ipairs({ "enemy", "msbt" }) do
            current:SetSetting("sctStyle", style)
            current:Press(plate, "RightButton")
            assert(camera.looking, "visible plate camera depended on SCT mode or style")
            current:Release("RightButton")
            assert(not camera.looking, "SCT mode/style lost camera release")
        end
    end
    current.env.DFRL.sct.FinishEdit(false)
    current:SetSetting("sctStyle", "enemy")
    current:Tick(0)
    local queries = camera.queries
    allocated = #current.objects
    for _, object in ipairs(current.objects) do
        assert(
            object == current.controller or not object:GetScript("OnUpdate"),
            "camera support installed another updater"
        )
    end
    current:ResetCounts()
    for _ = 1, 12 do
        current:Tick(1 / 60)
    end
    current:NoPresentationWrites()
    assert(camera.queries == queries and #current.objects == allocated, "idle camera support polled or allocated")
    assert(
        plate:GetScript("OnMouseDown") == down
            and plate:GetScript("OnMouseUp") == up
            and current.env.WorldFrame:GetScript("OnMouseUp") == worldUp,
        "plate discovery or reuse installed duplicate camera hooks"
    )
    current:Event(current.controller, "PLAYER_LEAVING_WORLD")
end
print(
    "PASS right-button camera entry survives native capture transfer and plate reuse while preserving left targeting and SCT modes"
)

for _, performance in ipairs({ false, true }) do
    for _, cleanup in ipairs({ "worldHide", "PLAYER_LEAVING_WORLD", "PLAYER_LOGOUT", "reload" }) do
        for _, foreign in ipairs({ false, true }) do
            local current = CameraPlates(performance)
            current:Tick(0)
            local camera, plate = current.camera, current.ordinary
            if foreign then
                current.env.MouselookStart()
                current:Press(plate, "RightButton")
                assert(camera.starts == 1, "pre-existing native camera look was started again")
                current:Release("RightButton")
                assert(camera.looking and camera.stops == 0, "plate release stopped a pre-existing foreign camera")
            else
                current:Press(plate, "RightButton")
            end
            if cleanup == "worldHide" then
                current.env.WorldFrame:Hide()
                assert(camera.worldHides == 1, "camera cleanup replaced the existing WorldFrame hide handler")
            elseif cleanup == "reload" then
                current.env.ReloadUI()
                assert(camera.reloads == 1, "camera cleanup replaced native ReloadUI")
            else
                current:Event(current.controller, cleanup)
            end
            assert(camera.looking == foreign and camera.stops == (foreign and 0 or 1), "cleanup lost camera ownership")
            local starts = camera.starts
            current:Call(plate, "OnMouseDown", "RightButton")
            assert(camera.starts == starts, "inactive or hidden world accepted plate camera input")
        end
    end

    local transferred = CameraPlates(performance)
    transferred:Tick(0)
    transferred:Press(transferred.ordinary, "RightButton")
    transferred.env.MouselookStart()
    transferred:Release("RightButton")
    transferred:Event(transferred.controller, "PLAYER_LEAVING_WORLD")
    assert(transferred.camera.looking and transferred.camera.stops == 0, "external start did not take camera ownership")
    local stopped = CameraPlates(performance)
    stopped:Tick(0)
    stopped:Press(stopped.ordinary, "RightButton")
    stopped.env.MouselookStop()
    stopped:Release("RightButton")
    stopped:Event(stopped.controller, "PLAYER_LEAVING_WORLD")
    assert(stopped.camera.stops == 1, "external stop left an owned hold that stopped again")
end
print("PASS camera world/logout/reload cleanup stops only owned holds and preserves external native look sessions")

for _, performance in ipairs({ false, true }) do
    local hidden = CameraPlates(performance)
    hidden:Tick(0)
    hidden.camera.onStart = function() hidden.env.WorldFrame:Hide() end
    hidden:Press(hidden.ordinary, "RightButton")
    assert(
        hidden.camera.starts == 1 and hidden.camera.stops == 1 and not hidden.camera.looking,
        "synchronous world hiding left a camera hold pending after native start"
    )
    hidden.camera.onStart = nil
    hidden.env.WorldFrame:Show()
    hidden:Press(hidden.ordinary, "RightButton")
    assert(hidden.camera.starts == 2 and hidden.camera.looking, "deferred cleanup prevented the next camera hold")
    hidden:Release("RightButton")
    hidden:Event(hidden.controller, "PLAYER_LEAVING_WORLD")
    assert(hidden.camera.stops == 2, "deferred cleanup retained ownership after the next real release")

    local released = CameraPlates(performance)
    released:Tick(0)
    released:Press(released.ordinary, "RightButton")
    -- A native release can bypass both Lua mouse-up scripts and the global
    -- stop verb; the next physical press must still acquire a new hold.
    released.camera.looking, released.camera.focus = false, nil
    released:Press(released.ordinary, "RightButton")
    assert(released.camera.starts == 2 and released.camera.looking, "stale ownership blocked a fresh camera press")
    released:Release("RightButton")
    released:Event(released.controller, "PLAYER_LEAVING_WORLD")
    assert(released.camera.stops == 1 and not released.camera.looking, "fresh camera hold did not stop exactly once")

    local failed = CameraPlates(performance)
    failed:Tick(0)
    failed.camera.onStart = function() error("injected native error after camera entry") end
    failed:Press(failed.ordinary, "RightButton")
    assert(
        failed.camera.starts == 1 and failed.camera.stops == 1 and not failed.camera.looking,
        "native entry error retained a partially started camera hold"
    )
    failed.camera.onStart = nil
    failed:Press(failed.ordinary, "RightButton")
    assert(failed.camera.starts == 2 and failed.camera.looking, "native entry error prevented a later valid hold")
    failed:Release("RightButton")
    failed:Event(failed.controller, "PLAYER_LEAVING_WORLD")
    assert(failed.camera.stops == 2, "native entry error retained stale ownership")
end
print(
    "PASS camera entry flushes synchronous cleanup, recovers from unobserved native release and stops partial native errors"
)

for _, missing in ipairs({ "MouselookStart", "MouselookStop", "IsMouselooking" }) do
    local current = CameraPlates(false, missing)
    current:Tick(0)
    local plate, camera = current.ordinary, current.camera
    for _, button in ipairs({ "LeftButton", "RightButton", "MiddleButton" }) do
        current:Press(plate, button)
        current:Release(button)
        assert(
            plate.nativeDown[button] == 1 and plate.nativeUp[button] == 1,
            "missing API changed native plate handlers"
        )
    end
    assert(camera.starts == 0 and camera.stops == 0 and camera.queries == 0, "partial native camera API was used")
    assert(current.nativeTarget == plate, "missing API fallback changed left-click targeting")
    current:Event(current.controller, "PLAYER_LEAVING_WORLD")
end
print("PASS missing native camera APIs preserve original plate input without partial camera control")
