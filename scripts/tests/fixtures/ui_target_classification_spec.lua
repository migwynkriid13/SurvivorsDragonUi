-- CI only: actual target-border selection over explicit native boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "target classification fixtures require CI Lua 5.1")
local context = H.New()
local env = context.env
env.TargetFrame = env.CreateFrame("Frame", nil, env.UIParent)
env.tex = "Interface\\AddOns\\SurvivorsDragonUi\\media\\tex\\unitframes\\"
env.UnitClassification = function(unit)
    assert(unit == "target", "classification queried another unit")
    context.reads.classification = (context.reads.classification or 0) + 1
    return context.classification
end
env.DFRL.targetHealth = {
    GetKind = function()
        context.reads.kind = (context.reads.kind or 0) + 1
        return context.kind
    end,
}
env.UpdateBorderTexture = function(path)
    context.writes.SetTexture = (context.writes.SetTexture or 0) + 1
    context.path = path
end

local file = assert(io.open("modules/unit/target.lua", "r"))
local source = file:read("*a")
file:close()
local first = assert(string.find(source, "    local borderTexture", 1, true))
local last = assert(string.find(source, "    _G.TargetFrame_CheckClassification", first, true))
local chunk = assert(
    loadstring(
        string.sub(source, first, last - 1) .. "\nreturn UpdateClassification",
        "@production-target-classification"
    )
)
setfenv(chunk, env)
local update = chunk()
local allocated = table.getn(context.objects)

for _, choice in ipairs({
    { "guardian", "elite", "UI-TargetingFrame-RareElite.blp" },
    { "boss", "rareelite", "UI-TargetingFrame-Boss.blp" },
    { "final", "normal", "UI-TargetingFrame-Boss.blp" },
    { "normal", "rare", "UI-TargetingFrame-Rare.blp" },
    { "elite", "rareelite", "UI-TargetingFrame-RareElite.blp" },
    { false, "worldboss", "UI-TargetingFrame-Boss.blp" },
    { false, "rareelite", "UI-TargetingFrame-RareElite.blp" },
    { false, "elite", "UI-TargetingFrame-Elite.blp" },
    { false, "rare", "UI-TargetingFrame-Rare.blp" },
    { false, "normal", "UI-TargetingFrameDF1.blp" },
    { false, "unknown", "UI-TargetingFrameDF1.blp" },
}) do
    context.kind, context.classification = choice[1] or nil, choice[2]
    context:ResetCounts()
    update(true)
    assert(context.path == env.tex .. choice[3], "incorrect border for " .. tostring(choice[1]) .. "/" .. choice[2])
    assert(context.writes.SetTexture == 1, "forced native rebuild did not bind its selected border once")
    context:ResetCounts()
    update()
    context:NoPresentationWrites()
end

context.kind, context.classification = "guardian", "worldboss"
update()
assert(context.path == env.tex .. "UI-TargetingFrame-RareElite.blp", "guardian inherited native boss artwork")
context:ResetCounts()
context.kind = "boss"
update()
assert(
    context.path == env.tex .. "UI-TargetingFrame-Boss.blp" and context.writes.SetTexture == 1,
    "accepted kind change did not refresh the existing border"
)
context:ResetCounts()
context.kind = "final"
update()
context:NoPresentationWrites()

-- Vanilla clients without the accepted AZS owner keep their original classification.
local health = env.DFRL.targetHealth
env.DFRL.targetHealth = nil
context.classification = "elite"
update()
assert(context.path == env.tex .. "UI-TargetingFrame-Elite.blp", "missing health owner broke native fallback")

env.DFRL.targetHealth = health
env.TargetFrame:Hide()
context:ResetCounts()
update(true)
assert(
    not next(context.reads) and not next(context.writes),
    "hidden target read kind/classification or rebound artwork"
)
assert(table.getn(context.objects) == allocated, "classification changes allocated drawing objects")
print("PASS guardian and boss winged borders share accepted target metadata and unchanged/hidden work guards")
