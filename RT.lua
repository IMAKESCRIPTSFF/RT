--// GAME ID RESTRICTION
if game.PlaceId ~= 115161798722315 then
    warn("[Auto Control] Wrong game ID. Script stopped.")
    return
end

--// SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
while not player do
    task.wait(0.25)
    player = Players.LocalPlayer
end

local playerGui = player:WaitForChild("PlayerGui", 15)
if not playerGui then
    warn("Player Gui not available.")
    return
end

local VirtualInputManager
pcall(function()
    VirtualInputManager = game:GetService("VirtualInputManager")
end)

--// SETTINGS
local HATCH_INTERVAL = 0.2
local TELEPORT_INTERVAL = 3
local CHEST_INTERVAL = 0.1
local TAP_INTERVAL = 0.01
local RUNE_INTERVAL = 0.01
local ACKNOWLEDGE_INTERVAL = 5
local BOSS_DELAY = 3
local MERCHANT_INTERVAL = 1

local HATCH_POSITION = Vector3.new(-173, 104, -372)

local BOSS_NAMES = {
    "Autumn Forest",
    "Ancient Oasis",
    "Aurora Glacier",
    "Arcane Jungle",
    "Inferno Spire"
}

--// STATE
local running = true
local tapEnabled = true
local runesEnabled = true
local hatchEnabled = false
local chestEnabled = false
local bossesEnabled = false
local merchantEnabled = true
local autoBreakEnabled = false
local breakableDetectionConnection = nil
local breakableRemovalConnection = nil
local minimized = false
local selectedBosses = {}

for _, bossName in ipairs(BOSS_NAMES) do
    selectedBosses[bossName] = false
end

--// REMOVE OLD GUI
for _, guiName in ipairs({"AutoControlGUI", "GUI"}) do
    local oldGui = playerGui:FindFirstChild(guiName)
    if oldGui then
        oldGui:Destroy()
    end
end

--// MAIN GUI
local gui = Instance.new("ScreenGui")
gui.Name = "GUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
gui.Parent = playerGui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(285, 350)
main.Position = UDim2.new(0, 30, 0.3, 0)
main.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
main.BorderSizePixel = 0
main.Active = true
main.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 9)
corner.Parent = main

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(75, 75, 95)
stroke.Parent = main

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

--// BUTTON CREATOR
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

    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 5)
    buttonCorner.Parent = button

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

--// SCROLLING CONTENT
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
    return label
end

--// TOGGLE CREATOR
local function makeToggle(text, callback, startEnabled)
    local enabled = startEnabled == true

    local button = makeButton(
        content,
        text .. (enabled and ": ON" or ": OFF"),
        UDim2.new(1, -2, 0, 30),
        UDim2.new(),
        enabled and Color3.fromRGB(45, 125, 85)
            or Color3.fromRGB(55, 55, 70)
    )

    button.MouseButton1Click:Connect(function()
        if not running then return end

        enabled = not enabled

        button.Text = text .. (enabled and ": ON" or ": OFF")
        button.BackgroundColor3 = enabled
            and Color3.fromRGB(45, 125, 85)
            or Color3.fromRGB(55, 55, 70)

        local ok, err = pcall(callback, enabled)
        if not ok then
            warn("GUI Toggle error:", err)
        end
    end)

    if enabled then
        task.defer(function()
            if running then
                local ok, err = pcall(callback, true)
                if not ok then
                    warn("GUI Startup error:", err)
                end
            end
        end)
    end

    return button
end

--// REMOTE HELPERS
local function getRemote(name)
    local network = ReplicatedStorage:FindFirstChild("Network")
    return network and network:FindFirstChild(name)
end

local function safeInvoke(remote, ...)
    if not remote or not remote:IsA("RemoteFunction") then
        return false
    end

    local args = table.pack(...)

    local success, result = pcall(function()
        return remote:InvokeServer(table.unpack(args, 1, args.n))
    end)

    if not success then
        warn("GUI Remote error:", result)
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

--// AUTO BREAK — LIGHTWEIGHT TRACKING
local damageBreakableRemote = ReplicatedStorage
    :WaitForChild("Network")
    :WaitForChild("DamageBreakable")

-- 0.05 seconds = 20 requests/sec while active. Avoids the heavy 0.01s spam loop.
local BREAK_HIT_INTERVAL = 0.05
local ID_KEYS = {"ID", "Id", "id", "BreakableId"}
local HEALTH_KEYS = {"Health", "HP", "CurrentHealth", "CurrentHP"}

local breakableIdQueue = {}
local queuedIds = {}
local queueIndex = 1
local objectBreakableIds = {}
local breakableObjectsById = {}

local function getNumericValue(obj, key)
    local ok, value = pcall(function()
        local attr = obj:GetAttribute(key)
        if typeof(attr) == "number" then
            return attr
        end

        local child = obj:FindFirstChild(key)
        if child and child:IsA("ValueBase") and typeof(child.Value) == "number" then
            return child.Value
        end
        return nil
    end)
    if ok then return value end
    return nil
end

local function getBreakableId(obj)
    for _, key in ipairs(ID_KEYS) do
        local id = getNumericValue(obj, key)
        if id ~= nil then return id end
    end
    return nil
end

local function getHealth(obj)
    for _, key in ipairs(HEALTH_KEYS) do
        local health = getNumericValue(obj, key)
        if health ~= nil then return health end
    end
    return nil
end

local function trackBreakableObject(obj, id)
    if objectBreakableIds[obj] == id then return end

    local oldId = objectBreakableIds[obj]
    if oldId ~= nil and breakableObjectsById[oldId] then
        breakableObjectsById[oldId][obj] = nil
    end

    objectBreakableIds[obj] = id
    breakableObjectsById[id] = breakableObjectsById[id] or {}
    breakableObjectsById[id][obj] = true

    -- Queue an ID again if it respawns after its previous turn.
    if not queuedIds[id] then
        queuedIds[id] = true
        table.insert(breakableIdQueue, id)
    end
end

local function tryTrack(obj)
    if not obj or obj == Workspace then return end

    -- Check this instance and a few ancestors. IDs are often stored on a Model
    -- while DescendantAdded fires for one of its children.
    local current = obj
    for _ = 1, 4 do
        if not current or current == Workspace then break end
        local id = getBreakableId(current)
        if id ~= nil then
            trackBreakableObject(current, id)
            return
        end
        current = current.Parent
    end
end

local function unregisterBreakableObject(obj)
    local id = objectBreakableIds[obj]
    if id ~= nil then
        objectBreakableIds[obj] = nil
        local objects = breakableObjectsById[id]
        if objects then objects[obj] = nil end
    end
end

-- One batched initial scan. Yield periodically so joining the game does not freeze.
task.spawn(function()
    local descendants = Workspace:GetDescendants()
    for i, obj in ipairs(descendants) do
        if not running then return end
        tryTrack(obj)
        if i % 300 == 0 then task.wait() end
    end
end)

breakableDetectionConnection = Workspace.DescendantAdded:Connect(function(obj)
    tryTrack(obj)
end)
breakableRemovalConnection = Workspace.DescendantRemoving:Connect(function(obj)
    unregisterBreakableObject(obj)
end)

-- Sequentially hit one ID until its tracked object is removed or its explicit
-- health value reaches zero. No per-object tasks and no console spam.
task.spawn(function()
    while running do
        if not autoBreakEnabled or queueIndex > #breakableIdQueue then
            task.wait(0.1)
        else
            local id = breakableIdQueue[queueIndex]
            local objects = breakableObjectsById[id]
            local hasLiveObject = false
            local confirmedDestroyed = false

            if objects then
                for obj in pairs(objects) do
                    if obj and obj:IsDescendantOf(Workspace) then
                        local health = getHealth(obj)
                        if health ~= nil and health <= 0 then
                            confirmedDestroyed = true
                        else
                            hasLiveObject = true
                        end
                    else
                        objects[obj] = nil
                        objectBreakableIds[obj] = nil
                    end
                end
            end

            if not hasLiveObject or confirmedDestroyed then
                queuedIds[id] = nil
                queueIndex += 1

                -- Compact occasionally to keep the queue small in long sessions.
                if queueIndex > 100 and queueIndex > (#breakableIdQueue / 2) then
                    local compact = {}
                    for i = queueIndex, #breakableIdQueue do
                        table.insert(compact, breakableIdQueue[i])
                    end
                    breakableIdQueue = compact
                    queueIndex = 1
                end
                task.wait(0.03)
            else
                local ok, err = pcall(function()
                    damageBreakableRemote:FireServer(id)
                end)
                if not ok then
                    warn("[Auto Break] Remote call failed:", err)
                    task.wait(0.25)
                else
                    task.wait(BREAK_HIT_INTERVAL)
                end
            end
        end
    end
end)

--// AUTO ACKNOWLEDGE BOSS EXIT
task.spawn(function()
    while running do
        safeInvoke(getRemote("AcknowledgeBossExit"))
        task.wait(ACKNOWLEDGE_INTERVAL)
    end
end)

--// GENERAL
makeSection("GENERAL")

makeToggle("Auto Tap", function(enabled)
    tapEnabled = enabled
    if not enabled then return end

    task.spawn(function()
        while running and tapEnabled do
            safeInvoke(getRemote("Tap"))
            task.wait(TAP_INTERVAL)
        end
    end)
end, true)

makeToggle("Equip Best Runes", function(enabled)
    runesEnabled = enabled
    if not enabled then return end

    task.spawn(function()
        while running and runesEnabled do
            safeInvoke(getRemote("EquipBestRunes"))
            task.wait(RUNE_INTERVAL)
        end
    end)
end, true)

--// AUTO BREAK — ENABLED ON STARTUP
makeToggle("Auto Break", function(enabled)
    autoBreakEnabled = enabled
end, true)

--// AUTO HATCH
makeSection("AUTO HATCH")

makeToggle("Auto Hatch (T Key)", function(enabled)
    hatchEnabled = enabled
    if not enabled then return end

    if not VirtualInputManager then
        warn("GUI VirtualInputManager unavailable; Auto Hatch key input may not work.")
    end

    task.spawn(function()
        while running and hatchEnabled do
            if VirtualInputManager then
                local ok, err = pcall(function()
                    VirtualInputManager:SendKeyEvent(
                        true, Enum.KeyCode.T, false, game
                    )
                    task.wait(0.05)
                    VirtualInputManager:SendKeyEvent(
                        false, Enum.KeyCode.T, false, game
                    )
                end)

                if not ok then
                    warn("GUI T key simulation failed:", err)
                end
            end

            task.wait(HATCH_INTERVAL)
        end
    end)

    task.spawn(function()
        while running and hatchEnabled do
            teleportCharacter()
            task.wait(TELEPORT_INTERVAL)
        end
    end)
end)

--// AUTO OPEN KEYS
makeSection("AUTO OPEN KEYS")

makeToggle("Auto Open Keys", function(enabled)
    chestEnabled = enabled
    if not enabled then return end

    task.spawn(function()
        while running and chestEnabled do
            safeInvoke(
                getRemote("Open Universal Chest"),
                "Ancient Oasis Chest",
                1
            )

            task.wait(CHEST_INTERVAL)
        end
    end)
end)

--// AUTO MERCHANT — ENABLED ON STARTUP
makeSection("AUTO MERCHANT")

makeToggle("Auto Buy Merchant", function(enabled)
    merchantEnabled = enabled
    if not enabled then return end

    task.spawn(function()
        while running and merchantEnabled do
            for merchantId = 1, 3 do
                if not running or not merchantEnabled then
                    break
                end

                safeInvoke(getRemote("BuyMerchantItem"), merchantId)
                task.wait(MERCHANT_INTERVAL)
            end
        end
    end)
end, true)

--// BOSS SELECTION
makeSection("AUTO BOSSES")

for _, bossName in ipairs(BOSS_NAMES) do
    local button = makeButton(
        content,
        bossName .. ": OFF",
        UDim2.new(1, -2, 0, 27),
        UDim2.new(),
        Color3.fromRGB(55, 55, 70)
    )

    button.MouseButton1Click:Connect(function()
        if not running then return end

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
    if not enabled then return end

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
                        local map = workspace:FindFirstChild("Map")
                        local area = map and map:FindFirstChild(bossName)
                        local boss = area and area:FindFirstChild("Boss")
                        local walls = boss and boss:FindFirstChild("Walls")
                        local bossPart = walls and walls:FindFirstChild("Part")

                        if not bossPart then
                            warn("GUI Boss part not found:", bossName)
                            return
                        end

                        safeInvoke(
                            getRemote("RequestStartBossFight"),
                            bossPart
                        )

                        task.wait(BOSS_DELAY)
                    end)

                    if not ok then
                        warn("GUI Boss error:", bossName, err)
                    end

                    task.wait(1)
                end
            end

            if not found then
                task.wait(0.5)
            end
        end
    end)
end)

--// MINIMIZE
minimizeButton.MouseButton1Click:Connect(function()
    minimized = not minimized
    content.Visible = not minimized

    main.Size = minimized
        and UDim2.fromOffset(285, 35)
        or UDim2.fromOffset(285, 350)

    minimizeButton.Text = minimized and "+" or "-"
end)

--// UNLOAD
closeButton.MouseButton1Click:Connect(function()
    running = false
    tapEnabled = false
    runesEnabled = false
    hatchEnabled = false
    chestEnabled = false
    bossesEnabled = false
    merchantEnabled = false
    autoBreakEnabled = false

    if breakableDetectionConnection then
        breakableDetectionConnection:Disconnect()
        breakableDetectionConnection = nil
    end
    if breakableRemovalConnection then
        breakableRemovalConnection:Disconnect()
        breakableRemovalConnection = nil
    end

    gui:Destroy()
end)

--// DRAGGING
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
