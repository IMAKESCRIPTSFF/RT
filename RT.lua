
--// Auto Control GUI

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Network = ReplicatedStorage:WaitForChild("Network")

-- Settings
local HATCH_INTERVAL = 0.2
local TELEPORT_INTERVAL = 3
local TAP_INTERVAL = 0.01
local RUNE_INTERVAL = 0.01
local ACKNOWLEDGE_INTERVAL = 0.5
local BOSS_DELAY = 30

local HATCH_POSITION = Vector3.new(-252, 5, 494)

local BOSS_NAMES = {
    "Autumn Forest",
    "Ancient Oasis",
    "Aurora Glacier",
    "Arcane Jungle",
    "Inferno Spire"
}

-- State
local running = true
local tapEnabled = false
local runesEnabled = false
local hatchEnabled = false
local bossesEnabled = false
local minimized = false
local hatchCount = 7
local selectedBosses = {}

for _, name in ipairs(BOSS_NAMES) do
    selectedBosses[name] = false
end

-- Safe remote invocation
local function safeInvoke(remote, ...)
    local args = table.pack(...)

    local success, result = pcall(function()
        return remote:InvokeServer(table.unpack(args, 1, args.n))
    end)

    if not success then
        warn("[Auto Control] Remote error:", result)
    end

    return success, result
end

local function teleportCharacter()
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")

    if root then
        root.CFrame = CFrame.new(HATCH_POSITION)
    end
end

-- Remove old GUI
local oldGui = playerGui:FindFirstChild("AutoControlGUI")
if oldGui then
    oldGui:Destroy()
end

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "AutoControlGUI"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(285, 440)
main.Position = UDim2.new(0, 30, 0.3, 0)
main.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
main.BorderSizePixel = 0
main.Active = true
main.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 9)
mainCorner.Parent = main

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(75, 75, 95)
mainStroke.Parent = main

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 35)
topBar.BackgroundColor3 = Color3.fromRGB(38, 38, 49)
topBar.BorderSizePixel = 0
topBar.Active = true
topBar.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -75, 1, 0)
title.Position = UDim2.fromOffset(10, 0)
title.BackgroundTransparency = 1
title.Text = "Auto Control"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = topBar

local function makeButton(parent, text, size, position, color)
    local button = Instance.new("TextButton")
    button.Size = size
    button.Position = position
    button.BackgroundColor3 = color or Color3.fromRGB(55, 55, 70)
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = Color3.new(1, 1, 1)
    button.TextSize = 12
    button.Font = Enum.Font.GothamBold
    button.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = button

    return button
end

local minimizeButton = makeButton(
    topBar, "-", UDim2.fromOffset(25, 25),
    UDim2.new(1, -62, 0, 5)
)

local closeButton = makeButton(
    topBar, "X", UDim2.fromOffset(25, 25),
    UDim2.new(1, -32, 0, 5),
    Color3.fromRGB(150, 45, 50)
)

local content = Instance.new("ScrollingFrame")
content.Name = "Content"
content.Position = UDim2.fromOffset(8, 42)
content.Size = UDim2.new(1, -16, 1, -50)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 4
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.CanvasSize = UDim2.new()
content.Parent = main

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = content

local function makeSection(text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -2, 0, 22)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(160, 190, 255)
    label.TextSize = 12
    label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = content
end

local function makeToggle(text, callback)
    local enabled = false

    local button = makeButton(
        content, text .. ": OFF",
        UDim2.new(1, -2, 0, 30),
        UDim2.new(), Color3.fromRGB(55, 55, 70)
    )

    button.MouseButton1Click:Connect(function()
        if not running then
            return
        end

        enabled = not enabled
        button.Text = text .. (enabled and ": ON" or ": OFF")
        button.BackgroundColor3 = enabled
            and Color3.fromRGB(45, 125, 85)
            or Color3.fromRGB(55, 55, 70)

        local ok, err = pcall(callback, enabled)
        if not ok then
            warn("[Auto Control] Toggle error:", err)
        end
    end)

    return button
end

-- Auto Acknowledge Boss Exit
task.spawn(function()
    local remote = Network:WaitForChild("AcknowledgeBossExit")

    while running do
        safeInvoke(remote)
        task.wait(ACKNOWLEDGE_INTERVAL)
    end
end)

-- Auto Tap
makeSection("GENERAL")

makeToggle("Auto Tap", function(enabled)
    tapEnabled = enabled

    if enabled then
        task.spawn(function()
            while running and tapEnabled do
                safeInvoke(Network:WaitForChild("Tap"))
                task.wait(TAP_INTERVAL)
            end
        end)
    end
end)

-- Equip Best Runes
makeToggle("Equip Best Runes", function(enabled)
    runesEnabled = enabled

    if enabled then
        task.spawn(function()
            while running and runesEnabled do
                safeInvoke(Network:WaitForChild("EquipBestRunes"))
                task.wait(RUNE_INTERVAL)
            end
        end)
    end
end)

-- Auto Hatch
makeSection("AUTO HATCH")

local countLabel = Instance.new("TextLabel")
countLabel.Size = UDim2.new(1, -2, 0, 22)
countLabel.BackgroundTransparency = 1
countLabel.Text = "Eggs per request (1-100):"
countLabel.TextColor3 = Color3.fromRGB(230, 230, 235)
countLabel.TextSize = 12
countLabel.Font = Enum.Font.Gotham
countLabel.TextXAlignment = Enum.TextXAlignment.Left
countLabel.Parent = content

local countBox = Instance.new("TextBox")
countBox.Size = UDim2.new(1, -2, 0, 30)
countBox.BackgroundColor3 = Color3.fromRGB(42, 42, 53)
countBox.BorderSizePixel = 0
countBox.Text = "7"
countBox.PlaceholderText = "Egg count"
countBox.TextColor3 = Color3.new(1, 1, 1)
countBox.TextSize = 13
countBox.Font = Enum.Font.Gotham
countBox.ClearTextOnFocus = false
countBox.Parent = content

local countCorner = Instance.new("UICorner")
countCorner.CornerRadius = UDim.new(0, 5)
countCorner.Parent = countBox

countBox.FocusLost:Connect(function()
    local number = tonumber(countBox.Text)

    if number then
        hatchCount = math.clamp(math.floor(number), 1, 100)
    end

    countBox.Text = tostring(hatchCount)
end)

makeToggle("Auto Hatch Fall Event Egg", function(enabled)
    hatchEnabled = enabled

    if enabled then
        task.spawn(function()
            while running and hatchEnabled do
                safeInvoke(
                    Network:WaitForChild("OpenEgg"),
                    "Fall Event Egg",
                    hatchCount
                )
                task.wait(HATCH_INTERVAL)
            end
        end)

        task.spawn(function()
            while running and hatchEnabled do
                teleportCharacter()
                task.wait(TELEPORT_INTERVAL)
            end
        end)
    end
end)

-- Auto Bosses
makeSection("AUTO BOSSES")

for _, bossName in ipairs(BOSS_NAMES) do
    local button = makeButton(
        content, bossName .. ": OFF",
        UDim2.new(1, -2, 0, 27),
        UDim2.new(), Color3.fromRGB(55, 55, 70)
    )

    button.MouseButton1Click:Connect(function()
        if not running then
            return
        end

        selectedBosses[bossName] = not selectedBosses[bossName]
        local selected = selectedBosses[bossName]

        button.Text = bossName .. (selected and ": ON" or ": OFF")
        button.BackgroundColor3 = selected
            and Color3.fromRGB(65, 100, 150)
            or Color3.fromRGB(55, 55, 70)
    end)
end

makeToggle("Auto Bosses", function(enabled)
    bossesEnabled = enabled

    if enabled then
        task.spawn(function()
            while running and bossesEnabled do
                local found = false

                for _, bossName in ipairs(BOSS_NAMES) do
                    if not running or not bossesEnabled then
                        break
                    end

                    if selectedBosses[bossName] then
                        found = true

                        local ok, err = pcall(function()
                            local bossPart = workspace
                                :WaitForChild("Map")
                                :WaitForChild(bossName)
                                :WaitForChild("Boss")
                                :WaitForChild("Walls")
                                :WaitForChild("Part")

                            safeInvoke(
                                Network:WaitForChild("RequestStartBossFight"),
                                bossPart
                            )

                            -- This delay does not confirm a defeat.
                            task.wait(BOSS_DELAY)
                        end)

                        if not ok then
                            warn("[Auto Control] Boss error:", bossName, err)
                        end

                        task.wait(1)
                    end
                end

                if not found then
                    task.wait(0.5)
                end
            end
        end)
    end
end)

-- Minimize / restore
minimizeButton.MouseButton1Click:Connect(function()
    minimized = not minimized
    content.Visible = not minimized
    main.Size = minimized
        and UDim2.fromOffset(285, 35)
        or UDim2.fromOffset(285, 440)

    minimizeButton.Text = minimized and "+" or "-"
end)

-- Unload
closeButton.MouseButton1Click:Connect(function()
    running = false
    tapEnabled = false
    runesEnabled = false
    hatchEnabled = false
    bossesEnabled = false
    gui:Destroy()
end)

-- Dragging
local dragging = false
local dragStart
local startPosition

topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = true
        dragStart = input.Position
        startPosition = main.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (
        input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
    ) then
        local delta = input.Position - dragStart

        main.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end)

print("[Auto Control] GUI loaded successfully.")
