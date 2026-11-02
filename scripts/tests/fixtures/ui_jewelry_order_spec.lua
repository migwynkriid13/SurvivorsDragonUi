-- CI only: real Display transactions and extracted production placement.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "jewelry order fixtures require CI Lua 5.1")
local context = H.New()
context:Load("core/display.lua", "Display")
local env, display = context.env, context.env.DFRL.display
assert(display.Get("jewelryCustomOrder") == false and display.Get("jewelryOrder") == "12345")
for _, invalid in ipairs({ "", "1234", "123456", "11345", "02345", "abcde", false, 12345, {} }) do
    assert(display.Copy({ jewelryOrder = invalid }).jewelryOrder == "12345", "invalid order was retained")
end
assert(display.Copy({ jewelryCustomOrder = false, jewelryOrder = "54321" }).jewelryOrder == "54321")
assert(display.Copy({ jewelryCustomOrder = "true" }).jewelryCustomOrder == false)
env.WIDTH, env.ICON_SIZE, env.columnPitch = 317, 32, 50
env.hud, env.slots, env.displayGeometry = {}, {}, {}
env.inWorld, env.attached = true, true
local writes = 0
for index = 1, 5 do
    local button = {}
    function button:ClearAllPoints() writes = writes + 1 end
    function button:SetPoint(_, _, _, x, y)
        writes = writes + 1
        self.x, self.y = x, y
    end
    env.slots[index] = { orderKey = tostring(index), position = index, button = button, id = 10 + index }
end
local chunk = assert(loadfile(arg[1]))
setfenv(chunk, env)
local place = chunk()
place()
assert(writes == 0, "default order moved the original slots")
display.BeginEdit()
display.SetJewelryPosition(1, "4")
assert(display.Get("jewelryOrder") == "12345", "default-off custom placement accepted a swap")
display.Set("jewelryCustomOrder", true)
display.SetJewelryPosition(1, "4")
assert(display.Get("jewelryOrder") == "42315" and not env.SurvivorsDragonUiDisplay)
place()
assert(env.slots[1].position == 4 and env.slots[4].position == 1 and writes == 4)
assert(env.slots[1].id == 11 and env.slots[4].id == 14, "placement rewrote native identity")
assert(env.slots[4].button.x == 317 / 2 - 16 - 100 and env.slots[4].button.y == -30.5)
place()
assert(writes == 4, "settled placement repeated anchors")
display.Set("performanceMode", true)
place()
assert(writes == 4 and env.slots[4].position == 1, "Performance Mode changed custom placement")
display.Set("performanceMode", false)
display.FinishEdit(false)
place()
assert(env.slots[1].position == 1 and env.slots[4].position == 4 and not display.Get("jewelryCustomOrder"))
display.BeginEdit()
display.Set("jewelryCustomOrder", true)
display.SetJewelryPosition(2, "5")
display.FinishEdit(true)
assert(env.SurvivorsDragonUiDisplay.jewelryOrder == "15342")
local profile = display.Snapshot()
display.BeginEdit()
display.Set("jewelryCustomOrder", false)
display.FinishEdit(true)
assert(not display.Get("jewelryCustomOrder") and display.Get("jewelryOrder") == "15342")
place()
for index, slot in ipairs(env.slots) do
    assert(slot.position == index, "turning custom order off lost original placement")
end
display.BeginEdit()
display.Load(profile)
assert(display.Get("jewelryCustomOrder") and display.Get("jewelryOrder") == "15342", "profile lost custom order")
display.Set("jewelryOrder", "11111")
assert(display.Get("jewelryOrder") == "15342", "invalid direct edit duplicated an item")
for _, invalid in ipairs({ 0, 6, 1.5, "1" }) do
    display.SetJewelryPosition(invalid, "1")
    assert(display.Get("jewelryOrder") == "15342")
end
for position = 1, 5 do
    for choice = 1, 5 do
        display.SetJewelryPosition(position, tostring(choice))
        local order = display.Get("jewelryOrder")
        assert(string.sub(order, position, position) == tostring(choice))
        for item = 1, 5 do
            local first, last = string.find(order, tostring(item), 1, true)
            assert(first and first == last and not string.find(order, tostring(item), last + 1, true))
        end
    end
end
display.Set("jewelryOrder", "54321")
env.inWorld = false
local before = writes
place()
assert(writes == before, "world-hidden placement changed anchors")
env.inWorld = true
display.Set("equippedJewelry", false)
place()
assert(writes == before, "disabled jewelry changed anchors")
display.Set("equippedJewelry", true)
place()
assert(env.slots[1].position == 5 and env.slots[5].position == 1)
display.FinishEdit(false)
display.Reset()
place()
assert(not display.Get("jewelryCustomOrder") and display.Get("jewelryOrder") == "12345")
for index, slot in ipairs(env.slots) do
    assert(slot.position == index and slot.id == 10 + index)
end
print(
    "PASS jewelry order defaults, swaps, validation, profiles, Confirm/Cancel/reset and changed-only native-slot placement"
)
