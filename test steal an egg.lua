--[[
    Steal An Egg - Rayfield GUI with two steal methods
    Методы:
    1. Телепорт: мгновенно к яйцу, ждёт 3-4 сек, жмёт E, мгновенно обратно.
    2. Легитный полёт: летит к яйцу с обычной скоростью (Tween), ждёт 3-4 сек, жмёт E, летит обратно.
    GUI открывается по RightControl.
]]

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
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

-- Функция сканирования яиц
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
    -- Удаление дубликатов (по позиции)
    local unique = {}
    local seen = {}
    for _, egg in ipairs(eggList) do
        local key = egg.Position.X .. "_" .. egg.Position.Y .. "_" .. egg.Position.Z
        if not seen[key] then
            seen[key] = true
            table.insert(unique, egg)
        end
    end
    eggList = unique
    -- Сортировка по дистанции
    table.sort(eggList, function(a, b)
        return (a.Position - rootPart.Position).Magnitude < (b.Position - rootPart.Position).Magnitude
    end)
end

-- Создание GUI
local Window = Rayfield:CreateWindow({
    Name = "Egg Stealer",
    LoadingTitle = "Загрузка...",
    LoadingSubtitle = "by Assistant",
    ConfigurationSaving = { Enabled = false },
    Discord = { Enabled = false },
    KeySystem = false,
})

local Tab = Window:CreateTab("Main", 4483362458)

-- Кнопка сканирования
local ScanButton = Tab:CreateButton({
    Name = "Сканировать яйца",
    Callback = function()
        scanEggs()
        local options = {}
        for i, egg in ipairs(eggList) do
            table.insert(options, string.format("Яйцо %d (%.0fм)", i, (egg.Position - rootPart.Position).Magnitude))
        end
        EggDropdown:Refresh(options, true)
        Rayfield:Notify({
            Title = "Сканирование",
            Content = "Найдено яиц: " .. #eggList,
            Duration = 2,
            Image = 4483362458,
        })
    end,
})

-- Дропдаун для выбора яйца
local EggDropdown = Tab:CreateDropdown({
    Name = "Выберите яйцо",
    Options = {},
    CurrentOption = "",
    Flag = "SelectedEgg",
    Callback = function(Value)
        local num = Value:match("#(%d+)")
        if num then
            selectedEgg = eggList[tonumber(num)]
        end
    end,
})

-- Кнопка сохранения позиции
local SavePosButton = Tab:CreateButton({
    Name = "Сохранить позицию",
    Callback = function()
        savedPosition = rootPart.Position
        Rayfield:Notify({
            Title = "Позиция",
            Content = "Точка доставки сохранена!",
            Duration = 2,
            Image = 4483362458,
        })
    end,
})

-- Функция активации яйца (ждёт 3-4 сек и жмёт E)
local function activateEgg(egg)
    task.wait(math.random(3, 4)) -- ожидание
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
    task.wait(0.5) -- небольшая пауза после активации
end

-- Телепорт к точке
local function teleportTo(pos)
    rootPart.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0)) -- чуть приподнимаем
end

-- Легитный полёт к точке (Tween с WalkSpeed)
local function flyTo(pos)
    local targetPos = pos + Vector3.new(0, 2, 0)
    local distance = (targetPos - rootPart.Position).Magnitude
    local speed = humanoid.WalkSpeed or 16
    local duration = distance / speed
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(rootPart, tweenInfo, {CFrame = CFrame.new(targetPos)})
    tween:Play()
    tween.Completed:Wait()
end

-- Кнопка "Спиздить (Телепорт)"
local StealTeleportButton = Tab:CreateButton({
    Name = "Спиздить (Телепорт)",
    Callback = function()
        if isWorking then return end
        if not selectedEgg or not savedPosition then
            Rayfield:Notify({
                Title = "Ошибка",
                Content = "Выберите яйцо и сохраните позицию!",
                Duration = 2,
                Image = 4483362458,
            })
            return
        end
        isWorking = true
        task.spawn(function()
            -- Телепорт к яйцу
            teleportTo(selectedEgg.Position)
            task.wait(0.3)
            -- Активация
            activateEgg(selectedEgg)
            -- Телепорт обратно
            teleportTo(savedPosition)
            isWorking = false
            Rayfield:Notify({
                Title = "Готово",
                Content = "Яйцо украдено и доставлено!",
                Duration = 2,
                Image = 4483362458,
            })
        end)
    end,
})

-- Кнопка "Спиздить (Легитный полёт)"
local StealFlyButton = Tab:CreateButton({
    Name = "Спиздить (Легитный полёт)",
    Callback = function()
        if isWorking then return end
        if not selectedEgg or not savedPosition then
            Rayfield:Notify({
                Title = "Ошибка",
                Content = "Выберите яйцо и сохраните позицию!",
                Duration = 2,
                Image = 4483362458,
            })
            return
        end
        isWorking = true
        task.spawn(function()
            -- Летим к яйцу
            flyTo(selectedEgg.Position)
            task.wait(0.3)
            -- Активация
            activateEgg(selectedEgg)
            -- Летим обратно
            flyTo(savedPosition)
            isWorking = false
            Rayfield:Notify({
                Title = "Готово",
                Content = "Яйцо украдено и доставлено!",
                Duration = 2,
                Image = 4483362458,
            })
        end)
    end,
})

-- Скрытие GUI по RightControl
local guiVisible = true
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.RightControl and not gameProcessed then
        guiVisible = not guiVisible
        Window:SetVisible(guiVisible)
    end
end)

-- Первоначальное сканирование
scanEggs()
local initialOptions = {}
for i, egg in ipairs(eggList) do
    table.insert(initialOptions, string.format("Яйцо %d (%.0fм)", i, (egg.Position - rootPart.Position).Magnitude))
end
EggDropdown:Refresh(initialOptions, true)

-- Уведомление
Rayfield:Notify({
    Title = "Скрипт запущен",
    Content = "Нажмите RightControl для скрытия/показа GUI",
    Duration = 5,
    Image = 4483362458,
})
