-- CI only: production pet caption caches and retirement, without native feeds.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1")
local context = H.New()
local env = context.env
local formats = 0
env.string = {}
for name, value in pairs(string) do
    env.string[name] = value
end
env.string.format = function(...)
    formats = formats + 1
    return string.format(...)
end
local chunk = assert(loadfile(assert(arg[1])))
setfenv(chunk, env)
local captions = chunk()
local row = {}
assert(captions.Timer(row, 60.9, true) == "1:01" and formats == 1)
assert(captions.Timer(row, 60.1, true) == "1:01" and formats == 1, "pet timer reformatted one rounded second")
assert(captions.Timer(row, 60, true) == "1:00" and formats == 2)
assert(captions.Timer(row, 0, true) == "0:00", "pet timer zero was treated as missing")
assert(captions.Timer(row, nil, true) == "--:--")
assert(captions.Timer(row, 60, false) == "", "hidden timer exposed old text")
assert(captions.Timer(row, 60, true) == "1:00")
assert(captions.Count(row, 3, true) == "x3" and captions.Count(row, 3, true) == "x3")
assert(captions.Count(row, 3, false) == "" and captions.Count(row, 1, true) == "")
assert(captions.Count(row, 2, true) == "x2")
-- Inactive cleanup must clear display strings even after a failed first paint.
captions.Hide(row)
assert(row.timerText == nil and row.timerSecond == nil and row.countText == nil and row.countValue == nil)
local before = formats
assert(captions.Timer(row, 60, true) == "1:00" and formats == before + 1)
print("PASS pet timer/count captions retain exact output, displayed-second reuse, option transitions and retirement")
