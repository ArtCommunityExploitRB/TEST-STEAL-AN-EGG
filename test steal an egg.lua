-- Отключаем вывод в консоль
getgenv().print = function() end
getgenv().warn = function() end
getgenv().error = function() end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")

-- Переменные
local savedPosition = nil
local eggList = {}
local selectedEgg = nil
local isWorking = false
local guiVisible = false

-- Создание скрытого GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HiddenGUI"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false  -- скрыто при старте
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 260, 0, 360)
mainFrame.Position = UDim2.new(0.1, 0, 0.2, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

-- Заголовок
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Text = "Stealth Egg"
title.Font = Enum.Font.SourceSansBold
title.TextSize = 18
title.Parent = mainFrame

-- Кнопка сканирования
local scanBtn = Instance.new("TextButton")
scanBtn.Size = UDim2.new(1, -10, 0, 28)
scanBtn.Position = UDim2.new(0, 5, 0, 35)
scanBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
scanBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
scanBtn.Text = "Сканировать яйца"
scanBtn.Parent = mainFrame

-- Список яиц (ScrollingFrame)
local listFrame = Instance.new("ScrollingFrame")
listFrame.Size = UDim2.new(1, -10, 1, -140)
listFrame.Position = UDim2.new(0, 5, 0, 68)
listFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
listFrame.BorderSizePixel = 0
listFrame.ScrollBarThickness = 5
listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
listFrame.Parent = mainFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Parent = listFrame
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 2)

-- Кнопка сохранения позиции
local saveBtn = Instance.new("TextButton")
saveBtn.Size = UDim2.new(1, -10, 0, 28)
saveBtn.Position = UDim2.new(0, 5, 0, 260)
saveBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
saveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
saveBtn.Text = "Сохранить позицию"
saveBtn.Parent = mainFrame

-- Кнопки кражи
local teleportBtn = Instance.new("TextButton")
teleportBtn.Size = UDim2.new(1, -10, 0, 28)
teleportBtn.Position = UDim2.new(0, 5, 0, 293)
teleportBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 0)
teleportBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
teleportBtn.Text = "Спиздить (Телепорт)"
teleportBtn.Parent = mainFrame

local flyBtn = Instance.new("TextButton")
flyBtn.Size = UDim2.new(1, -10, 0, 28)
flyBtn.Position = UDim2.new(0, 5, 0, 326)
flyBtn.BackgroundColor3 = Color3.fromRGB(0, 80, 120)
flyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
flyBtn.Text = "Спиздить (Легитный полёт)"
flyBtn.Parent = mainFrame

-- Функция сканирования
local function scanEggs()
    eggList = {}
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") and not v:IsDescendantOf(character) then
            local isEgg = false
            if v:FindFirstChildOfClass("ProximityPrompt") then
                isEgg = true
            else
                local name = v.Name:lower()
                local parentName = v.Parent and v.Parent.Name:lower() or ""
                if name:find("egg") or name:find("яйцо") or parentName:find("egg") or parentName:find("яйцо") then
                    isEgg = true
                end
            end
            if isEgg then
                table.insert(eggList, v)
            end
        end
    end
    -- Удаление дубликатов
    local unique, seen = {}, {}
    for _, egg in ipairs(eggList) do
        local key = egg.Position.X .. "_" .. egg.Position.Y .. "_" .. egg.Position.Z
        if not seen[key] then
            seen[key] = true
            table.insert(unique, egg)
        end
    end
    eggList = unique
    table.sort(eggList, function(a,b)
        return (a.Position - rootPart.Position).Magnitude < (b.Position - rootPart.Position).Magnitude
    end)
    -- Обновление списка
    for _, child in ipairs(listFrame:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    for i, egg in ipairs(eggList) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -10, 0, 24)
        btn.Position = UDim2.new(0, 5, 0, (i-1)*26)
        btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Text = string.format("Яйцо %d (%.0fм)", i, (egg.Position - rootPart.Position).Magnitude)
        btn.Parent = listFrame
        btn.LayoutOrder = i
        btn.MouseButton1Click:Connect(function()
            selectedEgg = egg
            -- Подсветка выбранного
            for _, b in ipairs(listFrame:GetChildren()) do
                if b:IsA("TextButton") then
                    b.BackgroundColor3 = b == btn and Color3.fromRGB(0, 120, 215) or Color3.fromRGB(50, 50, 50)
                end
            end
        end)
    end
    listFrame.CanvasSize = UDim2.new(0, 0, 0, #eggList * 26)
end

-- Привязка событий
scanBtn.MouseButton1Click:Connect(scanEggs)

saveBtn.MouseButton1Click:Connect(function()
    savedPosition = rootPart.Position
    saveBtn.Text = "Позиция сохранена!"
    task.wait(1)
    saveBtn.Text = "Сохранить позицию"
end)

-- Функция активации
local function activateEgg(egg)
    task.wait(math.random(3, 4))
    local prompt = egg:FindFirstChildOfClass("ProximityPrompt")
    if prompt then
        if fireproximityprompt then
            fireproximityprompt(prompt)
        else
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, nil)
            task.wait(0.1)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, nil)
        end
    end
    task.wait(0.5)
end

-- Телепорт
local function teleportTo(pos)
    rootPart.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0))
end

-- Легитный полёт
local function flyTo(pos)
    local target = pos + Vector3.new(0, 2, 0)
    local dist = (target - rootPart.Position).Magnitude
    local speed = humanoid.WalkSpeed or 16
    local tween = TweenService:Create(rootPart, TweenInfo.new(dist/speed, Enum.EasingStyle.Linear), {CFrame = CFrame.new(target)})
    tween:Play()
    tween.Completed:Wait()
end

-- Обработчики кнопок кражи
teleportBtn.MouseButton1Click:Connect(function()
    if isWorking or not selectedEgg or not savedPosition then return end
    isWorking = true
    task.spawn(function()
        teleportTo(selectedEgg.Position)
        task.wait(0.3)
        activateEgg(selectedEgg)
        teleportTo(savedPosition)
        isWorking = false
    end)
end)

flyBtn.MouseButton1Click:Connect(function()
    if isWorking or not selectedEgg or not savedPosition then return end
    isWorking = true
    task.spawn(function()
        flyTo(selectedEgg.Position)
        task.wait(0.3)
        activateEgg(selectedEgg)
        flyTo(savedPosition)
        isWorking = false
    end)
end)

-- Открытие/скрытие GUI по RightControl
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.RightControl and not gameProcessed then
        guiVisible = not guiVisible
        screenGui.Enabled = guiVisible
    end
end)

-- Никаких действий при старте, всё по требованию
