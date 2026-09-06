--[[
    СКРИПТ ДЛЯ STEAL AN EGG — ПОЛНЫЙ СКРЫТНЫЙ GUI (без Rayfield)
    Управление:
    [RightControl] — показать/скрыть GUI
    [F9] — остановить все действия
    Все функции только по нажатию, нет автоматического запуска.
    Переменные обфусцированы, print/warn/error отключены.
]]

-- Отключаем вывод в консоль
getgenv().print = function() end
getgenv().warn = function() end
getgenv().error = function() end

-- Случайные имена для маскировки
local a1 = game:GetService("Players")
local a2 = game:GetService("UserInputService")
local a3 = game:GetService("VirtualInputManager")
local a4 = game:GetService("TweenService")
local a5 = a1.LocalPlayer
local a6 = a5.Character or a5.CharacterAdded:Wait()
local a7 = a6:WaitForChild("Humanoid")
local a8 = a6:WaitForChild("HumanoidRootPart")
local a9 = false      -- режим телепорта
local a10 = false     -- режим полёта
local a11 = false     -- занятость
local a12 = nil       -- сохранённая позиция
local a13 = nil       -- выбранное яйцо
local a14 = {}        -- список яиц

-- Создание скрытого GUI (Instance)
local a15 = Instance.new("ScreenGui")
a15.Name = "StealthGUI"
a15.ResetOnSpawn = false
a15.Enabled = false  -- скрыто до нажатия
a15.Parent = a5:WaitForChild("PlayerGui")

local a16 = Instance.new("Frame")
a16.Size = UDim2.new(0, 260, 0, 370)
a16.Position = UDim2.new(0.1, 0, 0.2, 0)
a16.BackgroundColor3 = Color3.fromRGB(20,20,20)
a16.BorderSizePixel = 0
a16.Active = true
a16.Draggable = true
a16.Parent = a15

local a17 = Instance.new("TextLabel")
a17.Size = UDim2.new(1,0,0,30)
a17.Position = UDim2.new(0,0,0,0)
a17.BackgroundColor3 = Color3.fromRGB(40,40,40)
a17.TextColor3 = Color3.fromRGB(255,255,255)
a17.Text = "Egg Helper"
a17.Font = Enum.Font.SourceSansBold
a17.TextSize = 18
a17.Parent = a16

-- Кнопка сканирования
local a18 = Instance.new("TextButton")
a18.Size = UDim2.new(1,-10,0,28)
a18.Position = UDim2.new(0,5,0,35)
a18.BackgroundColor3 = Color3.fromRGB(60,60,60)
a18.TextColor3 = Color3.fromRGB(255,255,255)
a18.Text = "Сканировать яйца"
a18.Parent = a16

-- Список яиц
local a19 = Instance.new("ScrollingFrame")
a19.Size = UDim2.new(1,-10,1,-140)
a19.Position = UDim2.new(0,5,0,68)
a19.BackgroundColor3 = Color3.fromRGB(35,35,35)
a19.BorderSizePixel = 0
a19.ScrollBarThickness = 5
a19.CanvasSize = UDim2.new(0,0,0,0)
a19.Parent = a16

local a20 = Instance.new("UIListLayout")
a20.Parent = a19
a20.SortOrder = Enum.SortOrder.LayoutOrder
a20.Padding = UDim.new(0,2)

-- Кнопка сохранения позиции
local a21 = Instance.new("TextButton")
a21.Size = UDim2.new(1,-10,0,28)
a21.Position = UDim2.new(0,5,0,265)
a21.BackgroundColor3 = Color3.fromRGB(60,60,60)
a21.TextColor3 = Color3.fromRGB(255,255,255)
a21.Text = "Сохранить позицию"
a21.Parent = a16

-- Кнопки кражи
local a22 = Instance.new("TextButton")
a22.Size = UDim2.new(1,-10,0,28)
a22.Position = UDim2.new(0,5,0,298)
a22.BackgroundColor3 = Color3.fromRGB(0,100,0)
a22.TextColor3 = Color3.fromRGB(255,255,255)
a22.Text = "Спиздить (Телепорт)"
a22.Parent = a16

local a23 = Instance.new("TextButton")
a23.Size = UDim2.new(1,-10,0,28)
a23.Position = UDim2.new(0,5,0,331)
a23.BackgroundColor3 = Color3.fromRGB(0,80,120)
a23.TextColor3 = Color3.fromRGB(255,255,255)
a23.Text = "Спиздить (Легитный полёт)"
a23.Parent = a16

-- Сканирование яиц
local function a24()
    a14 = {}
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") and not v:IsDescendantOf(a6) then
            local isEgg = false
            if v:FindFirstChildOfClass("ProximityPrompt") then
                isEgg = true
            else
                local nm = v.Name:lower()
                local pnm = v.Parent and v.Parent.Name:lower() or ""
                if nm:find("egg") or nm:find("яйцо") or pnm:find("egg") or pnm:find("яйцо") then
                    isEgg = true
                end
            end
            if isEgg then
                table.insert(a14, v)
            end
        end
    end
    -- Уникальность по позиции
    local unique, seen = {}, {}
    for _, egg in ipairs(a14) do
        local key = egg.Position.X .. "_" .. egg.Position.Y .. "_" .. egg.Position.Z
        if not seen[key] then
            seen[key] = true
            table.insert(unique, egg)
        end
    end
    a14 = unique
    table.sort(a14, function(a,b) return (a.Position - a8.Position).Magnitude < (b.Position - a8.Position).Magnitude end)

    -- Очистка списка
    for _, child in ipairs(a19:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    -- Создание кнопок
    for i, egg in ipairs(a14) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1,-10,0,24)
        btn.Position = UDim2.new(0,5,0,(i-1)*26)
        btn.BackgroundColor3 = Color3.fromRGB(50,50,50)
        btn.TextColor3 = Color3.fromRGB(255,255,255)
        btn.Text = string.format("Яйцо %d (%.0fм)", i, (egg.Position - a8.Position).Magnitude)
        btn.Parent = a19
        btn.LayoutOrder = i
        btn.MouseButton1Click:Connect(function()
            a13 = egg
            for _, b in ipairs(a19:GetChildren()) do
                if b:IsA("TextButton") then
                    b.BackgroundColor3 = b == btn and Color3.fromRGB(0,120,215) or Color3.fromRGB(50,50,50)
                end
            end
        end)
    end
    a19.CanvasSize = UDim2.new(0,0,0,#a14*26)
end

-- Обработчики кнопок
a18.MouseButton1Click:Connect(a24)
a21.MouseButton1Click:Connect(function()
    a12 = a8.Position
    a21.Text = "Позиция сохранена!"
    task.wait(1)
    a21.Text = "Сохранить позицию"
end)

-- Функция активации (ждёт 3-4 сек)
local function a25(egg)
    task.wait(math.random(3,4))
    local prompt = egg:FindFirstChildOfClass("ProximityPrompt")
    if prompt then
        if fireproximityprompt then
            fireproximityprompt(prompt)
        else
            a3:SendKeyEvent(true, Enum.KeyCode.E, false, nil)
            task.wait(0.1)
            a3:SendKeyEvent(false, Enum.KeyCode.E, false, nil)
        end
    end
    task.wait(0.5)
end

-- Телепорт
local function a26(pos)
    a8.CFrame = CFrame.new(pos + Vector3.new(0,2,0))
end

-- Легитный полёт
local function a27(pos)
    local target = pos + Vector3.new(0,2,0)
    local dist = (target - a8.Position).Magnitude
    local speed = a7.WalkSpeed or 16
    local tween = a4:Create(a8, TweenInfo.new(dist/speed, Enum.EasingStyle.Linear), {CFrame = CFrame.new(target)})
    tween:Play()
    tween.Completed:Wait()
end

-- Основная функция кражи
local function a28()
    if a11 or not a13 or not a12 then return end
    a11 = true
    task.spawn(function()
        if a9 then
            a26(a13.Position)
        elseif a10 then
            a27(a13.Position)
        end
        task.wait(0.3)
        a25(a13)
        if a9 then
            a26(a12)
        elseif a10 then
            a27(a12)
        end
        a11 = false
    end)
end

-- Обработчики кнопок кражи
a22.MouseButton1Click:Connect(function()
    a9 = true; a10 = false
    a28()
end)
a23.MouseButton1Click:Connect(function()
    a10 = true; a9 = false
    a28()
end)

-- Открытие/скрытие GUI по RightControl
a2.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.RightControl then
        a15.Enabled = not a15.Enabled
    elseif input.KeyCode == Enum.KeyCode.F9 then
        a9 = false
        a10 = false
        a11 = false
        a15.Enabled = false
    end
end)

-- Никаких действий при старте, всё по требованию
