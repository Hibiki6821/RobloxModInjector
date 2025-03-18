-- ローカルプレイヤーと各サービスの取得
local player = game.Players.LocalPlayer
local userInputService = game:GetService("UserInputService")
local runService = game:GetService("RunService")
local camera = workspace.CurrentCamera

-- 各機能用の変数
local isRunning = false
local multiplier = 2  -- F前進の移動速度
local forwardMovementEnabled = false

local freeFlyEnabled = false
local freeFlySpeed = 50

local noclipEnabled = false
local spinEnabled = false
local spinSpeed = 50  -- Spin回転速度（ラジアン/秒）

local espEnabled = false

-- テレポート機能用の変数
local selectedTeleportPlayer = nil
local playersPerPage = 5
local currentPage = 1
local teleportLoopEnabled = false

local infiniteJump = false

------------------------------------------------
-- 背景アニメーション（虹色アニメーション・動的）
------------------------------------------------
local function animateRainbowBackground(guiMain)
    local gradient = guiMain:FindFirstChildOfClass("UIGradient")
    if not gradient then
        gradient = Instance.new("UIGradient", guiMain)
    end
    local t = 0
    runService.RenderStepped:Connect(function(delta)
        t = t + delta
        gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromHSV(t % 1, 1, 1)),
            ColorSequenceKeypoint.new(0.15, Color3.fromHSV((t + 0.15) % 1, 1, 1)),
            ColorSequenceKeypoint.new(0.3, Color3.fromHSV((t + 0.3) % 1, 1, 1)),
            ColorSequenceKeypoint.new(0.45, Color3.fromHSV((t + 0.45) % 1, 1, 1)),
            ColorSequenceKeypoint.new(0.6, Color3.fromHSV((t + 0.6) % 1, 1, 1)),
            ColorSequenceKeypoint.new(0.75, Color3.fromHSV((t + 0.75) % 1, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.fromHSV((t + 1) % 1, 1, 1))
        })
    end)
end

------------------------------------------------
-- ESP機能：足元に各プレイヤーの名前を表示
------------------------------------------------
local function createESP(character)
    local root = character:FindFirstChild("HumanoidRootPart")
    if root and not root:FindFirstChild("ESP") then
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "ESP"
        billboard.Parent = root
        billboard.Size = UDim2.new(0,100,0,50)
        billboard.AlwaysOnTop = true
        billboard.StudsOffset = Vector3.new(0, -3, 0)
        local textLabel = Instance.new("TextLabel", billboard)
        textLabel.Size = UDim2.new(1,0,1,0)
        textLabel.BackgroundTransparency = 1
        textLabel.TextColor3 = Color3.new(1,0,0)
        textLabel.Text = character.Name
        textLabel.TextScaled = true
    end
end

local function enableESP()
    for _, plr in pairs(game.Players:GetPlayers()) do
        if plr ~= player then
            if plr.Character then
                createESP(plr.Character)
            end
            plr.CharacterAdded:Connect(function(character)
                wait(0.1)
                if espEnabled then
                    createESP(character)
                end
            end)
        end
    end
end

local function disableESP()
    for _, plr in pairs(game.Players:GetPlayers()) do
        if plr ~= player and plr.Character then
            local root = plr.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local esp = root:FindFirstChild("ESP")
                if esp then
                    esp:Destroy()
                end
            end
        end
    end
end

------------------------------------------------
-- テレポート機能：対象プレイヤーの正面（HumanoidRootPart基準）に瞬時に移動
------------------------------------------------
local function teleportToPlayer(targetPlayer)
    if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local targetHRP = targetPlayer.Character.HumanoidRootPart
        local offset = 1.5
        local newPos = targetHRP.Position + targetHRP.CFrame.LookVector * offset
        player.Character.HumanoidRootPart.CFrame = CFrame.new(newPos, targetHRP.Position)
        camera.CFrame = CFrame.new(camera.CFrame.Position, targetHRP.Position)
    end
end

------------------------------------------------
-- F前進機能
------------------------------------------------
userInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F then
        if forwardMovementEnabled then
            isRunning = true
            task.spawn(function()
                while isRunning do
                    task.wait()
                    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                        local hrp = player.Character.HumanoidRootPart
                        hrp.CFrame = hrp.CFrame + hrp.CFrame.LookVector * multiplier
                    end
                end
            end)
        end
    end
end)

userInputService.InputEnded:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F then
        isRunning = false
    end
end)

------------------------------------------------
-- FreeFly移動処理 (RenderStepped)
------------------------------------------------
runService.RenderStepped:Connect(function(delta)
    if freeFlyEnabled and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = player.Character.HumanoidRootPart
        local bv = hrp:FindFirstChild("FlyBodyVelocity")
        if not bv then
            bv = Instance.new("BodyVelocity")
            bv.Name = "FlyBodyVelocity"
            bv.MaxForce = Vector3.new(1e5,1e5,1e5)
            bv.P = 1e4
            bv.Parent = hrp
        end
        local moveVector = Vector3.new()
        if userInputService:IsKeyDown(Enum.KeyCode.W) then
            moveVector = moveVector + camera.CFrame.LookVector
        end
        if userInputService:IsKeyDown(Enum.KeyCode.S) then
            moveVector = moveVector - camera.CFrame.LookVector
        end
        if userInputService:IsKeyDown(Enum.KeyCode.A) then
            moveVector = moveVector - camera.CFrame.RightVector
        end
        if userInputService:IsKeyDown(Enum.KeyCode.D) then
            moveVector = moveVector + camera.CFrame.RightVector
        end
        if userInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveVector = moveVector + Vector3.new(0,1,0)
        end
        if userInputService:IsKeyDown(Enum.KeyCode.LeftShift) or userInputService:IsKeyDown(Enum.KeyCode.RightShift) then
            moveVector = moveVector - Vector3.new(0,1,0)
        end
        if moveVector.Magnitude > 0 then
            moveVector = moveVector.Unit
        end
        bv.Velocity = moveVector * freeFlySpeed
    else
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = player.Character.HumanoidRootPart
            local bv = hrp:FindFirstChild("FlyBodyVelocity")
            if bv then bv:Destroy() end
        end
    end
end)

------------------------------------------------
-- Spin処理 (RenderStepped)
------------------------------------------------
runService.RenderStepped:Connect(function(delta)
    if spinEnabled and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = player.Character.HumanoidRootPart
        hrp.CFrame = hrp.CFrame * CFrame.Angles(0, spinSpeed * delta, 0)
    end
end)

------------------------------------------------
-- Noclip処理 (Stepped)
------------------------------------------------
runService.Stepped:Connect(function()
    if noclipEnabled and player.Character then
        for _, part in pairs(player.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end)

------------------------------------------------
-- 無限ジャンプ
------------------------------------------------
userInputService.JumpRequest:Connect(function()
    if infiniteJump and player.Character then
        local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

------------------------------------------------
-- Teleport Loop処理 (RenderStepped)
-- 対象プレイヤーのHumanoidRootPartを基準に、正面に1.5スタッドで追従
------------------------------------------------
runService.RenderStepped:Connect(function(delta)
    if teleportLoopEnabled 
       and selectedTeleportPlayer 
       and selectedTeleportPlayer.Character 
       and selectedTeleportPlayer.Character:FindFirstChild("HumanoidRootPart")
       and player.Character 
       and player.Character:FindFirstChild("HumanoidRootPart") then
        local targetHRP = selectedTeleportPlayer.Character.HumanoidRootPart
        local offset = 1.5
        local newPos = targetHRP.Position + targetHRP.CFrame.LookVector * offset
        player.Character.HumanoidRootPart.CFrame = CFrame.new(newPos, targetHRP.Position)
        camera.CFrame = CFrame.new(camera.CFrame.Position, targetHRP.Position)
    end
end)

------------------------------------------------
-- カメラ更新処理 (RenderStepped)
-- 常にカメラはCustomにする（Teleport Loop中も一人称視点にならない）
------------------------------------------------
runService.RenderStepped:Connect(function(delta)
    local cam = workspace.CurrentCamera
    cam.CameraType = Enum.CameraType.Custom
end)

------------------------------------------------
-- GUI作成（タブ切替付き）
------------------------------------------------
local function createCustomSliderForList(parent, min, max, callback, labelText)
    local sliderFrame = Instance.new("Frame", parent)
    sliderFrame.Size = UDim2.new(0,250,0,50)
    sliderFrame.BackgroundColor3 = Color3.new(1,1,1)
    local sliderLabel = Instance.new("TextLabel", sliderFrame)
    sliderLabel.Size = UDim2.new(1,0,0,20)
    sliderLabel.Position = UDim2.new(0,0,0,0)
    sliderLabel.BackgroundColor3 = Color3.new(1,1,1)
    sliderLabel.Text = labelText
    sliderLabel.TextScaled = true
    local sliderBar = Instance.new("Frame", sliderFrame)
    sliderBar.Size = UDim2.new(0,200,0,10)
    sliderBar.Position = UDim2.new(0.5,-100,0.5,-5)
    sliderBar.BackgroundColor3 = Color3.new(0.3,0.3,0.3)
    local sliderButton = Instance.new("TextButton", sliderBar)
    sliderButton.Size = UDim2.new(0,20,0,20)
    sliderButton.BackgroundColor3 = Color3.new(1,0,0)
    sliderButton.Text = ""
    sliderButton.MouseButton1Down:Connect(function()
        local movingConnection = userInputService.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                local x = math.clamp(input.Position.X - sliderBar.AbsolutePosition.X, 0, sliderBar.AbsoluteSize.X)
                sliderButton.Position = UDim2.new(0, x - sliderButton.AbsoluteSize.X/2, 0.5, -5)
                callback(math.floor(min + (max - min) * (x / sliderBar.AbsoluteSize.X)))
            end
        end)
        local upConnection = userInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                movingConnection:Disconnect()
                upConnection:Disconnect()
            end
        end)
    end)
    return sliderFrame
end

local function createGUI()
    local screenGui = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
    screenGui.Name = "MODInjectorGUI"
    
    local hiddenLabel = Instance.new("TextLabel", screenGui)
    hiddenLabel.Name = "HiddenLabel"
    hiddenLabel.Size = UDim2.new(0,300,0,50)
    hiddenLabel.Position = UDim2.new(0.5,-150,0,10)
    hiddenLabel.Text = "坂部響己のチートを使用中"
    hiddenLabel.TextColor3 = Color3.new(1,1,1)
    hiddenLabel.BackgroundColor3 = Color3.new(0,0,0)
    hiddenLabel.Visible = false

    local txtButton = Instance.new("TextButton")
    txtButton.BackgroundTransparency = 1
    txtButton.Size = UDim2.new(0,0,0,0)
    txtButton.Text = " "
    txtButton.Parent = screenGui

    local guiMain = Instance.new("Frame", screenGui)
    guiMain.Name = "MODInjectorMain"
    guiMain.Size = UDim2.new(0,500,0,700)
    guiMain.Position = UDim2.new(0.5,-250,0.5,-350)
    guiMain.BorderSizePixel = 2
    guiMain.Active = true
    guiMain.Draggable = true
    local mainFrameCorner = Instance.new("UICorner", guiMain)
    mainFrameCorner.CornerRadius = UDim.new(0,10)

    local gradient = Instance.new("UIGradient", guiMain)
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255,0,0)),
        ColorSequenceKeypoint.new(0.15, Color3.fromRGB(255,165,0)),
        ColorSequenceKeypoint.new(0.3, Color3.fromRGB(255,255,0)),
        ColorSequenceKeypoint.new(0.45, Color3.fromRGB(0,255,0)),
        ColorSequenceKeypoint.new(0.6, Color3.fromRGB(0,0,255)),
        ColorSequenceKeypoint.new(0.75, Color3.fromRGB(75,0,130)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(238,130,238))
    })
    animateRainbowBackground(guiMain)

    if not screenGui:FindFirstChild("LogoImage") then
        local logo = Instance.new("ImageLabel")
        logo.Name = "LogoImage"
        logo.Parent = screenGui
        logo.Size = UDim2.new(0,150,0,150)
        logo.AnchorPoint = Vector2.new(1,1)
        logo.Position = UDim2.new(1, -10, 1, -10)
        logo.BackgroundTransparency = 1
        logo.Image = "rbxassetid://71061330924177"
    end

    local headerFrame = Instance.new("Frame", guiMain)
    headerFrame.Size = UDim2.new(1,0,0,30)
    headerFrame.Position = UDim2.new(0,0,0,0)
    headerFrame.BackgroundTransparency = 1
    headerFrame.BorderSizePixel = 0
    local headerCorner = Instance.new("UICorner", headerFrame)
    headerCorner.CornerRadius = UDim.new(0,8)

    local titleLabel = Instance.new("TextLabel", headerFrame)
    titleLabel.Size = UDim2.new(1,0,1,0)
    titleLabel.Position = UDim2.new(0,0,0,0)
    titleLabel.Text = "MOD INJECTOR"
    titleLabel.TextColor3 = Color3.new(1,1,1)
    titleLabel.BackgroundTransparency = 0
    titleLabel.BackgroundColor3 = Color3.new(0,0,0)
    titleLabel.TextSize = 20
    titleLabel.TextScaled = true
    titleLabel.TextXAlignment = Enum.TextXAlignment.Center
    local titleCorner = Instance.new("UICorner", titleLabel)
    titleCorner.CornerRadius = UDim.new(0,8)

    local hideButton = Instance.new("TextButton", headerFrame)
    hideButton.Size = UDim2.new(0,20,0,20)
    hideButton.Position = UDim2.new(0,0,0,0)
    hideButton.Text = "_"
    hideButton.BackgroundColor3 = Color3.new(1,0,0)
    hideButton.TextColor3 = Color3.new(1,1,1)
    hideButton.TextScaled = true
    local hideButtonCorner = Instance.new("UICorner", hideButton)
    hideButtonCorner.CornerRadius = UDim.new(0,8)
    hideButton.MouseButton1Click:Connect(function()
        guiMain.Visible = false
        hiddenLabel.Visible = true
        userInputService.MouseIconEnabled = false
        txtButton.Modal = false
        userInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    end)

    local contentFrame = Instance.new("Frame", guiMain)
    contentFrame.Size = UDim2.new(1,0,1,-30)
    contentFrame.Position = UDim2.new(0,0,0,30)
    contentFrame.BackgroundTransparency = 1

    local mainPage = Instance.new("Frame", contentFrame)
    mainPage.Size = UDim2.new(1,0,1,0)
    mainPage.Position = UDim2.new(0,0,0,0)
    mainPage.BackgroundTransparency = 1
    mainPage.Visible = true

    local mainListLayout = Instance.new("UIListLayout", mainPage)
    mainListLayout.FillDirection = Enum.FillDirection.Vertical
    mainListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    mainListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    mainListLayout.Padding = UDim.new(0,10)

    local walkSpeedSlider = createCustomSliderForList(mainPage, 16, 100, function(value)
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = value
        end
    end, "スピード調整")
    walkSpeedSlider.LayoutOrder = 1

    local jumpPowerSlider = createCustomSliderForList(mainPage, 50, 200, function(value)
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.JumpPower = value
        end
    end, "ジャンプ力調整")
    jumpPowerSlider.LayoutOrder = 2

    local infiniteJumpButton = Instance.new("TextButton", mainPage)
    infiniteJumpButton.Size = UDim2.new(0,250,0,50)
    infiniteJumpButton.Text = "無限ジャンプ OFF"
    infiniteJumpButton.BackgroundColor3 = Color3.new(1,0,0)
    infiniteJumpButton.TextColor3 = Color3.new(1,1,1)
    infiniteJumpButton.LayoutOrder = 3
    local infiniteJumpButtonCorner = Instance.new("UICorner", infiniteJumpButton)
    infiniteJumpButtonCorner.CornerRadius = UDim.new(0,8)
    infiniteJumpButton.MouseButton1Click:Connect(function()
        infiniteJump = not infiniteJump
        infiniteJumpButton.Text = infiniteJump and "無限ジャンプ ON" or "無限ジャンプ OFF"
    end)
    userInputService.JumpRequest:Connect(function()
        if infiniteJump then
            local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end)

    local forwardButton = Instance.new("TextButton", mainPage)
    forwardButton.Size = UDim2.new(0,250,0,50)
    forwardButton.Text = "F前進 OFF"
    forwardButton.BackgroundColor3 = Color3.new(1,0,0)
    forwardButton.TextColor3 = Color3.new(1,1,1)
    forwardButton.LayoutOrder = 4
    local forwardButtonCorner = Instance.new("UICorner", forwardButton)
    forwardButtonCorner.CornerRadius = UDim.new(0,8)
    forwardButton.MouseButton1Click:Connect(function()
        forwardMovementEnabled = not forwardMovementEnabled
        forwardButton.Text = forwardMovementEnabled and "F前進 ON" or "F前進 OFF"
    end)

    local forwardSpeedButton = Instance.new("TextButton", mainPage)
    forwardSpeedButton.Size = UDim2.new(0,250,0,50)
    forwardSpeedButton.Text = "F速度: " .. multiplier
    forwardSpeedButton.BackgroundColor3 = Color3.new(0,1,0)
    forwardSpeedButton.TextColor3 = Color3.new(1,1,1)
    forwardSpeedButton.LayoutOrder = 5
    local forwardSpeedButtonCorner = Instance.new("UICorner", forwardSpeedButton)
    forwardSpeedButtonCorner.CornerRadius = UDim.new(0,8)
    forwardSpeedButton.MouseButton1Click:Connect(function()
        multiplier = multiplier + 1
        if multiplier > 5 then
            multiplier = 1
        end
        forwardSpeedButton.Text = "F速度: " .. multiplier
    end)

    local freeFlyButton = Instance.new("TextButton", mainPage)
    freeFlyButton.Size = UDim2.new(0,250,0,50)
    freeFlyButton.Text = "FreeFly OFF"
    freeFlyButton.BackgroundColor3 = Color3.new(1,0,0)
    freeFlyButton.TextColor3 = Color3.new(1,1,1)
    freeFlyButton.LayoutOrder = 6
    local freeFlyButtonCorner = Instance.new("UICorner", freeFlyButton)
    freeFlyButtonCorner.CornerRadius = UDim.new(0,8)
    freeFlyButton.MouseButton1Click:Connect(function()
        freeFlyEnabled = not freeFlyEnabled
        freeFlyButton.Text = freeFlyEnabled and "FreeFly ON" or "FreeFly OFF"
        if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            humanoid.PlatformStand = freeFlyEnabled
        end
    end)

    local freeFlySlider = createCustomSliderForList(mainPage, 10, 200, function(value)
        freeFlySpeed = value
    end, "FreeFly速度調整")
    freeFlySlider.LayoutOrder = 7

    local noclipButton = Instance.new("TextButton", mainPage)
    noclipButton.Size = UDim2.new(0,250,0,50)
    noclipButton.Text = "Noclip OFF"
    noclipButton.BackgroundColor3 = Color3.new(1,0,0)
    noclipButton.TextColor3 = Color3.new(1,1,1)
    noclipButton.LayoutOrder = 8
    local noclipButtonCorner = Instance.new("UICorner", noclipButton)
    noclipButtonCorner.CornerRadius = UDim.new(0,8)
    noclipButton.MouseButton1Click:Connect(function()
        noclipEnabled = not noclipEnabled
        if noclipEnabled then
            noclipButton.Text = "Noclip ON"
        else
            noclipButton.Text = "Noclip OFF"
            if player.Character then
                for _, part in pairs(player.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = true
                    end
                end
            end
        end
    end)

    local spinButton = Instance.new("TextButton", mainPage)
    spinButton.Size = UDim2.new(0,250,0,50)
    spinButton.Text = "Spin OFF"
    spinButton.BackgroundColor3 = Color3.new(1,0,0)
    spinButton.TextColor3 = Color3.new(1,1,1)
    spinButton.LayoutOrder = 9
    local spinButtonCorner = Instance.new("UICorner", spinButton)
    spinButtonCorner.CornerRadius = UDim.new(0,8)
    spinButton.MouseButton1Click:Connect(function()
        spinEnabled = not spinEnabled
        spinButton.Text = spinEnabled and "Spin ON" or "Spin OFF"
    end)

    local espButton = Instance.new("TextButton", mainPage)
    espButton.Size = UDim2.new(0,250,0,50)
    espButton.Text = "ESP OFF"
    espButton.BackgroundColor3 = Color3.new(1,0,0)
    espButton.TextColor3 = Color3.new(1,1,1)
    espButton.LayoutOrder = 10
    local espButtonCorner = Instance.new("UICorner", espButton)
    espButtonCorner.CornerRadius = UDim.new(0,8)
    espButton.MouseButton1Click:Connect(function()
        espEnabled = not espEnabled
        espButton.Text = espEnabled and "ESP ON" or "ESP OFF"
        if espEnabled then
            enableESP()
        else
            disableESP()
        end
    end)

    local teleportPage = Instance.new("Frame", contentFrame)
    teleportPage.Size = UDim2.new(1,0,1,0)
    teleportPage.Position = UDim2.new(0,0,0,0)
    teleportPage.BackgroundTransparency = 1
    teleportPage.Visible = false

    local teleportListFrame = Instance.new("Frame", teleportPage)
    teleportListFrame.Size = UDim2.new(1, -20, 0, 300)
    teleportListFrame.Position = UDim2.new(0,10,0,10)
    teleportListFrame.BackgroundTransparency = 1
    local teleportListLayout = Instance.new("UIListLayout", teleportListFrame)
    teleportListLayout.FillDirection = Enum.FillDirection.Vertical
    teleportListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    teleportListLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    teleportListLayout.Padding = UDim.new(0,5)

    local navFrame = Instance.new("Frame", teleportPage)
    navFrame.Size = UDim2.new(1, -20, 0, 40)
    navFrame.Position = UDim2.new(0,10,0,320)
    navFrame.BackgroundTransparency = 1

    local prevButton = Instance.new("TextButton", navFrame)
    prevButton.Size = UDim2.new(0, (navFrame.AbsoluteSize.X/2) - 5, 1, 0)
    prevButton.Position = UDim2.new(0,0,0,0)
    prevButton.Text = "前のページ"
    prevButton.BackgroundColor3 = Color3.new(0,0,0)
    prevButton.TextColor3 = Color3.new(1,1,1)
    prevButton.TextScaled = true
    local prevCorner = Instance.new("UICorner", prevButton)
    prevCorner.CornerRadius = UDim.new(0,8)
    prevButton.MouseButton1Click:Connect(function()
        currentPage = currentPage - 1
        updateTeleportList()
    end)

    local nextButton = Instance.new("TextButton", navFrame)
    nextButton.Size = UDim2.new(0, (navFrame.AbsoluteSize.X/2) - 5, 1, 0)
    nextButton.Position = UDim2.new(0.5,5,0,0)
    nextButton.Text = "次のページ"
    nextButton.BackgroundColor3 = Color3.new(0,0,0)
    nextButton.TextColor3 = Color3.new(1,1,1)
    nextButton.TextScaled = true
    local nextCorner = Instance.new("UICorner", nextButton)
    nextCorner.CornerRadius = UDim.new(0,8)
    nextButton.MouseButton1Click:Connect(function()
        currentPage = currentPage + 1
        updateTeleportList()
    end)

    local teleportLoopButton = Instance.new("TextButton", teleportPage)
    teleportLoopButton.Size = UDim2.new(1, -20, 0, 40)
    teleportLoopButton.Position = UDim2.new(0,10,0,370)
    teleportLoopButton.Text = "Teleport Loop: OFF"
    teleportLoopButton.BackgroundColor3 = Color3.new(0,0,0)
    teleportLoopButton.TextColor3 = Color3.new(1,1,1)
    teleportLoopButton.TextScaled = true
    local teleportLoopButtonCorner = Instance.new("UICorner", teleportLoopButton)
    teleportLoopButtonCorner.CornerRadius = UDim.new(0,8)
    teleportLoopButton.MouseButton1Click:Connect(function()
        teleportLoopEnabled = not teleportLoopEnabled
        teleportLoopButton.Text = teleportLoopEnabled and "Teleport Loop: ON" or "Teleport Loop: OFF"
    end)

    local pageInfoLabel = Instance.new("TextLabel", teleportPage)
    pageInfoLabel.Size = UDim2.new(1, -20, 0, 30)
    pageInfoLabel.Position = UDim2.new(0,10,0,420)
    pageInfoLabel.BackgroundTransparency = 1
    pageInfoLabel.TextColor3 = Color3.new(1,1,1)
    pageInfoLabel.TextScaled = true
    pageInfoLabel.Text = "1/1"

    local selectedLabel = Instance.new("TextLabel", teleportPage)
    selectedLabel.Size = UDim2.new(1, -20, 0, 30)
    selectedLabel.Position = UDim2.new(0,10,0,460)
    selectedLabel.BackgroundTransparency = 1
    selectedLabel.Text = "選択中: なし"
    selectedLabel.TextColor3 = Color3.new(1,1,1)
    selectedLabel.TextScaled = true

    local teleportButton = Instance.new("TextButton", teleportPage)
    teleportButton.Size = UDim2.new(1, -20, 0, 50)
    teleportButton.Position = UDim2.new(0,10,0,510)
    teleportButton.Text = "テレポート"
    teleportButton.BackgroundColor3 = Color3.new(0,1,0)
    teleportButton.TextColor3 = Color3.new(1,1,1)
    teleportButton.TextScaled = true
    local teleportButtonCorner = Instance.new("UICorner", teleportButton)
    teleportButtonCorner.CornerRadius = UDim.new(0,8)
    teleportButton.MouseButton1Click:Connect(function()
        if selectedTeleportPlayer then
            teleportToPlayer(selectedTeleportPlayer)
        end
    end)

    function updateTeleportList()
        teleportListFrame:ClearAllChildren()
        local layout = Instance.new("UIListLayout", teleportListFrame)
        layout.FillDirection = Enum.FillDirection.Vertical
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        layout.VerticalAlignment = Enum.VerticalAlignment.Top
        layout.Padding = UDim.new(0,5)
        local playersList = {}
        for _, plr in pairs(game.Players:GetPlayers()) do
            if plr ~= player then
                table.insert(playersList, plr)
            end
        end
        local totalPages = math.max(1, math.ceil(#playersList / playersPerPage))
        if currentPage > totalPages then currentPage = totalPages end
        if currentPage < 1 then currentPage = 1 end
        pageInfoLabel.Text = currentPage .. "/" .. totalPages
        local startIndex = (currentPage - 1) * playersPerPage + 1
        local endIndex = math.min(currentPage * playersPerPage, #playersList)
        for i = startIndex, endIndex do
            local plr = playersList[i]
            local btn = Instance.new("TextButton", teleportListFrame)
            btn.Size = UDim2.new(1,0,0,30)
            btn.Text = plr.Name
            btn.BackgroundColor3 = Color3.new(0,0,0)
            btn.TextColor3 = Color3.new(1,1,1)
            btn.TextScaled = true
            local btnCorner = Instance.new("UICorner", btn)
            btnCorner.CornerRadius = UDim.new(0,8)
            btn.MouseButton1Click:Connect(function()
                selectedTeleportPlayer = plr
                selectedLabel.Text = "選択中: " .. plr.Name
            end)
        end
    end
    updateTeleportList()

    local tabFrame = Instance.new("Frame", guiMain)
    tabFrame.Size = UDim2.new(0,140,0,30)
    tabFrame.Position = UDim2.new(1,-140,1,-30)
    tabFrame.BackgroundTransparency = 1

    local tabMain = Instance.new("TextButton", tabFrame)
    tabMain.Size = UDim2.new(0,60,1,0)
    tabMain.Position = UDim2.new(0,0,0,0)
    tabMain.Text = "Main"
    tabMain.BackgroundColor3 = Color3.new(0,0,0)
    tabMain.TextColor3 = Color3.new(1,1,1)
    tabMain.TextScaled = true
    local tabMainCorner = Instance.new("UICorner", tabMain)
    tabMainCorner.CornerRadius = UDim.new(0,8)

    local tabTeleport = Instance.new("TextButton", tabFrame)
    tabTeleport.Size = UDim2.new(0,80,1,0)
    tabTeleport.Position = UDim2.new(0,60,0,0)
    tabTeleport.Text = "Teleport"
    tabTeleport.BackgroundColor3 = Color3.new(0.2,0.2,0.2)
    tabTeleport.TextColor3 = Color3.new(1,1,1)
    tabTeleport.TextScaled = true
    local tabTeleportCorner = Instance.new("UICorner", tabTeleport)
    tabTeleportCorner.CornerRadius = UDim.new(0,8)

    tabMain.MouseButton1Click:Connect(function()
        mainPage.Visible = true
        teleportPage.Visible = false
        tabMain.BackgroundColor3 = Color3.new(0,0,0)
        tabTeleport.BackgroundColor3 = Color3.new(0.2,0.2,0.2)
    end)
    tabTeleport.MouseButton1Click:Connect(function()
        mainPage.Visible = false
        teleportPage.Visible = true
        tabTeleport.BackgroundColor3 = Color3.new(0,0,0)
        tabMain.BackgroundColor3 = Color3.new(0.2,0.2,0.2)
        updateTeleportList()
    end)
    tabMain.BackgroundColor3 = Color3.new(0,0,0)
    tabTeleport.BackgroundColor3 = Color3.new(0.2,0.2,0.2)

    userInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == Enum.KeyCode.M then
            guiMain.Visible = not guiMain.Visible
            hiddenLabel.Visible = not guiMain.Visible
            if guiMain.Visible then
                userInputService.MouseIconEnabled = true
                txtButton.Modal = true
                userInputService.MouseBehavior = Enum.MouseBehavior.Default
            else
                userInputService.MouseIconEnabled = false
                txtButton.Modal = false
                userInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
            end
        end
    end)
    
    styleAllText(screenGui)
end

function styleAllText(screenGui)
    for _, obj in pairs(screenGui:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            if obj.Name == "HiddenLabel" then
                obj.TextScaled = false
                obj.TextSize = 24
                obj.TextWrapped = true
            else
                obj.Font = Enum.Font.SourceSansBold
                obj.TextStrokeTransparency = 0
                obj.TextStrokeColor3 = Color3.new(0,0,0)
                obj.TextSize = 36
            end
        end
    end
end

createGUI()

player.CharacterAdded:Connect(function()
    task.wait(1)
    createGUI()
end)

userInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.N then
        userInputService.MouseIconEnabled = not userInputService.MouseIconEnabled
    end
end)

runService.RenderStepped:Connect(function(delta)
    if teleportLoopEnabled 
       and selectedTeleportPlayer 
       and selectedTeleportPlayer.Character 
       and selectedTeleportPlayer.Character:FindFirstChild("HumanoidRootPart")
       and player.Character 
       and player.Character:FindFirstChild("HumanoidRootPart") then
        local targetHRP = selectedTeleportPlayer.Character.HumanoidRootPart
        local offset = 1.5
        local newPos = targetHRP.Position + targetHRP.CFrame.LookVector * offset
        player.Character.HumanoidRootPart.CFrame = CFrame.new(newPos, targetHRP.Position)
        camera.CFrame = CFrame.new(camera.CFrame.Position, targetHRP.Position)
    end
end)

runService.RenderStepped:Connect(function(delta)
    local cam = workspace.CurrentCamera
    cam.CameraType = Enum.CameraType.Custom
end)
