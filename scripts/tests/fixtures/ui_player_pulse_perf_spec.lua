-- CI only: extracted production pulse with explicit native event/alpha boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
local context = H.New()
local env = context.env
env.PlayerFrame = env.CreateFrame("Frame", nil, env.UIParent)
env.PlayerFrameHealthBar = env.CreateFrame("StatusBar", nil, env.PlayerFrame)
env.tex, env.pulseTextures = "Interface\\AddOns\\SurvivorsDragonUi\\media\\tex\\unitframes\\", {}
local createFrame = env.CreateFrame
env.CreateFrame = function(kind, name, parent)
    local frame = createFrame(kind, name, parent)
    local createTexture = frame.CreateTexture
    function frame:CreateTexture(textureName, layer)
        local texture = createTexture(self, textureName, layer)
        function texture:SetBlendMode(value) self.blendMode = value end
        return texture
    end
    return frame
end
env.T.CreateRoundPlayerRim = function(owner) return env.CreateFrame("Frame", nil, owner) end
local chunk = assert(loadfile(assert(arg[1])))
setfenv(chunk, env)
local createPulse = chunk()
local reads = 0
local nativeActive = false
local function Active()
    reads = reads + 1
    return nativeActive
end
local function CheckPulse(startEvent, stopEvent)
    local before = #context.objects
    createPulse(1, 0, 0, Active, startEvent, stopEvent)
    local overlay = context.objects[before + 1]
    local artwork = env.pulseTextures[#env.pulseTextures]
    local texture, round = artwork.original, artwork.round
    assert(not overlay:GetScript("OnUpdate"), "settled pulse retained an idle updater")
    local initialReads = reads
    context:ResetCounts()
    for _ = 1, 60 do
        context:Call(overlay, "OnUpdate", 1 / 60)
    end
    assert(reads == initialReads, "inactive pulse polled native state every frame")
    context:NoPresentationWrites()

    nativeActive = true
    context:Event(overlay, startEvent)
    assert(overlay:GetScript("OnUpdate"), "native activation failed to attach animation")
    initialReads = reads
    context:Call(overlay, "OnUpdate", 0.25)
    assert(
        math.abs(texture:GetAlpha() - 1) < 1e-12 and round:GetAlpha() == texture:GetAlpha(),
        "pulse equation changed"
    )
    context:Call(overlay, "OnUpdate", 0.25)
    assert(math.abs(texture:GetAlpha() - 0.5) < 1e-12, "active pulse cadence changed")
    assert(reads == initialReads, "active animation repeated native eligibility reads")

    nativeActive = false
    context:Event(overlay, stopEvent or startEvent)
    local setAlpha = texture.SetAlpha
    local failAlpha = true
    function texture:SetAlpha(value)
        if failAlpha then
            failAlpha = false
            return
        end
        setAlpha(self, value)
    end
    context:Call(overlay, "OnUpdate", 0.3)
    assert(overlay:GetScript("OnUpdate") and texture:GetAlpha() > 0, "failed native fade stopped future retries")
    context:Call(overlay, "OnUpdate", 0.1)
    assert(math.abs(texture:GetAlpha() - 0.3) < 1e-12, "inactive pulse lost its authored fade")
    context:Call(overlay, "OnUpdate", 0.2)
    assert(texture:GetAlpha() == 0 and round:GetAlpha() == 0, "fade did not finish on both rim variants")
    assert(not overlay:GetScript("OnUpdate"), "completed fade retained an updater")

    nativeActive = true
    context:Event(overlay, startEvent)
    context:Call(overlay, "OnUpdate", 0.5)
    assert(texture:GetAlpha() > 0 and round:GetAlpha() == texture:GetAlpha())
    nativeActive = false
    context:Event(overlay, stopEvent or startEvent)
    local setRoundAlpha, failRound = round.SetAlpha, true
    function round:SetAlpha(value)
        if failRound and value == 0 then
            failRound = false
            return
        end
        setRoundAlpha(self, value)
    end
    context:Call(overlay, "OnUpdate", 0.3)
    assert(
        texture:GetAlpha() == 0 and round:GetAlpha() > 0 and overlay:GetScript("OnUpdate"),
        "failed round-rim completion stopped its retry"
    )
    context:SetSetting("hidePortraits", true)
    assert(not overlay:GetScript("OnUpdate"), "failed round fade retained hidden work")
    context:SetSetting("hidePortraits", false)
    assert(overlay:GetScript("OnUpdate"), "round-only residual alpha did not rearm after hidden recovery")
    context:Call(overlay, "OnUpdate", 0.016)
    assert(
        texture:GetAlpha() == 0 and round:GetAlpha() == 0 and not overlay:GetScript("OnUpdate"),
        "round-rim retry did not settle both variants"
    )

    nativeActive = true
    context:Event(overlay, startEvent)
    context:SetSetting("hidePortraits", true)
    assert(not overlay:GetScript("OnUpdate"), "hidden portraits retained pulse work")
    context:SetSetting("hidePortraits", false)
    assert(overlay:GetScript("OnUpdate"), "portrait preview recovery did not rearm current native state")
    env.PlayerFrame:Hide()
    assert(not overlay:GetScript("OnUpdate"), "hidden owner retained pulse work")
    env.PlayerFrame:Show()
    assert(overlay:GetScript("OnUpdate"), "owner Show failed to rearm pulse")
    context:Event(overlay, "PLAYER_LEAVING_WORLD")
    assert(not overlay:GetScript("OnUpdate"), "world retirement retained pulse work")
    context:Event(overlay, "PLAYER_ENTERING_WORLD")
    assert(overlay:GetScript("OnUpdate"), "world entry failed to sample native eligibility")
    nativeActive = false
    context:Event(overlay, stopEvent or startEvent)
    context:Call(overlay, "OnUpdate", 1)
    assert(not overlay:GetScript("OnUpdate"), "final inactive pulse remained attached")
end
CheckPulse("PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED")
CheckPulse("PLAYER_UPDATE_RESTING")
print("PASS player rim eligibility is event-driven, while active pulse/fade and lifecycle recovery remain exact")
