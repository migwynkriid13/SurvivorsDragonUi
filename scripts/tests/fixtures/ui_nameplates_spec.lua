-- CI only: full production filter, masking and skin over explicit native plates.
assert(_VERSION == "Lua 5.1", "nameplate fixtures require CI Lua 5.1")
local SCT = dofile("scripts/tests/fixtures/ui_sct_helpers.lua")
local function Plates()
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
            function object:GetCenter() return 200, 200 end
            function object:GetTop() return 205 end
            function object:GetChildren()
                local children = {}
                for _, child in ipairs(context.objects) do
                    if child.parent == self and child.kind ~= "Texture" and child.kind ~= "FontString" then
                        table.insert(children, child)
                    end
                end
                return unpack(children)
            end
            function object:GetNumChildren() return select("#", self:GetChildren()) end
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
            function object:GetMinMaxValues() return self.minimum or 0, self.maximum or 100 end
            function object:SetMinMaxValues(low, high)
                Write(self, "SetMinMaxValues")
                self.minimum, self.maximum = low, high
            end
            function object:GetValue() return self.value or 0 end
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
context:Tick(0.21)
assert(not context.guardian.fixture.style.name:IsVisible(), "unpublished guardian bypassed the filter")
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
