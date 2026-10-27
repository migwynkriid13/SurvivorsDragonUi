-- CI only: exact production hover functions over explicit native boundaries.
assert(_VERSION == "Lua 5.1", "guardian hover fixtures require CI Lua 5.1")
local function Fixture()
    local state = { writes = 0, cursorX = 0, cursorY = 0 }
    local pin = { guardianName = "Kobold Taskmaster", visible = true, drawnX = 0, drawnY = 0 }
    function pin:IsVisible() return self.visible end
    local minimap = {}
    function minimap:GetCenter() return 0, 0 end
    function minimap:GetEffectiveScale() return 1.5 end
    local tooltip = { shown = false }
    function tooltip:IsOwned(owner) return self.owner == owner end
    function tooltip:IsShown() return self.shown end
    function tooltip:IsVisible() return self.shown end
    function tooltip:SetOwner(owner)
        self.owner = owner
        state.writes = state.writes + 1
    end
    function tooltip:SetText(text)
        self.text = text
        state.writes = state.writes + 1
    end
    function tooltip:Show()
        self.shown = true
        state.writes = state.writes + 1
    end
    function tooltip:Hide()
        self.shown = false
        state.writes = state.writes + 1
    end
    local entries = { { key = "1:10" } }
    local env = setmetatable({
        GameTooltip = tooltip,
        Minimap = minimap,
        trackers = { {}, { minimapPins = { ["1:10"] = pin } } },
        MinimapEntries = function() return entries end,
        GetCursorPosition = function() return state.cursorX, state.cursorY end,
        T = { GetLocalSize = function() return 100, 100 end },
        DFRL = {
            layout = {
                IsEditing = function() return state.editing end,
                IsHidden = function() return state.hidden end,
            },
        },
    }, { __index = _G })
    env._G = env
    local chunk = assert(loadfile(arg[1]))
    setfenv(chunk, env)
    state.Update, state.pin, state.minimap, state.tooltip = chunk(), pin, minimap, tooltip
    local parent, root = {}, {}
    function parent:GetEffectiveScale() return 1 end
    function root:GetEffectiveScale() return 1 end
    function root:IsVisible() return not state.hidden end
    function tooltip:GetParent() return parent end
    function tooltip:GetScale() return 1 end
    function tooltip:GetNumPoints() return self.point and 1 or 0 end
    function tooltip:GetPoint() return unpack(self.point or {}) end
    function tooltip:ClearAllPoints()
        self.point = nil
        state.writes = state.writes + 1
    end
    function tooltip:SetPoint(...)
        self.point = { ... }
        state.writes = state.writes + 1
    end
    env.UIParent, env.tooltipRoot = parent, root
    env.registeredIcons, env.iconAnchors, env.iconSides = { [pin] = pin }, {}, { [pin] = "cursor" }
    env.T.NearlyEqual = function(a, b) return a == b end
    env.T.PlaceHoverAtCursor = function(frame)
        assert(frame == tooltip, "cursor helper received a different tooltip")
        state.cursorPlacements = (state.cursorPlacements or 0) + 1
        return true
    end
    env.DFRL.display = {
        Get = function(key)
            assert(key == "tooltipAtCursor", "unexpected cursor placement setting")
            return state.cursorPreference
        end,
    }
    local placement = assert(loadfile(arg[2]))
    setfenv(placement, env)
    state.Place, state.env = placement(), env
    return state
end

local state = Fixture()
state.Update()
assert(state.tooltip.text == "Kobold Taskmaster" and state.tooltip:IsOwned(state.pin) and state.tooltip.shown)
state.writes = 0
state.Update()
assert(state.writes == 0, "stationary unchanged guardian hover repainted")
state.pin.guardianName = "Gruff Swiftbite"
state.Update()
assert(state.tooltip.text == "Gruff Swiftbite", "accepted guardian-name change did not refresh the hover")
state.pin.visible = false
state.Update()
assert(not state.tooltip.shown, "retired marker retained its tooltip")
print("PASS guardian hover naming, unchanged work and retired-marker cleanup")

state = Fixture()
state.pin.drawnX, state.cursorX = 20, 30
state.Update()
assert(state.tooltip.shown, "scaled minimap cursor did not hit the drawn guardian marker")
state.cursorX = 75
state.Update()
assert(not state.tooltip.shown, "moving off a scaled marker retained its name")
state.pin.guardianName, state.cursorX = nil, 30
state.Update()
assert(not state.tooltip.shown, "a missing native name was invented")
print("PASS guardian hover uses minimap scale and requires a native name")

state = Fixture()
state.tooltip.owner, state.tooltip.shown = {}, true
state.Update()
assert(state.writes == 0, "guardian hover stole a foreign tooltip")
state.tooltip.shown = false
state.Update()
state.tooltip.owner = {}
state.writes = 0
state.Update()
assert(state.writes == 0, "guardian hover reclaimed a replaced native owner")
state.cursorX = 2000
state.Update()
assert(state.writes == 0 and state.tooltip.shown, "leaving hid a foreign tooltip")
print("PASS guardian hover respects foreign/native tooltip ownership")

state = Fixture()
state.Update()
state.hidden = true
state.Update()
assert(not state.tooltip.shown, "hidden Tooltip layout left the guardian name visible")
state.hidden, state.writes = false, 0
state.Update()
assert(state.writes == 0, "unhiding replayed a retired hover without re-entry")
state.cursorX = 60
state.Update()
state.cursorX = 0
state.Update()
assert(state.tooltip.shown, "fresh hover did not resume after Tooltip unhiding")
state.editing = true
state.Update()
assert(not state.tooltip.shown, "Layout editing retained a guardian hover")
print("PASS guardian hover respects Tooltip hiding, re-entry and editing")

state = Fixture()
state.Update()
state.Place()
assert(state.cursorPlacements == 1 and not state.tooltip.point, "guardian tooltip used the bottom-right Layout seat")
state.writes = 0
state.Place()
assert(state.cursorPlacements == 2 and state.writes == 0, "guardian placement fought the shared cursor helper")
state.tooltip.owner = {}
state.Place()
assert(state.tooltip.point[1] == "BOTTOMRIGHT" and state.tooltip.point[2] == state.env.tooltipRoot)
assert(state.cursorPlacements == 2, "ordinary Layout tooltip was forced to the cursor")
local icon = { IsVisible = function() return true end }
state.env.registeredIcons[icon], state.env.iconSides[icon] = icon, "above"
state.tooltip.owner = icon
state.Place()
assert(state.tooltip.point[1] == "BOTTOM" and state.tooltip.point[2] == icon, "ordinary icon lost its own anchor")
state.cursorPreference = true
state.Place()
assert(state.cursorPlacements == 3, "global cursor preference no longer applied to ordinary icons")
state.cursorPreference, state.tooltip.owner, state.pin.visible = false, state.pin, false
state.Place()
assert(not state.tooltip.shown and state.cursorPlacements == 3, "hidden guardian owner kept a cursor tooltip")
print("PASS shared tooltip controller forces only guardian pins to the cursor and preserves ordinary placement")
