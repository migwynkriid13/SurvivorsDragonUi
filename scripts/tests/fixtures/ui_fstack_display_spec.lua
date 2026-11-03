-- CI only: actual inspector presentation over explicit font/anchor boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1")

for _, performance in ipairs({ false, true }) do
    local c = H.New()
    local env = c.env
    c.settings.performanceMode = performance
    c.scale = 1
    local create = c.Object
    function c:Object(...)
        local object = create(self, ...)
        local setPoint, clear = object.SetPoint, object.ClearAllPoints
        function object:SetPoint(...)
            setPoint(self, ...)
            self.point = { ... }
        end
        function object:ClearAllPoints()
            clear(self)
            self.point = nil
        end
        function object:GetPoint() return unpack(self.point or {}) end
        function object:GetNumPoints() return self.point and 1 or 0 end
        function object:GetEffectiveScale() return c.scale end
        local setTextColor = object.SetTextColor
        function object:SetTextColor(red, green, blue, alpha) setTextColor(self, red, green, blue, alpha or 1) end
        function object:GetStringWidth()
            c.reads.measure = (c.reads.measure or 0) + 1
            if c.missingMetrics then return 0 end
            local span = string.len(self:GetText()) * 7 * (select(2, self:GetFont()) or 11) / 11
            self.measuredHeight = math.max(1, math.ceil(span / self:GetWidth())) * 12
            return math.min(self:GetWidth(), span)
        end
        local getHeight = object.GetHeight
        function object:GetHeight() return self.kind == "FontString" and (self.measuredHeight or 12) or getHeight(self) end
        return object
    end
    env.panel, env.labels = env.CreateFrame("Frame", nil, env.UIParent), {}
    local chunk = assert(loadfile(assert(arg[1], "missing frame-stack display source")))
    setfenv(chunk, env)
    local display = chunk()
    local lines = { "Inspector heading", string.rep("wrapped line ", 20), "Last line" }
    display(lines, 100, 800, 600)
    local allocated = #c.objects
    c:ResetCounts()
    for _ = 1, 10 do
        display(lines, 100, 800, 600)
    end
    c:NoPresentationWrites()
    assert(not c.reads.measure, "unchanged inspector rows repeated glyph measurement")
    local label = env.labels[2]
    label.text, label.width, label.point, label.textColor = "native reset", 1, nil, { 0, 0, 0, 0 }
    env.panel.width, env.panel.point = 1, nil
    display(lines, 100, 800, 600)
    assert(label:GetText() == lines[2] and label:GetWidth() == 600 and label.point[4] == 10)
    assert(label.textColor[1] == 1 and label.textColor[4] == 1 and env.panel:GetWidth() == 620)
    label.font[2] = 12
    c:ResetCounts()
    display(lines, 100, 800, 600)
    assert(c.reads.measure == 1, "changed native font kept old wrapping metrics")
    c.scale = 1.25
    c:ResetCounts()
    display(lines, 100, 800, 600)
    assert(c.reads.measure == 3, "effective scale change kept old wrapping metrics")
    display(lines, 700, 800, 50)
    local notice = env.DFRL.locale.Text("... screen limit reached; /fstack off to close.")
    assert(env.labels[1]:GetText() == notice and not label:IsShown() and not label.fstackMetrics)
    env.labels[1].measuredHeight = 24 -- Native notice wrapping can settle after SetText.
    c:ResetCounts()
    display(lines, 700, 800, 50)
    c:NoPresentationWrites()
    assert(not c.reads.measure, "stable clipping measured and rewrote the hidden full line")
    display(lines, 700, 800, 600)
    assert(env.labels[1]:GetText() == lines[1] and label:IsShown() and env.panel.point[1] == "TOPLEFT")
    c.missingMetrics = true
    lines[2] = "Changed but not measurable yet"
    display(lines, 700, 800, 600)
    c:ResetCounts()
    display(lines, 700, 800, 600)
    assert((c.reads.measure or 0) > 0, "failed inspector metrics were cached as ready")
    c.missingMetrics = false
    display(lines, 700, 800, 600)
    assert(label.fstackMetrics.lineHeight and #c.objects == allocated, "metric recovery rebuilt the inspector pool")
end
print(
    "PASS inspector presentation reuses settled metrics, repairs native state and retains clipping/retry behavior in both modes"
)
