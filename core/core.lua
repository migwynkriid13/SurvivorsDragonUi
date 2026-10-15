-- AzerothSurvivors styling is fixed; frame geometry and SCT mode are saved.
DFRL = CreateFrame("Frame", nil, UIParent)
DFRL.env = {}
DFRL.tools = {}
DFRL.modules = {}

setmetatable(DFRL.env, { __index = getfenv(0) })

function DFRL:GetEnv()
    self.env._G = getfenv(0)
    self.env.T = self.tools
    return self.env
end

function DFRL:GetInfoOrCons(kind)
    local path = "Interface\\AddOns\\SurvivorsDragonUi\\"
    if kind == "tex" then return path .. "media\\tex\\" end
    return path
end

function DFRL:NewMod(name, priority, initialize)
    table.insert(self.modules, { name = name, priority = priority, initialize = initialize })
end

local booted = false
local function Initialize()
    if booted then return end
    booted = true
    table.sort(DFRL.modules, function(a, b)
        if a.priority == b.priority then return a.name < b.name end
        return a.priority < b.priority
    end)
    for _, module in ipairs(DFRL.modules) do
        setfenv(module.initialize, DFRL:GetEnv())
        local success, message = pcall(module.initialize)
        if not success then geterrorhandler()(module.name .. ": " .. tostring(message)) end
    end
    DFRL.modules = nil
    DFRL:UnregisterAllEvents()
end

-- The port may load loose addons after stock FrameXML has already initialized.
DFRL:RegisterEvent("ADDON_LOADED")
DFRL:RegisterEvent("PLAYER_LOGIN")
DFRL:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" or (event == "ADDON_LOADED" and arg1 == "SurvivorsDragonUi") then Initialize() end
end)
