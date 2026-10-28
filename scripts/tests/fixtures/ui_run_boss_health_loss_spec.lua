-- CI only: the production boss-loss controller over explicit texture/clock boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "boss health-loss fixtures require the CI Lua 5.1 interpreter")

local function Near(actual, expected, message)
    assert(type(actual) == "number" and math.abs(actual - expected) < 0.0000001, message)
end

local function New(performance)
    local context = H.New()
    local env = context.env
    env.path, env.performanceMode = "timer\\", performance and true or false
    env.IsNumber = function(value) return type(value) == "number" and value >= 0 and value - value == 0 end
    env.GetTime = function()
        context.reads.clock = (context.reads.clock or 0) + 1
        return context.now
    end
    local create = context.Object
    function context:Object(...)
        local object = create(self, ...)
        local point, uv, color = object.SetPoint, object.SetTexCoord, object.SetVertexColor
        function object:SetPoint(...)
            point(self, ...)
            self.point = { ... }
        end
        function object:SetTexCoord(...)
            uv(self, ...)
            self.uv = { ... }
        end
        function object:SetVertexColor(...)
            color(self, ...)
            self.vertex = { ... }
        end
        return object
    end
    local chunk = assert(loadfile(assert(arg[1], "missing extracted boss health-loss source")))
    setfenv(chunk, env)
    local source = chunk()
    local controller = source.New()
    context.source = source
    function context:Row()
        local frame = env.CreateFrame("Frame", nil, env.UIParent)
        local bar = env.CreateFrame("StatusBar", nil, frame)
        bar:SetWidth(280)
        bar:SetHeight(15)
        local width = bar.GetWidth
        function bar:GetWidth()
            context.reads.width = (context.reads.width or 0) + 1
            return width(self)
        end
        return { frame = frame, bar = bar }
    end
    function context:Observe(row, value, maximum, key, name)
        controller:Observe(row, value, maximum or 1000, key or "boss:71", name or "Edwin VanCleef")
    end
    return context, env, controller
end

do
    local context, env, controller = New(true)
    local row = context:Row()
    local allocated = #context.objects
    context:ResetCounts()
    context:Observe(row, 1)
    context:Observe(row, 0.8)
    for _ = 1, 60 do
        controller:Update()
    end
    assert(#context.objects == allocated and not row.lossTexture, "Performance Mode allocated damage-loss artwork")
    assert(controller.count == 0 and not next(controller.active), "Performance Mode queued a loss trail")
    context:NoPresentationWrites()
    assert(not next(context.reads), "Performance Mode sampled cosmetic time or bar geometry")

    env.performanceMode = false
    controller:ClearAll({ row })
    context:Observe(row, 0.8)
    assert(not row.lossTexture, "leaving Performance Mode replayed a previous decrease")
    context:Observe(row, 0.6)
    assert(row.lossTexture and controller.count == 1, "normal mode did not arm a future loss")
end

do
    local context, _, controller = New()
    local row = context:Row()
    local allocated = #context.objects
    context:ResetCounts()
    context:Observe(row, 1)
    for _ = 1, 60 do
        context:Observe(row, 1)
        controller:Update()
    end
    assert(#context.objects == allocated and not next(context.reads), "idle rows allocated or sampled loss work")
    context:NoPresentationWrites()

    context:Observe(row, 0.8)
    local texture = assert(row.lossTexture, "first decrease did not prepare the loss region")
    local started = context.now
    assert(#context.objects == allocated + 1 and texture:GetParent() == row.bar, "loss prepared more than one region")
    assert(texture:IsShown() and row.lossReady and controller.count == 1)
    assert(texture:GetTexture() == "timer\\FillWhite.blp", "loss did not reuse the bundled fill")
    Near(texture.vertex[1], 235 / 255, "crimson tint red channel changed")
    Near(texture.vertex[2], 65 / 255, "crimson tint green channel changed")
    Near(texture.vertex[3], 51 / 255, "crimson tint blue channel changed")
    Near(texture.vertex[4], 0.74, "crimson echo opacity changed")
    Near(texture:GetWidth(), 280 * 0.2, "initial loss width did not cover the missing section")
    assert(texture.uv[1] == 0 and texture.uv[2] == 1 and texture.uv[3] == 0 and texture.uv[4] == 15 / 16)

    context.now = started + 0.475
    controller:Update()
    local edge = 0.8 + 0.2 * 0.5 ^ 1.45
    Near(texture:GetWidth(), 280 * (edge - 0.8), "crimson echo lost its selected easing equation")
    context:ResetCounts()
    controller:Update()
    context:NoPresentationWrites()
    assert(context.reads.clock == 1, "an active trail did not use one shared cosmetic time sample")

    row.bar:SetWidth(420)
    context:ResetCounts()
    controller:Update()
    Near(texture:GetWidth(), 420 * (edge - 0.8), "active trail did not follow a Layout width change")
    Near(row.lossLeft, 420 * 0.8, "resized trail did not follow the actual health edge")
    assert(not context.writes.SetTexture and not context.writes.SetAlpha, "resize rebound unchanged art or alpha")

    context:Observe(row, 0.6)
    Near(row.lossFrom, edge, "a close decrease resurrected an already-drained trail")
    assert(row.lossTexture == texture and #context.objects == allocated + 1 and controller.count == 1)
    Near(texture:GetWidth(), 420 * (edge - 0.6), "close losses did not coalesce into the existing strip")
    context.now = context.now + 1
    controller:Update()
    assert(
        controller.count == 0 and not next(controller.active) and not texture:IsShown(),
        "completed trail stayed active"
    )
    context:ResetCounts()
    for _ = 1, 60 do
        controller:Update()
    end
    context:NoPresentationWrites()
    assert(not next(context.reads), "completed effects retained cosmetic clock or geometry work")
end

do
    local context, env, controller = New()
    local row = context:Row()
    context:Observe(row, 1)
    context:Observe(row, 0.8)
    local texture = assert(row.lossTexture)
    local prepared = #context.objects
    context:Observe(row, 0.9)
    assert(controller.count == 0 and not texture:IsShown(), "healing left a stale damage afterimage")
    context:Observe(row, 0.7)
    assert(controller.count == 1)
    context:Observe(row, 0.7, 2000)
    assert(controller.count == 0 and not texture:IsShown(), "same-ratio maximum-health change retained damage")
    context:Observe(row, 0.5, 2000)
    context:Observe(row, 0.4, 2000, "guardian:71")
    assert(controller.count == 0 and not texture:IsShown(), "a different encounter kind inherited loss")
    context:Observe(row, 0.3, 2000, "guardian:71")
    context:Observe(row, 0.2, 2000, "guardian:71", "A different name")
    assert(controller.count == 0 and not texture:IsShown(), "a renamed row inherited loss")
    controller:Clear(row)
    context:Observe(row, 0.1)
    assert(controller.count == 0 and row.lossTexture == texture and #context.objects == prepared)
    assert(not texture:IsShown(), "recycled artwork replayed the previous row's damage")

    context:Observe(row, 0.05)
    row.frame:Hide()
    controller:Update()
    assert(controller.count == 0 and not texture:IsShown(), "hidden rows retained active loss artwork")
    context:ResetCounts()
    context:Observe(row, 0.02)
    controller:Update()
    context:NoPresentationWrites()
    assert(not next(context.reads), "hidden rows sampled cosmetic clock or geometry")
    row.frame:Show()
    context:Observe(row, 0.02)
    assert(controller.count == 0, "Show replayed damage received while hidden")
    context:Observe(row, 0.01)
    assert(controller.count == 1 and #context.objects == prepared)

    env.performanceMode = true
    controller:ClearAll({ row })
    assert(controller.count == 0 and not texture:IsShown(), "mode entry did not settle the active trail")
    context:ResetCounts()
    controller:Update()
    context:NoPresentationWrites()
    assert(not next(context.reads), "Performance Mode retained cosmetic work after settlement")
end

do
    local context, _, controller = New()
    local row = context:Row()
    local width = row.bar.GetWidth
    function row.bar:GetWidth()
        if context.missingWidth then
            context.reads.width = (context.reads.width or 0) + 1
            return nil
        end
        return width(self)
    end
    local allocated = #context.objects
    context:Observe(row, 1)
    context.missingWidth = true
    context:Observe(row, 0.8)
    assert(controller.count == 1 and not row.lossTexture, "missing metrics prepared unusable loss artwork")
    context.missingWidth = nil
    row.bar:SetWidth(0)
    context:ResetCounts()
    for _ = 1, 10 do
        controller:Update()
    end
    assert(#context.objects == allocated and not row.lossTexture, "zero width repeatedly allocated a loss region")
    context:NoPresentationWrites()
    row.bar:SetWidth(280)
    controller:Update()
    assert(row.lossTexture and row.lossTexture:IsShown(), "available width did not retry active loss preparation")
    assert(#context.objects == allocated + 1, "metric recovery created more than one loss region")
    context:ResetCounts()
    controller:Update()
    context:NoPresentationWrites()
    assert(#context.objects == allocated + 1, "settled metric recovery replaced the loss region")
end

do
    local context, _, controller = New()
    local first, second = context:Row(), context:Row()
    context:Observe(first, 1)
    context:Observe(second, 1, 1000, "boss:72")
    context.failTexture = "timer\\FillWhite.blp"
    context:Observe(first, 0.8)
    local texture = assert(first.lossTexture)
    assert(not first.lossReady and not texture:IsShown(), "failed artwork was marked ready or shown")
    local prepared = #context.objects
    context.failTexture = nil
    controller:Update()
    assert(first.lossReady and texture:IsShown() and #context.objects == prepared, "failed art did not retry in place")
    context:Observe(second, 0.7, 1000, "boss:72")
    assert(controller.count == 2, "independent boss rows did not retain separate effects")
    context:ResetCounts()
    context.now = context.now + 0.1
    controller:Update()
    assert(context.reads.clock == 1, "multiple active boss rows sampled cosmetic time separately")
    controller:ClearAll()
    assert(controller.count == 0 and not next(controller.active), "clearing active rows left a pooled effect")
    assert(not first.lossTexture:IsShown() and not second.lossTexture:IsShown())
    context:ResetCounts()
    controller:Update()
    context:NoPresentationWrites()
    assert(not next(context.reads), "cleared multi-boss effects retained animation work")
end

do
    local context, env, controller = New()
    local row = context:Row()
    local entry = { hp = 1000, maximum = 1000, key = "boss:71", id = 71, name = "Edwin VanCleef" }
    env.DEBUFF_SIZE, env.DEBUFF_GAP = 18, 4
    env.render = { bossLoss = controller, customBosses = true, bossShown = true }
    env.bossGroup = env.CreateFrame("Frame", nil, env.UIParent)
    env.bossGroup:SetWidth(296)
    env.activeRows, env.rowOrder, env.spareRows = { [entry.key] = row }, { row }, {}
    context.settings.bossRows = 0
    context.settings.bossShowCurrentHealth, context.settings.bossShowMaximumHealth = true, true
    row.name, row.health, row.debuffs = row.frame:CreateFontString(), row.frame:CreateFontString(), {}
    row.frame.RefreshWidth = function() end
    function row.bar:SetValue(value)
        context.writes.value = (context.writes.value or 0) + 1
        self.value = value
    end
    env.EncounterRows = function() return { entry }, { [entry.key] = true } end
    env.ClearDebuffs = function() end
    env.UpdateDebuffRows = function() end
    env.TakeOver = function(part)
        assert(part == "bosses")
        return true
    end
    env.T.SetEncounterHealthText = function(label, current, maximum, showCurrent, showMaximum)
        label.received = { current, maximum, showCurrent, showMaximum }
    end
    context.source.Rows("playing")
    assert(row.bar.value == 1 and row.health.received[1] == 1000 and not row.lossTexture)
    entry.hp = 800
    context.source.Rows("playing")
    assert(row.bar.value == 0.8 and row.health.received[1] == 800, "loss animation delayed real health fill or text")
    assert(row.lossTexture:IsShown() and controller.count == 1, "received health decrease did not start its echo")
    assert(entry.hp == 800 and entry.maximum == 1000, "cosmetic loss changed the native snapshot")
    context.source.Retire(row)
    assert(controller.count == 0 and not row.lossTexture:IsShown(), "pooled row retirement retained a loss trail")
    assert(row.lossValue == nil and row.key == nil and env.spareRows[1] == row)
    assert(row.bar.value == 0 and not row.frame:IsShown(), "retirement lost the existing health cleanup")
end

print(
    "PASS boss Crimson echo keeps one lazy reused strip, exact easing, bounded rapid losses and idle/static/hidden cleanup"
)
