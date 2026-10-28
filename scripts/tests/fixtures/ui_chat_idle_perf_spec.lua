-- CI only: the production chat fade-settings boundary over explicit native state.
assert(_VERSION == "Lua 5.1", "chat idle fixtures require CI Lua 5.1")
local visible, reads, writes, failed, expectedFading = true, 0, 0, false, true
local expectedHold, expectedDuration = 14, 0.6
local env = {
    root = {
        IsVisible = function()
            reads = reads + 1
            return visible
        end,
    },
}
local chunk = assert(loadfile(assert(arg[1], "missing extracted chat fade-settings source")))
setfenv(chunk, env)
local apply = chunk()
local state = {}
state.native = {
    SetTimeVisible = function(_, value)
        assert(math.abs(value - expectedHold) < 0.000001)
        writes = writes + 1
    end,
    SetFadeDuration = function(_, value)
        assert(value == expectedDuration)
        writes = writes + 1
        if failed then
            failed = false
            error("injected native fade configuration failure")
        end
    end,
    SetFading = function(_, value)
        assert(value == expectedFading)
        writes = writes + 1
    end,
}
apply(state, false)
assert(reads == 1 and writes == 3 and state.fadeConfigured and state.held == false)
reads, writes = 0, 0
for _ = 1, 100 do
    apply(state, false)
end
assert(reads == 0 and writes == 0, "settled chat fade state kept reading native visibility")
visible = false
apply(state, true)
assert(reads == 1 and writes == 0 and state.held == false, "hidden chat committed a fade handoff")
visible = true
expectedFading = false
apply(state, true)
assert(reads == 2 and writes == 1 and state.held == true, "visible chat did not retry the pending hold")
state.fadeConfigured, state.held = nil, nil
reads, writes, failed = 0, 0, true
expectedFading = true
local success = pcall(apply, state, false)
assert(not success and not state.fadeConfigured and state.held == nil, "failed native setup was cached")
apply(state, false)
assert(state.fadeConfigured and state.held == false and writes == 5, "failed native setup did not retry")
env.performanceMode = true
expectedHold, expectedDuration, writes = 14.6, 0, 0
apply(state, false)
assert(
    state.held == false and state.fadeDuration == 0 and writes == 2,
    "Performance Mode stopped native chat expiry instead of removing its fade"
)
reads, writes = 0, 0
for _ = 1, 100 do
    apply(state, false)
end
assert(reads == 0 and writes == 0, "Performance Mode repeated a settled native fade handoff")
expectedFading = false
apply(state, true)
assert(state.held == true and writes == 1, "Performance Mode did not hold wheel-scrolled history")
expectedFading, writes = true, 0
apply(state, false)
assert(state.held == false and writes == 1, "Performance Mode did not resume expiry at the bottom")
env.performanceMode = false
expectedHold, expectedDuration, reads, writes = 14, 0.6, 0, 0
visible = false
apply(state, false)
assert(state.fadeDuration == 0 and writes == 0, "hidden mode exit performed native fade work")
visible = true
apply(state, false)
assert(state.fadeDuration == 0.6 and writes == 2, "disabling Performance Mode did not restore native chat fading")
env.performanceMode = true
expectedHold, expectedDuration, failed, writes = 14.6, 0, true, 0
success = pcall(apply, state, false)
assert(not success and state.fadeDuration == 0.6, "failed mode handoff committed its new native duration")
apply(state, false)
assert(state.fadeDuration == 0 and writes == 4, "failed mode handoff did not retry")
print(
    "PASS settled chat skips native reads; instant native expiry preserves wheel holds, hidden handoffs and failed retries"
)
