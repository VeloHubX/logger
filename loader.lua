-- ============================================
-- AA Passive Remote Dumper — Delta Compatible
-- Execute once = instant full remote dump
-- + stays live for fired events
-- ============================================

local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ============================================
-- DUMP UTILITY
-- ============================================
local function dumpValue(v, indent, seen)
    indent = indent or 0
    seen   = seen or {}
    local pad = string.rep("  ", indent)
    if type(v) == "table" then
        if seen[v] then return "[circular ref]" end
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

-- ============================================
-- STEP 1 — INSTANT PASSIVE DUMP
-- Prints every remote it finds the moment you execute
-- ============================================
local function dumpAllRemotes()
    print("╔══════════════════════════════════════╗")
    print("║      PASSIVE REMOTE DUMP — START     ║")
    print("╚══════════════════════════════════════╝")

    local services = {
        "ReplicatedStorage",
        "ReplicatedFirst",
        "Workspace",
        "StarterGui",
        "StarterPlayer",
    }

    local count = 0

    for _, sName in ipairs(services) do
        local ok, svc = pcall(function() return game:GetService(sName) end)
        if ok and svc then
            for _, obj in ipairs(svc:GetDescendants()) do
                if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                    count = count + 1
                    local path = "unknown"
                    pcall(function() path = obj:GetFullName() end)
                    print(string.format("[DUMP][%s] %-20s → %s",
                        obj.ClassName, obj.Name, path))
                end
            end
        end
    end

    print("──────────────────────────────────────")
    print("[DUMP] Total remotes found: " .. count)
    print("──────────────────────────────────────")
end

-- run immediately on execute
dumpAllRemotes()

-- ============================================
-- STEP 2 — LIVE FIRE LOGGER
-- Stays running, logs anything that fires
-- ============================================
local function logFire(eventType, name, path, args)
    print("══════════════════════════════════════")
    print("[LIVE::" .. eventType .. "]")
    print("  Name : " .. tostring(name))
    print("  Path : " .. tostring(path))
    for i, arg in ipairs(args or {}) do
        print("  Arg["..i.."] <"..typeof(arg).."> = "..dumpValue(arg))
    end
    print("══════════════════════════════════════")
end

-- namecall hook for FireServer / InvokeServer
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
        logFire(method, name, path, args)
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
            logFire("OnClientEvent", name, path, {...})
        end)
    end
end

-- hook everything already in game
task.spawn(function()
    task.wait(1)
    local services = {
        "ReplicatedStorage","ReplicatedFirst",
        "Workspace","StarterGui","StarterPlayer"
    }
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

-- heartbeat catches anything spawned late
RunService.Heartbeat:Connect(function()
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") and not hooked[obj] then
            hookClient(obj)
        end
    end
end)

print("[SPY] Live logger armed. Waiting for fires...")
