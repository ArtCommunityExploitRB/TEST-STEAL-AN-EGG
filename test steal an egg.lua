--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

--// НАСТРОЙКИ
local Config = {
    AimEnabled = false,
    EspEnabled = false,
    BhopEnabled = false,
    AutoShoot = true,
    Fov = 200,
    Smooth = 0.25,
    FireMode = "Tool",     -- "Tool" | "Raycast" | "Remote"
    RemotePath = "ReplicatedStorage.RemoteEvent", -- путь к RemoteEvent (если FireMode = "Remote")
    HitDamage = 100,       -- урон для Raycast-режима (если сервер слушает)
}

local IGNORE_TEAMS = { "призрак", "ghost", "spectator", "наблюдатель" }
local lastFire = 0
local FIRE_COOLDOWN = 0.08

--// ================= ПРОВЕРКИ =================
local function isIgnored(player)
    if player == LocalPlayer then return true end
    if player.Team and player.Team == LocalPlayer.Team then return true end
    if player.Team then
        local tName = player.Team.Name:lower()
        for _, n in ipairs(IGNORE_TEAMS) do
            if tName:find(n) then return true end
        end
    end
    if player:GetAttribute("IsGhost") or player:GetAttribute("Ghost") then return true end
    local char = player.Character
    if char then
        if char:GetAttribute("IsGhost") or char:GetAttribute("Ghost") then return true end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health <= 0 then return true end
    end
    return false
end

--// ================= ESP =================
local espObjects = {}

local function createESP(player)
    if isIgnored(player) then return end
    local char = player.Character
    if not char then return end
    if espObjects[player] and espObjects[player].Parent then return end

    local hl = Instance.new("Highlight")
    hl.Name = "ESP"
    hl.FillColor = Color3.fromRGB(255, 0, 0)
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.5
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = char
    hl.Parent = char
    espObjects[player] = hl
end

local function removeESP(player)
    if espObjects[player] then
        espObjects[player]:Destroy()
        espObjects[player] = nil
    end
end

local function refreshESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if Config.EspEnabled and not isIgnored(player) then
            createESP(player)
        else
            removeESP(player)
        end
    end
end

local function hookPlayer(p)
    p.CharacterAdded:Connect(function()
        task.wait(0.3)
        if Config.EspEnabled then createESP(p) end
    end)
    p.CharacterRemoving:Connect(function() removeESP(p) end)
end

for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
Players.PlayerAdded:Connect(hookPlayer)
Players.PlayerRemoving:Connect(removeESP)

--// ================= AIMBOT =================
local function getClosestTarget()
    local closest, shortest = nil, Config.Fov
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, player in ipairs(Players:GetPlayers()) do
        if isIgnored(player) then continue end
        local char = player.Character
        if not char then continue end
        local head = char:FindFirstChild("Head")
        if not head then continue end

        local origin = Camera.CFrame.Position
        local dir = (head.Position - origin)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { LocalPlayer.Character, Camera }
        local result = workspace:Raycast(origin, dir, params)
        if result and not result.Instance:IsDescendantOf(char) then continue end

        local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
        if not onScreen then continue end

        local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
        if dist < shortest then
            shortest = dist
            closest = { head = head, char = char, player = player }
        end
    end
    return closest
end

--// ================= СТРЕЛЬБА =================
local function fireViaTool()
    local char = LocalPlayer.Character
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        pcall(function() tool:Activate() end)
    end
end

local function fireViaRemote(targetInfo)
    -- Свой RemoteEvent. Ищи в своём плейсе: ReplicatedStorage.Shoot, WeaponFire и т.д.
    local path = Config.RemotePath
    if path == "" then return end
    local node = game
    for part in path:gmatch("[^%.]+") do
        node = node and node:FindFirstChild(part)
    end
    if not node or not node:IsA("RemoteEvent") then return end

    local char = LocalPlayer.Character
    if not char then return end
    local origin = char:FindFirstChild("Head") and char.Head.Position or char:GetPivot().Position
    pcall(function()
        node:FireServer(targetInfo and targetInfo.head.Position or Camera.CFrame.LookVector * 1000, origin)
    end)
end

local function fireViaRaycast(targetInfo)
    if not targetInfo then return end
    local origin = Camera.CFrame.Position
    local dir = targetInfo.head.Position - origin

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LocalPlayer.Character, Camera }
    params.IgnoreWater = true

    local result = workspace:Raycast(origin, dir, params)
    if not result then return end

    local hit = result.Instance
    local model = hit:FindFirstAncestorOfClass("Model")
    if model then
        local hum = model:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function()
                hum:TakeDamage(Config.HitDamage)
            end)
        end
    end
    -- визуальный след
    local beam = Instance.new("Part")
    beam.Anchored = true
    beam.CanCollide = false
    beam.Material = Enum.Material.Neon
    beam.Color = Color3.fromRGB(255, 200, 0)
    beam.Size = Vector3.new(0.1, 0.1, (result.Position - origin).Magnitude)
    beam.CFrame = CFrame.new(origin, result.Position) * CFrame.new(0, 0, -beam.Size.Z / 2)
    beam.Parent = workspace
    game:GetService("Debris"):AddItem(beam, 0.15)
end

local function fireWeapon(targetInfo)
    if Config.FireMode == "Raycast" then
        fireViaRaycast(targetInfo)
    elseif Config.FireMode == "Remote" then
        fireViaRemote(targetInfo)
    else
        fireViaTool()
    end
end

--// ================= ГЛАВНЫЙ ЦИКЛ AIM =================
RunService.RenderStepped:Connect(function()
    if not Config.AimEnabled then return end
    local targetInfo = getClosestTarget()
    if not targetInfo then return end

    -- Наводим камеру в голову
    local targetCF = CFrame.new(Camera.CFrame.Position, targetInfo.head.Position)
    Camera.CFrame = Camera.CFrame:Lerp(targetCF, 1 - Config.Smooth)

    -- Авто-выстрел
    if Config.AutoShoot then
        local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        local screenPos = Camera.WorldToViewportPoint(Camera, targetInfo.head.Position)
        local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
        if dist < 30 and tick() - lastFire > FIRE_COOLDOWN then
            lastFire = tick()
            fireWeapon(targetInfo)
        end
    end
end)

--// ================= BUNNY HOP =================
RunService.Heartbeat:Connect(function()
    if not Config.BhopEnabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if hum.FloorMaterial ~= Enum.Material.Air and UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        hum.Jump = true
    end
end)

--// ================= GUI =================
local gui = Instance.new("ScreenGui")
gui.Name = "CheatGUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 340, 0, 470)
main.Position = UDim2.new(0.5, -170, 0.5, -235)
main.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

local stroke = Instance.new("UIStroke", main)
stroke.Color = Color3.fromRGB(60, 60, 80)
stroke.Thickness = 1.5

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
title.BorderSizePixel = 0
title.Text = "⚔  CHEAT MENU"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.Parent = main
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 10)

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 30, 0, 30)
toggleBtn.Position = UDim2.new(1, -35, 0, 5)
toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
toggleBtn.Text = "—"
toggleBtn.TextColor3 = Color3.new(1, 1, 1)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 16
toggleBtn.BorderSizePixel = 0
toggleBtn.Parent = main
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 6)

local container = Instance.new("Frame")
container.Size = UDim2.new(1, -20, 1, -60)
container.Position = UDim2.new(0, 10, 0, 50)
container.BackgroundTransparency = 1
container.Parent = main

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = container

local function makeToggle(name, order, default, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = default and Color3.fromRGB(60, 180, 90) or Color3.fromRGB(45, 45, 55)
    btn.Text = name .. ": " .. (default and "ВКЛ" or "ВЫКЛ")
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 14
    btn.BorderSizePixel = 0
    btn.LayoutOrder = order
    btn.Parent = container
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    local state = default
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.BackgroundColor3 = state and Color3.fromRGB(60, 180, 90) or Color3.fromRGB(45, 45, 55)
        btn.Text = name .. ": " .. (state and "ВКЛ" or "ВЫКЛ")
        callback(state)
    end)
    return btn
end

local function makeSlider(name, order, min, max, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 50)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    frame.BorderSizePixel = 0
    frame.LayoutOrder = order
    frame.Parent = container
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 0, 20)
    label.Position = UDim2.new(0, 5, 0, 2)
    label.BackgroundTransparency = 1
    label.Text = name .. ": " .. tostring(default)
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local bar = Instance.new("TextButton")
    bar.Size = UDim2.new(1, -20, 0, 8)
    bar.Position = UDim2.new(0, 10, 0, 32)
    bar.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    bar.Text = ""
    bar.BorderSizePixel = 0
    bar.Parent = frame
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 4)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(80, 140, 255)
    fill.BorderSizePixel = 0
    fill.Parent = bar
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)

    local dragging = false
    local function update(input)
        local pos = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local val = math.floor(min + (max - min) * pos + 0.5)
        fill.Size = UDim2.new(pos, 0, 1, 0)
        label.Text = name .. ": " .. tostring(val)
        callback(val)
    end
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            update(input)
        end
    end)
    bar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            update(input)
        end
    end)
end

-- Кнопка выбора режима стрельбы
local function makeSelector(name, order, options, default, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = Color3.fromRGB(80, 100, 180)
    btn.Text = name .. ": " .. default
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 14
    btn.BorderSizePixel = 0
    btn.LayoutOrder = order
    btn.Parent = container
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    local idx = 1
    for i, o in ipairs(options) do if o == default then idx = i end end

    btn.MouseButton1Click:Connect(function()
        idx = idx % #options + 1
        local v = options[idx]
        btn.Text = name .. ": " .. v
        callback(v)
    end)
end

-- === Элементы GUI ===
makeToggle("Aimbot (L)", 1, Config.AimEnabled, function(v) Config.AimEnabled = v end)
makeToggle("ESP (K)", 2, Config.EspEnabled, function(v)
    Config.EspEnabled = v
    refreshESP()
end)
makeToggle("Bunny Hop (B)", 3, Config.BhopEnabled, function(v) Config.BhopEnabled = v end)
makeToggle("Auto Shoot", 4, Config.AutoShoot, function(v) Config.AutoShoot = v end)

makeSlider("FOV", 5, 50, 500, Config.Fov, function(v) Config.Fov = v end)
makeSlider("Smooth", 6, 0, 0.9, Config.Smooth, function(v) Config.Smooth = v end)

makeSelector("Fire Mode", 7, { "Tool", "Raycast", "Remote" }, Config.FireMode, function(v)
    Config.FireMode = v
    print("FireMode =", v)
end)

-- Свернуть / развернуть
local collapsed = false
toggleBtn.MouseButton1Click:Connect(function()
    collapsed = not collapsed
    if collapsed then
        container.Visible = false
        main.Size = UDim2.new(0, 340, 0, 50)
        toggleBtn.Text = "+"
    else
        container.Visible = true
        main.Size = UDim2.new(0, 340, 0, 470)
        toggleBtn.Text = "—"
    end
end)

--// Горячие клавиши
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.L then
        Config.AimEnabled = not Config.AimEnabled
    elseif input.KeyCode == Enum.KeyCode.K then
        Config.EspEnabled = not Config.EspEnabled
        refreshESP()
    elseif input.KeyCode == Enum.KeyCode.B then
        Config.BhopEnabled = not Config.BhopEnabled
    end
end)

print("[+] Загружено. Режим стрельбы: " .. Config.FireMode)
