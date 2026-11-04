-- CI only: native unit-frame clicks, dropdown ownership and marking are explicit boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
local context = H.New()
local env = context.env
local list = env.CreateFrame("Frame", "DropDownList1", env.UIParent)
list:Hide()
local rows, calls, marked = {}, {}, { player = 8, party4 = 2 }
local units = { player = true, target = true, party4 = true }
local spellTargeting, editing
env.UnitExists = function(unit) return units[unit] end
env.SpellIsTargeting = function() return spellTargeting end
env.DFRL.layout.IsEditing = function() return editing end
env.GetRaidTargetIndex = function(unit) return marked[unit] end
env.SetRaidTargetIcon = function(unit, index) table.insert(calls, { unit, index }) end
env.UnitPopupButtons = { RAID_TARGET_NONE = { text = "None" } }
for index = 1, 8 do
    env.UnitPopupButtons["RAID_TARGET_" .. index] = {
        text = "Mark " .. index,
        color = { r = 1, g = 0.5, b = 0 },
        icon = "native raid art",
        tCoordLeft = 0,
        tCoordRight = 0.25,
        tCoordTop = 0,
        tCoordBottom = 0.25,
    }
end
env.UIDropDownMenu_AddButton = function(row) table.insert(rows, row) end
env.CloseDropDownMenus = function() list:Hide() end
env.ToggleDropDownMenu = function(level, _, owner, anchor)
    assert(level == 1 and anchor == "cursor", "marks did not open as a direct cursor menu")
    list:Hide()
    env.UIDROPDOWNMENU_OPEN_MENU = owner:GetName()
    rows = {}
    owner.initialize()
    list:Show()
end
context:Load("core/widgets.lua")

local function Frame(unit, nativeBarClick)
    local frame = env.CreateFrame("Button", nil, env.UIParent)
    local bar = env.CreateFrame("StatusBar", nil, frame)
    frame:SetScript("OnClick", function() table.insert(calls, { unit, env.arg1, "portrait" }) end)
    function frame:Click(button) context:Call(self, "OnClick", button) end
    if nativeBarClick then
        bar:SetScript("OnMouseUp", function() table.insert(calls, { unit, env.arg1, "health" }) end)
    end
    env.T.BindRaidMarkMenu(frame, bar, unit)
    return frame, bar
end
local player, playerBar = Frame("player", true)
local target, targetBar = Frame("target", false)
local party, partyBar = Frame("party4", true)
assert(not env.SurvivorsDragonUiRaidMarks, "menu allocated before use")

context:Call(playerBar, "OnMouseUp", "LeftButton")
context:Call(targetBar, "OnMouseUp", "LeftButton")
context:Call(party, "OnClick", "LeftButton")
assert(calls[1][3] == "health" and calls[2][3] == "portrait" and calls[3][3] == "portrait")
spellTargeting = true
context:Call(targetBar, "OnMouseUp", "RightButton")
assert(calls[4][1] == "target" and calls[4][2] == "RightButton" and not list:IsShown())
spellTargeting = false
editing = true
context:Call(partyBar, "OnMouseUp", "RightButton")
assert(not list:IsShown() and not env.SurvivorsDragonUiRaidMarks, "edit click opened a gameplay menu")
editing = false

context:Call(player, "OnClick", "RightButton")
local menu = assert(env.SurvivorsDragonUiRaidMarks)
assert(menu.unit == "player" and table.getn(rows) == 9 and rows[8].checked == 1 and not rows[9].checked)
assert(rows[1].icon == "native raid art" and rows[1].textR == 1 and rows[1].tCoordRight == 0.25)
assert(rows[9].text == "None" and not rows[9].icon, "menu added a title or lacked the clear row")
rows[9].func(rows[9].arg1, rows[9].arg2)
assert(calls[5][1] == "player" and calls[5][2] == 0)

context:Call(partyBar, "OnMouseUp", "RightButton")
assert(env.SurvivorsDragonUiRaidMarks == menu and menu.unit == "party4" and rows[2].checked == 1)
local oldRow = rows[8]
context:Event(menu, "PARTY_MEMBERS_CHANGED")
assert(not list:IsShown() and not menu.unit and next(menu.events) == nil)
oldRow.func(oldRow.arg1, oldRow.arg2)
assert(table.getn(calls) == 5, "old party slot accepted a mark")

context:Call(targetBar, "OnMouseUp", "RightButton")
assert(menu.unit == "target" and rows[9].checked == 1)
rows[1].func(rows[1].arg1, rows[1].arg2)
assert(calls[6][1] == "target" and calls[6][2] == 1)
context:Event(menu, "PLAYER_TARGET_CHANGED")
assert(not list:IsShown(), "target change left a live popup")
context:Call(target, "OnClick", "RightButton")
target:Hide()
assert(not list:IsShown(), "frame hiding left a live popup")

context:Call(playerBar, "OnMouseUp", "RightButton")
context:Call(player, "OnClick", "RightButton")
assert(not list:IsShown(), "clicking the same unit again did not toggle off")
context:Call(party, "OnClick", "RightButton")
context:Event(menu, "PLAYER_LEAVING_WORLD")
assert(not list:IsShown() and not menu.unit and next(menu.events) == nil)
print("PASS direct raid mark menu binds both hit paths, native unit selection and popup retirement")
