--// ============ SERVICES ============
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Debris            = game:GetService("Debris")
local Camera            = workspace.CurrentCamera
local LocalPlayer       = Players.LocalPlayer

--// ============ CONFIG ============
local Config = {
    -- Aim
    AimEnabled      = false,
    AimAlways       = false,
    AimKey          = Enum.KeyCode.E,
    AimFov          = 180,
    AimSmooth       = 0.35,
    AimPart         = "Head",
    AimPrediction   = 0.12,
    AimVisCheck     = true,
    AimTeamCheck    = true,
    ShowFovCircle   = true,

    -- Auto shoot
    AutoShoot       = true,
    FireCooldown    = 0.08,
    FireMode        = "Tool",
    RemotePath      = "",
    HitDamage       = 100,

    -- ESP
    EspEnabled      = false,
    EspTeamCheck    = true,
    EspName         = true,
    EspHealth       = true,
    EspDistance     = true,
    EspTracer       = true,
    EspHighlight    = true,
    EspBox          = true,

    -- Misc
    BhopEnabled     = false,
}

local IGNORE_TEAMS = { "призрак", "ghost", "spectator", "наблюдатель" }
local lastFire = 0

--// ============ HELPERS ============
local function isIgnoredTeam(tName)
    tName = tName:lower()
    for _, n in ipairs(IGNORE_TEAMS) do
        if tName:find(n) then return true end
    end
    return false
end

local function isEnemy(player, teamCheck)
    if player == LocalPlayer then return false end
    if player.Team and isIgnoredTeam(player.Team.Name) then return false end
    if teamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
        return false
    end
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    if char:GetAttribute("IsGhost") or char:GetAttribute("Ghost") then return false end
    return true
end

local function hasLineOfSight(char, targetPos)
    local origin = Camera.CFrame.Position
    local dir = targetPos - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LocalPlayer.Character, Camera }
    params.IgnoreWater = true
    local result = workspace:Raycast(origin, dir, params)
    if not result then return true end
    return result.Instance:IsDescendantOf(char)
end

--// ============ GUI ============
local gui = Instance.new("ScreenGui")
gui.Name = "CheatGUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- === FOV circle (отдельный слой поверх всего) ===
local fovCircle = Instance.new("Frame")
fovCircle.Name = "FovCircle"
fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
fovCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
fovCircle.BackgroundTransparency = 1
fovCircle.Visible = false
fovCircle.ZIndex = 100
fovCircle.Parent = gui
local fovStroke = Instance.new("UIStroke", fovCircle)
fovStroke.Thickness = 2
fovStroke.Color = Color3.fromRGB(255, 255, 255)
fovStroke.Transparency = 0.15
Instance.new("UICorner", fovCircle).CornerRadius = UDim.new(1, 0)

local function updateFovCircle()
    local r = Config.AimFov
    fovCircle.Size = UDim2.new(0, r * 2, 0, r * 2)
end
updateFovCircle()

-- === ESP-слой (для трассеров и боксов) ===
local espLayer = Instance.new("Frame")
espLayer.Name = "EspLayer"
espLayer.Size = UDim2.new(1, 0, 1, 0)
espLayer.BackgroundTransparency = 1
espLayer.ZIndex = 2
espLayer.Parent = gui

-- === Main panel ===
local main = Instance.new("Frame")
main.Size = UDim2.new(0, 340, 0, 560)
main.Position = UDim2.new(0, 30, 0, 100)
main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.ZIndex = 10
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)

local stroke = Instance.new("UIStroke", main)
stroke.Color = Color3.fromRGB(60, 60, 75)
stroke.Thickness = 1.5

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 42)
title.BackgroundColor3 = Color3.fromRGB(26, 26, 34)
title.BorderSizePixel = 0
title.Text = "⚔  MENU   [N - hide]"
title.TextColor3 = Color3.fromRGB(235, 235, 245)
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.ZIndex = 11
title.Parent = main
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 12)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 26, 0, 26)
closeBtn.Position = UDim2.new(1, -32, 0, 8)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
closeBtn.Text = "×"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.BorderSizePixel = 0
closeBtn.ZIndex = 12
closeBtn.Parent = main
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
closeBtn.MouseButton1Click:Connect(function() main.Visible = false end)

local container = Instance.new("Frame")
container.Size = UDim2.new(1, -20, 1, -60)
container.Position = UDim2.new(0, 10, 0, 52)
container.BackgroundTransparency = 1
container.ZIndex = 11
container.Parent = main
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = container
local pad = Instance.new("UIPadding", container)
pad.PaddingBottom = UDim.new(0, 10)

local function section(text, order)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 22)
    lbl.BackgroundTransparency = 1
    lbl.Text = "— " .. text .. " —"
    lbl.TextColor3 = Color3.fromRGB(150, 150, 170)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12
    lbl.LayoutOrder = order
    lbl.ZIndex = 11
    lbl.Parent = container
end

local function makeToggle(name, order, default, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.BackgroundColor3 = default and Color3.fromRGB(55, 160, 90) or Color3.fromRGB(38, 38, 48)
    btn.Text = name .. ": " .. (default and "ON" or "OFF")
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 13
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.LayoutOrder = order
    btn.ZIndex = 11
    btn.Parent = container
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    local state = default
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.BackgroundColor3 = state and Color3.fromRGB(55, 160, 90) or Color3.fromRGB(38, 38, 48)
        btn.Text = name .. ": " .. (state and "ON" or "OFF")
        callback(state)
    end)
    return btn
end

local function makeSlider(name, order, min, max, default, isFloat, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 46)
    frame.BackgroundColor3 = Color3.fromRGB(26, 26, 34)
    frame.BorderSizePixel = 0
    frame.LayoutOrder = order
    frame.ZIndex = 11
    frame.Parent = container
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -12, 0, 18)
    label.Position = UDim2.new(0, 8, 0, 3)
    label.BackgroundTransparency = 1
    label.Text = name .. ": " .. tostring(default)
    label.TextColor3 = Color3.fromRGB(220, 220, 230)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 12
    label.Parent = frame

    local bar = Instance.new("TextButton")
    bar.Size = UDim2.new(1, -20, 0, 8)
    bar.Position = UDim2.new(0, 10, 0, 28)
    bar.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
    bar.Text = ""
    bar.BorderSizePixel = 0
    bar.AutoButtonColor = false
    bar.ZIndex = 12
    bar.Parent = frame
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 4)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(90, 150, 255)
    fill.BorderSizePixel = 0
    fill.ZIndex = 13
    fill.Parent = bar
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)

    local dragging = false
    local function update(input)
        local pos = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local val = min + (max - min) * pos
        if isFloat then val = math.floor(val * 100 + 0.5) / 100
        else val = math.floor(val + 0.5) end
        fill.Size = UDim2.new(pos, 0, 1, 0)
        label.Text = name .. ": " .. tostring(val)
        callback(val)
    end
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; update(input) end
    end)
    bar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then update(input) end
    end)
end

local function makeSelector(name, order, options, default, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.BackgroundColor3 = Color3.fromRGB(60, 80, 160)
    btn.Text = name .. ": " .. default
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 13
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.LayoutOrder = order
    btn.ZIndex = 11
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

section("AIM", 1)
makeToggle("Aimbot (E / hold)", 2, Config.AimEnabled, function(v) Config.AimEnabled = v end)
makeToggle("Always Aim", 3, Config.AimAlways, function(v) Config.AimAlways = v end)
makeToggle("Team Check", 4, Config.AimTeamCheck, function(v) Config.AimTeamCheck = v end)
makeToggle("Visibility Check", 5, Config.AimVisCheck, function(v) Config.AimVisCheck = v end)
makeToggle("Show FOV Circle", 6, Config.ShowFovCircle, function(v) Config.ShowFovCircle = v end)
makeToggle("Auto Shoot", 7, Config.AutoShoot, function(v) Config.AutoShoot = v end)
makeSlider("FOV", 8, 30, 600, Config.AimFov, false, function(v) Config.AimFov = v; updateFovCircle() end)
makeSlider("Smooth", 9, 0, 0.9, Config.AimSmooth, true, function(v) Config.AimSmooth = v end)
makeSlider("Prediction", 10, 0, 0.3, Config.AimPrediction, true, function(v) Config.AimPrediction = v end)
makeSelector("Fire Mode", 11, {"Tool", "Raycast", "Remote"}, Config.FireMode, function(v) Config.FireMode = v end)
makeSelector("Aim Part", 12, {"Head", "HumanoidRootPart", "UpperTorso"}, Config.AimPart, function(v) Config.AimPart = v end)

section("ESP", 20)
makeToggle("ESP", 21, Config.EspEnabled, function(v)
    Config.EspEnabled = v
    refreshESP()
end)
makeToggle("ESP Team Check", 22, Config.EspTeamCheck, function(v)
    Config.EspTeamCheck = v; refreshESP()
end)
makeToggle("ESP Highlight", 23, Config.EspHighlight, function(v) Config.EspHighlight = v end)
makeToggle("ESP Box", 24, Config.EspBox, function(v) Config.EspBox = v end)
makeToggle("ESP Name", 25, Config.EspName, function(v) Config.EspName = v end)
makeToggle("ESP Health", 26, Config.EspHealth, function(v) Config.EspHealth = v end)
makeToggle("ESP Distance", 27, Config.EspDistance, function(v) Config.EspDistance = v end)
makeToggle("ESP Tracer", 28, Config.EspTracer, function(v) Config.EspTracer = v end)

section("MISC", 40)
makeToggle("Bunny Hop", 41, Config.BhopEnabled, function(v) Config.BhopEnabled = v end)

--// ============ ESP (полностью переделан) ============
local espData = {}

local function removeESP(player)
    local data = espData[player]
    if not data then return end
    if data.conn then data.conn:Disconnect() end
    if data.hl then data.hl:Destroy() end
    if data.boxHandle then data.boxHandle:Destroy() end
    if data.billboard then data.billboard:Destroy() end
    if data.box then data.box:Destroy() end
    if data.boxStroke then data.boxStroke:Destroy() end
    if data.tracer then data.tracer:Destroy() end
    espData[player] = nil
end

local function createESP(player)
    if not isEnemy(player, Config.EspTeamCheck) then return end
    local char = player.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    if not head or not hrp then return end

    removeESP(player)
    local data = { player = player, char = char }

    -- Highlight (сквозь стены)
    if Config.EspHighlight then
        local hl = Instance.new("Highlight")
        hl.FillColor = Color3.fromRGB(255, 60, 60)
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = 0.55
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Adornee = char
        hl.Parent = char
        data.hl = hl
    end

    -- 3D BoxHandleAdornment (видно сквозь стены)
    if Config.EspBox then
        local boxHandle = Instance.new("BoxHandleAdornment")
        boxHandle.Name = "ESPBox"
        boxHandle.Adornee = hrp
        boxHandle.AlwaysOnTop = true
        boxHandle.Size = Vector3.new(2.2, 5.2, 2.2)
        boxHandle.Transparency = 0.5
        boxHandle.Color3 = Color3.fromRGB(255, 60, 60)
        boxHandle.ZIndex = 5
        boxHandle.Parent = hrp
        data.boxHandle = boxHandle
    end

    -- BillboardGui с ником / HP / дистанцией
    local bb = Instance.new("BillboardGui")
    bb.Name = "ESPInfo"
    bb.Size = UDim2.new(0, 200, 0, 60)
    bb.StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0)
    bb.AlwaysOnTop = true
    bb.Adornee = head
    bb.Parent = char
    data.billboard = bb

    local nameLbl = Instance.new("TextLabel")
    nameLbl.BackgroundTransparency = 1
    nameLbl.Size = UDim2.new(1, 0, 0, 16)
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 14
    nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLbl.TextStrokeTransparency = 0
    nameLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLbl.Text = player.Name
    nameLbl.Parent = bb
    data.nameLbl = nameLbl

    local distLbl = Instance.new("TextLabel")
    distLbl.BackgroundTransparency = 1
    distLbl.Size = UDim2.new(1, 0, 0, 14)
    distLbl.Position = UDim2.new(0, 0, 0, 16)
    distLbl.Font = Enum.Font.Gotham
    distLbl.TextSize = 12
    distLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    distLbl.TextStrokeTransparency = 0
    distLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    distLbl.Text = "0"
    distLbl.Parent = bb
    data.distLbl = distLbl

    local hpBg = Instance.new("Frame")
    hpBg.Size = UDim2.new(0, 100, 0, 5)
    hpBg.Position = UDim2.new(0.5, -50, 0, 32)
    hpBg.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    hpBg.BorderSizePixel = 0
    hpBg.Parent = bb
    Instance.new("UICorner", hpBg).CornerRadius = UDim.new(1, 0)

    local hpFill = Instance.new("Frame")
    hpFill.Size = UDim2.new(1, 0, 1, 0)
    hpFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    hpFill.BorderSizePixel = 0
    hpFill.Parent = hpBg
    Instance.new("UICorner", hpFill).CornerRadius = UDim.new(1, 0)

    data.hpBg = hpBg
    data.hpFill = hpFill

    -- 2D-бокс вокруг игрока (на экране)
    local box = Instance.new("Frame")
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 0
    box.ZIndex = 3
    box.Visible = false
    box.Parent = espLayer
    local boxStroke = Instance.new("UIStroke", box)
    boxStroke.Thickness = 1.5
    boxStroke.Color = Color3.fromRGB(255, 60, 60)
    boxStroke.Transparency = 0.1
    data.box = box
    data.boxStroke = boxStroke

    -- Tracer
    local tracer = Instance.new("Frame")
    tracer.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    tracer.BorderSizePixel = 0
    tracer.Visible = false
    tracer.ZIndex = 3
    tracer.Parent = espLayer
    data.tracer = tracer

    -- Обновление каждый кадр
    data.conn = RunService.RenderStepped:Connect(function()
        if not char.Parent then removeESP(player) return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then removeESP(player) return end

        local pivot = char:GetPivot().Position
        local dist = (Camera.CFrame.Position - pivot).Magnitude

        -- Highlight toggle
        if data.hl then data.hl.Enabled = Config.EspHighlight end

        -- BoxHandle toggle
        if data.boxHandle then
            data.boxHandle.Visible = Config.EspBox
            data.boxHandle.Transparency = 0.5
        end

        -- Name
        data.nameLbl.Visible = Config.EspName
        data.nameLbl.Text = player.Name

        -- Distance
        data.distLbl.Visible = Config.EspDistance
        data.distLbl.Text = string.format("[%d studs]", math.floor(dist))

        -- HP bar
        data.hpBg.Visible = Config.EspHealth
        local hp = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
        data.hpFill.Size = UDim2.new(hp, 0, 1, 0)
        data.hpFill.BackgroundColor3 = Color3.fromRGB(255 * (1 - hp), 255 * hp, 40)

        -- 2D бокс: считаем bounding box через 8 углов
        if Config.EspBox then
            local cf, size = char:GetBoundingBox()
            local corners = {}
            for xi = -1, 1, 2 do
                for yi = -1, 1, 2 do
                    for zi = -1, 1, 2 do
                        local world = cf * Vector3.new(size.X/2 * xi, size.Y/2 * yi, size.Z/2 * zi)
                        local sp, onScreen = Camera:WorldToViewportPoint(world)
                        if onScreen and sp.Z > 0 then
                            table.insert(corners, Vector2.new(sp.X, sp.Y))
                        end
                    end
                end
            end
            if #corners >= 2 then
                local minX, minY = math.huge, math.huge
                local maxX, maxY = -math.huge, -math.huge
                for _, c in ipairs(corners) do
                    minX = math.min(minX, c.X); maxX = math.max(maxX, c.X)
                    minY = math.min(minY, c.Y); maxY = math.max(maxY, c.Y)
                end
                data.box.Visible = true
                data.box.Position = UDim2.new(0, minX, 0, minY)
                data.box.Size = UDim2.new(0, maxX - minX, 0, maxY - minY)
                data.boxStroke.Color = Color3.fromRGB(255, 60, 60)
            else
                data.box.Visible = false
            end
        else
            data.box.Visible = false
        end

        -- Tracer
        if Config.EspTracer then
            local sp, onScreen = Camera:WorldToViewportPoint(pivot)
            if onScreen and sp.Z > 0 then
                local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                local from = center
                local to = Vector2.new(sp.X, sp.Y)
                local diff = to - from
                local len = diff.Magnitude
                if len > 1 then
                    local mid = (from + to) / 2
                    local ang = math.deg(math.atan2(diff.Y, diff.X))
                    data.tracer.Visible = true
                    data.tracer.Size = UDim2.new(0, len, 0, 1)
                    data.tracer.Position = UDim2.new(0, mid.X, 0, mid.Y)
                    data.tracer.AnchorPoint = Vector2.new(0.5, 0.5)
                    data.tracer.Rotation = ang
                else
                    data.tracer.Visible = false
                end
            else
                data.tracer.Visible = false
            end
        else
            data.tracer.Visible = false
        end
    end)

    espData[player] = data
end

function refreshESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if Config.EspEnabled and isEnemy(player, Config.EspTeamCheck) then
            if not espData[player] then createESP(player) end
        else
            removeESP(player)
        end
    end
end

-- Постоянный скан игроков (чтобы ничего не пропустить)
task.spawn(function()
    while task.wait(0.35) do
        if Config.EspEnabled then refreshESP() end
    end
end)

local function hookPlayer(p)
    p.CharacterAdded:Connect(function()
        task.wait(0.4)
        if Config.EspEnabled then createESP(p) end
    end)
    p.CharacterRemoving:Connect(function() removeESP(p) end)
    p:GetPropertyChangedSignal("Team"):Connect(function()
        if Config.EspEnabled then
            if isEnemy(p, Config.EspTeamCheck) then createESP(p) else removeESP(p) end
        end
    end)
end
for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
Players.PlayerAdded:Connect(hookPlayer)
Players.PlayerRemoving:Connect(removeESP)

--// ============ AIMBOT ============
local function getClosestTarget()
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local best, bestDist = nil, Config.AimFov

    for _, player in ipairs(Players:GetPlayers()) do
        if isEnemy(player, Config.AimTeamCheck) then
            local char = player.Character
            if char then
                local part = char:FindFirstChild(Config.AimPart) or char:FindFirstChild("Head")
                if part then
                    local pos = part.Position
                    if Config.AimPrediction > 0 then
                        local ok, vel = pcall(function() return part.AssemblyLinearVelocity end)
                        if ok and vel then pos = pos + vel * Config.AimPrediction end
                    end
                    local sp, onScreen = Camera:WorldToViewportPoint(pos)
                    if onScreen and sp.Z > 0 then
                        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                        if d < bestDist then
                            if not Config.AimVisCheck or hasLineOfSight(char, part.Position) then
                                bestDist = d
                                best = { part = part, char = char, player = player, aimPos = pos }
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

--// ============ FIRE ============
local function fireViaTool()
    local char = LocalPlayer.Character
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then pcall(function() tool:Activate() end) end
end

local function resolvePath(path)
    local node = game
    for part in path:gmatch("[^%.]+") do node = node and node:FindFirstChild(part) end
    return node
end

local function fireViaRemote(targetInfo)
    if Config.RemotePath == "" then return end
    local node = resolvePath(Config.RemotePath)
    if not node or not node:IsA("RemoteEvent") then return end
    local char = LocalPlayer.Character
    if not char then return end
    local origin = char:FindFirstChild("Head") and char.Head.Position or char:GetPivot().Position
    local hitPos = targetInfo and targetInfo.aimPos or (Camera.CFrame.Position + Camera.CFrame.LookVector * 1000)
    pcall(function() node:FireServer(hitPos, origin) end)
end

local function fireViaRaycast(targetInfo)
    if not targetInfo then return end
    local origin = Camera.CFrame.Position
    local dir = targetInfo.part.Position - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LocalPlayer.Character, Camera }
    params.IgnoreWater = true
    local result = workspace:Raycast(origin, dir, params)
    if not result then return end
    local model = result.Instance:FindFirstAncestorOfClass("Model")
    if model then
        local hum = model:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum:TakeDamage(Config.HitDamage) end) end
    end
    local beam = Instance.new("Part")
    beam.Anchored = true
    beam.CanCollide = false
    beam.Material = Enum.Material.Neon
    beam.Color = Color3.fromRGB(255, 200, 0)
    beam.Size = Vector3.new(0.08, 0.08, (result.Position - origin).Magnitude)
    beam.CFrame = CFrame.new(origin, result.Position) * CFrame.new(0, 0, -beam.Size.Z / 2)
    beam.Parent = workspace
    Debris:AddItem(beam, 0.15)
end

local function fireWeapon(targetInfo)
    if Config.FireMode == "Raycast" then fireViaRaycast(targetInfo)
    elseif Config.FireMode == "Remote" then fireViaRemote(targetInfo)
    else fireViaTool() end
end

--// ============ AIM LOOP ============
RunService.RenderStepped:Connect(function()
    fovCircle.Visible = Config.AimEnabled and Config.ShowFovCircle

    if not Config.AimEnabled then return end
    local keyHeld = UserInputService:IsKeyDown(Config.AimKey)
    if not keyHeld and not Config.AimAlways then return end

    local target = getClosestTarget()
    if not target then return end

    local camPos = Camera.CFrame.Position
    local aimCF = CFrame.new(camPos, target.aimPos)
    Camera.CFrame = Camera.CFrame:Lerp(aimCF, math.clamp(1 - Config.AimSmooth, 0.01, 1))

    if Config.AutoShoot then
        local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        local sp = Camera:WorldToViewportPoint(target.aimPos)
        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
        if d < 20 and tick() - lastFire > Config.FireCooldown then
            lastFire = tick()
            fireWeapon(target)
        end
    end
end)

--// ============ BHOP ============
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

--// ============ KEYBINDS ============
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.N then
        main.Visible = not main.Visible
    end
end)

print("[+] Loaded. Mode: " .. Config.FireMode)
