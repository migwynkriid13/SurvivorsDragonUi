-- CI only: the production chat fade-settings boundary over explicit native state.
assert(_VERSION == "Lua 5.1", "chat idle fixtures require CI Lua 5.1")
local visible, reads, writes, failed, expectedFading = true, 0, 0, false, true
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
        assert(value == 14)
        writes = writes + 1
    end,
    SetFadeDuration = function(_, value)
        assert(value == 0.6)
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
expectedFading, writes = false, 0
apply(state, false)
assert(state.held == true and writes == 1, "Performance Mode left native chat fading enabled")
reads, writes = 0, 0
for _ = 1, 100 do
    apply(state, false)
end
assert(reads == 0 and writes == 0, "Performance Mode repeated a settled native fade handoff")
env.performanceMode = false
expectedFading = true
apply(state, false)
assert(state.held == false and writes == 1, "disabling Performance Mode did not restore native chat fading")
print("PASS settled chat skips native visibility reads and preserves hidden handoffs and failed configuration retries")
