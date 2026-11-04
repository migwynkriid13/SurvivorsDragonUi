-- CI only: exact gold glow with native texture/font and scheduling boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1")

local function Fixture()
    local c = H.New()
    local env = c.env
    local create = c.Object
    function c:Object(...)
        local object = create(self, ...)
        function object:SetBlendMode(value) self.blend = value end
        local alpha, texture = object.SetAlpha, object.SetTexture
        function object:SetAlpha(value)
            if self.kind == "FontString" then c.fontAlphas = (c.fontAlphas or 0) + 1 end
            return alpha(self, value)
        end
        function object:SetTexture(value)
            if c.rejectTexture and value and string.find(value, "AffordableRays", 1, true) then
                c.rejectTexture = false
                error("injected gold artwork assignment failure")
            end
            return texture(self, value)
        end
        return object
    end
    local content = env.CreateFrame("Frame", nil, env.UIParent)
    content:SetWidth(50)
    local text = content:CreateFontString(nil, "OVERLAY")
    text:SetText("123")
    local entry = { content = content, text = text, fitFontSize = 9, fitTextWidth = 28 }
    local chunk = assert(loadfile(assert(arg[1], "missing gold glow source")))
    setfenv(chunk, env)
    local api = chunk()
    api.New(entry)
    return c, env, entry, api
end

do
    local c, env, entry, api = Fixture()
    local baseline = #c.objects
    env.performanceMode = true
    api.Set(true)
    assert(not entry.glowPrepared and #c.objects == baseline and not entry.content:GetScript("OnUpdate"))
    env.performanceMode = false
    api.Set(false)
    entry.content:Hide()
    api.Set(true)
    assert(not entry.glowPrepared and #c.objects == baseline, "hidden gold field prepared decoration")
    entry.content:Show()
    assert(entry.glowPrepared and entry.glowRunning and #c.objects == baseline + 13)
    assert(#entry.glow == 8 and #entry.glowLights[1].sparkles == 3)
    for _, glow in ipairs(entry.glow) do
        assert(glow:IsVisible() and glow:GetText() == "123" and glow:GetWidth() == 28)
        assert(select(2, glow:GetFont()) == 9, "first-use glow ignored current fitted font")
    end
    assert(entry.glowLights[1].spotlight:GetWidth() == 50 * 1.65)
    local allocated = #c.objects
    c:ResetCounts()
    c.fontAlphas = 0
    c:Call(entry.content, "OnUpdate", 0.01)
    c:NoPresentationWrites()
    assert(entry.glowPhase == 0, "gold glow advanced its phase between paints")
    c:Call(entry.content, "OnUpdate", 0.025)
    assert(math.abs(entry.glowPhase - 0.035 * 2 * math.pi / 4.8) < 1e-12, "gold glow lost elapsed time between paints")
    assert(c.fontAlphas > 0 and c.fontAlphas < 8, "gold glow rewrote unchanged alpha copies")
    local cosine, sine = math.cos(entry.glowPhase), math.sin(entry.glowPhase)
    for index, glow in ipairs(entry.glow) do
        local direction = entry.glowDirections[index]
        local facing = math.max(0, cosine * direction.x - sine * direction.y)
        local expected = (0.04 + 0.14 * facing ^ 4) * 1.4
        assert(math.abs(glow:GetAlpha() - expected) < 1e-12, "gold glow brightness equation changed")
    end
    local phase = entry.glowPhase
    c:Call(entry.content, "OnUpdate", 0.3)
    assert(
        math.abs(entry.glowPhase - phase - 0.1 * 2 * math.pi / 4.8) < 1e-12,
        "long frame bypassed the glow delta cap"
    )
    entry.text:SetText("456")
    api.Set(true)
    for _, glow in ipairs(entry.glow) do
        assert(glow:GetText() == "456", "live gold text was held by preparation reuse")
    end
    env.performanceMode = true
    api.Set(true)
    assert(not entry.glowRunning and not entry.content:GetScript("OnUpdate"))
    for _, glow in ipairs(entry.glow) do
        assert(not glow:IsShown())
    end
    c:ResetCounts()
    api.Set(true)
    c:NoPresentationWrites()
    env.performanceMode = false
    api.Set(true)
    assert(entry.glowRunning and #c.objects == allocated, "returning gold glow rebuilt its pool")
    entry.content:Hide()
    assert(not entry.content:GetScript("OnUpdate"))
    entry.content:Show()
    assert(entry.glowRunning and #c.objects == allocated)
end

do
    local c, _, entry, api = Fixture()
    api.Set(true)
    local rays = entry.glowLights[1].rays
    assert(rays.rotationStep == 0, "starting gold glow did not paint its rays")
    local sets, writes = {}, 0
    function rays:SetTexCoord(...)
        writes = writes + 1
        sets[table.concat({ ... }, ",")] = true
    end
    for _ = 1, 150 do
        c:Call(entry.content, "OnUpdate", 1 / 30)
    end
    local unique = 0
    for _ in pairs(sets) do
        unique = unique + 1
    end
    assert(writes > 0 and unique <= 129, "gold rays wrote more UV sets than their rotation steps")
    assert(writes <= 129, "gold rays rewrote an unchanged rotation step")
    api.Set(false)
    assert(not entry.glowRunning)
    writes = 0
    api.Set(true)
    assert(entry.glowRunning and writes == 1 and rays.rotationStep == 0, "restarted gold glow did not repaint its rays")
end

do
    local c, _, entry, api = Fixture()
    local baseline = #c.objects
    c.rejectTexture = true
    assert(not pcall(api.Set, true) and not entry.glowPrepared)
    api.Set(true)
    assert(entry.glowPrepared and #c.objects == baseline + 13, "failed gold preparation leaked replacement regions")
end

print(
    "PASS gold glow prepares only visible first use and preserves exact artwork, timing, alpha, current text and pool recovery"
)
