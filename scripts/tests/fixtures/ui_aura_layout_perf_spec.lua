-- CI only: exact aura layout/formatting helpers with native anchor boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1")
local context = H.New()
local env = context.env
env.container = env.CreateFrame("Frame", nil, env.UIParent)
env.nativeFrames, env.entries = {}, {}
env.iconSize, env.gap, env.rowGap, env.columns = 28, 3, 14, 6
env.width, env.flipped, env.editing, env.layoutDirty = 183, false, false, true
local reads, sizes = 0, 0
for index = 1, 2 do
    local native = env.CreateFrame("Frame", nil, env.container)
    function native:GetNumPoints() return self.point and 1 or 0 end
    function native:GetPoint() return unpack(self.point or {}) end
    function native:ClearAllPoints() self.point = nil end
    function native:SetPoint(...) self.point = { ... } end
    env.nativeFrames[index] = native
    local button = env.CreateFrame("Button", nil, env.container)
    local shown = button.IsShown
    function button:IsShown()
        reads = reads + 1
        return shown(self)
    end
    env.entries[index] = { button = button }
end
env.SizeButton = function() sizes = sizes + 1 end
env.DFRL.layout.Place = function(key) assert(key == "buffs") end
local chunk = assert(loadfile(assert(arg[1])))
setfenv(chunk, env)
local layout = chunk()
layout(false)
assert(reads == 2 and sizes == 2 and env.entries[2].slot == 1 and not env.layoutDirty)
reads, sizes = 0, 0
env.nativeFrames[1].point = { "CENTER", env.UIParent, "CENTER", 20, 30 }
layout(false)
assert(reads == 0 and sizes == 0, "settled native anchor repair rescanned aura slots")
assert(env.nativeFrames[1].point[1] == "TOPLEFT" and env.nativeFrames[1].point[2] == env.container)
env.entries[1].button:Hide()
env.layoutDirty = true
layout(false)
assert(env.entries[1].slot == nil and env.entries[2].slot == 0 and sizes == 1)
reads, sizes = 0, 0
layout(true)
assert(reads == 2 and sizes == 1, "forced native layout stopped repairing current artwork")
env.container:Hide()
env.layoutDirty = true
reads, sizes = 0, 0
layout(false)
assert(reads == 0 and sizes == 0 and env.layoutDirty, "hidden layout consumed pending presentation")
env.container:Show()
layout(false)
assert(reads == 2 and not env.layoutDirty)
reads = 0
env.editing = true
layout(false)
assert(reads == 2, "editing skipped current aura bounds")

local duration = context.env.CreateFrame("Frame", nil, context.env.UIParent):CreateFontString(nil, "OVERLAY")
local entry = { duration = duration }
local formats = 0
env.string = {}
for name, value in pairs(string) do
    env.string[name] = value
end
env.string.format = function(...)
    formats = formats + 1
    return string.format(...)
end
chunk = assert(loadfile(assert(arg[2])))
setfenv(chunk, env)
local setDuration = chunk()
setDuration(entry, 60.9)
assert(duration:GetText() == "1:01" and formats == 1)
context:ResetCounts()
setDuration(entry, 60.1)
assert(formats == 1 and not context.writes.SetText, "unchanged rounded aura time was reformatted")
duration.text = "native reset"
setDuration(entry, 60.1)
assert(duration:GetText() == "1:01" and formats == 1, "cached aura time hid actual text repair")
context.failText = "1:00"
local success = pcall(function() setDuration(entry, 60) end)
assert(not success and formats == 2)
setDuration(entry, 60)
assert(duration:GetText() == "1:00" and formats == 2, "failed aura text did not retry cached output")
setDuration(entry, 0)
assert(duration:GetText() == "0")
print(
    "PASS aura layout remains event/dirty driven with native anchor repair and cached duration text retains rounding and retries"
)
