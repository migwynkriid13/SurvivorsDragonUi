-- CI only: production SCT icon resolver and bounded spellbook preparation.
assert(_VERSION == "Lua 5.1", "metadata fixtures require CI Lua 5.1")
local SCT = dofile("scripts/tests/fixtures/ui_sct_helpers.lua")
local passed = 0
local function Test(name, callback)
    local ok, failure = pcall(callback)
    assert(ok, name .. ": " .. tostring(failure))
    passed = passed + 1
    print("PASS " .. name)
end
local function Art(index) return "Interface\\Icons\\Spell_Nature_Metadata" .. tostring(index) end
local function Book(count, setup)
    return SCT(true, function(context, env)
        context.count, context.names, context.art = count, {}, {}
        context.slotReads, context.textureReads, context.headerReads, context.countReads = 0, 0, 0, 0
        context.settings.sctDirectDamage = true
        env.DFRL.locale.code, env.DFRL.locale.data = "en", { en = {}, de = {} }
        env.DFRL.locale.Native = function(value) return value end
        env.T.SpellIconCatalog = { game = { Shared = "Interface\\Icons\\Spell_Nature_Thorns" } }
        for index = 1, count do
            context.names[index], context.art[index] = "Spell" .. index, Art(index)
        end
        env.GetNumSpellTabs = function()
            context.countReads = context.countReads + 1
            return context.tabs or 1
        end
        env.GetSpellTabInfo = function()
            context.headerReads = context.headerReads + 1
            return "Book", nil, 0, context.emptyTabs and 0 or context.count
        end
        env.GetSpellName = function(index, book)
            assert(book == (env.BOOKTYPE_SPELL or "spell"))
            context.slotReads = context.slotReads + 1
            if context.failName then error("native spell metadata is not ready") end
            if context.onName then context.onName(index) end
            return context.names[index]
        end
        env.GetSpellTexture = function(index)
            context.textureReads = context.textureReads + 1
            return context.art[index]
        end
        env.T.ParseNameplateCombatEvent = function(_, message)
            return {
                kind = "damage",
                damageType = "spell",
                sourceName = "Player",
                targetName = "Enemy",
                spell = context.spell or "Spell1",
                amount = tonumber(message),
            }
        end
        if setup then setup(context, env) end
    end)
end
local function Lookup(context, name) return context:LookupIcon(name) end

Test("warm preparation bounds slot/header work and settles SCT icon lookups", function()
    local context = Book(19)
    assert(context.slotReads == 0 and context.countReads == 0, "initialization scanned eagerly")
    for _ = 1, 12 do
        local slots, headers = context.slotReads, context.headerReads
        context:Tick(0.016)
        assert(context.slotReads - slots + context.headerReads - headers <= 4, "warm callback exceeded four work steps")
    end
    assert(context.slotReads == 19, "bounded preparation did not traverse the complete book")
    local reads, headers, counts = context.slotReads, context.headerReads, context.countReads
    assert(Lookup(context, "Spell1") == Art(1) and Lookup(context, "Spell19") == Art(19))
    assert(
        context.slotReads == reads and context.headerReads == headers and context.countReads == counts,
        "accepted warm generation did not serve SCT lookups without native book reads"
    )
    context:Tick(0.016)
    assert(
        context.slotReads == reads and context.headerReads == headers and context.countReads == counts,
        "settled warming retained native book polling"
    )
end)

Test("empty tabs consume the same bounded warm budget", function()
    local context = Book(0, function(current)
        current.tabs, current.emptyTabs = 33, true
    end)
    context:Tick(0.016)
    assert(context.headerReads == 4 and context.slotReads == 0, "empty tab loop escaped its four-step budget")
    for _ = 1, 24 do
        context:Tick(0.016)
    end
    local headers = context.headerReads
    assert(Lookup(context, "Missing") == context.env.T.SourceIconFallback)
    assert(context.headerReads == headers, "completed empty tabs did not settle atomically")
end)

Test("cold hit discards partial preparation and keeps first-hit priority and grouping", function()
    local context = Book(9, function(current)
        current.names[1], current.names[9], current.spell = "Shared", "Shared", "Shared"
    end)
    context:Tick(0.016)
    assert(context.slotReads == 3, "first warm header/slot budget changed")
    context:Hit(111)
    assert(context.slotReads == 12, "first hit did not perform a fresh complete native traversal")
    assert(Lookup(context, "Shared") == Art(9), "partial/weak icon outranked the last native book record")
    local reads = context.slotReads
    context:Tick(0.01)
    context:Hit(111)
    context:Tick(0.1)
    local labels = context:Labels()
    assert(#labels == 1 and labels[1]:GetText() == "111", "preparation split exact duplicate grouping or summed hits")
    assert(context.slotReads == reads, "grouped hits repeated a settled book scan")
end)

Test("a warm metadata hole stays provisional and the consumer samples newly ready art", function()
    local context = Book(9, function(current) current.art[1] = nil end)
    context:Tick(0.016)
    context.art[1] = Art(101)
    for _ = 1, 5 do
        context:Tick(0.016)
    end
    assert(context.slotReads == 9, "missing warm art caused an immediate unbounded retry")
    assert(Lookup(context, "Spell1") == Art(101), "a provisional missing slot hid newly ready first-hit art")
    assert(context.slotReads == 18, "real consumer reused the early unready slot instead of sampling a fresh full book")
end)

Test("consumer missing metadata retains one-second retry semantics", function()
    local context = Book(5, function(current) current.art[1] = nil end)
    assert(Lookup(context, "Spell1") == context.env.T.SourceIconFallback)
    local reads = context.slotReads
    context.art[1] = Art(101)
    Lookup(context, "Spell2")
    context:Tick(0.5)
    assert(
        Lookup(context, "Spell1") == context.env.T.SourceIconFallback and context.slotReads == reads,
        "accepted incomplete metadata bypassed its existing one-second retry"
    )
    context:Tick(0.51)
    assert(Lookup(context, "Spell1") == Art(101), "ready metadata failed to recover after the native retry interval")
end)

Test("shape, getter, book and language changes cannot publish stale warm data", function()
    local context = Book(9)
    context:Tick(0.016)
    context.names[10], context.art[10], context.count = "Spell10", Art(10), 10
    context:Tick(0.016)
    context:Tick(0.016)
    assert(Lookup(context, "Spell10") == Art(10), "changed native tab shape published the old warm range")
    context:Event(context.controller, "SPELLS_CHANGED")
    context:Tick(0.016)
    context.env.GetSpellTexture = function(index) return Art(100 + index) end
    assert(Lookup(context, "Spell1") == Art(101), "getter replacement retained old provisional artwork")
    local reads = context.slotReads
    context.env.BOOKTYPE_SPELL = "new-spell-book"
    assert(
        Lookup(context, "Spell1") == Art(101) and context.slotReads == reads + 10,
        "book selector replacement retained an accepted generation"
    )
    context.env.DFRL.locale.code = "de"
    context:NotifyLocale()
    context.names[1] = "Zauber1"
    assert(Lookup(context, "Zauber1") == Art(101), "language retirement retained the old book generation")
end)

Test("optional warm failure does not interrupt active text and backs off", function()
    local context = Book(9)
    context:Hit(111)
    context:Tick(0.1)
    local label = assert(context:Labels()[1], "initial text was not displayed")
    local holder = label.parent.parent
    local x, y = holder.anchor.x, holder.anchor.y
    context:Hit(222)
    context:Event(context.controller, "SPELLS_CHANGED")
    context.failName = true
    context:Tick(0.1)
    assert(holder.anchor.x ~= x or holder.anchor.y ~= y, "optional metadata failure aborted SCT animation")
    assert(#context:Labels() == 2, "optional metadata failure blocked already queued hit delivery")
    local reads = context.slotReads
    for _ = 1, 20 do
        context:Tick(0.016)
    end
    assert(context.slotReads == reads, "failed warm getter retried every rendered frame")
    context.failName = false
    assert(Lookup(context, "Spell1") == Art(1), "real consumer waited for optional warm error backoff")
    context:Tick(1.5)
    assert(#context:Labels() == 0, "warm error prevented the original text lifetime from retiring")
end)

Test("off, hidden and world retirement stop provisional work; resumed SCT demand stays fresh", function()
    local context = Book(9)
    context:Tick(0.016)
    context:SetScrollHidden(true)
    local reads = context.slotReads
    context:Tick(0.2)
    assert(context.slotReads == reads, "hidden stream kept warming optional metadata")
    context:SetScrollHidden(false)
    context:Tick(0.016)
    assert(context.slotReads == reads + 3, "hidden retirement retained a provisional cursor")
    local source = context.env.DFRL.sct
    source.BeginEdit()
    source.SetMode("off")
    source.FinishEdit(true)
    reads = context.slotReads
    context:Tick(0.2)
    assert(context.slotReads == reads, "off mode retained the optional warm worker")
    source.BeginEdit()
    source.SetMode("on")
    source.FinishEdit(true)
    assert(
        Lookup(context, "Spell9") == Art(9) and context.slotReads == reads + 9,
        "resumed SCT consumer lost its on-demand complete lookup"
    )
    context:Event(context.controller, "PLAYER_LEAVING_WORLD")
    reads = context.slotReads
    context:Tick(1)
    assert(context.slotReads == reads, "world retirement retained warm reads")
    context:Event(context.controller, "PLAYER_ENTERING_WORLD")
    context.names[1], context.art[1] = "NewWorldSpell", Art(501)
    assert(Lookup(context, "NewWorldSpell") == Art(501), "new world reused prior accepted metadata")
end)

Test("reentrant invalidation restarts a real consumer instead of publishing old slots", function()
    local context = Book(7)
    context.onName = function(index)
        if index ~= 2 then return end
        context.onName = nil
        context.art[1] = Art(701)
        context:Event(context.controller, "SPELLS_CHANGED")
    end
    assert(Lookup(context, "Spell1") == Art(701), "reentrant dirty publication leaked the first provisional slot")
    assert(context.slotReads == 9, "real consumer did not restart once from the current generation")
end)

print("PASS " .. passed .. " chunked metadata lifecycle contracts")
