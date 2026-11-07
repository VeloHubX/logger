-- ============================================
-- AA Trade-Only Spy — Delta Compatible
-- ============================================

local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- keywords to watch for
local KEYWORDS = {
    "trade", "offer", "accept", "confirm",
    "request", "swap", "exchange", "unit", "inventory"
}

local function isTradeRelated(name)
    local lower = string.lower(tostring(name))
    for _, kw in ipairs(KEYWORDS) do
        if string.find(lower, kw) then
            return true
        end
    end
    return false
end

local function dumpValue(v, indent, seen)
    indent = indent or 0
    seen   = seen or {}
    local pad = string.rep("  ", indent)
    if type(v) == "table" then
        if seen[v] then return "[circular]" end
        seen[v] = true
        local out = "{\n"
        for k, v2 in pairs(v) do
            out = out .. pad .. "  [" .. tostring(k) .. "] = " .. dumpValue(v2, indent+1, seen) .. ",\n"
        end
        return out .. pad .. "}"
    elseif typeof(v) == "Instance" then
        local ok, r = pcall(function() return v:GetFullName() end)
        return ok and "Instance<"..r..">" or "Instance<unknown>"
    else
        return tostring(v)
    end
end

local function logTrade(method, name, path, args)
    print("══════════════════════════════════════")
    print("[TRADE::" .. method .. "]")
    print("  Name : " .. tostring(name))
    print("  Path : " .. tostring(path))
    for i, arg in ipairs(args or {}) do
        print("  Arg["..i.."] <"..typeof(arg).."> = "..dumpValue(arg))
    end
    print("══════════════════════════════════════")
end

-- namecall hook
local mt = getrawmetatable(game)
local oldNC = mt.__namecall
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args   = {...}

    if method == "FireServer" or method == "InvokeServer" then
        local name, path = "?", "?"
        pcall(function() name = self.Name end)
        pcall(function() path = self:GetFullName() end)

        if isTradeRelated(name) then
            logTrade(method, name, path, args)
        end
    end

    return oldNC(self, table.unpack(args))
end)

setreadonly(mt, true)

-- OnClientEvent hooks
local hooked = {}

local function hookClient(obj)
    if hooked[obj] then return end
    hooked[obj] = true
    if obj:IsA("RemoteEvent") then
        obj.OnClientEvent:Connect(function(...)
            local name, path = "?", "?"
            pcall(function() name = obj.Name end)
            pcall(function() path = obj:GetFullName() end)
            if isTradeRelated(name) then
                logTrade("OnClientEvent", name, path, {...})
            end
        end)
    end
end

task.spawn(function()
    task.wait(1)
    local services = { "ReplicatedStorage", "ReplicatedFirst", "Workspace", "StarterGui" }
    for _, sName in ipairs(services) do
        local ok, svc = pcall(function() return game:GetService(sName) end)
        if ok and svc then
            for _, obj in ipairs(svc:GetDescendants()) do hookClient(obj) end
            svc.DescendantAdded:Connect(function(obj)
                task.wait(0.05)
                hookClient(obj)
            end)
        end
    end
end)

RunService.Heartbeat:Connect(function()
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") and not hooked[obj] then
            hookClient(obj)
        end
    end
end)

print("[TRADE SPY] Armed — only trade remotes will print.")
print("[TRADE SPY] Go open a trade now.")
