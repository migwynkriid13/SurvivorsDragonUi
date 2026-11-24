-- CI only: production timer caption placement over explicit native/Layout boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "timer caption fixtures require CI Lua 5.1")
for _, performance in ipairs({ false, true }) do
    local c = H.New()
    local env = c.env
    c:Load("core/display.lua", "Display")
    local display = env.DFRL.display
    display.BeginEdit()
    display.Set("performanceMode", performance)
    local create = c.Object
    function c:Object(kind, name, parent)
        local object = create(self, kind, name, parent)
        function object:SetParent(value) self.parent = value end
        function object:GetEffectiveScale() return self.scale or 1 end
        function object:SetPoint(...)
            self.point = { ... }
            self.points = self.points or {}
            self.points[self.point[1]] = self.point
            self.context.writes.SetPoint = (self.context.writes.SetPoint or 0) + 1
        end
        function object:GetStringWidth() return string.len(self:GetText()) * 7 end
        return object
    end
    env.run = env.CreateFrame("Frame", nil, env.UIParent)
    env.run:SetWidth(296)
    env.run:SetHeight(31)
    local overlay = env.CreateFrame("Frame", nil, env.run)
    local geometry, anchor, layoutOptions
    env.DFRL.layout.IsHidden = function() return false end
    env.DFRL.layout.Register = function(key, frame, place, options)
        assert(key == "runTimerText")
        c.frame, anchor, layoutOptions = frame, place, options
        place(frame)
    end
    env.DFRL.layout.Place = function(key)
        assert(key == "runTimerText")
        if geometry then
            c.frame:SetPoint("CENTER", env.UIParent, "CENTER", geometry.x, geometry.y)
        else
            anchor(c.frame)
        end
    end
    local chunk = assert(loadfile(assert(arg[1], "missing extracted timer text source")))
    setfenv(chunk, env)
    local api = chunk()
    local view = api.New()
    env.timerText = view
    view:Bind(env.run, overlay)
    env.runText, env.bossText = view.root:CreateFontString(), view.root:CreateFontString()
    env.runText:SetText("RUN 10:00 / 16:00")
    env.bossText:SetText("BOSS IN: 0:51")
    env.runText:SetHeight(14)
    env.bossText:SetHeight(14)
    env.runClock, env.bossClock = { visible = true, pixel = 1 }, { visible = true, pixel = 1 }
    env.currentFont, env.runBar = { size = 14 }, { layoutWidth = 280 }
    env.run.affixes = {
        width = 0,
        height = 23,
        attached = true,
        HeaderWidth = function() return 0 end,
        Context = function(_, first, second, width, height, below)
            c.affixCaptionWidth, c.affixBelow = width, below
        end,
    }
    env.runMoveRegion = env.CreateFrame("Frame", nil, env.run)
    view.onBounds, view.onShow = api.Bounds, api.Bounds
    view:RegisterLayout()
    api.Bounds()
    assert(view.root:GetParent() == overlay and not view.detached:IsShown() and not layoutOptions.handleAvailable())
    assert(env.runText.point[1] == "BOTTOMLEFT" and env.bossText.point[1] == "BOTTOMRIGHT")
    display.Set("runTextBelow", true)
    api.Bounds()
    assert(env.runText.point[1] == "TOPLEFT" and env.runText.point[3] == "BOTTOMLEFT")
    assert(env.bossText.point[1] == "TOPRIGHT" and env.runMoveRegion.points.BOTTOMRIGHT[5] < 0)
    assert(not c.affixBelow and c.affixCaptionWidth == 0, "timer captions changed independent affix placement")
    display.Set("affixIconsBelow", true)
    api.Bounds()
    assert(c.affixBelow and c.affixCaptionWidth > 0, "affixes did not share the lower caption lane")
    display.Set("detachRunText", true)
    view:SetActive(true)
    api.Bounds()
    assert(view.root:GetParent() == view.detached and view:Visible() and layoutOptions.handleAvailable())
    assert(c.affixBelow and c.affixCaptionWidth == 0, "detaching captions changed the selected affix side")
    assert(env.runText.point[2] == view.root and env.bossText.point[2] == view.root)
    geometry = { x = 250.5, y = -80.25 }
    env.DFRL.layout.Place("runTimerText")
    assert(view.detached.point[4] == 250.5 and view.detached.point[5] == -80.25)
    env.run:Hide()
    assert(view:Visible(), "detached captions inherited the timer bar's visibility")
    c:ResetCounts()
    api.Bounds()
    c:NoPresentationWrites()
    display.Set("detachRunText", false)
    assert(view.root:GetParent() == overlay and not view.detached:IsShown())
    display.Set("detachRunText", true)
    assert(view.root:GetParent() == view.detached and view.detached.point[4] == geometry.x)
    display.FinishEdit(false)
    assert(not view.separate and not display.Get("runTextBelow"), "Cancel retained timer caption previews")
    display.BeginEdit()
    display.Set("runTextBelow", true)
    display.Set("detachRunText", true)
    display.FinishEdit(true)
    assert(env.SurvivorsDragonUiDisplay.detachRunText and env.SurvivorsDragonUiDisplay.runTextBelow)
    view:SetActive(false)
    assert(not view.detached:IsShown(), "retired native clock retained detached captions")
    display.Reset()
    assert(not view.separate and not display.Get("runTextBelow"), "reset retained a detached/below choice")
    assert(env.runText:GetText() == "RUN 10:00 / 16:00" and env.bossText:GetText() == "BOSS IN: 0:51")
    for _, object in ipairs(c.objects) do
        assert(not object:GetScript("OnUpdate"), "timer caption placement added an idle worker")
    end
end
print(
    "PASS timer caption placement, independent Layout ownership, geometry retention, visibility and settings lifecycle"
)
