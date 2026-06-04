-- Priority.Dev Hub | Auto Play + Auto Steal + Inf Jump + Auto Bat + Drop + TpDown + AntiRagdoll
-- GUI: Twayve Hub Style (Extended)
-- Авто-скорость: 55 без мозга, 29 с мозгом в руках
-- Auto Left/Right: возвращается на позицию кражи только если брейнрот в руках
-- ПКМ на кнопке = сменить бинд

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local Stats = game:GetService("Stats")
local Player = Players.LocalPlayer

-- ========== WAYPOINTS ==========
local leftWaypoints = {
    Vector3.new(-476.85, -6.59, 94.91), Vector3.new(-485.55, -4.53, 100.61),
    Vector3.new(-475.60, -6.59, 92.80), Vector3.new(-475.26, -6.57, 21.54),
}
local rightWaypoints = {
    Vector3.new(-475.77, -6.57, 26.76), Vector3.new(-485.85, -4.48, 20.13),
    Vector3.new(-475.83, -6.59, 26.54), Vector3.new(-476.17, -6.09, 97.73),
}

-- ========== CONFIG ==========
local ConfigFileName = "PriorityDev_AutoPlay_Speeds.json"
local Values = { GoingSpeed = 55, StealSpeed = 29 }

local function loadConfig()
    if not readfile or not isfile then return end
    pcall(function()
        if isfile(ConfigFileName) then
            local data = HttpService:JSONDecode(readfile(ConfigFileName))
            Values.GoingSpeed = data.GoingSpeed or 55
            Values.StealSpeed = data.StealSpeed or 29
        end
    end)
end
local function saveConfig()
    if not writefile then return end
    pcall(function() writefile(ConfigFileName, HttpService:JSONEncode(Values)) end)
end
loadConfig()

-- ========== PROXY ==========
local proxy = nil
local function ensureProxy()
    local char = Player.Character; if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return nil end
    if not proxy or proxy.Parent ~= char then
        if proxy then proxy:Destroy() end
        proxy = Instance.new("Part"); proxy.Name = "PriorityDev_AutoPlayProxy"
        proxy.Size = Vector3.new(1,1,1); proxy.Transparency = 1; proxy.CanCollide = false; proxy.Massless = true; proxy.Parent = char
        local weld = Instance.new("Weld"); weld.Part0 = hrp; weld.Part1 = proxy; weld.C0 = CFrame.new(0,0,0); weld.Parent = proxy
    end
    return proxy
end

-- ========== MOVEMENT ==========
local function isCarryingBrainrot()
    local char = Player.Character
    if not char then return false end
    if Player:GetAttribute("Stealing") == true then return true end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.WalkSpeed < 20 then return true end
    return false
end
local function getDynamicSpeed()
    if isCarryingBrainrot() then return Values.StealSpeed else return Values.GoingSpeed end
end
local function moveTo(target, speed)
    local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local dir = (target - hrp.Position); local moveDir = Vector3.new(dir.X, 0, dir.Z).Unit
    local hum = Player.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum:Move(moveDir, false) end
    if proxy then
        local currentVel = proxy.AssemblyLinearVelocity
        proxy.AssemblyLinearVelocity = Vector3.new(moveDir.X * speed, currentVel.Y, moveDir.Z * speed)
    end
end
local function stopMoving()
    if proxy then proxy.AssemblyLinearVelocity = Vector3.new(0,0,0) end
    local hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum:Move(Vector3.zero, false) end
end

-- ========== PATROL (FIXED - бесконечный循环) ==========
local activeConnection, activeWaypoints, waypointIndex = nil, nil, 1
local returnToBase = false
local lastStealPos = nil

local function startPatrol(waypoints)
    if activeConnection then activeConnection:Disconnect() end
    activeWaypoints = waypoints; waypointIndex = 1; returnToBase = false; lastStealPos = nil
    ensureProxy()
    activeConnection = RunService.Stepped:Connect(function()
        if not activeWaypoints then return end
        local char = Player.Character; if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
        
        -- Проверяем: если украли брейнрот и ещё не возвращаемся
        if isCarryingBrainrot() and not returnToBase then
            returnToBase = true
            lastStealPos = hrp.Position -- Запоминаем где украли
        end
        
        -- Если возвращаемся и брейнрот пропал (донесли до базы)
        if returnToBase and not isCarryingBrainrot() then
            returnToBase = false
            lastStealPos = nil
        end
        
        local target
        if returnToBase and lastStealPos then
            -- Возвращаемся на позицию где украли
            target = lastStealPos
        else
            -- Идём по обычному маршруту (бесконечно)
            if waypointIndex > #activeWaypoints then
                waypointIndex = 1 -- Зацикливаем
            end
            target = activeWaypoints[waypointIndex]
        end
        
        if not target then return end
        
        local dist = (target - hrp.Position).Magnitude
        local speed = getDynamicSpeed()
        
        if dist < 2.5 then
            if returnToBase and lastStealPos then
                -- Вернулись на позицию кражи
                returnToBase = false
                lastStealPos = nil
                -- Продолжаем с текущей точки маршрута
            else
                -- Обычное движение по маршруту
                waypointIndex = waypointIndex + 1
                if waypointIndex > #activeWaypoints then
                    waypointIndex = 1 -- Зацикливаем (никогда не останавливаемся)
                end
            end
        else
            moveTo(target, speed)
        end
    end)
end

local function stopPatrol()
    if activeConnection then activeConnection:Disconnect(); activeConnection = nil end
    activeWaypoints = nil; waypointIndex = 1; returnToBase = false; lastStealPos = nil; stopMoving()
end

-- ========== AUTO STEAL ==========
local STEAL_RADIUS, STEAL_DURATION = 60, 1.4
local isStealing, StealData, stealHeartbeatConn, progressFill, percentLabel = false, {}, nil, nil, nil
local function getHRP() local c = Player.Character; if c then return c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso") or c:FindFirstChild("UpperTorso") end end
local function isMyPlotByName(pn)
    local plots = workspace:FindFirstChild("Plots"); if not plots then return false end
    local plot = plots:FindFirstChild(pn); if not plot then return false end
    local sign = plot:FindFirstChild("PlotSign")
    if sign then local yb = sign:FindFirstChild("YourBase"); if yb and yb:IsA("BillboardGui") then return yb.Enabled == true end end
    return false
end
local function findNearestPrompt()
    local hrp = getHRP(); if not hrp then return nil end
    local plots = workspace:FindFirstChild("Plots"); if not plots then return nil end
    local nearest, dist = nil, math.huge
    for _, plot in ipairs(plots:GetChildren()) do
        if isMyPlotByName(plot.Name) then continue end
        local pods = plot:FindFirstChild("AnimalPodiums"); if not pods then continue end
        for _, pod in ipairs(pods:GetChildren()) do
            local base = pod:FindFirstChild("Base"); if not base then continue end
            local spawn = base:FindFirstChild("Spawn"); if not spawn then continue end
            local d = (spawn.Position - hrp.Position).Magnitude
            if d <= STEAL_RADIUS and d < dist then
                local att = spawn:FindFirstChild("PromptAttachment")
                if att then for _, p in ipairs(att:GetChildren()) do
                    if p:IsA("ProximityPrompt") and p.ActionText and p.ActionText:find("Steal") then nearest, dist = p, d end
                end end
            end
        end
    end
    return nearest
end
local function updateProgressBar(p)
    if progressFill then pcall(function() TweenService:Create(progressFill, TweenInfo.new(0.05, Enum.EasingStyle.Linear), {Size = UDim2.new(p, 0, 1, 0)}):Play() end) end
    if percentLabel then percentLabel.Text = math.floor(p * 100) .. "%" end
end
local function executeSteal(prompt)
    if isStealing then return end
    if not prompt or not prompt.Parent then return end
    if not StealData[prompt] then
        StealData[prompt] = {hold = {}, trigger = {}, ready = true}
        if getconnections then pcall(function()
            for _, c in ipairs(getconnections(prompt.PromptButtonHoldBegan)) do if c.Function then table.insert(StealData[prompt].hold, c.Function) end end
            for _, c in ipairs(getconnections(prompt.Triggered)) do if c.Function then table.insert(StealData[prompt].trigger, c.Function) end end
        end) end
    end
    local data = StealData[prompt]; if not data.ready then return end
    data.ready = false; isStealing = true; local startTime = tick()
    task.spawn(function() for _, f in ipairs(data.hold) do pcall(f) end end)
    task.spawn(function()
        while tick() - startTime < STEAL_DURATION do
            local elapsed = tick() - startTime; local p = math.clamp(elapsed / STEAL_DURATION, 0, 1)
            updateProgressBar(p); task.wait()
        end
        updateProgressBar(1); for _, f in ipairs(data.trigger) do pcall(f) end
        task.wait(0.1); updateProgressBar(0); data.ready = true; isStealing = false
    end)
end
local function startAutoSteal()
    if stealHeartbeatConn then return end; updateProgressBar(0)
    stealHeartbeatConn = RunService.Heartbeat:Connect(function()
        if isStealing then return end
        local success, prompt = pcall(findNearestPrompt)
        if success and prompt then pcall(executeSteal, prompt) end
    end)
end
local function stopAutoSteal()
    if stealHeartbeatConn then stealHeartbeatConn:Disconnect(); stealHeartbeatConn = nil end
    isStealing = false; updateProgressBar(0)
end

-- ========== INF JUMP ==========
local infJumpActive, infJumpHeartbeatConn, infJumpUserConn = false, nil, nil
local JUMP_FORCE, CLAMP_FALL_SPEED = 50, 80
local function startInfJump()
    if infJumpHeartbeatConn then return end
    infJumpHeartbeatConn = RunService.Heartbeat:Connect(function()
        if not infJumpActive then return end
        local char = Player.Character; if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp and hrp.Velocity.Y < -CLAMP_FALL_SPEED then hrp.Velocity = Vector3.new(hrp.Velocity.X, -CLAMP_FALL_SPEED, hrp.Velocity.Z) end
    end)
    infJumpUserConn = UserInputService.JumpRequest:Connect(function()
        if not infJumpActive then return end
        local char = Player.Character; if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.Velocity = Vector3.new(hrp.Velocity.X, JUMP_FORCE, hrp.Velocity.Z) end
    end)
end
local function stopInfJump()
    if infJumpHeartbeatConn then infJumpHeartbeatConn:Disconnect(); infJumpHeartbeatConn = nil end
    if infJumpUserConn then infJumpUserConn:Disconnect(); infJumpUserConn = nil end
end

-- ========== AUTO BAT ==========
local autoBatEnabled, autoSwingEnabled, autoBatConn = false, true, nil
local AUTO_BAT_SPEED, AUTO_BAT_DIST, AUTO_BAT_HEIGHT, AUTO_BAT_V_OFF = 58, -2.8, 4.75, 1
local AUTO_BAT_TURN_SPEED, AUTO_BAT_MAX_TURN_RATE = 285, 28
local _autoBatTarget, _autoBatLastScan = nil, 0
local function getAutoBatTarget()
    local root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local now = tick()
    if now - _autoBatLastScan <= 0.1 and _autoBatTarget and _autoBatTarget.Parent then
        local hum = _autoBatTarget.Parent:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then return _autoBatTarget end
    end
    _autoBatLastScan = now; _autoBatTarget = nil
    local closest, minDist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= Player and plr.Character then
            local tRoot = plr.Character:FindFirstChild("HumanoidRootPart")
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if tRoot and hum and hum.Health > 0 then
                local dist = (tRoot.Position - root.Position).Magnitude
                if dist < minDist then minDist = dist; closest = tRoot end
            end
        end
    end
    _autoBatTarget = closest; return _autoBatTarget
end
local function findBatTool()
    local c = Player.Character; if not c then return nil end
    local bp = Player:FindFirstChildOfClass("Backpack")
    for _, ch in ipairs(c:GetChildren()) do if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end end
    if bp then for _, ch in ipairs(bp:GetChildren()) do if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end end end
    local SlapList = {"Bat","Slap","Iron Slap","Gold Slap","Diamond Slap","Emerald Slap","Ruby Slap","Dark Matter Slap","Flame Slap","Nuclear Slap","Galaxy Slap","Glitched Slap"}
    for _, name in ipairs(SlapList) do local t = c:FindFirstChild(name) or (bp and bp:FindFirstChild(name)); if t then return t end end
end
local function startAutoBat()
    if autoBatConn then return end
    if autoLeftEnabled then autoLeftEnabled = false; if updateButtonUI then updateButtonUI() end; stopAutoLeft() end
    if autoRightEnabled then autoRightEnabled = false; if updateButtonUI then updateButtonUI() end; stopAutoRight() end
    autoBatEnabled = true
    autoBatConn = RunService.Heartbeat:Connect(function()
        if not autoBatEnabled then return end
        local char = Player.Character; if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid"); local root = char:FindFirstChild("HumanoidRootPart")
        if not root or not hum then return end
        if not char:FindFirstChildOfClass("Tool") then
            local bpBat = findBatTool()
            if bpBat and bpBat.Parent ~= char then pcall(function() hum:EquipTool(bpBat) end) end
        end
        local target = getAutoBatTarget()
        if target then
            local targetVel = target.AssemblyLinearVelocity
            local aimTargetPos = target.Position + (targetVel * math.clamp(targetVel.Magnitude / 130, 0.05, 0.15)) + Vector3.new(0, AUTO_BAT_V_OFF, 0)
            hum.AutoRotate = false
            local look = aimTargetPos - root.Position; local flatLook = Vector3.new(look.X, 0, look.Z)
            if look.Magnitude > 0.01 and flatLook.Magnitude > 0.01 then
                local targetYaw = math.deg(math.atan2(-flatLook.X, -flatLook.Z))
                local yawDelta = (targetYaw - root.Orientation.Y + 180) % 360 - 180
                local targetPitch = math.deg(math.atan2(look.Y, flatLook.Magnitude))
                local pitchDelta = (targetPitch - root.Orientation.X + 180) % 360 - 180
                local yawRate = math.clamp(math.rad(yawDelta) * AUTO_BAT_TURN_SPEED, -AUTO_BAT_MAX_TURN_RATE, AUTO_BAT_MAX_TURN_RATE)
                local pitchRate = math.clamp(math.rad(pitchDelta) * AUTO_BAT_TURN_SPEED, -AUTO_BAT_MAX_TURN_RATE, AUTO_BAT_MAX_TURN_RATE)
                local yawRad = math.rad(root.Orientation.Y); local rightAxis = Vector3.new(math.cos(yawRad), 0, -math.sin(yawRad))
                root.AssemblyAngularVelocity = Vector3.new(0, yawRate, 0) + (rightAxis * pitchRate)
            else root.AssemblyAngularVelocity = Vector3.zero end
            local dir = look.Magnitude > 0.01 and look.Unit or Vector3.zero
            local standPos = aimTargetPos - (dir * AUTO_BAT_DIST) + Vector3.new(0, AUTO_BAT_HEIGHT, 0)
            local moveDir = standPos - root.Position; local hDir = Vector3.new(moveDir.X, 0, moveDir.Z)
            local hVel = hDir.Magnitude > 0.1 and hDir.Unit * AUTO_BAT_SPEED or Vector3.zero
            local vVel = math.abs(moveDir.Y) > 0.1 and Vector3.new(0, math.sign(moveDir.Y) * 52, 0) or Vector3.new(0, -2, 0)
            root.AssemblyLinearVelocity = hVel + vVel
            if hDir.Magnitude > 0.5 then hum:Move(hDir.Unit, false) end
        else hum.AutoRotate = true; root.AssemblyAngularVelocity = Vector3.zero end
        if autoSwingEnabled then
            local bat = char:FindFirstChild("Bat")
            if bat and bat:IsA("Tool") then pcall(function() bat:Activate() end) end
        end
    end)
end
local function stopAutoBat()
    autoBatEnabled = false
    if autoBatConn then autoBatConn:Disconnect(); autoBatConn = nil end
    local char = Player.Character
    if char then local hum = char:FindFirstChildOfClass("Humanoid"); if hum then hum.AutoRotate = true end end
end

-- ========== DROP ==========
local dropActive, dropConnections = false, {}
local function runDrop()
    if dropActive then return end; dropActive = true
    local colConn = RunService.Stepped:Connect(function()
        if not dropActive then return end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= Player and p.Character then
                for _, part in ipairs(p.Character:GetChildren()) do if part:IsA("BasePart") then part.CanCollide = false end end
            end
        end
    end); table.insert(dropConnections, colConn)
    task.spawn(function()
        while dropActive do
            RunService.Heartbeat:Wait(); local char = Player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart"); if not root then break end
            local vel = root.Velocity; root.Velocity = vel * 10000 + Vector3.new(0, 10000, 0)
            RunService.RenderStepped:Wait(); if root and root.Parent then root.Velocity = vel end
            RunService.Stepped:Wait(); if root and root.Parent then root.Velocity = vel + Vector3.new(0, 0.1, 0) end
        end
    end)
    task.delay(0.1, function()
        dropActive = false
        for _, c in ipairs(dropConnections) do if typeof(c) == "RBXScriptConnection" then c:Disconnect() end end
        dropConnections = {}
    end)
end

-- ========== TP DOWN ==========
local function runTpDown()
    local char = Player.Character; if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    hrp.CFrame = CFrame.new(hrp.Position.X, -7.00, hrp.Position.Z) * CFrame.Angles(0, select(2, hrp.CFrame:ToEulerAnglesYXZ()), 0)
    hrp.AssemblyLinearVelocity = Vector3.zero
end

-- ========== ANTI RAGDOLL ==========
local antiRagdollEnabled, antiRagdollConn = false, nil
local function startAntiRagdoll()
    if antiRagdollConn then return end
    antiRagdollConn = RunService.Heartbeat:Connect(function()
        local char = Player.Character; if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid"); local root = char:FindFirstChild("HumanoidRootPart")
        if hum then
            local st = hum:GetState()
            if st == Enum.HumanoidStateType.Physics or st == Enum.HumanoidStateType.Ragdoll or st == Enum.HumanoidStateType.FallingDown then
                hum:ChangeState(Enum.HumanoidStateType.Running); workspace.CurrentCamera.CameraSubject = hum
                if root then root.Velocity = Vector3.zero; root.RotVelocity = Vector3.zero end
            end
        end
        for _, obj in ipairs(char:GetDescendants()) do if obj:IsA("Motor6D") and not obj.Enabled then obj.Enabled = true end end
    end)
end
local function stopAntiRagdoll()
    if antiRagdollConn then antiRagdollConn:Disconnect(); antiRagdollConn = nil end
end

-- ========== THEME ==========
local HAZE = {
    BG = Color3.fromRGB(2, 2, 12), SURF = Color3.fromRGB(8, 12, 28), SURF2 = Color3.fromRGB(14, 24, 52),
    TEXT = Color3.fromRGB(200, 240, 255), DIM = Color3.fromRGB(80, 160, 210),
    ACCENT = Color3.fromRGB(0, 200, 255), ACCENT2 = Color3.fromRGB(0, 120, 255),
    STROKE = Color3.fromRGB(0, 180, 255), ON_COLOR = Color3.fromRGB(140, 30, 255),
}
local function HazeCorner(p, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = p; return c end
local function HazeStroke(p, t, c, tr) local s = Instance.new("UIStroke"); s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Thickness = t or 1; s.Color = c or HAZE.STROKE; s.Transparency = tr or 0.5; s.Parent = p; return s end

-- ========== UI ==========
local Enabled = { AutoLeft = false, AutoRight = false, AutoSteal = false, InfJump = false, AutoBat = false, AntiRagdoll = false }
local updateButtonUI = nil
local infoLabel = nil
local Binds = {
    AutoLeft = Enum.KeyCode.Z, AutoRight = Enum.KeyCode.C, AutoSteal = Enum.KeyCode.V,
    InfJump = Enum.KeyCode.X, AutoBat = Enum.KeyCode.E, Drop = Enum.KeyCode.R,
    TpDown = Enum.KeyCode.F, AntiRagdoll = Enum.KeyCode.G,
}
local BindAction = {}
for action, key in pairs(Binds) do BindAction[key] = action end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PriorityDevHub"; screenGui.ResetOnSpawn = false
pcall(function()
    if gethui then screenGui.Parent = gethui()
    elseif syn and syn.protect_gui then syn.protect_gui(screenGui) screenGui.Parent = game:GetService("CoreGui")
    else screenGui.Parent = Player:WaitForChild("PlayerGui") end
end)

-- TOP BAR
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(0, 260, 0, 26); topBar.Position = UDim2.new(0.5, -130, 0, 10)
topBar.BackgroundColor3 = HAZE.BG; topBar.BackgroundTransparency = 0.03; topBar.BorderSizePixel = 0; topBar.Parent = screenGui
HazeCorner(topBar, 10); HazeStroke(topBar, 2, HAZE.STROKE, 0.25)
local topBarInner = Instance.new("Frame")
topBarInner.Size = UDim2.new(1, -4, 1, -4); topBarInner.Position = UDim2.new(0, 2, 0, 2)
topBarInner.BackgroundColor3 = HAZE.SURF; topBarInner.BorderSizePixel = 0; topBarInner.Parent = topBar; HazeCorner(topBarInner, 9)
infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, 0, 1, 0); infoLabel.BackgroundTransparency = 1
infoLabel.Font = Enum.Font.GothamBold; infoLabel.TextSize = 11; infoLabel.TextColor3 = HAZE.TEXT
infoLabel.Text = "Priority.Dev | Ping: 0ms | FPS: 0"; infoLabel.TextXAlignment = Enum.TextXAlignment.Center; infoLabel.Parent = topBarInner

-- PROGRESS BAR
local progressContainer = Instance.new("Frame")
progressContainer.Size = UDim2.new(0, 260, 0, 18); progressContainer.Position = UDim2.new(0.5, -130, 0, 40)
progressContainer.BackgroundColor3 = HAZE.BG; progressContainer.BackgroundTransparency = 0.03; progressContainer.BorderSizePixel = 0; progressContainer.Parent = screenGui
HazeCorner(progressContainer, 10); HazeStroke(progressContainer, 1.5, HAZE.STROKE, 0.3)
local progressBarBg = Instance.new("Frame")
progressBarBg.Size = UDim2.new(1, -6, 1, -6); progressBarBg.Position = UDim2.new(0, 3, 0, 3)
progressBarBg.BackgroundColor3 = Color3.fromRGB(8, 12, 28); progressBarBg.BorderSizePixel = 0; progressBarBg.Parent = progressContainer; HazeCorner(progressBarBg, 8)
progressFill = Instance.new("Frame")
progressFill.Size = UDim2.new(0, 0, 1, 0); progressFill.BackgroundColor3 = HAZE.ON_COLOR; progressFill.BorderSizePixel = 0; progressFill.Parent = progressBarBg; HazeCorner(progressFill, 8)
percentLabel = Instance.new("TextLabel")
percentLabel.Size = UDim2.new(1, 0, 1, 0); percentLabel.BackgroundTransparency = 1; percentLabel.Font = Enum.Font.GothamBold; percentLabel.TextSize = 10
percentLabel.TextColor3 = Color3.fromRGB(255, 255, 255); percentLabel.Text = "0%"; percentLabel.TextStrokeTransparency = 0.5; percentLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0); percentLabel.Parent = progressBarBg

-- MAIN PANEL
local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 160, 0, 304); panel.Position = UDim2.new(0.5, -80, 0.5, -120)
panel.BackgroundColor3 = HAZE.BG; panel.BackgroundTransparency = 0.03; panel.BorderSizePixel = 0; panel.Parent = screenGui
HazeCorner(panel, 18); HazeStroke(panel, 2, Color3.fromRGB(0, 120, 255), 0)

-- Header
local sHeader = Instance.new("Frame")
sHeader.Size = UDim2.new(1, 0, 0, 36); sHeader.BackgroundColor3 = HAZE.SURF; sHeader.BackgroundTransparency = 0; sHeader.BorderSizePixel = 0; sHeader.Parent = panel
HazeCorner(sHeader, 18)
local hdrBot = Instance.new("Frame", sHeader); hdrBot.Size = UDim2.new(1, 0, 0.5, 0); hdrBot.Position = UDim2.new(0, 0, 0.5, 0)
hdrBot.BackgroundColor3 = HAZE.SURF; hdrBot.BorderSizePixel = 0; HazeStroke(sHeader, 1, HAZE.STROKE, 0.42)
local titleAccent = Instance.new("Frame", sHeader)
titleAccent.Size = UDim2.fromOffset(3, 16); titleAccent.Position = UDim2.new(0, 10, 0.5, -8)
titleAccent.BackgroundColor3 = HAZE.ACCENT; titleAccent.BorderSizePixel = 0; HazeCorner(titleAccent, 999)
local sTitle = Instance.new("TextLabel")
sTitle.BackgroundTransparency = 1; sTitle.Position = UDim2.fromOffset(18, 2); sTitle.Size = UDim2.new(1, -30, 0, 16)
sTitle.Font = Enum.Font.GothamBlack; sTitle.Text = "Priority.Dev"; sTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
sTitle.TextSize = 12; sTitle.TextXAlignment = Enum.TextXAlignment.Left; sTitle.Parent = sHeader
local titleSub = Instance.new("TextLabel", sHeader)
titleSub.BackgroundTransparency = 1; titleSub.Position = UDim2.fromOffset(18, 18); titleSub.Size = UDim2.new(1, -30, 0, 12)
titleSub.Font = Enum.Font.GothamMedium; titleSub.Text = "Full Hub v6"; titleSub.TextColor3 = HAZE.ACCENT
titleSub.TextSize = 8; titleSub.TextXAlignment = Enum.TextXAlignment.Left

-- Drag
local dragging = false; local dragStart, startPos
sHeader.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = panel.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - dragStart
        panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)

-- Content
local content = Instance.new("Frame", panel)
content.Size = UDim2.new(1, -14, 1, -46); content.Position = UDim2.new(0, 7, 0, 40); content.BackgroundTransparency = 1

-- Speed Row
local function makeSpeedRow(y, label, key)
    local row = Instance.new("Frame", content)
    row.Size = UDim2.new(1, 0, 0, 22); row.Position = UDim2.new(0, 0, 0, y)
    row.BackgroundColor3 = HAZE.SURF2; row.BackgroundTransparency = 0.12; row.BorderSizePixel = 0; HazeCorner(row, 7); HazeStroke(row, 1, HAZE.STROKE, 0.55)
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(0.5, 0, 1, 0); lbl.Position = UDim2.new(0, 6, 0, 0); lbl.BackgroundTransparency = 1
    lbl.Text = label; lbl.TextColor3 = HAZE.TEXT; lbl.Font = Enum.Font.GothamMedium; lbl.TextSize = 9; lbl.TextXAlignment = Enum.TextXAlignment.Left
    local box = Instance.new("TextBox", row)
    box.Size = UDim2.new(0.35, 0, 0, 16); box.Position = UDim2.new(0.6, 0, 0.5, -8)
    box.BackgroundColor3 = Color3.fromRGB(14, 6, 24); box.Text = tostring(Values[key])
    box.TextColor3 = Color3.fromRGB(255, 255, 255); box.Font = Enum.Font.GothamBold; box.TextSize = 8; box.BorderSizePixel = 0; HazeCorner(box, 4); HazeStroke(box, 1, HAZE.STROKE, 0.5)
    box.FocusLost:Connect(function()
        local n = tonumber(box.Text)
        if n then n = math.clamp(n, 10, 200); Values[key] = n; box.Text = tostring(n); saveConfig() else box.Text = tostring(Values[key]) end
    end)
end
makeSpeedRow(0, "Going Spd", "GoingSpeed")
makeSpeedRow(26, "Steal Spd", "StealSpeed")

-- Универсальная функция создания кнопки с ПКМ-биндингом
local function makeBindableButton(y, actionName, defaultBind)
    local btn = Instance.new("TextButton", content)
    btn.Size = UDim2.new(1, 0, 0, 22); btn.Position = UDim2.new(0, 0, 0, y)
    btn.BackgroundColor3 = HAZE.SURF2; btn.BackgroundTransparency = 0.12
    btn.Font = Enum.Font.GothamBold; btn.TextSize = 8; btn.AutoButtonColor = false; btn.BorderSizePixel = 0; HazeCorner(btn, 7)
    local btnStroke = HazeStroke(btn, 1, HAZE.STROKE, 0.55)
    btn.Text = actionName .. " [" .. Binds[actionName].Name .. "]: OFF"; btn.TextColor3 = HAZE.DIM

    local function refreshText()
        local state = Enabled[actionName]
        local bindName = Binds[actionName].Name
        if state then
            btn.BackgroundColor3 = HAZE.ON_COLOR; btn.BackgroundTransparency = 0.1
            btn.Text = actionName .. " [" .. bindName .. "]: ON"; btn.TextColor3 = Color3.fromRGB(255,255,255)
            btnStroke.Transparency = 0.2; btnStroke.Color = HAZE.ON_COLOR
        else
            btn.BackgroundColor3 = HAZE.SURF2; btn.BackgroundTransparency = 0.12
            btn.Text = actionName .. " [" .. bindName .. "]: OFF"; btn.TextColor3 = HAZE.DIM
            btnStroke.Transparency = 0.55; btnStroke.Color = HAZE.STROKE
        end
    end

    btn.MouseButton2Click:Connect(function()
        local oldText = btn.Text
        btn.Text = actionName .. " [...]: ?"; btn.TextColor3 = HAZE.ACCENT
        local conn
        conn = UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                local newKey = input.KeyCode
                local oldAction = BindAction[Binds[actionName]]
                if oldAction then BindAction[Binds[actionName]] = nil end
                local conflictAction = BindAction[newKey]
                if conflictAction and conflictAction ~= actionName then BindAction[newKey] = nil end
                Binds[actionName] = newKey
                BindAction[newKey] = actionName
                refreshText()
                if conn then conn:Disconnect() end
            end
        end)
        task.delay(5, function()
            if conn and conn.Connected then conn:Disconnect(); refreshText() end
        end)
    end)

    btn.MouseButton1Click:Connect(function()
        Enabled[actionName] = not Enabled[actionName]
        local state = Enabled[actionName]
        if actionName == "AutoLeft" then
            if state then stopPatrol(); Enabled.AutoRight = false; startPatrol(leftWaypoints) else stopPatrol() end
        elseif actionName == "AutoRight" then
            if state then stopPatrol(); Enabled.AutoLeft = false; startPatrol(rightWaypoints) else stopPatrol() end
        elseif actionName == "AutoSteal" then
            if state then startAutoSteal() else stopAutoSteal() end
        elseif actionName == "InfJump" then
            infJumpActive = state; if state then startInfJump() else stopInfJump() end
        elseif actionName == "AutoBat" then
            if state then startAutoBat() else stopAutoBat() end
        elseif actionName == "AntiRagdoll" then
            antiRagdollEnabled = state; if state then startAntiRagdoll() else stopAntiRagdoll() end
        elseif actionName == "Drop" then
            runDrop(); Enabled.Drop = false
            task.delay(0.3, function() refreshText() end)
            return
        elseif actionName == "TpDown" then
            runTpDown(); Enabled.TpDown = false
            task.delay(0.3, function() refreshText() end)
            return
        end
        updateButtonUI()
    end)

    return btn, btnStroke, refreshText
end

local buttons = {}
local buttonRefreshers = {}
local actions = {
    {y = 52, name = "AutoLeft", default = Enum.KeyCode.Z},
    {y = 78, name = "AutoRight", default = Enum.KeyCode.C},
    {y = 104, name = "AutoSteal", default = Enum.KeyCode.V},
    {y = 130, name = "InfJump", default = Enum.KeyCode.X},
    {y = 156, name = "AutoBat", default = Enum.KeyCode.E},
    {y = 182, name = "Drop", default = Enum.KeyCode.R},
    {y = 208, name = "TpDown", default = Enum.KeyCode.F},
    {y = 234, name = "AntiRagdoll", default = Enum.KeyCode.G},
}
for _, a in ipairs(actions) do
    local btn, stroke, ref = makeBindableButton(a.y, a.name, a.default)
    buttons[a.name] = {btn = btn, stroke = stroke}
    buttonRefreshers[a.name] = ref
end

updateButtonUI = function()
    for _, ref in pairs(buttonRefreshers) do ref() end
end

-- ========== KEYBINDS ==========
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local action = BindAction[input.KeyCode]
    if not action then return end
    if action == "Drop" then runDrop()
    elseif action == "TpDown" then runTpDown()
    elseif action == "AutoLeft" then Enabled.AutoLeft = not Enabled.AutoLeft; if Enabled.AutoLeft then stopPatrol(); Enabled.AutoRight = false; startPatrol(leftWaypoints) else stopPatrol() end
    elseif action == "AutoRight" then Enabled.AutoRight = not Enabled.AutoRight; if Enabled.AutoRight then stopPatrol(); Enabled.AutoLeft = false; startPatrol(rightWaypoints) else stopPatrol() end
    elseif action == "AutoSteal" then Enabled.AutoSteal = not Enabled.AutoSteal; if Enabled.AutoSteal then startAutoSteal() else stopAutoSteal() end
    elseif action == "InfJump" then Enabled.InfJump = not Enabled.InfJump; infJumpActive = Enabled.InfJump; if Enabled.InfJump then startInfJump() else stopInfJump() end
    elseif action == "AutoBat" then Enabled.AutoBat = not Enabled.AutoBat; if Enabled.AutoBat then startAutoBat() else stopAutoBat() end
    elseif action == "AntiRagdoll" then Enabled.AntiRagdoll = not Enabled.AntiRagdoll; antiRagdollEnabled = Enabled.AntiRagdoll; if Enabled.AntiRagdoll then startAntiRagdoll() else stopAntiRagdoll() end
    end
    updateButtonUI()
end)

-- ========== FPS/PING ==========
task.spawn(function()
    local fps, ping = 60, 0; local framesCount, last = 0, tick()
    RunService.RenderStepped:Connect(function()
        framesCount = framesCount + 1
        if tick() - last >= 1 then fps = framesCount; framesCount = 0; last = tick() end
        local network = Stats:FindFirstChild("Network")
        if network and network:FindFirstChild("ServerStatsItem") then
            local dataPing = network.ServerStatsItem:FindFirstChild("Data Ping")
            if dataPing then ping = math.floor(dataPing:GetValue()) end
        end
        if infoLabel then infoLabel.Text = "Priority.Dev | Ping: " .. ping .. "ms | FPS: " .. fps end
    end)
end)

updateButtonUI()

-- Auto-anti drop
RunService.Stepped:Connect(function()
    local c = Player.Character
    if c then local hrp = c:FindFirstChild("HumanoidRootPart")
        if hrp and hrp.Position.Y < -10 then hrp.Position = Vector3.new(hrp.Position.X, -6.5, hrp.Position.Z) end
    end
end)

Player.CharacterAdded:Connect(function()
    task.wait(0.8)
    if Enabled.AutoLeft then stopPatrol(); startPatrol(leftWaypoints)
    elseif Enabled.AutoRight then stopPatrol(); startPatrol(rightWaypoints) end
end)
