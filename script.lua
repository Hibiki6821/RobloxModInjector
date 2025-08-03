--[[
    Script: MOD INJECTOR (Fluent Edition)
    Description: A feature-rich script for Roblox using the Fluent GUI library.
    Author: Gemini
    Version: 3.6
    Date: 2025-08-04
]]

--// SERVICES //--
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

--// PLAYER & CAMERA //--
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local mouse = player:GetMouse()

--// FLUENT LIBRARY //--
-- Fluentライブラリを読み込みます。これはExecutorに直接配置するか、URLから読み込む必要があります。
local function loadLibrary(url, name)
    local success, result = pcall(function()
        return loadstring(game:HttpGet(url, true))()
    end)
    if not success or not result then
        warn(string.format("Failed to load library '%s'. Error: %s", name, tostring(result)))
        game.StarterGui:SetCore("SendNotification", {
            Title = "Library Error",
            Text = string.format("Failed to load '%s'. The script may not work correctly.", name),
            Duration = 10
        })
        return nil
    end
    return result
end

-- ユーザー提供の動作するURLに更新
local Fluent = loadLibrary("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua", "Fluent")
-- Fluent本体の読み込みに失敗した場合、スクリプトを停止
if not Fluent then return end

local SaveManager = loadLibrary("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua", "SaveManager")
local InterfaceManager = loadLibrary("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua", "InterfaceManager")

--// CONFIGURATION & STATE //--
-- UIの状態はFluent.Optionsで管理します。
-- このstateテーブルは、UIに直接関連しない内部的な状態のみを保持します。
local state = {
    selectedTeleportPlayerName = nil,
    isSpectating = false,
    isRunning = false,
    waterPart = nil,
    -- CutGrass States
    cutGrass_AntiTeleportConnections = {},
    cutGrass_AutoCollectCoroutine = nil,
    cutGrass_AutoGrassDeleteCoroutine = nil,
    cutGrass_ESPHighlights = {},
    cutGrass_ChestESPConnections = {},
    cutGrass_PlayerESPConnections = {},
    cutGrass_ChestESPUpdateCoroutine = nil,
    cutGrass_PlayerESPUpdateCoroutine = nil,
    cutGrass_HitboxLoop = nil,
    cutGrass_OriginalGrassTransparencies = {},
    cutGrass_GrassAddedConnections = {}
}

--// FUNCTIONS //--

------------------------------------------------
-- Feature Implementations
------------------------------------------------
local Options = Fluent.Options

local function createESP(character)
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root or root:FindFirstChild("ESP_GUI") then return end
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_GUI"
    billboard.Parent = root
    billboard.Size = UDim2.new(0, 150, 0, 60)
    billboard.AlwaysOnTop = true
    billboard.StudsOffset = Vector3.new(0, -3.5, 0)
    billboard.LightInfluence = 0

    local frame = Instance.new("Frame", billboard)
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Fluent.Colors.Background
    frame.BackgroundTransparency = 0.3
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local border = Instance.new("UIStroke", frame)
    border.Color = Fluent.Colors.Accent
    border.Thickness = 1.5

    local textLabel = Instance.new("TextLabel", frame)
    textLabel.Size = UDim2.new(1, -10, 1, -10)
    textLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
    textLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    textLabel.BackgroundTransparency = 1
    textLabel.TextColor3 = Fluent.Colors.Text
    textLabel.Font = Fluent.Fonts.Primary
    textLabel.Text = character.Name
    textLabel.TextScaled = true
    textLabel.TextStrokeTransparency = 0.5
end

local function updateESP(enabled)
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player then
            p.CharacterAdded:Connect(function(character)
                if Options.PlayerESP.Value then
                    task.wait(0.1)
                    createESP(character)
                end
            end)
            if p.Character then
                if enabled then
                    createESP(p.Character)
                else
                    local espGui = p.Character:FindFirstChild("HumanoidRootPart") and p.Character.HumanoidRootPart:FindFirstChild("ESP_GUI")
                    if espGui then espGui:Destroy() end
                end
            end
        end
    end
end

local function getSelectedPlayer()
    if not state.selectedTeleportPlayerName then return nil end
    return Players:FindFirstChild(state.selectedTeleportPlayerName)
end

local function teleportToPlayer(targetPlayer)
    if not targetPlayer or not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
    
    local targetHRP = targetPlayer.Character.HumanoidRootPart
    local playerHRP = player.Character.HumanoidRootPart
    
    local offset = Options.TeleportPositionToggle.Value and -3 or 3
    
    local lookAtPos = targetHRP.Position
    local newPos = targetHRP.CFrame * CFrame.new(0, 0, offset).Position
    playerHRP.CFrame = CFrame.new(newPos, lookAtPos)
end

local function bringPlayer(targetPlayer)
    if not targetPlayer or not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
    
    local targetHRP = targetPlayer.Character.HumanoidRootPart
    local playerHRP = player.Character.HumanoidRootPart
    targetHRP.CFrame = playerHRP.CFrame * CFrame.new(0, 0, -3)
end

local function spectatePlayer(targetPlayer, shouldSpectate)
    if shouldSpectate then
        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChildOfClass("Humanoid") then
            state.isSpectating = true
            camera.CameraSubject = targetPlayer.Character.Humanoid
        end
    else
        state.isSpectating = false
        if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
            camera.CameraSubject = player.Character.Humanoid
        end
    end
end

local function setCharacterSize(scale)
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    local scales = {"BodyDepthScale", "BodyHeightScale", "BodyWidthScale", "HeadScale"}
    for _, scaleName in ipairs(scales) do
        local scaleValue = humanoid:FindFirstChild(scaleName)
        if scaleValue then
            scaleValue.Value = scale
        end
    end
end

local function handleWalkOnWater()
    local char = player.Character
    if not (Options.WalkOnWater and Options.WalkOnWater.Value) or not char or not char:FindFirstChild("HumanoidRootPart") then
        if state.waterPart then state.waterPart:Destroy(); state.waterPart = nil; end
        return
    end

    local hrp = char.HumanoidRootPart
    local rayOrigin = hrp.Position
    local rayDirection = Vector3.new(0, -10, 0)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {char}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    
    local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

    if result and result.Material == Enum.Material.Water then
        if not state.waterPart then
            state.waterPart = Instance.new("Part")
            state.waterPart.Name = "WaterWalkPart"
            state.waterPart.Size = Vector3.new(15, 1, 15)
            state.waterPart.Anchored = true
            state.waterPart.CanCollide = true
            state.waterPart.Transparency = 1
            state.waterPart.Parent = workspace
        end
        state.waterPart.CFrame = CFrame.new(hrp.Position.X, result.Position.Y, hrp.Position.Z)
    else
        if state.waterPart then state.waterPart:Destroy(); state.waterPart = nil; end
    end
end

------------------------------------------------
-- CutGrass Feature Implementations
------------------------------------------------
local cutGrass_tierColors = {
    [1] = Color3.fromRGB(150, 150, 150), [2] = Color3.fromRGB(30, 236, 0),
    [3] = Color3.fromRGB(53, 165, 255), [4] = Color3.fromRGB(167, 60, 255),
    [5] = Color3.fromRGB(255, 136, 0), [6] = Color3.fromRGB(255, 0, 0)
}

local function cutGrass_GetAllLootZones()
    local zones = {}
    local lootZonesFolder = workspace:FindFirstChild("LootZones")
    if lootZonesFolder then
        for _, zone in ipairs(lootZonesFolder:GetChildren()) do
            table.insert(zones, zone.Name)
        end
    end
    if #zones == 0 then return {"Main"} end
    return zones
end

local function cutGrass_SetAutoCut(enabled)
    local WeaponSwingEvent = ReplicatedStorage:FindFirstChild("RemoteEvents"):FindFirstChild("WeaponSwingEvent")
    if not WeaponSwingEvent then return end
    if enabled then
        WeaponSwingEvent:FireServer("HitboxStart")
    else
        WeaponSwingEvent:FireServer("HitboxEnd")
    end
end

local function cutGrass_SetGrassVisibility(grass, visible)
    local function setPartVisibility(part, vis)
        if vis then
            part.Transparency = state.cutGrass_OriginalGrassTransparencies[part] or 0
            part.CanCollide = true
        else
            if not state.cutGrass_OriginalGrassTransparencies[part] then
                state.cutGrass_OriginalGrassTransparencies[part] = part.Transparency
            end
            part.Transparency = 1
            part.CanCollide = false
        end
    end

    if grass:IsA("BasePart") then
        setPartVisibility(grass, visible)
    elseif grass:IsA("Model") then
        for _, part in pairs(grass:GetDescendants()) do
            if part:IsA("BasePart") then
                setPartVisibility(part, visible)
            end
        end
    end
end

local function cutGrass_StopGrassMonitoring()
    for _, conn in ipairs(state.cutGrass_GrassAddedConnections) do conn:Disconnect() end
    state.cutGrass_GrassAddedConnections = {}
end

local function cutGrass_StartGrassMonitoring()
    cutGrass_StopGrassMonitoring()
    local grassFolder = workspace:FindFirstChild("Grass")
    if grassFolder then
        local conn = grassFolder.ChildAdded:Connect(function(newGrass)
            if not Options.cutGrass_ToggleGrass.Value then
                cutGrass_SetGrassVisibility(newGrass, false)
            end
        end)
        table.insert(state.cutGrass_GrassAddedConnections, conn)
    end
end

local function cutGrass_ToggleGrassVisibility(visible)
    local grassFolder = workspace:FindFirstChild("Grass")
    if visible then
        cutGrass_StopGrassMonitoring()
        if grassFolder then
            for _, grass in pairs(grassFolder:GetChildren()) do
                cutGrass_SetGrassVisibility(grass, true)
            end
        end
    else
        if grassFolder then
            for _, grass in pairs(grassFolder:GetChildren()) do
                cutGrass_SetGrassVisibility(grass, false)
            end
        end
        cutGrass_StartGrassMonitoring()
    end
end

local function cutGrass_DeactivateAntiTeleport()
    for _, connection in ipairs(state.cutGrass_AntiTeleportConnections) do connection:Disconnect() end
    state.cutGrass_AntiTeleportConnections = {}
end

local function cutGrass_ActivateAntiTeleport(character)
    cutGrass_DeactivateAntiTeleport()
    if not character then return end
    local humanoid = character:FindFirstChildOfClass('Humanoid')
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not (humanoid and rootPart) then return end

    local lastCF = rootPart.CFrame
    local stop
    local heartbeatConn = RunService.Heartbeat:Connect(function()
        if stop or not rootPart or not rootPart.Parent then return end
        lastCF = rootPart.CFrame
    end)
    table.insert(state.cutGrass_AntiTeleportConnections, heartbeatConn)

    local cframeConn = rootPart:GetPropertyChangedSignal('CFrame'):Connect(function()
        stop = true
        if rootPart and rootPart.Parent then rootPart.CFrame = lastCF end
        RunService.Heartbeat:Wait()
        stop = false
    end)
    table.insert(state.cutGrass_AntiTeleportConnections, cframeConn)

    local diedConn = humanoid.Died:Connect(cutGrass_DeactivateAntiTeleport)
    table.insert(state.cutGrass_AntiTeleportConnections, diedConn)
end

local function cutGrass_SetAutoCollect(enabled)
    if enabled then
        if not Options.cutGrass_AntiTeleportToggle.Value then
            Options.cutGrass_AntiTeleportToggle:SetValue(true)
        end
        if state.cutGrass_AutoCollectCoroutine then coroutine.close(state.cutGrass_AutoCollectCoroutine) end
        if state.cutGrass_AutoGrassDeleteCoroutine then coroutine.close(state.cutGrass_AutoGrassDeleteCoroutine) end

        state.cutGrass_AutoGrassDeleteCoroutine = coroutine.create(function()
            while Options.cutGrass_AutoCollectChestsToggle.Value do
                cutGrass_ToggleGrassVisibility(false)
                task.wait(0.5)
            end
        end)

        state.cutGrass_AutoCollectCoroutine = coroutine.create(function()
            local function collect(item)
                if not Options.cutGrass_AutoCollectChestsToggle.Value or not item or not item.Parent then return false end
                local Character = player.Character
                if not Character then return false end
                local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
                if not HumanoidRootPart then return false end
                local TargetPart = item:IsA("BasePart") and item or (item:IsA("Model") and (item.PrimaryPart or item:FindFirstChildOfClass("BasePart")))
                if not TargetPart or not TargetPart.Parent then return true end

                local antiTeleportWasEnabled = Options.cutGrass_AntiTeleportToggle.Value
                if antiTeleportWasEnabled then cutGrass_DeactivateAntiTeleport() end

                HumanoidRootPart.CFrame = TargetPart.CFrame * CFrame.new(0, 0, -1.5)
                task.wait(0.01)
                for i = 1, 4 do
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                    task.wait(0.01)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                    if i < 4 then task.wait(0.01) end
                end
                task.wait(0.02)
                if antiTeleportWasEnabled then cutGrass_ActivateAntiTeleport(Character) end
                return true
            end

            while Options.cutGrass_AutoCollectChestsToggle.Value do
                local selectedZone = Options.cutGrass_LootZoneDropdown.Value
                local lootZoneFolder = workspace.LootZones:FindFirstChild(selectedZone)
                if lootZoneFolder and lootZoneFolder:FindFirstChild("Loot") then
                    local children = lootZoneFolder.Loot:GetChildren()
                    if #children > 0 then
                        for _, item in ipairs(children) do
                            if not Options.cutGrass_AutoCollectChestsToggle.Value then break end
                            collect(item)
                            task.wait(0.01)
                        end
                    else
                        task.wait(0.1)
                    end
                end
                task.wait(0.02)
            end
        end)
        coroutine.resume(state.cutGrass_AutoGrassDeleteCoroutine)
        coroutine.resume(state.cutGrass_AutoCollectCoroutine)
    else
        if state.cutGrass_AutoCollectCoroutine then coroutine.close(state.cutGrass_AutoCollectCoroutine); state.cutGrass_AutoCollectCoroutine = nil end
        if state.cutGrass_AutoGrassDeleteCoroutine then coroutine.close(state.cutGrass_AutoGrassDeleteCoroutine); state.cutGrass_AutoGrassDeleteCoroutine = nil end
    end
end

local function cutGrass_UpdateHitbox()
    if not player.Character then return end
    local Tool = player.Character:FindFirstChildOfClass("Tool")
    if Tool then
        local Hitbox = Tool:FindFirstChild("Hitbox", true) or Tool:FindFirstChild("Blade", true) or Tool:FindFirstChild("Handle")
        if Hitbox and Hitbox:IsA("BasePart") then
            local size = Options.cutGrass_HitboxSizeSlider.Value
            Hitbox.Size = Vector3.new(size, size, size)
            Hitbox.Transparency = 0.5
        end
    end
end

local function cutGrass_SetWalkSpeed(value)
    if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
        player.Character.Humanoid.WalkSpeed = value
    end
end

local function cutGrass_addHighlight(parent, type)
    if not parent or not parent.Parent or parent:FindFirstChild("ESPHighlight") then return end
    local tier = parent:GetAttribute("Tier") or 1
    local fillColor = (type == "Player") and Color3.fromRGB(255, 0, 0) or (cutGrass_tierColors[tier] or Color3.fromRGB(255, 255, 255))
    local outlineColor = (type == "Player") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(255, 255, 0)
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "ESPHighlight"; highlight.FillColor = fillColor; highlight.OutlineColor = outlineColor
    highlight.FillTransparency = 0.5; highlight.OutlineTransparency = 0; highlight.Adornee = parent
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; highlight.Parent = parent
    table.insert(state.cutGrass_ESPHighlights, {Highlight = highlight, Type = type, Parent = parent})
end

local function cutGrass_ClearESP(type)
    for i = #state.cutGrass_ESPHighlights, 1, -1 do
        local entry = state.cutGrass_ESPHighlights[i]
        if entry.Type == type then
            if entry.Highlight and entry.Highlight.Parent then pcall(function() entry.Highlight:Destroy() end) end
            table.remove(state.cutGrass_ESPHighlights, i)
        end
    end
end

local function cutGrass_ToggleChestESP(enabled)
    if enabled then
        for _, conn in ipairs(state.cutGrass_ChestESPConnections) do conn:Disconnect() end
        state.cutGrass_ChestESPConnections = {}
        local lootZones = workspace:FindFirstChild("LootZones")
        if lootZones then
            local function setupZone(zone)
                local lootFolder = zone:FindFirstChild("Loot")
                if lootFolder then
                    for _, chest in ipairs(lootFolder:GetChildren()) do cutGrass_addHighlight(chest, "Chest") end
                    local conn = lootFolder.ChildAdded:Connect(function(newChest) if Options.cutGrass_ChestESPToggle.Value then cutGrass_addHighlight(newChest, "Chest") end end)
                    table.insert(state.cutGrass_ChestESPConnections, conn)
                end
            end
            for _, zone in ipairs(lootZones:GetChildren()) do setupZone(zone) end
            local conn = lootZones.ChildAdded:Connect(function(newZone) if Options.cutGrass_ChestESPToggle.Value then setupZone(newZone) end end)
            table.insert(state.cutGrass_ChestESPConnections, conn)
        end
        if state.cutGrass_ChestESPUpdateCoroutine then coroutine.close(state.cutGrass_ChestESPUpdateCoroutine) end
        state.cutGrass_ChestESPUpdateCoroutine = coroutine.create(function()
            while Options.cutGrass_ChestESPToggle.Value do
                local lootZones = workspace:FindFirstChild("LootZones")
                if lootZones then
                    for _, zone in ipairs(lootZones:GetChildren()) do
                        local lootFolder = zone:FindFirstChild("Loot")
                        if lootFolder then
                            for _, chest in ipairs(lootFolder:GetChildren()) do if not chest:FindFirstChild("ESPHighlight") then cutGrass_addHighlight(chest, "Chest") end end
                        end
                    end
                end
                task.wait(0.2)
            end
        end)
        coroutine.resume(state.cutGrass_ChestESPUpdateCoroutine)
    else
        cutGrass_ClearESP("Chest")
        for _, conn in ipairs(state.cutGrass_ChestESPConnections) do conn:Disconnect() end
        state.cutGrass_ChestESPConnections = {}
        if state.cutGrass_ChestESPUpdateCoroutine then coroutine.close(state.cutGrass_ChestESPUpdateCoroutine); state.cutGrass_ChestESPUpdateCoroutine = nil end
    end
end

local function cutGrass_TogglePlayerESP(enabled)
    if enabled then
        for _, conn in ipairs(state.cutGrass_PlayerESPConnections) do conn:Disconnect() end
        state.cutGrass_PlayerESPConnections = {}
        local function setupPlayer(p)
            if p == player then return end
            if p.Character then cutGrass_addHighlight(p.Character, "Player") end
            local charConn = p.CharacterAdded:Connect(function(char) if Options.cutGrass_PlayerESPToggle.Value then task.wait(0.2); cutGrass_addHighlight(char, "Player") end end)
            table.insert(state.cutGrass_PlayerESPConnections, charConn)
        end
        for _, p in ipairs(Players:GetPlayers()) do setupPlayer(p) end
        local playerAddedConn = Players.PlayerAdded:Connect(function(p) if Options.cutGrass_PlayerESPToggle.Value then setupPlayer(p) end end)
        table.insert(state.cutGrass_PlayerESPConnections, playerAddedConn)

        if state.cutGrass_PlayerESPUpdateCoroutine then coroutine.close(state.cutGrass_PlayerESPUpdateCoroutine) end
        state.cutGrass_PlayerESPUpdateCoroutine = coroutine.create(function()
            while Options.cutGrass_PlayerESPToggle.Value do
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= player and p.Character and not p.Character:FindFirstChild("ESPHighlight") then cutGrass_addHighlight(p.Character, "Player") end
                end
                task.wait(0.3)
            end
        end)
        coroutine.resume(state.cutGrass_PlayerESPUpdateCoroutine)
    else
        cutGrass_ClearESP("Player")
        for _, conn in ipairs(state.cutGrass_PlayerESPConnections) do conn:Disconnect() end
        state.cutGrass_PlayerESPConnections = {}
        if state.cutGrass_PlayerESPUpdateCoroutine then coroutine.close(state.cutGrass_PlayerESPUpdateCoroutine); state.cutGrass_PlayerESPUpdateCoroutine = nil end
    end
end

------------------------------------------------
-- Core Logic (Loops & Events)
------------------------------------------------

RunService.Heartbeat:Connect(function(deltaTime)
    local selectedPlayer = getSelectedPlayer()
    if Options.LoopTeleportToggle and Options.LoopTeleportToggle.Value and selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("HumanoidRootPart") then
        teleportToPlayer(selectedPlayer)
    end
end)

RunService.RenderStepped:Connect(function(delta)
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp then return end

    if Options.GodMode and Options.GodMode.Value then humanoid.Health = humanoid.MaxHealth end
    
    if Options.RainbowCharacter and Options.RainbowCharacter.Value then
        local hue = tick() % 5 / 5
        local color = Color3.fromHSV(hue, 1, 1)
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") then part.Color = color end
        end
    end

    handleWalkOnWater()

    if Options.Noclip and Options.Noclip.Value then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end

    if Options.FreeFly and Options.FreeFly.Value then
        local bv = hrp:FindFirstChild("FlyBodyVelocity") or Instance.new("BodyVelocity", hrp)
        bv.Name = "FlyBodyVelocity"; bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge); bv.P = 1250
        local moveVector = Vector3.new()
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVector += camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVector -= camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVector -= camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVector += camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveVector += Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveVector -= Vector3.new(0, 1, 0) end
        bv.Velocity = (moveVector.Magnitude > 0 and moveVector.Unit or moveVector) * Options.FreeFlySpeed.Value
    else
        local bv = hrp:FindFirstChild("FlyBodyVelocity")
        if bv then bv:Destroy() end
    end

    if Options.Spin and Options.Spin.Value then hrp.CFrame = hrp.CFrame * CFrame.Angles(0, 50 * delta, 0) end
    
    if not state.isSpectating then camera.CameraType = Enum.CameraType.Custom end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F and Options.FForward.Value then
        state.isRunning = true
        task.spawn(function()
            while state.isRunning do
                if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    player.Character.HumanoidRootPart.CFrame += player.Character.HumanoidRootPart.CFrame.LookVector * Options.FForwardSpeed.Value
                end
                task.wait()
            end
        end)
    end
    if Options.ClickTeleport.Value and input.UserInputType == Enum.UserInputType.MouseButton1 and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and mouse.Target then
            player.Character.HumanoidRootPart.CFrame = CFrame.new(mouse.Hit.p)
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.F then state.isRunning = false end
end)

UserInputService.JumpRequest:Connect(function()
    if Options.InfiniteJump.Value and player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
        player.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

------------------------------------------------
-- GUI CREATION & MANAGEMENT
------------------------------------------------

local Window = Fluent:CreateWindow({
    Title = "MOD INJECTOR v3.6 by Gemini",
    SubTitle = "Home",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 500),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

-- メインタブ
local MainTab = Window:AddTab({ Title = "Main", Icon = "home" })
local PlayerSection = MainTab:AddSection("Player")

PlayerSection:AddToggle("GodMode", { Title = "ゴッドモード", Description = "プレイヤーを無敵にします", Default = false })
PlayerSection:AddToggle("InfiniteJump", { Title = "無限ジャンプ", Description = "ジャンプを無限にできるようにします", Default = false })
PlayerSection:AddToggle("RainbowCharacter", { Title = "虹色キャラクター", Description = "キャラクターの色を虹色に変化させます", Default = false })
PlayerSection:AddToggle("WalkOnWater", { Title = "ウォークオンウォーター", Description = "水の上を歩けるようにします", Default = false }):OnChanged(function(value)
    if not value and state.waterPart then
        state.waterPart:Destroy()
        state.waterPart = nil
    end
end)

PlayerSection:AddSlider("WalkSpeed", {
    Title = "歩く速度", Min = 16, Max = 200, Default = 16, Rounding = 0,
    Callback = function(value) if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then player.Character.Humanoid.WalkSpeed = value end end
})

PlayerSection:AddSlider("JumpPower", {
    Title = "ジャンプ力", Min = 50, Max = 300, Default = 50, Rounding = 0,
    Callback = function(value) if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then player.Character.Humanoid.JumpPower = value end end
})

PlayerSection:AddSlider("CharacterSize", { Title = "キャラクターサイズ", Min = 0.5, Max = 3, Default = 1, Rounding = 2, Callback = setCharacterSize })

local MovementSection = MainTab:AddSection("Movement")
MovementSection:AddToggle("FreeFly", { Title = "FreeFly", Description = "空中を自由に飛行します (W/A/S/D, Space, L-Shift)", Default = false }):OnChanged(function(value)
    if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then player.Character.Humanoid.PlatformStand = value end
end)
MovementSection:AddSlider("FreeFlySpeed", { Title = "FreeFly 速度", Min = 10, Max = 500, Default = 50, Rounding = 0 })
MovementSection:AddToggle("Noclip", { Title = "Noclip", Description = "壁を通り抜けられるようにします", Default = false }):OnChanged(function(value)
    if not value and player.Character then
        for _, part in ipairs(player.Character:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = true end end
    end
end)

local MiscSection = MainTab:AddSection("Misc")
MiscSection:AddToggle("ClickTeleport", { Title = "クリックテレポート", Description = "左Ctrlを押しながらクリックした場所にテレポートします", Default = false })
MiscSection:AddToggle("FForward", { Title = "F-Forward", Description = "Fキーを押している間、前進し続けます", Default = false })
MiscSection:AddSlider("FForwardSpeed", { Title = "F-Forward 速度", Min = 1, Max = 10, Default = 2, Rounding = 1 })
MiscSection:AddToggle("Spin", { Title = "Spin", Description = "キャラクターを回転させます", Default = false })
MiscSection:AddToggle("PlayerESP", { Title = "プレイヤーESP", Description = "他のプレイヤーの位置を表示します", Default = false, Callback = updateESP })

-- テレポートタブ
local TeleportTab = Window:AddTab({ Title = "Teleport", Icon = "shuffle" })
local PlayerSelectionSection = TeleportTab:AddSection("Player Selection")
local TeleportActionsSection = TeleportTab:AddSection("Actions")
local playerDropdown = PlayerSelectionSection:AddDropdown("PlayerList", { Title = "プレイヤーを選択", Values = {}, Default = nil, Callback = function(v) state.selectedTeleportPlayerName = v end })
PlayerSelectionSection:AddButton({ Title = "プレイヤーリストを更新", Callback = function()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do if p ~= player then table.insert(names, p.Name) end end
    playerDropdown:SetValues(names)
    Fluent:Notify({ Title = "更新完了", Content = #names .. "人のプレイヤーが見つかりました。", Duration = 3 })
end})
TeleportActionsSection:AddButton({ Title = "選択したプレイヤーにテレポート", Callback = function() local t = getSelectedPlayer() if t then teleportToPlayer(t) else Fluent:Notify({Title="エラー",Content="プレイヤーが選択されていません。"}) end end })
TeleportActionsSection:AddButton({ Title = "選択したプレイヤーを自分に呼ぶ", Callback = function() local t = getSelectedPlayer() if t then bringPlayer(t) else Fluent:Notify({Title="エラー",Content="プレイヤーが選択されていません。"}) end end })
TeleportActionsSection:AddToggle("SpectateToggle", { Title = "観戦", Default = false, Callback = function(v) local t = getSelectedPlayer() if t then spectatePlayer(t, v) else Fluent:Notify({Title="エラー",Content="プレイヤーが選択されていません。"}) end end})
TeleportActionsSection:AddToggle("LoopTeleportToggle", { Title = "ループテレポート", Default = false })
TeleportActionsSection:AddToggle("TeleportPositionToggle", { Title = "ループ位置: 後ろ / 正面", Description = "トグルがONの時、正面にテレポートします", Default = false })

-- CutGrassタブ
local CutGrassTab = Window:AddTab({ Title = "CutGrass", Icon = "leaf" })
local CgHacksSection = CutGrassTab:AddSection("Hacks")
CgHacksSection:AddToggle("cutGrass_AutoCutGrassToggle", { Title = "Auto Cut Grass", Default = false, Callback = cutGrass_SetAutoCut })
CgHacksSection:AddToggle("cutGrass_ToggleGrass", { Title = "Toggle Grass Visibility", Default = true, Callback = cutGrass_ToggleGrassVisibility })
CgHacksSection:AddToggle("cutGrass_AntiTeleportToggle", { Title = "Enable Anti-Teleport", Default = false, Callback = function(v) if v then cutGrass_ActivateAntiTeleport(player.Character) else cutGrass_DeactivateAntiTeleport() end end })
CgHacksSection:AddSlider("cutGrass_HitboxSizeSlider", { Title = "Hitbox Size", Min = 1, Max = 50, Default = 1, Rounding = 0, Callback = function(v)
    cutGrass_UpdateHitbox()
    if state.cutGrass_HitboxLoop then state.cutGrass_HitboxLoop:Disconnect(); state.cutGrass_HitboxLoop = nil end
    if v > 1 then state.cutGrass_HitboxLoop = RunService.Heartbeat:Connect(cutGrass_UpdateHitbox) end
end})
CgHacksSection:AddSlider("cutGrass_WalkSpeedSlider", { Title = "Walk Speed", Min = 16, Max = 100, Default = 16, Rounding = 0, Callback = cutGrass_SetWalkSpeed })

local CgChestsSection = CutGrassTab:AddSection("Chests")
local cgLootZoneDropdown = CgChestsSection:AddDropdown("cutGrass_LootZoneDropdown", { Title = "Select Loot Zone", Values = cutGrass_GetAllLootZones(), Default = "Main", Callback = function()
    if Options.cutGrass_AutoCollectChestsToggle.Value then
        cutGrass_SetAutoCollect(false)
        cutGrass_SetAutoCollect(true)
    end
end})
CgChestsSection:AddToggle("cutGrass_AutoCollectChestsToggle", { Title = "Auto Collect Chests", Default = false, Callback = function(v)
    cutGrass_SetAutoCollect(v)
    cutGrass_ToggleGrassVisibility(not v)
end})

local CgVisualsSection = CutGrassTab:AddSection("Visuals")
CgVisualsSection:AddToggle("cutGrass_ChestESPToggle", { Title = "Chest ESP", Default = false, Callback = cutGrass_ToggleChestESP })
CgVisualsSection:AddToggle("cutGrass_PlayerESPToggle", { Title = "Player ESP", Default = false, Callback = cutGrass_TogglePlayerESP })


-- ワールドタブ
local WorldTab = Window:AddTab({ Title = "World", Icon = "world" })
local LightingSection = WorldTab:AddSection("Lighting")
LightingSection:AddSlider("FogEnd", { Title = "霧の距離", Min = 100, Max = 100000, Default = Lighting.FogEnd, Rounding = 0, Callback = function(v) Lighting.FogEnd = v end })
LightingSection:AddSlider("TimeOfDay", { Title = "時間", Min = 0, Max = 1440, Default = Lighting:GetMinutesAfterMidnight(), Rounding = 0, Callback = function(v) Lighting:SetMinutesAfterMidnight(v) end })

-- 設定タブ
local SettingsTab = Window:AddTab({ Title = "Settings", Icon = "settings" })
if SaveManager and InterfaceManager then
    SaveManager:SetLibrary(Fluent)
    InterfaceManager:SetLibrary(Fluent)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetFolder("ModInjectorFluentConfig")
    InterfaceManager:SetFolder("ModInjectorFluentConfig")
    InterfaceManager:BuildInterfaceSection(SettingsTab)
    SaveManager:BuildConfigSection(SettingsTab)
end

-- 初期化
Window:SelectTab(1)
task.wait(1)
local initialPlayerNames = {}
for _, p in ipairs(Players:GetPlayers()) do if p ~= player then table.insert(initialPlayerNames, p.Name) end end
playerDropdown:SetValues(initialPlayerNames)

player.CharacterAdded:Connect(function(character)
    task.wait(1)
    local humanoid = character:WaitForChild("Humanoid")
    
    -- Main Features
    if Options.PlayerESP and Options.PlayerESP.Value then updateESP(true) end
    if Options.WalkSpeed and Options.WalkSpeed.Value then humanoid.WalkSpeed = Options.WalkSpeed.Value end
    if Options.JumpPower and Options.JumpPower.Value then humanoid.JumpPower = Options.JumpPower.Value end
    if Options.Noclip and Options.Noclip.Value then
         for _, part in ipairs(character:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = false end end
    end
    state.isSpectating = false
    if Options.WalkOnWater and Options.WalkOnWater.Value and state.waterPart then state.waterPart:Destroy(); state.waterPart = nil end

    -- CutGrass Features
    if Options.cutGrass_AntiTeleportToggle and Options.cutGrass_AntiTeleportToggle.Value then cutGrass_ActivateAntiTeleport(character) end
    if Options.cutGrass_HitboxSizeSlider and Options.cutGrass_HitboxSizeSlider.Value > 1 then cutGrass_UpdateHitbox() end
    if Options.cutGrass_WalkSpeedSlider and Options.cutGrass_WalkSpeedSlider.Value then cutGrass_SetWalkSpeed(Options.cutGrass_WalkSpeedSlider.Value) end
end)

Fluent:Notify({
    Title = "Mod Injector Fluent",
    Content = "ロードが完了しました。'"..tostring(Window.MinimizeKey).."キー'でUIを開閉できます。",
    Duration = 8
})

if SaveManager then
    SaveManager:LoadAutoloadConfig()
end
