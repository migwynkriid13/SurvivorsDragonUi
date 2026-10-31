-- Session-only meter resets and rolling rates from complete native counters.
-- No combat events, gameplay clock, frame, saved history or native writes.
setfenv(1, DFRL:GetEnv())

-- Purge every display view without writing the game's whole-run counters.
function DFRL.tools.NewMeterSession()
    local session, views = {}, {}
    local active, resetAt = false, nil
    local function Number(value) return type(value) == "number" and value - value == 0 and value >= 0 end
    local function Kind(entry) return entry.proc == 1 and 1 or 0 end
    local function Record(state, entry)
        local kinds = state.sources[entry.name]
        if not kinds then
            kinds = {}
            state.sources[entry.name] = kinds
        end
        local kind = Kind(entry)
        local record = kinds[kind]
        if not record then
            record = { base = 0 }
            kinds[kind] = record
        end
        return record
    end
    local function Baseline(source, total, zero)
        local state = { sources = {}, rows = {}, count = 0, serial = 0, total = total }
        for _, entry in ipairs(source) do
            local record = Record(state, entry)
            record.base, record.last = zero and 0 or entry.dmg, entry.dmg
        end
        return state
    end
    local function Order(left, right)
        if left.dmg == right.dmg then return left.order < right.order end
        return left.dmg > right.dmg
    end
    function session.Clear()
        if not active then return end
        views, active, resetAt = {}, false, nil
    end
    function session.Reset()
        views, active, resetAt = {}, true, nil
    end
    function session.IsReset() return active end
    -- The visible reader supplies a fresh token for each validated publication.
    -- Callers without one retain the complete counter comparison on every read.
    function session.Apply(index, source, total, rate, time, publication)
        if not active then return source, total, rate end
        if Number(time) then
            if resetAt and time < resetAt then session.Reset() end
            if not resetAt then resetAt = time end
        end
        local state = views[index]
        if not state then
            state = Baseline(source, total, false)
            views[index] = state
        end
        local serial, regressed = state.serial + 1, total < state.total
        local changed = state.amount == nil or total ~= state.total
        if not publication or publication ~= state.publication then
            for order, entry in ipairs(source) do
                local record = Record(state, entry)
                if record.last and entry.dmg < record.last then regressed = true end
                if record.last ~= entry.dmg or record.order ~= order or record.class ~= entry.class then
                    changed = true
                end
                record.seen = serial
            end
            for _, kinds in pairs(state.sources) do
                for _, record in pairs(kinds) do
                    if record.seen ~= serial then regressed = true end
                end
            end
        end
        if regressed then
            -- A new native boss fight is already fresh. Other counter resets
            -- rebase conservatively, so pre-purge values never reappear.
            state = Baseline(source, total, index == 3)
            views[index] = state
            changed = true
        end
        local elapsed = Number(time) and resetAt and math.max(1, time - resetAt) or nil
        state.publication = publication
        if not changed then
            for _, row in ipairs(state.rows) do
                row.dps = elapsed and row.dmg / elapsed or nil
            end
            state.serial = serial
            return state.rows, state.amount, elapsed and state.amount / elapsed or nil
        end
        local count, amount = 0, 0
        for order, entry in ipairs(source) do
            local record = Record(state, entry)
            record.last, record.order, record.class = entry.dmg, order, entry.class
            local delta = math.max(0, entry.dmg - record.base)
            if delta > 0 then
                count, amount = count + 1, amount + delta
                local row = state.rows[count] or {}
                row.name, row.proc, row.order = entry.name, entry.proc, order
                row.class = entry.class
                row.dmg, row.dps = delta, elapsed and delta / elapsed or nil
                state.rows[count] = row
            end
        end
        for order = count + 1, state.count do
            state.rows[order] = nil
        end
        table.setn(state.rows, count)
        for _, row in ipairs(state.rows) do
            row.share = row.dmg / amount
        end
        table.sort(state.rows, Order)
        state.count, state.serial, state.total, state.amount = count, serial, total, amount
        return state.rows, amount, elapsed and amount / elapsed or nil
    end
    return session
end

-- Native incoming counters have category totals rather than meter-source rows.
function DFRL.tools.NewMeterTaken()
    local model = { revision = 0 }
    local labels = {
        ["boss melee"] = "Boss melee",
        ["boss spell"] = "Boss spells",
        ["elite"] = "Elites",
        ["mob melee"] = "Enemy melee",
        ["mob spell"] = "Enemy spells",
        ["area"] = "Ground effects",
    }
    local rows, pool, names = {}, {}, {}
    local lastSource, lastStamp, lastReceipt, lastNativeTotal, lastTime
    local retiredSource, retiredStamp, retiredReceipt
    local total, rate, count
    local function Number(value) return type(value) == "number" and value - value == 0 and value >= 0 end
    local function ClearRow(row)
        for key in pairs(row) do
            row[key] = nil
        end
    end
    local function ClearNames()
        for name in pairs(names) do
            names[name] = nil
        end
    end
    local function Order(left, right)
        if left.dmg == right.dmg then return left.order < right.order end
        return left.dmg > right.dmg
    end
    local function Row(index, name, amount, order)
        local row = pool[index]
        if not row then
            row = {}
            pool[index] = row
        else
            ClearRow(row)
        end
        row.name, row.dmg, row.order, row.proc = name, amount, order, 0
        rows[index] = row
    end
    function model.Clear()
        if not lastSource and not count and not next(rows) and not next(names) then return end
        if lastSource then
            retiredSource, retiredStamp, retiredReceipt = lastSource, lastStamp, lastReceipt
        end
        for _, row in ipairs(pool) do
            ClearRow(row)
        end
        for index in pairs(rows) do
            rows[index] = nil
        end
        table.setn(rows, 0)
        ClearNames()
        lastSource, lastStamp, lastReceipt, lastNativeTotal, lastTime = nil, nil, nil, nil, nil
        total, rate, count = nil, nil, nil
        model.revision = model.revision + 1
    end
    local function Unavailable()
        model.Clear()
        return nil
    end
    function model.Read(time, receipt)
        local source, stamp = _G.AZS_TAKEN, _G.AZS_TAKEN_UPDATED
        if not Number(time) or type(source) ~= "table" or not Number(stamp) then return Unavailable() end
        if lastTime and time < lastTime then model.Clear() end
        if source == retiredSource and stamp == retiredStamp and receipt == retiredReceipt then return nil end
        local run, nativeTotal = _G.AZS_RUN
        if
            type(run) == "table"
            and Number(_G.AZS_RUN_UPDATED)
            and Number(run.t)
            and run.t <= time
            and Number(run.taken)
        then
            nativeTotal = run.taken
        end
        if source ~= lastSource or stamp ~= lastStamp or receipt ~= lastReceipt or nativeTotal ~= lastNativeTotal then
            local length, highest = 0, 0
            for index in pairs(source) do
                if type(index) ~= "number" or index < 1 or index > 64 or index ~= math.floor(index) then
                    return Unavailable()
                end
                length, highest = length + 1, math.max(highest, index)
            end
            if length ~= highest then return Unavailable() end
            local used, amount = 0, 0
            ClearNames()
            for index = 1, length do
                local entry = source[index]
                if
                    type(entry) ~= "table"
                    or type(entry.source) ~= "string"
                    or entry.source == ""
                    or not Number(entry.dmg)
                then
                    return Unavailable()
                end
                local name = labels[entry.source] or entry.source
                if names[name] then return Unavailable() end
                names[name] = true
                amount = amount + entry.dmg
                if not Number(amount) then return Unavailable() end
                if entry.dmg > 0 then
                    used = used + 1
                    Row(used, name, entry.dmg, index)
                end
            end
            if nativeTotal and nativeTotal > amount then
                if names["Unattributed damage"] then return Unavailable() end
                used = used + 1
                Row(used, "Unattributed damage", nativeTotal - amount, length + 1)
                amount = nativeTotal
            end
            for index = used + 1, count or table.getn(pool) do
                ClearRow(pool[index])
                rows[index] = nil
            end
            table.setn(rows, used)
            for _, row in ipairs(rows) do
                row.share = row.dmg / amount
            end
            table.sort(rows, Order)
            total, count = amount, used
            lastSource, lastStamp, lastReceipt, lastNativeTotal = source, stamp, receipt, nativeTotal
            retiredSource, retiredStamp, retiredReceipt = nil, nil, nil
            lastTime = nil
            model.revision = model.revision + 1
        end
        if time ~= lastTime then
            local elapsed = math.max(time, 1)
            for _, row in ipairs(rows) do
                row.dps = row.dmg / elapsed
            end
            lastTime, rate = time, total / elapsed
        end
        return rows, total, rate
    end
    return model
end

function DFRL.tools.NewMeterDps(window)
    local STEP, CAPACITY, MAX_WINDOW = 0.2, 604, 120
    local model = { window = window, revision = 0, valid = false }
    local sources, seen = {}, {}
    local lastTime, lastTotal, sampledAt, startedAt, lastPublication
    local function Number(value) return type(value) == "number" and value - value == 0 and value >= 0 end
    local function Series() return { times = {}, values = {}, first = 1, count = 0 } end
    local header = Series()
    local function Slot(series, offset) return math.mod(series.first - 1 + offset, CAPACITY) + 1 end
    local function Empty(series)
        for index in pairs(series.times) do
            series.times[index], series.values[index] = nil, nil
        end
        table.setn(series.times, 0)
        table.setn(series.values, 0)
        series.first, series.count = 1, 0
    end
    local function Push(series, time, value)
        local count = series.count
        local tail = count > 0 and Slot(series, count - 1) or nil
        if tail and series.times[tail] == time then
            series.values[tail] = value
        elseif
            tail
            and count > 1
            and series.values[tail] == value
            and series.values[Slot(series, count - 2)] == value
        then
            -- Keep the start of a flat interval and extend only its far end.
            series.times[tail] = time
        else
            if count == CAPACITY then
                series.first, count = Slot(series, 1), count - 1
            end
            local index = Slot(series, count)
            series.times[index], series.values[index] = time, value
            series.count = count + 1
        end
        while series.count > 1 and series.times[Slot(series, 1)] <= time - MAX_WINDOW do
            series.first, series.count = Slot(series, 1), series.count - 1
        end
    end
    local function At(series, time)
        if series.count == 0 then return nil end
        local first, last = series.first, Slot(series, series.count - 1)
        if time <= series.times[first] then return series.values[first] end
        if time >= series.times[last] then return series.values[last] end
        local low, high = 0, series.count - 1
        while high - low > 1 do
            local middle = math.floor((low + high) / 2)
            if series.times[Slot(series, middle)] <= time then
                low = middle
            else
                high = middle
            end
        end
        local left, right = Slot(series, low), Slot(series, high)
        local fraction = (time - series.times[left]) / (series.times[right] - series.times[left])
        return series.values[left] + (series.values[right] - series.values[left]) * fraction
    end
    function model.Clear()
        if not lastTime and not next(seen) then return end
        sources, seen, header = {}, {}, Series()
        lastTime, lastTotal, sampledAt, startedAt, lastPublication = nil, nil, nil, nil, nil
        model.valid = false
        model.revision = model.revision + 1
    end
    function model.Suspend()
        if model.valid or startedAt then model.revision = model.revision + 1 end
        model.valid = false
        if not startedAt then return end
        Empty(header)
        for _, kinds in pairs(sources) do
            for _, series in pairs(kinds) do
                Empty(series)
            end
        end
        sampledAt, startedAt = nil, nil
    end
    function model.SetWindow(value)
        if model.window == value then return end
        model.window = value
        if value == 0 then model.Suspend() end
    end
    function model.NeedsRead() return model.window > 0 end
    function model.Observe(time, lines, total, nativeRate, publication)
        if not Number(time) or not Number(total) or not Number(nativeRate) or type(lines) ~= "table" then
            return false
        end
        local regressed = (lastTime and time < lastTime) or (lastTotal and total < lastTotal)
        local publicationChanged = not publication or publication ~= lastPublication
        if publicationChanged then
            for name in pairs(seen) do
                seen[name] = nil
            end
            for _, entry in ipairs(lines) do
                if
                    type(entry) ~= "table"
                    or type(entry.name) ~= "string"
                    or entry.name == ""
                    or not Number(entry.dmg)
                    or not Number(entry.dps)
                    or not Number(entry.share)
                    or entry.share > 1
                then
                    return false
                end
                local kind = entry.proc == 1 and 1 or 0
                local bit = kind + 1
                local flags = seen[entry.name] or 0
                if flags == bit or flags == 3 then return false end
                seen[entry.name] = flags + bit
                local series = sources[entry.name] and sources[entry.name][kind]
                if series and entry.dmg < series.value then regressed = true end
            end
            for name, kinds in pairs(sources) do
                for kind in pairs(kinds) do
                    if seen[name] ~= kind + 1 and seen[name] ~= 3 then regressed = true end
                end
            end
        end
        if regressed then
            model.Clear()
            publicationChanged = true
        end
        -- Never bridge unobserved time after hiding, lost updates or a view gap.
        if lastTime and time - lastTime > 2 then model.Suspend() end
        local beginning = not startedAt
        local sample = model.window > 0 and (not sampledAt or time == sampledAt or time - sampledAt >= STEP)
        if publicationChanged then
            for _, entry in ipairs(lines) do
                local kinds = sources[entry.name]
                if not kinds then
                    kinds = {}
                    sources[entry.name] = kinds
                end
                local kind = entry.proc == 1 and 1 or 0
                local series = kinds[kind]
                if not series then
                    series = Series()
                    kinds[kind] = series
                    if not beginning and model.window > 0 then Push(series, lastTime, 0) end
                end
                series.value = entry.dmg
                if sample then Push(series, time, entry.dmg) end
            end
        elseif sample then
            for _, kinds in pairs(sources) do
                for _, series in pairs(kinds) do
                    Push(series, time, series.value)
                end
            end
        end
        header.value = total
        if sample then
            Push(header, time, total)
            sampledAt = time
            if beginning then startedAt = time end
        end
        lastTime, lastTotal, model.valid = time, total, true
        lastPublication = publication
        return true
    end
    local function Rate(series, nativeAverage)
        local average = nativeAverage
        if model.window == 0 then return average, average end
        if not model.valid or not startedAt or not series then return nil, average end
        local from = math.max(startedAt, lastTime - model.window)
        local span = lastTime - from
        if span < 1 then return nil, average end
        local base = At(series, from)
        return base and math.max(0, series.value - base) / span or nil, average
    end
    function model.Header(nativeAverage) return Rate(header, nativeAverage) end
    function model.Row(name, proc, nativeAverage)
        local kinds = sources[name]
        return Rate(kinds and kinds[proc == 1 and 1 or 0], nativeAverage)
    end
    return model
end
