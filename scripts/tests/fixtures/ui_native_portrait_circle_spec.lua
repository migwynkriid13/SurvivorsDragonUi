-- CI only: retained portraits use the production shared circle and strip pool.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "native portrait fixtures require CI Lua 5.1")

local function Fixture(circle)
    local c = H.New()
    local env = c.env
    local state = { calls = 0, preparations = 0, scale = 1 }
    local create = c.Object
    function c:Object(...)
        local object = create(self, ...)
        local setPoint, setTexCoord = object.SetPoint, object.SetTexCoord
        function object:SetPoint(...)
            setPoint(self, ...)
            self.point = { ... }
        end
        function object:SetTexCoord(...)
            setTexCoord(self, ...)
            self.uv = { ... }
        end
        return object
    end
    c:Load("core/widgets.lua")
    env.T.SourceIconFallback = "Interface\\Icons\\INV_Misc_QuestionMark"
    local parent = env.CreateFrame("Frame", nil, env.UIParent)
    function parent:GetEffectiveScale() return state.scale end
    local portrait = parent:CreateTexture("NativeCirclePortrait", "ARTWORK")
    portrait:Hide()
    if circle then
        env.SetPortraitToTexture = function(name, icon)
            state.preparations = state.preparations + 1
            assert(env[name] == portrait, "circle preparation targeted another texture")
            portrait.circleMask = true
            portrait:SetTexture(icon)
        end
    end
    env.AZS_SetMeterPortrait = function(texture, run, key)
        state.calls = state.calls + 1
        assert(run == "run" and type(key) == "string", "retained identity was rewritten")
        if texture == portrait then
            assert(texture.circleMask, "retained native image was bound to a square portrait")
        else
            assert(texture.uv and texture.point, "retained fallback image preceded strip geometry")
        end
        if state.failAt == state.calls then
            texture:SetTexture("partial-native-image")
            return nil, { code = "ART_NOT_READY", message = "pending", retryable = true, retryAfterSeconds = 0.2 }
        end
        texture:SetTexture("retained:" .. run .. ":" .. key)
        if state.badSuccess then return true, { code = "INTERNAL_ERROR", retryable = false } end
        return true, nil
    end
    local image = env.T.NewCircularIcon(portrait, 26, 4)
    function state:Parts()
        local result = {}
        for _, object in ipairs(c.objects) do
            if object.kind == "Texture" and object.parent == parent and object ~= portrait then
                table.insert(result, object)
            end
        end
        return result
    end
    return c, state, image, portrait
end

do
    local c, state, image, portrait = Fixture(true)
    local bound, failure = image.BindNative("run", "hero")
    assert(bound and failure == nil and portrait:IsShown(), "native circle did not bind")
    assert(portrait:GetTexture() == "retained:run:hero" and state.preparations == 1 and state.calls == 1)
    assert(table.getn(state:Parts()) == 0, "native circle allocated a fallback pool")
    c:ResetCounts()
    assert(image.BindNative("run", "hero", 2))
    c:NoPresentationWrites()
    assert(state.calls == 1 and state.preparations == 1, "unchanged native circle rebound its image")
    portrait.texture, portrait.circleMask = "foreign", false
    assert(image.BindNative("run", "hero"), "actual native texture reset did not recover")
    assert(state.preparations == 2 and state.calls == 2, "reset image did not reestablish its circle mask")
    image.Clear()
    assert(not portrait:IsShown() and portrait:GetTexture() == nil, "retired circle retained its native image")
    assert(image.BindNative("run", "hero") and state.preparations == 3, "retirement kept an old native binding")
end

do
    local c, state, image, portrait = Fixture(false)
    assert(image.BindNative("run", "hero"))
    local parts = state:Parts()
    assert(table.getn(parts) == 24 and not portrait:IsShown(), "retained fallback changed the authored circle density")
    for _, strip in ipairs(parts) do
        assert(
            strip:IsShown() and strip:GetTexture() == "retained:run:hero",
            "fallback exposed a partial or square image"
        )
    end
    local allocated, calls = table.getn(c.objects), state.calls
    c:ResetCounts()
    assert(image.BindNative("run", "hero"))
    c:NoPresentationWrites()
    assert(state.calls == calls and table.getn(c.objects) == allocated, "settled fallback rebound or reallocated")
    parts[3].texture = "foreign"
    assert(image.BindNative("run", "hero") and state.calls == calls + 1, "changed strip did not repair independently")
    state.scale = 2
    assert(image.BindNative("run", "hero"))
    local larger = state:Parts()
    assert(table.getn(larger) == 50, "physical-pixel fallback did not follow scale")
    for _, strip in ipairs(larger) do
        assert(strip:IsShown() and strip:GetTexture() == "retained:run:hero", "resized strip lost the retained image")
    end
    state.scale = 1
    assert(image.BindNative("run", "hero") and table.getn(state:Parts()) == 50, "fallback discarded its reusable pool")
    for index = 25, 50 do
        assert(
            not larger[index]:IsShown() and larger[index]:GetTexture() == nil,
            "shrunk fallback retained surplus native bindings"
        )
    end
    image.Clear()
    for _, strip in ipairs(larger) do
        assert(not strip:IsShown() and strip:GetTexture() == nil, "fallback cleanup kept native art")
    end
    assert(
        image.BindNative("run", "replacement") and table.getn(state:Parts()) == 50,
        "new identity did not reuse the pool"
    )
end

do
    local _, nativeState, retained = Fixture(false)
    local _, legacyState, legacy = Fixture(false)
    assert(retained.BindNative("run", "hero") and legacy.Bind("Interface\\Icons\\Legacy"))
    local nativeParts, legacyParts = nativeState:Parts(), legacyState:Parts()
    assert(table.getn(nativeParts) == table.getn(legacyParts), "native and legacy clipping pools disagree")
    for index, strip in ipairs(nativeParts) do
        local other = legacyParts[index]
        assert(
            strip.width == other.width and strip.height == other.height,
            "retained portrait changed strip dimensions"
        )
        for coordinate = 1, 4 do
            assert(strip.uv[coordinate] == other.uv[coordinate], "retained portrait changed authored sampling")
        end
        assert(
            strip.point[4] == other.point[4] and strip.point[5] == other.point[5],
            "retained portrait changed circle placement"
        )
    end
end

do
    local _, state, image, portrait = Fixture(false)
    state.failAt = 3
    local bound, failure = image.BindNative("run", "hero")
    assert(not bound and failure.code == "ART_NOT_READY" and failure.retryAfterSeconds == 0.2)
    assert(not portrait:IsShown(), "failed retained fallback exposed the square owner")
    for _, strip in ipairs(state:Parts()) do
        assert(not strip:IsShown() and strip:GetTexture() == nil, "failed strip left a partial retained image")
    end
    state.failAt = nil
    assert(image.BindNative("run", "hero"), "native fallback failure was cached permanently")
    assert(image.Bind("Interface\\Icons\\Neutral"), "neutral fallback could not reuse native strips")
    for _, strip in ipairs(state:Parts()) do
        assert(
            strip:GetTexture() == "Interface\\Icons\\Neutral" and strip.nativeKey == nil,
            "legacy reuse retained native identity"
        )
    end
end

do
    local _, state, image, portrait = Fixture(true)
    state.badSuccess = true
    local bound, failure = image.BindNative("run", "hero")
    assert(
        not bound and failure and not portrait:IsShown() and portrait:GetTexture() == nil,
        "true plus an error was accepted as native portrait success"
    )
    state.badSuccess = nil
    assert(image.BindNative("run", "hero"), "malformed native success prevented recovery")
    assert(
        image.BindNative("run", "hero", 0 / 0),
        "unchanged native circle unexpectedly needed scale-dependent geometry"
    )
    image.Clear()
    bound, failure = image.BindNative("run", "hero", 0 / 0)
    assert(not bound and failure.code == "INVALID_ARGUMENT", "unprepared native portrait accepted invalid scale")
end

print("PASS retained native portraits preserve shared circle masks, strip geometry, reuse and cleanup")
