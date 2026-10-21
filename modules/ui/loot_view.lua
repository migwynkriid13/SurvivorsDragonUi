--[[
Selected design 02: Blizzard Entertainment's silver retail loot alert.
Gethe/wow-ui-textures e80e3278cc833c89e1f3fc79557b68315d750935,
LootFrame/LootToast.PNG (1024x256), rectangle (289,148,565,244).
The unmodified 276x96 crop occupies the top-left of Toast.tga (512x128).
https://github.com/Gethe/wow-ui-textures/blob/e80e3278cc833c89e1f3fc79557b68315d750935/LootFrame/LootToast.PNG
Blizzard artwork retains its own terms; the public mirror grants no new license.
The existing WhiteIconFrame rim retains third_party/Character-ARTWORK.md's notice.
No retail Lua, mixin, atlas API or framework is imported.
Sources, layout and animation evidence: third_party/LootNotifications-ARTWORK.md.
]]
DFRL:NewMod("LootView", 4, function()
    local loot, layout, actionDefaults = DFRL.loot, DFRL.layout, DFRL.actionBarDefaults
    if not loot or not layout or not actionDefaults then return end
    local path = DFRL:GetInfoOrCons("tex")
    local WIDTH, HEIGHT, STEP, LIMIT = 276, 96, 80, 3
    local BORDER_BOTTOM_INSET = 12
    local FADE_IN, FADE_START, LIFETIME = 0.2, 4.05, 5.55
    local pool, visible, count = {}, {}, 0
    local ready = true
    local frame = CreateFrame("Frame", "DFRL_LootNotifications", UIParent)
    frame:SetWidth(WIDTH)
    frame:SetHeight(HEIGHT + (LIMIT - 1) * STEP)
    frame:SetFrameStrata("HIGH")
    frame:EnableMouse(false)
    frame:Hide()
    -- A separate cosmetic updater also retires cards while Layout hides the
    -- group. Hidden cards cannot stall the shared intake queue indefinitely.
    local animation = CreateFrame("Frame")

    local function Label(parent, size)
        local label = parent:CreateFontString(nil, "OVERLAY")
        local face = "Fonts\\FRIZQT__.TTF"
        local ok, loaded = pcall(label.SetFont, label, face, size, "")
        if not ok or (not loaded and label:GetFont() ~= face) then T.SetFont(label, size, "") end
        if not label:GetFont() then ready = false end
        label:SetJustifyH("LEFT")
        label:SetJustifyV("MIDDLE")
        label:SetShadowColor(0, 0, 0, 1)
        label:SetShadowOffset(1, -1)
        return label
    end
    local function Reflow()
        for index = 1, count do
            local card = visible[index]
            card:ClearAllPoints()
            card:SetPoint("BOTTOM", frame, "BOTTOM", 0, (index - 1) * STEP)
        end
    end
    local function Retire(card)
        card:Hide()
        card.entry, card.started, card.retryAt = nil, nil, nil
        card.icon:SetTexture(nil)
        card.icon:Hide()
        card.border:Hide()
        card.name:SetText("")
        card:SetAlpha(0)
    end
    local function Clear()
        for index = 1, LIMIT do
            Retire(pool[index])
        end
        for index = 1, count do
            visible[index] = nil
        end
        count = 0
        table.setn(visible, 0)
        animation:SetScript("OnUpdate", nil)
        frame:Hide()
    end
    local function Color(entry)
        if type(entry.color) == "string" and string.find(entry.color, "^%x%x%x%x%x%x%x%x$") then
            return tonumber(string.sub(entry.color, 3, 4), 16) / 255,
                tonumber(string.sub(entry.color, 5, 6), 16) / 255,
                tonumber(string.sub(entry.color, 7, 8), 16) / 255
        end
        if entry.quality and type(GetItemQualityColor) == "function" then
            local ok, r, g, b = pcall(GetItemQualityColor, entry.quality)
            if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then return r, g, b end
        end
        return 1, 1, 1
    end
    local function Refresh(card)
        local entry = card.entry
        local r, g, b = Color(entry)
        card.name:SetText(entry.name)
        card.name:SetTextColor(r, g, b)
        card.border:SetVertexColor(r, g, b, 1)
        local hasIcon = entry.icon and card.icon:SetTexture(entry.icon) ~= false
        if hasIcon then
            card.icon:Show()
            card.border:Show()
        else
            card.icon:Hide()
            card.border:Hide()
        end
        local left = hasIcon and 83 or 23
        card.heading:ClearAllPoints()
        card.heading:SetPoint("TOPLEFT", card, "TOPLEFT", left, -20)
        card.heading:SetWidth(WIDTH - left - 26)
        card.heading:SetText(DFRL.locale.Text("You received"))
        card.name:ClearAllPoints()
        card.name:SetPoint("TOPLEFT", card, "TOPLEFT", left, -40)
        card.name:SetWidth(WIDTH - left - 26)
    end
    for index = 1, LIMIT do
        local card = CreateFrame("Frame", nil, frame)
        card:SetWidth(WIDTH)
        card:SetHeight(HEIGHT)
        card:EnableMouse(false)
        card:Hide()
        local background = card:CreateTexture(nil, "BACKGROUND")
        if background:SetTexture(path .. "loot\\Toast.tga") == false then ready = false end
        background:SetAllPoints(card)
        background:SetTexCoord(0, 276 / 512, 0, 96 / 128)
        card.icon = card:CreateTexture(nil, "ARTWORK")
        card.icon:SetWidth(50)
        card.icon:SetHeight(50)
        card.icon:SetPoint("TOPLEFT", card, "TOPLEFT", 23, -24)
        card.border = card:CreateTexture(nil, "OVERLAY")
        if card.border:SetTexture(path .. "character\\QualityBorder.tga") == false then ready = false end
        card.border:SetWidth(58)
        card.border:SetHeight(58)
        card.border:SetPoint("CENTER", card.icon, "CENTER", 0, 0)
        card.heading = Label(card, 12)
        card.heading:SetTextColor(1, 0.82, 0)
        card.heading:SetHeight(16)
        card.name = Label(card, 14)
        card.name:SetHeight(34)
        pool[index] = card
    end

    local function Update()
        local now, changed = GetTime(), false
        for index = count, 1, -1 do
            local card = visible[index]
            local elapsed = now - card.started
            if elapsed >= LIFETIME then
                Retire(card)
                table.remove(visible, index)
                count = count - 1
                changed = true
            else
                local alpha = math.min(1, math.max(0, elapsed / FADE_IN))
                if elapsed > FADE_START then alpha = (LIFETIME - elapsed) / (LIFETIME - FADE_START) end
                card:SetAlpha(alpha)
                -- Exact item references sometimes acquire native metadata after
                -- delivery. Retry for two seconds, never by a guessed item name.
                if card.retryAt and now >= card.retryAt then
                    card.entry = loot.Resolve(card.entry)
                    card.retryAt = elapsed < 2 and not card.entry.icon and now + 0.2 or nil
                    Refresh(card)
                end
            end
        end
        if changed then
            table.setn(visible, count)
            Reflow()
        end
        if count == 0 then
            animation:SetScript("OnUpdate", nil)
            frame:Hide()
        end
    end
    local function Push(entry)
        -- Defence in depth: even a future producer cannot show collected loot.
        if entry.collection == "collected" then return true end
        if count == LIMIT then return false end
        local card
        for index = 1, LIMIT do
            if not pool[index].entry then
                card = pool[index]
                break
            end
        end
        if not card then return false end
        card.entry, card.started = entry, GetTime()
        card.retryAt = entry.itemReference and not entry.icon and card.started + 0.2 or nil
        Refresh(card)
        count = count + 1
        visible[count] = card
        table.setn(visible, count)
        Reflow()
        card:SetAlpha(0)
        card:Show()
        frame:Show()
        animation:SetScript("OnUpdate", function()
            if not pcall(Update) then
                ready = false
                Clear()
            end
        end)
        return true
    end
    layout.Register("lootNotifications", frame, function()
        -- Align the visible silver rim, above the crop's bottom padding, with
        -- the default action artwork top. Keep both groups independently movable.
        local barTop = actionDefaults.bottom + actionDefaults.height + actionDefaults.topInset
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, barTop - BORDER_BOTTOM_INSET)
    end, { labelAbove = true })
    DFRL.locale.Listen(function()
        for index = 1, count do
            if not pcall(Refresh, visible[index]) then
                ready = false
                Clear()
                return
            end
        end
    end)
    loot.SetRenderer({ IsReady = function() return ready end, Push = Push, Clear = Clear })
end)
