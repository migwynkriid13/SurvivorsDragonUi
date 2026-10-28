-- CI only: actual chat frame callback over explicit native boundaries.
assert(_VERSION == "Lua 5.1")
local now, reads, alphaCalls, layouts = 10, 0, 0, 0
local selected = { native = {}, visualAlpha = 1 }
function selected.native:SetAlpha(value)
    assert(value == 1)
    alphaCalls = alphaCalls + 1
end
function selected.native:IsShown() return true end
local env = setmetatable({
    root = { IsVisible = function() return true end },
    states = { selected },
    selected = selected,
    refresh = 0,
    GetTime = function()
        reads = reads + 1
        return now
    end,
    AtBottom = function() return true end,
    Flag = function(value) return value == true or value == 1 end,
    FadeSettings = function() end,
    UpdateIndicator = function() end,
    ReadDimensions = function() layouts = layouts + 1 end,
    PositionInput = function() end,
    RefreshFrames = function() end,
    PositionNative = function(_, sample) assert(sample == now) end,
    Clamp = function(value, low, high) return math.max(low, math.min(high, value)) end,
    SLIDE = 0.35,
    FADE = 0.6,
}, { __index = _G })
local chunk = assert(loadfile(assert(arg[1])))
setfenv(chunk, env)
local update = chunk()
env.arg1 = 0.01
for _ = 1, 20 do
    update()
end
assert(reads == 0 and alphaCalls == 20, "idle chat read native time or skipped native alpha repair")
env.arg1 = 0.81
update()
assert(reads == 1 and layouts == 1, "one-second repair did not take a fresh native time sample")
selected.slideStart, selected.revealStart = now, now
selected.pendingLevel = { deadline = now + 0.1 }
local delivered = 0
function selected.FlushLevel()
    delivered = delivered + 1
    selected.pendingLevel = nil
end
reads, env.arg1 = 0, 0.05
now = 10.05
update()
assert(reads == 1 and selected.visualAlpha > 0 and delivered == 0, "active animation did not share fresh time")
now = 10.4
update()
assert(reads == 2 and delivered == 1 and selected.slideStart == nil, "pending message/final slide sample was skipped")
now = 10.7
update()
assert(selected.revealStart == nil and selected.visualAlpha == 1, "reveal did not complete")
reads = 0
update()
assert(reads == 0, "settled effects retained native clock reads")
print("PASS idle chat skips native time reads; active animation, batching, alpha repair and geometry stay current")
