
repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local Player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local HttpService = game:GetService("HttpService")

-- ========== ANTI DIE BYPASS (always on, no toggle) ==========
do
    local antiDieConn = nil

    local function hookAntiDie(character)
        if not character then return end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
            or character:WaitForChild("Humanoid", 10)
        if not humanoid then return end

        if antiDieConn then
            pcall(function() antiDieConn:Disconnect() end)
            antiDieConn = nil
        end

        antiDieConn = humanoid:GetPropertyChangedSignal("Health"):Connect(function()
            if humanoid.Health <= 0 then
                humanoid.Health = humanoid.MaxHealth
            end
        end)

        if humanoid.Health <= 0 then
            humanoid.Health = humanoid.MaxHealth
        end
    end

    if Player.Character then
        hookAntiDie(Player.Character)
    end

    Player.CharacterAdded:Connect(function(character)
        task.wait(0.1)
        hookAntiDie(character)
    end)

    RunService.Heartbeat:Connect(function()
        local character = Player.Character
        if not character then return end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health <= 0 then
            humanoid.Health = humanoid.MaxHealth
        end
    end)
end

-- ========== THEME ==========
local HAZE = {
    BG = Color3.fromRGB(6, 6, 10),
    SURF = Color3.fromRGB(12, 12, 18),
    SURF2 = Color3.fromRGB(18, 17, 26),
    CARD = Color3.fromRGB(15, 14, 22),
    CARD_ON = Color3.fromRGB(22, 18, 36),
    TEXT = Color3.fromRGB(236, 234, 244),
    DIM = Color3.fromRGB(130, 126, 148),
    MUTED = Color3.fromRGB(88, 84, 102),
    ACCENT = Color3.fromRGB(148, 116, 218),
    ACCENT2 = Color3.fromRGB(196, 168, 244),
    CYAN = Color3.fromRGB(0, 200, 255),
    STROKE = Color3.fromRGB(48, 42, 78),
    STROKE_ON = Color3.fromRGB(138, 111, 205),
    SUCCESS = Color3.fromRGB(72, 220, 140),
    DANGER = Color3.fromRGB(255, 92, 120),
}

local TWEEN_FAST = TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local TWEEN_SNAP = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_SMOOTH = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TWEEN_SPRING = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TWEEN_DRAG = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function Round(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r)
    c.Parent = p
    return c
end

local function Stroke(p, t, c, tr)
    local s = Instance.new("UIStroke")
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Thickness = t or 1
    s.Color = c or HAZE.STROKE
    s.Transparency = tr or 0.5
    s.Parent = p
    return s
end

local function Gradient(parent, colors, rotation)
    local g = Instance.new("UIGradient", parent)
    g.Color = ColorSequence.new(colors)
    g.Rotation = rotation or 0
    return g
end

local function Tween(inst, props, info)
    TweenService:Create(inst, info or TWEEN_FAST, props):Play()
end

local function addGlowStack(parent, color, layers)
    local strokes = {}
    for i = layers or 2, 1, -1 do
        local s = Instance.new("UIStroke")
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        s.Thickness = 0.6 + ((layers or 2) - i + 1) * 1.0
        s.Color = color or HAZE.ACCENT
        s.Transparency = 0.5 + i * 0.18
        s.Parent = parent
        strokes[#strokes + 1] = s
    end
    return strokes
end

local function pulseStrokes(strokes, minT, maxT, speed)
    local t = 0
    RunService.RenderStepped:Connect(function(dt)
        if not strokes[1] or not strokes[1].Parent then return end
        t = t + dt * (speed or 1.6)
        local blend = (math.sin(t) + 1) * 0.5
        local tr = minT + (maxT - minT) * blend
        for _, s in ipairs(strokes) do
            if s.Parent then
                s.Transparency = math.clamp(tr + s.Thickness * 0.015, 0, 1)
            end
        end
    end)
end

local function addSheenOverlay(parent, corner)
    local sheen = Instance.new("Frame")
    sheen.Name = "Sheen"
    sheen.Size = UDim2.fromScale(1, 1)
    sheen.BackgroundTransparency = 0.9
    sheen.BorderSizePixel = 0
    sheen.ZIndex = (parent.ZIndex or 1) + 2
    sheen.Active = false
    sheen.Parent = parent
    Round(sheen, corner or 14)
    local grad = Gradient(sheen, {
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.4, Color3.fromRGB(170, 130, 255)),
        ColorSequenceKeypoint.new(0.55, Color3.fromRGB(0, 210, 255)),
        ColorSequenceKeypoint.new(0.7, Color3.fromRGB(170, 130, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
    }, 20)
    task.spawn(function()
        local rot = 20
        while sheen.Parent do
            rot = rot + 2.5
            grad.Rotation = rot
            task.wait(0.03)
        end
    end)
    return sheen
end

local function enableSmoothDrag(handle, frame)
    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local startPos = nil

    local dragZone = Instance.new("TextButton")
    dragZone.Name = "DragZone"
    dragZone.Size = UDim2.fromScale(1, 1)
    dragZone.BackgroundTransparency = 1
    dragZone.Text = ""
    dragZone.AutoButtonColor = false
    dragZone.ZIndex = (handle.ZIndex or 1) + 8
    dragZone.Parent = handle

    local function onDragBegan(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        dragging = true
        dragInput = input
        dragStart = input.Position
        startPos = frame.Position
        Tween(frame, {Rotation = 0.35}, TWEEN_SNAP)
    end

    dragZone.InputBegan:Connect(onDragBegan)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging or input ~= dragInput then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input ~= dragInput then return end
        dragging = false
        dragInput = nil
        Tween(frame, {Rotation = 0}, TWEEN_DRAG)
    end)
end

local function parentToSafeGui(screenGui)
    pcall(function()
        if gethui then
            screenGui.Parent = gethui()
        elseif syn and syn.protect_gui then
            syn.protect_gui(screenGui)
            screenGui.Parent = game:GetService("CoreGui")
        else
            screenGui.Parent = Player:WaitForChild("PlayerGui")
        end
    end)
end

-- ========== CONFIG ==========
local CONFIG_FILE = "PriorityDevMain_Config.json"

-- ========== BINDS ==========
local Binds = {
    InfJump = Enum.KeyCode.X,
    AntiRagdoll = Enum.KeyCode.G,
    AutoBat = Enum.KeyCode.E,
    Drop = Enum.KeyCode.R,
    TpDown = Enum.KeyCode.F,
    StealSpeed = Enum.KeyCode.V,
    AutoSteal = Enum.KeyCode.B,
    AutoJoiner = Enum.KeyCode.M,
    AutoTurret = Enum.KeyCode.T,
    InstaReset = Enum.KeyCode.Q,
    AutoLeave = Enum.KeyCode.U,
    AutoCloner = Enum.KeyCode.N,
    InvisibleSteal = Enum.KeyCode.H,
    AntiEffect = Enum.KeyCode.P,
}
local BindAction = {}
for action, key in pairs(Binds) do
    BindAction[key] = action
end

-- ========== STATE ==========
local infJumpActive = false
local antiRagdollEnabled = false
local antiEffectEnabled = false
local antiEffectApplied = false
local autoBatEnabled = false
local autoSwingEnabled = true
local stealSpeedEnabled = false
local stealSpeedConn = nil
local STEAL_SPEED = 28
local autoStealEnabled = false
local autoStealConn = nil
local isStealing = false
local function isHoldingBrainrot()
    return Player:GetAttribute("Stealing") == true
end
local StealData = {}
local currentStealName = ""
local bestStealPrompt = nil
local bestStealAnimal = nil
local bestStealPart = nil
local autoJoinerEnabled = false
local autoJoinerConn = nil
local isJoining = false
local MIN_JOIN_VALUE = 20000000
local autoTurretEnabled = false
local autoTurretConn = nil
local lastTurretTick = 0
local TURRET_TICK_DELAY = 0.5
local isResetting = false
local resetCFrame = CFrame.new(1000003.56, 999999.69, 8.17)
local autoLeaveEnabled = false
local invisibleStealEnabled = false
local invisibleGui = nil
local setInvisibleStealPanelVisible
local invisFeatureActive = false
local InvisSettings = {
    Angle = 233,
    Depth = 5,
    AutoRecover = true,
    AutoOnSteal = false,
}
local InvisPanelRefs = {}
local STEAL_RADIUS = 300
local STEAL_DURATION = 1.4
local progressFill = nil
local percentLabel = nil
local stealNameLabel = nil
local buttonStates = {}

-- ========== TOP BRAINROT LABEL ==========
local topBrainrotLabel = nil

-- ========== ALL ANIMALS CACHE ==========
local allAnimalsCache = {}
local lastAnimalData = {}

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Synchronizer = require(Packages:WaitForChild("Synchronizer"))
local Datas = ReplicatedStorage:WaitForChild("Datas")
local AnimalsData = require(Datas:WaitForChild("Animals"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimalsShared = require(Shared:WaitForChild("Animals"))
local Utils = ReplicatedStorage:WaitForChild("Utils")
local NumberUtils = require(Utils:WaitForChild("NumberUtils"))

local function getAnimalHash(al)
    if not al then return "" end
    local h = ""
    for slot, d in pairs(al) do
        if type(d) == "table" then
            h = h .. tostring(slot) .. tostring(d.Index) .. tostring(d.Mutation)
        end
    end
    return h
end

local function isMyPlotByName(pn)
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return false end
    local plot = plots:FindFirstChild(pn)
    if not plot then return false end
    local sign = plot:FindFirstChild("PlotSign")
    if sign then
        local yb = sign:FindFirstChild("YourBase")
        if yb and yb:IsA("BillboardGui") then return yb.Enabled == true end
    end
    return false
end

local function scanSinglePlot(plot)
    pcall(function()
        local ch = Synchronizer:Get(plot.Name)
        if not ch then return end
        local al = ch:Get("AnimalList")
        local owner = ch:Get("Owner")
        if not owner or not owner.Name or not Players:FindFirstChild(owner.Name) then
            lastAnimalData[plot.Name] = nil
            for i = #allAnimalsCache, 1, -1 do
                if allAnimalsCache[i].plot == plot.Name then table.remove(allAnimalsCache, i) end
            end
            return
        end
        local hash = getAnimalHash(al)
        if lastAnimalData[plot.Name] == hash then return end
        lastAnimalData[plot.Name] = hash
        for i = #allAnimalsCache, 1, -1 do
            if allAnimalsCache[i].plot == plot.Name then table.remove(allAnimalsCache, i) end
        end
        local ownerName = owner.Name
        if not al then return end
        for slot, ad in pairs(al) do
            if type(ad) == "table" then
                local aName = ad.Index
                local aInfo = AnimalsData[ad.Index]
                if aInfo then
                    local mut = ad.Mutation or "None"
                    if mut == "Yin Yang" then mut = "YinYang" end
                    local gv = AnimalsShared:GetGeneration(aName, ad.Mutation, ad.Traits, nil)
                    local gt = "$" .. NumberUtils:ToString(gv) .. "/s"
                    table.insert(allAnimalsCache, {
                        name = aInfo.DisplayName or aName,
                        genText = gt,
                        genValue = gv,
                        mutation = mut,
                        owner = ownerName,
                        plot = plot.Name,
                        slot = tostring(slot),
                        uid = plot.Name .. "_" .. tostring(slot)
                    })
                end
            end
        end
        table.sort(allAnimalsCache, function(a, b) return a.genValue > b.genValue end)
    end)
end

local function forceScanAllPlots()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return end
    for _, plot in ipairs(plots:GetChildren()) do
        scanSinglePlot(plot)
    end
end

local function setupPlotListeners()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return end
    for _, plot in ipairs(plots:GetChildren()) do
        scanSinglePlot(plot)
        plot.DescendantAdded:Connect(function() task.wait(0.1); scanSinglePlot(plot) end)
        plot.DescendantRemoving:Connect(function() task.wait(0.1); scanSinglePlot(plot) end)
    end
    plots.ChildAdded:Connect(function(p) task.wait(0.5); scanSinglePlot(p); setupPlotListeners() end)
end
task.spawn(setupPlotListeners)

-- ========== SOUND ALERT ==========
local lastAlertTime = 0
local ALERT_COOLDOWN = 10

local function playAlertSound()
    local now = tick()
    if now - lastAlertTime < ALERT_COOLDOWN then return end
    lastAlertTime = now
    pcall(function()
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://4590662766"
        sound.Volume = 10
        sound.Parent = Player:WaitForChild("PlayerGui")
        sound:Play()
        task.delay(3, function() pcall(function() sound:Destroy() end) end)
    end)
end

-- ========== INF JUMP ==========
local infJumpHeartbeatConn = nil
local infJumpUserConn = nil
local JUMP_FORCE = 50
local CLAMP_FALL_SPEED = 80

local function startInfJump()
    if infJumpHeartbeatConn then return end
    infJumpHeartbeatConn = RunService.Heartbeat:Connect(function()
        if not infJumpActive then return end
        local c = Player.Character
        if not c then return end
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if hrp and hrp.Velocity.Y < -CLAMP_FALL_SPEED then
            hrp.Velocity = Vector3.new(hrp.Velocity.X, -CLAMP_FALL_SPEED, hrp.Velocity.Z)
        end
    end)
    infJumpUserConn = UserInputService.JumpRequest:Connect(function()
        if not infJumpActive then return end
        local c = Player.Character
        if not c then return end
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.Velocity = Vector3.new(hrp.Velocity.X, JUMP_FORCE, hrp.Velocity.Z) end
    end)
end

local function stopInfJump()
    if infJumpHeartbeatConn then infJumpHeartbeatConn:Disconnect(); infJumpHeartbeatConn = nil end
    if infJumpUserConn then infJumpUserConn:Disconnect(); infJumpUserConn = nil end
end

-- ========== ANTI RAGDOLL V2 ==========
local AntiRagdollV2Data = { antiRagdollConns = {} }
local antiRagdollConns = AntiRagdollV2Data.antiRagdollConns
local cleanRagdollV2Scheduled = false

local function isRagdollRelatedDescendant(obj)
    if obj:IsA("BallSocketConstraint") or obj:IsA("NoCollisionConstraint") or obj:IsA("HingeConstraint") then return true end
    if obj:IsA("Attachment") and (obj.Name == "A" or obj.Name == "B") then return true end
    if obj:IsA("BodyVelocity") or obj:IsA("BodyPosition") or obj:IsA("BodyGyro") then return true end
    return false
end

local function cleanRagdollV2(char)
    if not char then return end
    local carpetEquipped = false
    pcall(function()
        local tool = char:FindFirstChild("Flying Carpet") or char:FindFirstChild("FlyingCarpet")
        if tool then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                for _, obj in ipairs(hrp:GetChildren()) do
                    if obj:IsA("BodyVelocity") or obj:IsA("BodyPosition") or obj:IsA("BodyGyro") then
                        carpetEquipped = true; break
                    end
                end
            end
            if not carpetEquipped then
                for _, obj in ipairs(tool:GetChildren()) do
                    if obj:IsA("BodyVelocity") or obj:IsA("BodyPosition") or obj:IsA("BodyGyro") then
                        carpetEquipped = true; break
                    end
                end
            end
        end
    end)
    local descendants = char:GetDescendants()
    for _, d in ipairs(descendants) do
        if d:IsA("BallSocketConstraint") or d:IsA("NoCollisionConstraint") or d:IsA("HingeConstraint") or (d:IsA("Attachment") and (d.Name == "A" or d.Name == "B")) then
            d:Destroy()
        elseif (d:IsA("BodyVelocity") or d:IsA("BodyPosition") or d:IsA("BodyGyro")) and not carpetEquipped then
            d:Destroy()
        end
    end
    for _, d in ipairs(descendants) do
        if d:IsA("Motor6D") then d.Enabled = true end
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        local animator = hum:FindFirstChild("Animator")
        if animator then
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                local n = track.Animation and track.Animation.Name:lower() or ""
                if n:find("rag") or n:find("fall") or n:find("hurt") or n:find("down") then track:Stop(0) end
            end
        end
    end
    task.defer(function()
        pcall(function()
            local pm = Player:FindFirstChild("PlayerScripts")
            if pm then pm = pm:FindFirstChild("PlayerModule") end
            if pm then require(pm):GetControls():Enable() end
        end)
    end)
end

local function cleanRagdollV2Debounced(char)
    if cleanRagdollV2Scheduled then return end
    cleanRagdollV2Scheduled = true
    task.defer(function()
        cleanRagdollV2Scheduled = false
        if char and char.Parent then cleanRagdollV2(char) end
    end)
end

local function stopAntiRagdollV2()
    cleanRagdollV2Scheduled = false
    for _, c in ipairs(antiRagdollConns) do pcall(function() c:Disconnect() end) end
    AntiRagdollV2Data.antiRagdollConns = {}
    antiRagdollConns = AntiRagdollV2Data.antiRagdollConns
end

local function hookAntiRagV2(char)
    stopAntiRagdollV2()
    local hum = char:WaitForChild("Humanoid", 10)
    local hrp = char:WaitForChild("HumanoidRootPart", 10)
    if not hum or not hrp then return end
    local lastVel = Vector3.new(0, 0, 0)
    local c1 = hum.StateChanged:Connect(function()
        local st = hum:GetState()
        if st == Enum.HumanoidStateType.Physics or st == Enum.HumanoidStateType.Ragdoll or st == Enum.HumanoidStateType.FallingDown or st == Enum.HumanoidStateType.GettingUp then
            local carpetActive = false
            pcall(function()
                local tool = char:FindFirstChild("Flying Carpet") or char:FindFirstChild("FlyingCarpet")
                if tool and hrp then
                    for _, obj in ipairs(hrp:GetChildren()) do
                        if obj:IsA("BodyVelocity") or obj:IsA("BodyPosition") or obj:IsA("BodyGyro") then carpetActive = true end
                    end
                end
            end)
            if not carpetActive then hum:ChangeState(Enum.HumanoidStateType.Running) end
            cleanRagdollV2(char)
            pcall(function() workspace.CurrentCamera.CameraSubject = hum end)
            pcall(function()
                local pm = Player:FindFirstChild("PlayerScripts")
                if pm then pm = pm:FindFirstChild("PlayerModule") end
                if pm then require(pm):GetControls():Enable() end
            end)
        end
    end)
    table.insert(antiRagdollConns, c1)
    local c2 = char.DescendantAdded:Connect(function(desc)
        if isRagdollRelatedDescendant(desc) then cleanRagdollV2Debounced(char) end
    end)
    table.insert(antiRagdollConns, c2)
    local c3 = RunService.Heartbeat:Connect(function()
        local st = hum:GetState()
        if st == Enum.HumanoidStateType.Physics or st == Enum.HumanoidStateType.Ragdoll or st == Enum.HumanoidStateType.FallingDown or st == Enum.HumanoidStateType.GettingUp then
            cleanRagdollV2(char)
            local vel = hrp.AssemblyLinearVelocity
            if (vel - lastVel).Magnitude > 40 and vel.Magnitude > 25 then
                hrp.AssemblyLinearVelocity = vel.Unit * math.min(vel.Magnitude, 15)
            end
        end
        lastVel = hrp.AssemblyLinearVelocity
    end)
    table.insert(antiRagdollConns, c3)
    cleanRagdollV2(char)
end

local function startAntiRagdollV2()
    stopAntiRagdollV2()
    if not antiRagdollEnabled then return end
    local char = Player.Character
    if char then task.spawn(function() hookAntiRagV2(char) end) end
    Player.CharacterAdded:Connect(function(c)
        if not antiRagdollEnabled then return end
        task.spawn(function() hookAntiRagV2(c) end)
    end)
end

-- ========== ANTI EFFECT ==========
local function applyAntiEffectPatch()
    if antiEffectApplied then return true end
    local ok, patched = pcall(function()
        local Sync = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Synchronizer"))
        local count = 0
        for _, fn in pairs(Sync) do
            if typeof(fn) ~= "function" then continue end
            if isexecutorclosure and isexecutorclosure(fn) then continue end
            local okUps, ups = pcall(debug.getupvalues, fn)
            if not okUps then continue end
            for idx, val in pairs(ups) do
                if typeof(val) == "function" and (not isexecutorclosure or not isexecutorclosure(val)) then
                    local ok2, innerUps = pcall(debug.getupvalues, val)
                    if ok2 then
                        local hasBoolean = false
                        for _, v in pairs(innerUps) do
                            if typeof(v) == "boolean" then
                                hasBoolean = true
                                break
                            end
                        end
                        if hasBoolean then
                            local emptyFn = newcclosure and newcclosure(function() end) or function() end
                            debug.setupvalue(fn, idx, emptyFn)
                            count += 1
                        end
                    end
                end
            end
        end
        return count
    end)
    if ok then
        antiEffectApplied = true
        print("[Priority.Dev] Anti Effect applied (" .. tostring(patched) .. " patches)")
        return true
    end
    warn("[Priority.Dev] Anti Effect failed:", patched)
    return false
end

local function startAntiEffect()
    antiEffectEnabled = true
    applyAntiEffectPatch()
end

local function stopAntiEffect()
    antiEffectEnabled = false
end

-- ========== AUTO BAT ==========
local autoBatConn = nil
local AUTO_BAT_SPEED = 58
local AUTO_BAT_DIST = -2.8
local AUTO_BAT_HEIGHT = 4.75
local AUTO_BAT_V_OFF = 1
local AUTO_BAT_TURN_SPEED = 285
local AUTO_BAT_MAX_TURN_RATE = 28
local _autoBatTarget = nil
local _autoBatLastScan = 0

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
    _autoBatTarget = closest
    return _autoBatTarget
end

local function findBatTool()
    local c = Player.Character
    if not c then return nil end
    local bp = Player:FindFirstChildOfClass("Backpack")
    for _, ch in ipairs(c:GetChildren()) do if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end end
    if bp then for _, ch in ipairs(bp:GetChildren()) do if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end end end
    local SlapList = {"Bat","Slap","Iron Slap","Gold Slap","Diamond Slap","Emerald Slap","Ruby Slap","Dark Matter Slap","Flame Slap","Nuclear Slap","Galaxy Slap","Glitched Slap"}
    for _, name in ipairs(SlapList) do local t = c:FindFirstChild(name) or (bp and bp:FindFirstChild(name)); if t then return t end end
    return nil
end

local function startAutoBat()
    if autoBatConn then return end
    autoBatEnabled = true
    autoBatConn = RunService.Heartbeat:Connect(function()
        if not autoBatEnabled then return end
        local c = Player.Character; if not c then return end
        local hum = c:FindFirstChildOfClass("Humanoid"); local root = c:FindFirstChild("HumanoidRootPart")
        if not root or not hum then return end
        if not c:FindFirstChildOfClass("Tool") then
            local bpBat = findBatTool()
            if bpBat and bpBat.Parent ~= c then pcall(function() hum:EquipTool(bpBat) end) end
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
            local bat = c:FindFirstChild("Bat")
            if bat and bat:IsA("Tool") then pcall(function() bat:Activate() end) end
        end
    end)
end

local function stopAutoBat()
    autoBatEnabled = false
    if autoBatConn then autoBatConn:Disconnect(); autoBatConn = nil end
    local c = Player.Character
    if c then local hum = c:FindFirstChildOfClass("Humanoid"); if hum then hum.AutoRotate = true end end
end

-- ========== DROP ==========
local dropActive = false
local dropConnections = {}

local function runDrop()
    if dropActive then return end; dropActive = true
    local colConn = RunService.Stepped:Connect(function()
        if not dropActive then return end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= Player and p.Character then
                for _, part in ipairs(p.Character:GetChildren()) do if part:IsA("BasePart") then part.CanCollide = false end end
            end
        end
    end)
    table.insert(dropConnections, colConn)
    task.spawn(function()
        while dropActive do
            RunService.Heartbeat:Wait(); local c = Player.Character
            local root = c and c:FindFirstChild("HumanoidRootPart"); if not root then break end
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
    local c = Player.Character; if not c then return end
    local hrp = c:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    hrp.CFrame = CFrame.new(hrp.Position.X, -7.00, hrp.Position.Z) * CFrame.Angles(0, select(2, hrp.CFrame:ToEulerAnglesYXZ()), 0)
    hrp.AssemblyLinearVelocity = Vector3.zero
end

-- ========== STEAL SPEED ==========
local function applyStealSpeed()
    if not stealSpeedEnabled or invisFeatureActive then return end
    local c = Player.Character
    local root = c and c:FindFirstChild("HumanoidRootPart")
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end
    local moveDir = hum.MoveDirection
    if moveDir.Magnitude > 0 then
        root.AssemblyLinearVelocity = Vector3.new(moveDir.X * STEAL_SPEED, root.AssemblyLinearVelocity.Y, moveDir.Z * STEAL_SPEED)
    end
end

local function startStealSpeed()
    if stealSpeedConn then return end
    stealSpeedConn = RunService.Heartbeat:Connect(applyStealSpeed)
end
local function stopStealSpeed()
    if stealSpeedConn then stealSpeedConn:Disconnect(); stealSpeedConn = nil end
end

-- ========== AUTO STEAL ==========
local function getHRP()
    local c = Player.Character
    if c then return c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso") or c:FindFirstChild("UpperTorso") end
    return nil
end

local function findBestPrompt()
    local hrp = getHRP()
    if not hrp then return nil, nil, nil end
    for _, animalData in ipairs(allAnimalsCache) do
        if animalData.genValue and animalData.genValue > 0 then
            if not isMyPlotByName(animalData.plot) then
                local plot = workspace:FindFirstChild("Plots") and workspace.Plots:FindFirstChild(animalData.plot)
                if plot then
                    local podiums = plot:FindFirstChild("AnimalPodiums")
                    if podiums then
                        local podium = podiums:FindFirstChild(animalData.slot)
                        if podium then
                            local base = podium:FindFirstChild("Base")
                            if base then
                                local spawn = base:FindFirstChild("Spawn")
                                if spawn then
                                    local d = (spawn.Position - hrp.Position).Magnitude
                                    if d <= STEAL_RADIUS then
                                        local att = spawn:FindFirstChild("PromptAttachment")
                                        if att then
                                            for _, p in ipairs(att:GetChildren()) do
                                                if p:IsA("ProximityPrompt") and p.Enabled and p.ActionText and p.ActionText:find("Steal") then
                                                    local targetPart = p.Parent
                                                    if targetPart:IsA("Attachment") then targetPart = targetPart.Parent end
                                                    return p, animalData, targetPart
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return nil, nil, nil
end

-- ========== TOP LABEL ==========
local function updateTopLabel(animalData, targetPart)
    if not autoStealEnabled then
        if topBrainrotLabel then topBrainrotLabel.Enabled = false end
        return
    end
    if animalData and targetPart then
        if not topBrainrotLabel then
            topBrainrotLabel = Instance.new("BillboardGui")
            topBrainrotLabel.Size = UDim2.new(0, 250, 0, 30)
            topBrainrotLabel.AlwaysOnTop = true
            topBrainrotLabel.StudsOffset = Vector3.new(0, 4, 0)
            topBrainrotLabel.MaxDistance = 500
            topBrainrotLabel.ResetOnSpawn = false
            local tl = Instance.new("TextLabel", topBrainrotLabel)
            tl.Size = UDim2.new(1, 0, 1, 0)
            tl.BackgroundTransparency = 1
            tl.Font = Enum.Font.GothamBlack
            tl.TextSize = 14
            tl.TextColor3 = Color3.fromRGB(255, 215, 0)
            tl.TextStrokeTransparency = 0
            tl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        end
        pcall(function()
            topBrainrotLabel.Adornee = targetPart
            topBrainrotLabel.Parent = targetPart
            topBrainrotLabel.Enabled = true
            local tl = topBrainrotLabel:FindFirstChild("TextLabel")
            if tl then tl.Text = "🏆 " .. animalData.name .. " (" .. animalData.genText .. ")" end
        end)
    else
        if topBrainrotLabel then topBrainrotLabel.Enabled = false end
    end
end

-- ========== PROGRESS BAR ==========
local function updateProgressBar(p, name)
    if progressFill then
        pcall(function() TweenService:Create(progressFill, TweenInfo.new(0.05, Enum.EasingStyle.Linear), {Size = UDim2.new(p, 0, 1, 0)}):Play() end)
    end
    if percentLabel then percentLabel.Text = math.floor(p * 100) .. "%" end
    if stealNameLabel then
        stealNameLabel.Text = (name and name ~= "") and name or "Idle"
    end
end

local function setProgressBrainrotName(name)
    currentStealName = name or ""
    if stealNameLabel then
        stealNameLabel.Text = currentStealName ~= "" and currentStealName or "Idle"
    end
end

task.spawn(function()
    while task.wait(0.2) do
        forceScanAllPlots()
    end
end)

local function executeSteal(prompt, animalData)
    if isStealing then return end
    if isHoldingBrainrot() then return end
    if not prompt or not prompt.Parent then return end
    if not StealData[prompt] then
        StealData[prompt] = {hold = {}, trigger = {}, ready = true}
        if getconnections then
            pcall(function()
                for _, c in ipairs(getconnections(prompt.PromptButtonHoldBegan)) do
                    if c.Function then table.insert(StealData[prompt].hold, c.Function) end
                end
                for _, c in ipairs(getconnections(prompt.Triggered)) do
                    if c.Function then table.insert(StealData[prompt].trigger, c.Function) end
                end
            end)
        end
    end
    local data = StealData[prompt]
    if not data.ready then return end
    data.ready = false; isStealing = true
    currentStealName = animalData and animalData.name or ""
    local startTime = tick()
    task.spawn(function() for _, f in ipairs(data.hold) do pcall(f) end end)
    task.spawn(function()
        while tick() - startTime < STEAL_DURATION do
            local elapsed = tick() - startTime
            local p = math.clamp(elapsed / STEAL_DURATION, 0, 1)
            updateProgressBar(p, currentStealName)
            task.wait()
        end
        updateProgressBar(1, currentStealName)
        for _, f in ipairs(data.trigger) do pcall(f) end
        task.wait(0.1)
        updateProgressBar(0, "")
        currentStealName = ""
        data.ready = true; isStealing = false
    end)
end

local function startAutoSteal()
    if autoStealConn then return end
    updateProgressBar(0, "")

    -- Forced scan every 0.1s
    task.spawn(function()
        while autoStealEnabled do
            forceScanAllPlots()
            task.wait(0.1)
        end
    end)

    -- Update top label every 0.1 seconds
    task.spawn(function()
        while autoStealEnabled do
            if isHoldingBrainrot() then
                updateTopLabel(nil, nil)
            else
                local _, animalData, targetPart = findBestPrompt()
                updateTopLabel(animalData, targetPart)
            end
            task.wait(0.1)
        end
        updateTopLabel(nil, nil)
    end)

    autoStealConn = RunService.Heartbeat:Connect(function()
        if not autoStealEnabled then return end
        if isHoldingBrainrot() then return end
        if isStealing then return end
        local prompt, animalData, _ = findBestPrompt()
        if prompt then
            pcall(function() executeSteal(prompt, animalData) end)
        end
    end)
end

local function stopAutoSteal()
    if autoStealConn then autoStealConn:Disconnect(); autoStealConn = nil end
    isStealing = false
    updateProgressBar(0, "")
    currentStealName = ""
    updateTopLabel(nil, nil)
end

-- ========== AUTO JOINER ==========
local joinedServers = {}
local scanStartTime = 0
local SCAN_WAIT = 2

local function stopAutoJoiner()
    if autoJoinerConn then autoJoinerConn:Disconnect(); autoJoinerConn = nil end
    isJoining = false
end

local function findHighValueBrainrot()
    for _, animalData in ipairs(allAnimalsCache) do
        if animalData.genValue and animalData.genValue >= MIN_JOIN_VALUE then
            if not isMyPlotByName(animalData.plot) then return true end
        end
    end
    return false
end

local function getCurrentServerId()
    local jobId = ""
    pcall(function() jobId = game.JobId end)
    return jobId
end

local function joinRandomServer()
    if isJoining then return end
    isJoining = true
    local currentJobId = getCurrentServerId()
    if currentJobId ~= "" then joinedServers[currentJobId] = tick() end
    local now = tick()
    for jobId, time in pairs(joinedServers) do
        if now - time > 300 then joinedServers[jobId] = nil end
    end
    pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, "", Player) end)
    task.delay(1, function()
        pcall(function() TeleportService:Teleport(game.PlaceId, Player) end)
    end)
    task.delay(1, function() isJoining = false end)
end

local function autoJoinerTick()
    if not autoJoinerEnabled then return end
    if isJoining then return end
    if tick() - scanStartTime < SCAN_WAIT then return end
    if findHighValueBrainrot() then
        autoJoinerEnabled = false
        if buttonStates["AutoJoiner"] then buttonStates["AutoJoiner"].setState(false) end
        stopAutoJoiner()
        playAlertSound()
        return
    end
    joinRandomServer()
    scanStartTime = tick()
end

local function startAutoJoiner()
    if autoJoinerConn then return end
    scanStartTime = tick()
    joinedServers = {}
    autoJoinerConn = RunService.Heartbeat:Connect(function()
        if not autoJoinerEnabled then return end
        autoJoinerTick()
    end)
end

-- ========== AUTO TURRET ==========
local function hasExclamation(target)
    for _, d in ipairs(target:GetDescendants()) do
        if d:IsA("BillboardGui") then
            local label = d:FindFirstChildWhichIsA("TextLabel", true)
            if label and label.Text:find("!") then return true end
        end
    end
    return false
end

local function getClosestSentry()
    local c = Player.Character; if not c then return nil end
    local hrp = c:FindFirstChild("HumanoidRootPart"); if not hrp then return nil end
    local closest, shortestDist = nil, math.huge
    for _, inst in ipairs(workspace:GetDescendants()) do
        if inst.Name:match("^Sentry_") and hasExclamation(inst) then
            local root = inst:IsA("BasePart") and inst or inst:FindFirstChildWhichIsA("BasePart", true)
            if root then
                local dist = (hrp.Position - root.Position).Magnitude
                if dist < shortestDist then shortestDist = dist; closest = inst end
            end
        end
    end
    return closest
end

local function turretTick()
    if not autoTurretEnabled then return end
    if isHoldingBrainrot() then return end
    local targetSentry = getClosestSentry(); if not targetSentry then return end
    local c = Player.Character; if not c then return end
    local hrp = c:FindFirstChild("HumanoidRootPart"); local hum = c:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end
    local offset = hrp.CFrame.LookVector * 4
    local targetCF = CFrame.new(hrp.Position + offset, hrp.Position)
    if targetSentry:IsA("Model") then pcall(function() targetSentry:PivotTo(targetCF) end)
    elseif targetSentry:IsA("BasePart") then targetSentry.CFrame = targetCF end
    local bat = Player:FindFirstChild("Backpack") and Player.Backpack:FindFirstChild("Bat")
    if not bat then bat = c:FindFirstChild("Bat") end
    if bat then
        if bat.Parent ~= c then pcall(function() hum:EquipTool(bat) end) end
        pcall(function() bat:Activate() end)
    end
end

local function startAutoTurret()
    if autoTurretConn then return end; lastTurretTick = 0
    autoTurretConn = RunService.Heartbeat:Connect(function()
        if not autoTurretEnabled then return end
        local now = tick()
        if now - lastTurretTick >= TURRET_TICK_DELAY then lastTurretTick = now; turretTick() end
    end)
end
local function stopAutoTurret()
    if autoTurretConn then autoTurretConn:Disconnect(); autoTurretConn = nil end
end

-- ========== INSTANT RESET ==========
local function instantReset()
    if isResetting then return end; isResetting = true
    local c = Player.Character; if not c then isResetting = false; return end
    local hrp = c:FindFirstChild("HumanoidRootPart"); local hum = c:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then isResetting = false; return end
    local carpet = Player.Backpack:FindFirstChild("Flying Carpet") or Player.Backpack:FindFirstChild("FlyingCarpet") or c:FindFirstChild("Flying Carpet") or c:FindFirstChild("FlyingCarpet")
    if carpet then carpet.Parent = c end
    camera.CameraType = Enum.CameraType.Scriptable
    task.delay(0.6, function()
        camera.CameraType = Enum.CameraType.Custom
        local nc = Player.Character
        if nc then local nh = nc:FindFirstChildOfClass("Humanoid"); if nh then camera.CameraSubject = nh end end
    end)
    hrp.CFrame = resetCFrame
    local hb; hb = RunService.Heartbeat:Connect(function()
        if not c.Parent or hum.Health <= 0 then hb:Disconnect(); return end
        hrp.CFrame = resetCFrame
    end)
    task.delay(1.5, function() isResetting = false end)
end

-- ========== AUTO LEAVE ==========
local autoLeaveConn = nil
local function startAutoLeave()
    if autoLeaveConn then return end
    task.delay(1, function()
        if not autoLeaveEnabled then return end
        autoLeaveConn = Player.PlayerGui.DescendantAdded:Connect(function(obj)
            if not autoLeaveEnabled then return end
            if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                local txt = string.lower(obj.Text or "")
                if txt:find("you stole") then
                    pcall(function() Player:Kick("Auto Leave") end)
                end
            end
        end)
    end)
end
local function stopAutoLeave()
    if autoLeaveConn then autoLeaveConn:Disconnect(); autoLeaveConn = nil end
end

-- ========== AUTO CLONER ==========
local function instantClone()
    local character = Player.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local cloner = Player.Backpack:FindFirstChild("Quantum Cloner") or character:FindFirstChild("Quantum Cloner")
    if not cloner then return end
    if cloner.Parent ~= character then humanoid:EquipTool(cloner); task.wait(0.3) end
    local PlayerGui = Player:WaitForChild("PlayerGui")
    local toolsFrames = PlayerGui:FindFirstChild("ToolsFrames")
    local qcFrame = toolsFrames and toolsFrames:FindFirstChild("QuantumCloner")
    local tpButton = qcFrame and qcFrame:FindFirstChild("TeleportToClone")
    if not tpButton then return end
    cloner:Activate()
    task.wait(0.3)
    tpButton.Visible = true
    if typeof(firesignal) == "function" then firesignal(tpButton.MouseButton1Up) end
end

-- ========== HIGH VALUE ALERT ==========
local function checkHighValue()
    for _, animalData in ipairs(allAnimalsCache) do
        if animalData.genValue and animalData.genValue >= 20000000 then
            if not isMyPlotByName(animalData.plot) then
                playAlertSound(); return
            end
        end
    end
end
task.spawn(function() while task.wait(3) do pcall(checkHighValue) end end)

-- ========== INVISIBLE STEAL (extracted core) ==========
_G.InvisStealAngle = InvisSettings.Angle
_G.SinkSliderValue = InvisSettings.Depth
_G.AutoRecoverLagback = InvisSettings.AutoRecover
_G.AutoInvisDuringSteal = InvisSettings.AutoOnSteal
_G.invisibleStealEnabled = false
_G.RecoveryInProgress = false

local function syncInvisGlobals()
    _G.InvisStealAngle = InvisSettings.Angle
    _G.SinkSliderValue = InvisSettings.Depth
    _G.AutoRecoverLagback = InvisSettings.AutoRecover
    _G.AutoInvisDuringSteal = InvisSettings.AutoOnSteal
end

local function saveInvisSettings()
    syncInvisGlobals()
end

local function applyInvisSettingsToPanel()
    if InvisPanelRefs.rotationSlider then
        InvisPanelRefs.rotationSlider.Set(InvisSettings.Angle, true)
    end
    if InvisPanelRefs.depthSlider then
        InvisPanelRefs.depthSlider.Set(InvisSettings.Depth, true)
    end
    if InvisPanelRefs.autoRecoverRow then
        InvisPanelRefs.autoRecoverRow.Set(InvisSettings.AutoRecover, true, true)
    end
    if InvisPanelRefs.autoInvisStealRow then
        InvisPanelRefs.autoInvisStealRow.Set(InvisSettings.AutoOnSteal, true, true)
    end
    if InvisPanelRefs.updateVisualState then
        InvisPanelRefs.updateVisualState(invisFeatureActive)
    end
end

task.spawn(function()
    local INVIS_WALK_SPEED = 20
    local animPlaying = false
    local tracks = {}
    local clone, oldRoot, hip, connection
    local savedInvisWalkSpeed = nil
    local folderConnections = {}
    local serverGhosts = {}
    local ghostEnabled = true
    local lagbackCallCount = 0
    local lagbackWindowStart = 0
    local lastLagbackTime = 0
    local errorOrbActive = false
    local errorOrb = nil

    local function clearErrorOrb()
        if errorOrb and errorOrb.Parent then errorOrb:Destroy() end
        errorOrb = nil
        errorOrbActive = false
    end

    local function createErrorOrb()
        if errorOrbActive then return end
        errorOrbActive = true
        for _, ghost in pairs(serverGhosts) do
            if ghost and ghost.Parent then ghost:Destroy() end
        end
        serverGhosts = {}
        local sg = Instance.new("ScreenGui")
        sg.Name = "PriorityInvisErrorOrb"
        sg.ResetOnSpawn = false
        sg.Parent = Player:WaitForChild("PlayerGui")
        local fr = Instance.new("Frame", sg)
        fr.Size = UDim2.new(0, 500, 0, 60)
        fr.Position = UDim2.new(0.5, -250, 0.3, 0)
        fr.BackgroundTransparency = 1
        local l1 = Instance.new("TextLabel", fr)
        l1.Size = UDim2.new(1, 0, 0.5, 0)
        l1.BackgroundTransparency = 1
        l1.Text = "ERROR CAUSED BY PLAYER DEATH"
        l1.TextColor3 = HAZE.DANGER
        l1.Font = Enum.Font.GothamBlack
        l1.TextScaled = true
        local l2 = Instance.new("TextLabel", fr)
        l2.Size = UDim2.new(1, 0, 0.5, 0)
        l2.Position = UDim2.new(0, 0, 0.5, 0)
        l2.BackgroundTransparency = 1
        l2.Text = "MUST RESET TO FIX ERROR"
        l2.TextColor3 = HAZE.DANGER
        l2.Font = Enum.Font.GothamBlack
        l2.TextScaled = true
        errorOrb = sg
    end

    local function createServerGhost(position)
        if not ghostEnabled or errorOrbActive then return end
        local now = tick()
        if now - lastLagbackTime < 0.05 then return end
        lastLagbackTime = now
        if now - lagbackWindowStart > 1 then
            lagbackCallCount = 0
            lagbackWindowStart = now
        end
        lagbackCallCount = lagbackCallCount + 1
        if lagbackCallCount >= 7 then
            createErrorOrb()
            return
        end
        for _, g in pairs(serverGhosts) do
            if g and g.Parent then g:Destroy() end
        end
        serverGhosts = {}
        local ghost = Instance.new("Part")
        ghost.Name = "PriorityLagbackGhost"
        ghost.Shape = Enum.PartType.Ball
        ghost.Size = Vector3.new(3, 3, 3)
        ghost.Color = HAZE.DANGER
        ghost.Material = Enum.Material.Glass
        ghost.Transparency = 0.3
        ghost.CanCollide = false
        ghost.Anchored = true
        ghost.CastShadow = false
        ghost.Position = position + Vector3.new(0, 5, 0)
        ghost.Parent = workspace.CurrentCamera
        table.insert(serverGhosts, ghost)
    end

    local function clearAllGhosts()
        for _, ghost in pairs(serverGhosts) do
            pcall(function()
                if ghost and ghost.Parent then ghost:Destroy() end
            end)
        end
        serverGhosts = {}
        clearErrorOrb()
        lagbackCallCount = 0
        lastLagbackTime = 0
        pcall(function()
            local pg = Player:FindFirstChild("PlayerGui")
            if pg then
                for _, gui in pairs(pg:GetChildren()) do
                    if gui.Name == "LagbackNotification" then gui:Destroy() end
                end
            end
        end)
        pcall(function()
            if workspace.CurrentCamera then
                for _, c in pairs(workspace.CurrentCamera:GetChildren()) do
                    if c.Name == "PriorityLagbackGhost" then c:Destroy() end
                end
            end
        end)
    end

    local function removeFolders()
        local pf = workspace:FindFirstChild(Player.Name)
        if not pf then return end
        local dr = pf:FindFirstChild("DoubleRig")
        if dr then
            local rr = dr:FindFirstChild("HumanoidRootPart") or dr:FindFirstChildWhichIsA("BasePart")
            if rr and ghostEnabled then createServerGhost(rr.Position) end
            dr:Destroy()
        end
        local cs = pf:FindFirstChild("Constraints")
        if cs then cs:Destroy() end
        local conn = pf.ChildAdded:Connect(function(child)
            if child.Name == "DoubleRig" then
                task.defer(function()
                    local rr = child:FindFirstChild("HumanoidRootPart") or child:FindFirstChildWhichIsA("BasePart")
                    if rr and ghostEnabled then createServerGhost(rr.Position) end
                    child:Destroy()
                end)
            elseif child.Name == "Constraints" then
                child:Destroy()
            end
        end)
        table.insert(folderConnections, conn)
    end

    local function restoreInvisWalkSpeed(humanoid)
        if humanoid and savedInvisWalkSpeed then
            humanoid.WalkSpeed = savedInvisWalkSpeed
            savedInvisWalkSpeed = nil
        end
    end

    local function doClone()
        local character = Player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not character or not humanoid or humanoid.Health <= 0 then
            return false
        end

        hip = humanoid.HipHeight
        oldRoot = character:FindFirstChild("HumanoidRootPart")
        if not oldRoot or not oldRoot.Parent then return false end

        savedInvisWalkSpeed = humanoid.WalkSpeed
        humanoid.WalkSpeed = INVIS_WALK_SPEED
        oldRoot.AssemblyLinearVelocity = Vector3.zero
        oldRoot.AssemblyAngularVelocity = Vector3.zero

        for _, c in pairs(oldRoot:GetChildren()) do
            if c:IsA("Attachment") and (c.Name:find("Beam") or c.Name:find("Attach")) then
                c:Destroy()
            elseif c:IsA("Beam") then
                c:Destroy()
            end
        end

        local savedCFrame = oldRoot.CFrame
        clone = oldRoot:Clone()
        clone.Name = "PriorityCloneRoot"
        clone.CanCollide = false
        clone.Parent = character

        for _, v in pairs(character:GetDescendants()) do
            if v:IsA("Weld") or v:IsA("Motor6D") then
                if v.Part0 == oldRoot then v.Part0 = clone end
                if v.Part1 == oldRoot then v.Part1 = clone end
            end
        end

        character.PrimaryPart = clone
        oldRoot.Name = "PriorityRealRoot"
        clone.Name = "HumanoidRootPart"
        clone.CFrame = savedCFrame
        oldRoot.Parent = workspace.CurrentCamera
        oldRoot.CanCollide = false

        pcall(function() clone:SetNetworkOwner(Player) end)
        return true
    end

    local function revertClone()
        local character = Player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not oldRoot or not oldRoot:IsDescendantOf(workspace) or not character or not humanoid or humanoid.Health <= 0 then
            restoreInvisWalkSpeed(humanoid)
            return
        end

        for _, v in pairs(character:GetDescendants()) do
            if v:IsA("Weld") or v:IsA("Motor6D") then
                if v.Part0 == clone then v.Part0 = oldRoot end
                if v.Part1 == clone then v.Part1 = oldRoot end
            end
        end

        local savedCFrame = clone and clone.CFrame or oldRoot.CFrame
        if clone then
            clone:Destroy()
            clone = nil
        end

        oldRoot.Name = "HumanoidRootPart"
        oldRoot.Parent = character
        oldRoot.CFrame = savedCFrame
        oldRoot.CanCollide = true
        character.PrimaryPart = oldRoot
        oldRoot = nil

        humanoid.HipHeight = hip
        restoreInvisWalkSpeed(humanoid)
        clearAllGhosts()
    end

    local function animationTrickery()
        local character = Player.Character
        if character and character:FindFirstChild("Humanoid") and character.Humanoid.Health > 0 then
            local anim = Instance.new("Animation")
            anim.AnimationId = "rbxassetid://18537363391"
            local humanoid = character.Humanoid
            local animator = humanoid:FindFirstChild("Animator") or Instance.new("Animator", humanoid)
            local animTrack = animator:LoadAnimation(anim)
            animTrack.Priority = Enum.AnimationPriority.Action4
            animTrack:Play(0, 1, 0)
            anim:Destroy()
            table.insert(tracks, animTrack)
            animTrack.Stopped:Connect(function()
                if animPlaying then animationTrickery() end
            end)
            task.delay(0, function()
                animTrack.TimePosition = 0.7
                task.delay(0.3, function()
                    if animTrack then animTrack:AdjustSpeed(math.huge) end
                end)
            end)
        end
    end

    local function turnOff()
        clearAllGhosts()
        if not animPlaying then return end
        local character = Player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        animPlaying = false
        invisFeatureActive = false
        _G.invisibleStealEnabled = false
        for _, t in pairs(tracks) do
            pcall(function() t:Stop() end)
        end
        tracks = {}
        if connection then
            connection:Disconnect()
            connection = nil
        end
        for _, c in ipairs(folderConnections) do
            if c then c:Disconnect() end
        end
        folderConnections = {}
        revertClone()
        clearAllGhosts()
        if humanoid then
            restoreInvisWalkSpeed(humanoid)
            pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        end
        if InvisPanelRefs.updateVisualState then
            pcall(InvisPanelRefs.updateVisualState, false)
        end
    end

    local function turnOn()
        if animPlaying then return end
        local character = Player.Character
        if not character then return end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end
        animPlaying = true
        invisFeatureActive = true
        _G.invisibleStealEnabled = true
        if InvisPanelRefs.updateVisualState then
            pcall(InvisPanelRefs.updateVisualState, true)
        end
        tracks = {}
        removeFolders()
        local success = doClone()
        if success then
            task.wait(0.05)
            animationTrickery()
            local lastSetPosition = nil
            local skipFrames = 5
            connection = RunService.PreSimulation:Connect(function()
                if character and character:FindFirstChild("Humanoid") and character.Humanoid.Health > 0 and oldRoot then
                    local hum = character:FindFirstChildOfClass("Humanoid")
                    if hum and hum.WalkSpeed ~= INVIS_WALK_SPEED then
                        hum.WalkSpeed = INVIS_WALK_SPEED
                    end
                    local root = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
                    if root then
                        if skipFrames > 0 then
                            skipFrames = skipFrames - 1
                            lastSetPosition = nil
                        elseif lastSetPosition and ghostEnabled then
                            local currentPos = oldRoot.Position
                            local jumpDist = (currentPos - lastSetPosition).Magnitude
                            if jumpDist > 3 and not _G.RecoveryInProgress then
                                lastSetPosition = nil
                                createServerGhost(currentPos)
                                if _G.AutoRecoverLagback and _G.toggleInvisibleSteal then
                                    _G.RecoveryInProgress = true
                                    task.spawn(function()
                                        pcall(_G.toggleInvisibleSteal)
                                        task.wait(0.5)
                                        pcall(_G.toggleInvisibleSteal)
                                        _G.RecoveryInProgress = false
                                    end)
                                end
                            end
                        end
                        if clone then clone.CanCollide = false end
                        for _, c in pairs(oldRoot:GetChildren()) do
                            if c:IsA("Attachment") or c:IsA("Beam") then
                                c:Destroy()
                            end
                        end
                        local rotAngle = _G.InvisStealAngle or 180
                        local sa = (_G.SinkSliderValue or 5) * 0.5
                        local cf = root.CFrame - Vector3.new(0, sa, 0)
                        oldRoot.CFrame = cf * CFrame.Angles(math.rad(rotAngle), 0, 0)
                        oldRoot.AssemblyLinearVelocity = root.AssemblyLinearVelocity
                        oldRoot.CanCollide = false
                        lastSetPosition = oldRoot.Position
                    end
                end
            end)
        else
            animPlaying = false
            invisFeatureActive = false
            _G.invisibleStealEnabled = false
            restoreInvisWalkSpeed(humanoid)
            if InvisPanelRefs.updateVisualState then
                pcall(InvisPanelRefs.updateVisualState, false)
            end
        end
    end

    _G.toggleInvisibleSteal = function()
        if animPlaying then
            turnOff()
        else
            turnOn()
        end
    end

    local function onCharacterAdded(newChar)
        clearErrorOrb()
        clearAllGhosts()
        lagbackCallCount = 0
        pcall(function()
            for _, c in pairs(workspace.CurrentCamera:GetChildren()) do
                if c:IsA("BasePart") and (c.Name == "HumanoidRootPart" or c.Name == "PriorityRealRoot") then
                    c:Destroy()
                end
            end
        end)
        if oldRoot then
            pcall(function() oldRoot:Destroy() end)
            oldRoot = nil
        end
        if clone then
            pcall(function() clone:Destroy() end)
            clone = nil
        end
        savedInvisWalkSpeed = nil
        animPlaying = false
        invisFeatureActive = false
        _G.invisibleStealEnabled = false
        if InvisPanelRefs.updateVisualState then
            pcall(InvisPanelRefs.updateVisualState, false)
        end
        task.wait(0.2)
        local cam = workspace.CurrentCamera
        if cam and newChar then
            local h = newChar:FindFirstChildOfClass("Humanoid")
            if h then
                cam.CameraSubject = h
                cam.CameraType = Enum.CameraType.Custom
            end
        end
    end

    Player.CharacterAdded:Connect(onCharacterAdded)

    local function setupDeathListener()
        local ch = Player.Character
        if ch then
            local h = ch:FindFirstChildOfClass("Humanoid")
            if h then
                h.Died:Connect(function()
                    clearErrorOrb()
                    clearAllGhosts()
                    lagbackCallCount = 0
                end)
            end
        end
    end
    setupDeathListener()
    Player.CharacterAdded:Connect(function()
        task.wait(0.1)
        setupDeathListener()
    end)

    task.spawn(function()
        local wasStealing = false
        local autoEnabledInvis = false
        task.wait(1)
        while task.wait(0.1) do
            if not InvisSettings.AutoOnSteal then
                wasStealing = false
                autoEnabledInvis = false
            else
                local isStealingNow = Player:GetAttribute("Stealing") == true
                if isStealingNow and not wasStealing then
                    if not invisFeatureActive and _G.toggleInvisibleSteal then
                        task.delay(0.25, function()
                            if Player:GetAttribute("Stealing") and not invisFeatureActive then
                                pcall(_G.toggleInvisibleSteal)
                                autoEnabledInvis = true
                            end
                        end)
                    end
                end
                if not isStealingNow and autoEnabledInvis and invisFeatureActive and _G.toggleInvisibleSteal then
                    pcall(_G.toggleInvisibleSteal)
                    autoEnabledInvis = false
                end
                wasStealing = isStealingNow
            end
        end
    end)
end)

-- ========== CONFIG SAVE/LOAD ==========
local function saveConfig()
    local cfg = {}
    for name, state in pairs(buttonStates) do
        if state and state.getState then cfg[name] = state.getState() end
    end
    cfg._invis = {
        Angle = InvisSettings.Angle,
        Depth = InvisSettings.Depth,
        AutoRecover = InvisSettings.AutoRecover,
        AutoOnSteal = InvisSettings.AutoOnSteal,
    }
    local ok, json = pcall(function() return HttpService:JSONEncode(cfg) end)
    if ok and writefile then pcall(function() writefile(CONFIG_FILE, json) end) end
end

local function loadConfig()
    if not readfile or not isfile or not isfile(CONFIG_FILE) then return end
    local ok, raw = pcall(function() return readfile(CONFIG_FILE) end)
    if not ok or not raw then return end
    local ok2, cfg = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok2 or not cfg then return end
    if type(cfg._invis) == "table" then
        local inv = cfg._invis
        if type(inv.Angle) == "number" then InvisSettings.Angle = inv.Angle end
        if type(inv.Depth) == "number" then InvisSettings.Depth = math.clamp(inv.Depth, 0, 5.4) end
        if type(inv.AutoRecover) == "boolean" then InvisSettings.AutoRecover = inv.AutoRecover end
        if type(inv.AutoOnSteal) == "boolean" then InvisSettings.AutoOnSteal = inv.AutoOnSteal end
        syncInvisGlobals()
        applyInvisSettingsToPanel()
    end
    for name, isOn in pairs(cfg) do
        if name:sub(1, 1) == "_" then
            -- skip metadata keys
        elseif buttonStates[name] then
            buttonStates[name].setState(isOn)
            if isOn then
                if name == "InfJump" then infJumpActive = true; startInfJump()
                elseif name == "AntiRagdoll" then antiRagdollEnabled = true; startAntiRagdollV2()
                elseif name == "AutoBat" then startAutoBat()
                elseif name == "StealSpeed" then stealSpeedEnabled = true; startStealSpeed()
                elseif name == "AutoSteal" then autoStealEnabled = true; startAutoSteal()
                elseif name == "AutoJoiner" then autoJoinerEnabled = true; startAutoJoiner()
                elseif name == "AutoTurret" then autoTurretEnabled = true; startAutoTurret()
                elseif name == "AutoLeave" then autoLeaveEnabled = true; startAutoLeave()
                elseif name == "InvisibleSteal" then
                    invisibleStealEnabled = true
                    setInvisibleStealPanelVisible(true)
                elseif name == "AntiEffect" then
                    antiEffectEnabled = true
                    startAntiEffect()
                end
            end
        end
    end
end

-- ========== GUI (scoped block: Lua 200-local limit) ==========
do
-- ========== PROGRESS GUI ==========
local progressGui = Instance.new("ScreenGui")
progressGui.Name = "PriorityDevProgress"
progressGui.ResetOnSpawn = false
progressGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
parentToSafeGui(progressGui)
progressGui.Enabled = true

local progressContainer = Instance.new("Frame")
progressContainer.Name = "Container"
progressContainer.Size = UDim2.fromOffset(320, 54)
progressContainer.Position = UDim2.new(0.5, -160, 0, 14)
progressContainer.BackgroundColor3 = HAZE.SURF
progressContainer.BorderSizePixel = 0
progressContainer.Parent = progressGui
Round(progressContainer, 14)
Stroke(progressContainer, 1, HAZE.STROKE_ON, 0.35)
Gradient(progressContainer, {
    ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 16, 28)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 16)),
}, 90)

stealNameLabel = Instance.new("TextLabel", progressContainer)
stealNameLabel.Size = UDim2.new(1, -24, 0, 16)
stealNameLabel.Position = UDim2.fromOffset(12, 7)
stealNameLabel.BackgroundTransparency = 1
stealNameLabel.Font = Enum.Font.GothamBold
stealNameLabel.TextSize = 11
stealNameLabel.TextColor3 = HAZE.ACCENT2
stealNameLabel.Text = "Idle"
stealNameLabel.TextXAlignment = Enum.TextXAlignment.Left

local progressBarBg = Instance.new("Frame", progressContainer)
progressBarBg.Size = UDim2.new(1, -24, 0, 20)
progressBarBg.Position = UDim2.fromOffset(12, 28)
progressBarBg.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
progressBarBg.BorderSizePixel = 0
Round(progressBarBg, 999)
Stroke(progressBarBg, 1, HAZE.STROKE, 0.4)

progressFill = Instance.new("Frame", progressBarBg)
progressFill.Size = UDim2.new(0, 0, 1, 0)
progressFill.BackgroundColor3 = HAZE.ACCENT
progressFill.BorderSizePixel = 0
Round(progressFill, 999)
Gradient(progressFill, {
    ColorSequenceKeypoint.new(0, Color3.fromRGB(55, 0, 255)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(138, 62, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(213, 61, 255)),
}, 0)

local fillShine = Instance.new("Frame", progressFill)
fillShine.Size = UDim2.new(1, -4, 0, 6)
fillShine.Position = UDim2.fromOffset(2, 2)
fillShine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
fillShine.BackgroundTransparency = 0.82
fillShine.BorderSizePixel = 0
Round(fillShine, 999)

percentLabel = Instance.new("TextLabel", progressBarBg)
percentLabel.Size = UDim2.fromScale(1, 1)
percentLabel.BackgroundTransparency = 1
percentLabel.Font = Enum.Font.GothamBlack
percentLabel.TextSize = 10
percentLabel.TextColor3 = HAZE.TEXT
percentLabel.Text = "0%"
percentLabel.TextStrokeTransparency = 0.5
percentLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

-- ========== INVISIBLE STEAL PANEL ==========
local function buildInvisibleStealPanel()
    if invisibleGui then return end

    invisibleGui = Instance.new("ScreenGui")
    invisibleGui.Name = "PriorityDevInvisible"
    invisibleGui.ResetOnSpawn = false
    invisibleGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    invisibleGui.Enabled = false
    parentToSafeGui(invisibleGui)

    local INVIS_UI = {
        BG = Color3.fromRGB(10, 10, 18),
        SURF = Color3.fromRGB(20, 18, 32),
        SURF_HOVER = Color3.fromRGB(30, 26, 48),
        TEXT = HAZE.TEXT,
        OFF_BG = Color3.fromRGB(32, 34, 52),
        OFF_TEXT = HAZE.MUTED,
        GREEN1 = Color3.fromRGB(14, 96, 68),
        GREEN2 = Color3.fromRGB(24, 168, 108),
        GREEN_STROKE = Color3.fromRGB(72, 220, 150),
        SLIDER_BG = Color3.fromRGB(28, 30, 46),
    }

    local root = Instance.new("Frame")
    root.Name = "InvisibleRoot"
    root.Size = UDim2.fromOffset(268, 318)
    root.Position = UDim2.new(1, -284, 0.5, -159)
    root.BackgroundTransparency = 1
    root.BorderSizePixel = 0
    root.Parent = invisibleGui
    InvisPanelRefs.rootFrame = root

    local panel = Instance.new("Frame")
    panel.Name = "InvisiblePanel"
    panel.Size = UDim2.fromOffset(268, 318)
    panel.Position = UDim2.fromOffset(0, 0)
    panel.BackgroundColor3 = INVIS_UI.BG
    panel.BorderSizePixel = 0
    panel.ZIndex = 2
    panel.Parent = root
    InvisPanelRefs.panelFrame = panel
    Round(panel, 16)

    local panelScale = Instance.new("UIScale", panel)
    panelScale.Scale = 1
    InvisPanelRefs.panelScale = panelScale

    local panelBg = Instance.new("Frame", panel)
    panelBg.Size = UDim2.fromScale(1, 1)
    panelBg.BackgroundTransparency = 0.15
    panelBg.BorderSizePixel = 0
    panelBg.ZIndex = 0
    Round(panelBg, 16)
    Gradient(panelBg, {
        ColorSequenceKeypoint.new(0, Color3.fromRGB(36, 24, 62)),
        ColorSequenceKeypoint.new(0.45, Color3.fromRGB(14, 14, 24)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 22, 40)),
    }, 130)

    Stroke(panel, 1, HAZE.STROKE, 0.55)

    local panelGlow = Instance.new("UIStroke", panel)
    panelGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    panelGlow.Thickness = 2.5
    panelGlow.Color = HAZE.ACCENT
    panelGlow.Transparency = 0.82
    addGlowStack(panel, HAZE.ACCENT2, 2)
    addSheenOverlay(panel, 16)
    task.spawn(function()
        while panelGlow.Parent do
            Tween(panelGlow, {Transparency = 0.68}, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut))
            task.wait(2)
            if not panelGlow.Parent then break end
            Tween(panelGlow, {Transparency = 0.88}, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut))
            task.wait(2)
        end
    end)

    local header = Instance.new("Frame", panel)
    header.Size = UDim2.new(1, 0, 0, 48)
    header.BackgroundTransparency = 1
    header.BorderSizePixel = 0
    header.ZIndex = 3

    local headerBg = Instance.new("Frame", header)
    headerBg.Size = UDim2.new(1, -16, 1, -8)
    headerBg.Position = UDim2.fromOffset(8, 4)
    headerBg.BackgroundColor3 = Color3.fromRGB(22, 18, 36)
    headerBg.BackgroundTransparency = 0.2
    headerBg.BorderSizePixel = 0
    Round(headerBg, 12)
    Gradient(headerBg, {
        ColorSequenceKeypoint.new(0, Color3.fromRGB(52, 36, 88)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 16, 30)),
    }, 90)
    Stroke(headerBg, 1, HAZE.STROKE_ON, 0.5)

    local title = Instance.new("TextLabel", headerBg)
    title.Size = UDim2.new(1, -12, 0, 18)
    title.Position = UDim2.fromOffset(12, 7)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBlack
    title.Text = "INVISIBLE STEAL"
    title.TextSize = 14
    title.TextColor3 = HAZE.ACCENT2
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextStrokeTransparency = 0.7
    title.TextStrokeColor3 = HAZE.ACCENT

    local subtitle = Instance.new("TextLabel", headerBg)
    subtitle.Size = UDim2.new(1, -12, 0, 12)
    subtitle.Position = UDim2.fromOffset(12, 26)
    subtitle.BackgroundTransparency = 1
    subtitle.Font = Enum.Font.GothamMedium
    subtitle.Text = "drag header  •  ghost mode"
    subtitle.TextSize = 9
    subtitle.TextColor3 = HAZE.DIM
    subtitle.TextXAlignment = Enum.TextXAlignment.Left

    local contentBox = Instance.new("Frame", panel)
    contentBox.Size = UDim2.new(1, -16, 1, -60)
    contentBox.Position = UDim2.fromOffset(8, 52)
    contentBox.BackgroundColor3 = Color3.fromRGB(8, 8, 14)
    contentBox.BackgroundTransparency = 0.25
    contentBox.BorderSizePixel = 0
    contentBox.ZIndex = 3
    Round(contentBox, 12)
    Stroke(contentBox, 1, HAZE.STROKE, 0.55)
    Gradient(contentBox, {
        ColorSequenceKeypoint.new(0, Color3.fromRGB(16, 14, 26)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 10, 18)),
    }, 180)

    local container = Instance.new("Frame", contentBox)
    container.BackgroundTransparency = 1
    container.Size = UDim2.new(1, -10, 1, -10)
    container.Position = UDim2.fromOffset(5, 5)

    local layout = Instance.new("UIListLayout", container)
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    local activeSlider = nil

    local function paintStateRow(row, stateBox, stateFill, stateText, stateStroke, on, instant)
        local info = instant and TWEEN_SNAP or TWEEN_FAST
        if on then
            Tween(stateBox, {BackgroundColor3 = INVIS_UI.GREEN1}, info)
            Tween(stateFill, {BackgroundTransparency = 0}, info)
            stateText.Text = "ON"
            Tween(stateText, {TextColor3 = Color3.fromRGB(232, 255, 240)}, info)
            Tween(stateStroke, {Color = INVIS_UI.GREEN_STROKE, Transparency = 0.15}, info)
            Tween(row, {BackgroundColor3 = Color3.fromRGB(18, 38, 32)}, info)
        else
            Tween(stateBox, {BackgroundColor3 = INVIS_UI.OFF_BG}, info)
            Tween(stateFill, {BackgroundTransparency = 1}, info)
            stateText.Text = "OFF"
            Tween(stateText, {TextColor3 = INVIS_UI.OFF_TEXT}, info)
            Tween(stateStroke, {Color = HAZE.STROKE, Transparency = 0.55}, info)
            Tween(row, {BackgroundColor3 = INVIS_UI.SURF}, info)
        end
    end

    local function addStateRow(text, defaultState, onToggle)
        local row = Instance.new("TextButton")
        row.AutoButtonColor = false
        row.Size = UDim2.new(1, 0, 0, 34)
        row.BackgroundColor3 = INVIS_UI.SURF
        row.BorderSizePixel = 0
        row.Text = ""
        row.Parent = container
        row.ZIndex = 4
        Round(row, 8)
        Stroke(row, 1, HAZE.STROKE, 0.55)

        local label = Instance.new("TextLabel", row)
        label.BackgroundTransparency = 1
        label.Position = UDim2.fromOffset(10, 0)
        label.Size = UDim2.new(1, -78, 1, 0)
        label.Font = Enum.Font.GothamBold
        label.Text = text
        label.TextColor3 = INVIS_UI.TEXT
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left

        local stateBox = Instance.new("Frame", row)
        stateBox.Size = UDim2.fromOffset(58, 22)
        stateBox.Position = UDim2.new(1, -68, 0.5, -11)
        stateBox.BackgroundColor3 = INVIS_UI.OFF_BG
        stateBox.BorderSizePixel = 0
        Round(stateBox, 6)
        local stateStroke = Stroke(stateBox, 1, HAZE.STROKE, 0.55)

        local stateFill = Instance.new("Frame", stateBox)
        stateFill.Size = UDim2.fromScale(1, 1)
        stateFill.BackgroundTransparency = 1
        stateFill.BorderSizePixel = 0
        Round(stateFill, 6)
        Gradient(stateFill, {
            ColorSequenceKeypoint.new(0, INVIS_UI.GREEN1),
            ColorSequenceKeypoint.new(1, INVIS_UI.GREEN2),
        }, 0)

        local stateText = Instance.new("TextLabel", stateBox)
        stateText.BackgroundTransparency = 1
        stateText.Size = UDim2.fromScale(1, 1)
        stateText.Font = Enum.Font.GothamBold
        stateText.TextSize = 10
        stateText.Parent = stateBox

        local state = defaultState
        local lockCallback = false

        row.MouseEnter:Connect(function()
            if not state then
                Tween(row, {BackgroundColor3 = INVIS_UI.SURF_HOVER}, TWEEN_SNAP)
            end
        end)
        row.MouseLeave:Connect(function()
            if not state then
                Tween(row, {BackgroundColor3 = INVIS_UI.SURF}, TWEEN_SNAP)
            end
        end)

        local function setState(newState, silent, instant)
            state = newState and true or false
            paintStateRow(row, stateBox, stateFill, stateText, stateStroke, state, instant)
            if onToggle and not lockCallback and not silent then
                onToggle(state)
            end
        end

        paintStateRow(row, stateBox, stateFill, stateText, stateStroke, state, true)

        row.MouseButton1Click:Connect(function()
            setState(not state, false)
        end)

        return {
            Set = function(newState, instant, silent)
                lockCallback = true
                setState(newState, silent, instant)
                lockCallback = false
            end,
            Get = function()
                return state
            end,
        }
    end

    local function addSliderRow(text, minValue, maxValue, initialValue, step, onChange)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 44)
        row.BackgroundColor3 = INVIS_UI.SURF
        row.BorderSizePixel = 0
        row.Parent = container
        row.ZIndex = 4
        Round(row, 8)
        Stroke(row, 1, HAZE.STROKE, 0.55)

        row.MouseEnter:Connect(function()
            Tween(row, {BackgroundColor3 = INVIS_UI.SURF_HOVER}, TWEEN_SNAP)
        end)
        row.MouseLeave:Connect(function()
            Tween(row, {BackgroundColor3 = INVIS_UI.SURF}, TWEEN_SNAP)
        end)

        local label = Instance.new("TextLabel", row)
        label.BackgroundTransparency = 1
        label.Position = UDim2.fromOffset(10, 4)
        label.Size = UDim2.new(1, -50, 0, 14)
        label.Font = Enum.Font.GothamBold
        label.Text = text
        label.TextColor3 = INVIS_UI.TEXT
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left

        local number = Instance.new("TextLabel", row)
        number.BackgroundTransparency = 1
        number.Position = UDim2.new(1, -36, 0, 4)
        number.Size = UDim2.fromOffset(26, 14)
        number.Font = Enum.Font.GothamBold
        number.TextColor3 = HAZE.ACCENT2
        number.TextSize = 10
        number.TextXAlignment = Enum.TextXAlignment.Right

        local barButton = Instance.new("TextButton", row)
        barButton.AutoButtonColor = false
        barButton.Text = ""
        barButton.Size = UDim2.new(1, -20, 0, 10)
        barButton.Position = UDim2.fromOffset(10, 28)
        barButton.BackgroundColor3 = INVIS_UI.SLIDER_BG
        barButton.BorderSizePixel = 0
        barButton.ClipsDescendants = true
        Round(barButton, 99)

        local fillGlow = Instance.new("Frame", barButton)
        fillGlow.Size = UDim2.new(0, 0, 1, 0)
        fillGlow.Position = UDim2.fromOffset(0, 0)
        fillGlow.BackgroundColor3 = HAZE.CYAN
        fillGlow.BackgroundTransparency = 0.72
        fillGlow.BorderSizePixel = 0
        fillGlow.ZIndex = 1
        Round(fillGlow, 99)

        local fill = Instance.new("Frame", barButton)
        fill.Size = UDim2.new(0, 0, 1, 0)
        fill.Position = UDim2.fromOffset(0, 0)
        fill.BackgroundColor3 = HAZE.ACCENT
        fill.BorderSizePixel = 0
        fill.ZIndex = 2
        Round(fill, 99)
        Gradient(fill, {
            ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 70, 200)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(148, 116, 218)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 200, 255)),
        }, 0)

        local knob = Instance.new("Frame", barButton)
        knob.AnchorPoint = Vector2.new(0.5, 0.5)
        knob.Position = UDim2.new(0, 0, 0.5, 0)
        knob.Size = UDim2.fromOffset(12, 12)
        knob.BackgroundColor3 = HAZE.TEXT
        knob.BorderSizePixel = 0
        knob.ZIndex = 3
        Round(knob, 99)
        local knobStroke = Stroke(knob, 1, HAZE.ACCENT2, 0.62)
        Gradient(knob, {
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(196, 168, 244)),
        }, 90)

        local value = initialValue
        local sliderDragging = false

        local function applyValue(v, silent, instant)
            value = math.clamp(v, minValue, maxValue)
            if step and step > 0 then
                value = math.floor((value / step) + 0.5) * step
                value = math.clamp(value, minValue, maxValue)
            end
            local alpha = (value - minValue) / (maxValue - minValue)
            local targetSize = UDim2.new(alpha, 0, 1, 0)
            local targetPos = UDim2.new(alpha, 0, 0.5, 0)
            local tweenInfo = (instant or sliderDragging) and TWEEN_SNAP or TWEEN_FAST
            Tween(fill, {Size = targetSize}, tweenInfo)
            Tween(fillGlow, {Size = targetSize}, tweenInfo)
            Tween(knob, {Position = targetPos}, tweenInfo)
            if step and step > 0 and step < 1 then
                number.Text = string.format("%.1f", value)
            else
                number.Text = tostring(math.floor(value + 0.5))
            end
            if onChange and not silent then
                onChange(value)
            end
        end

        local function setFromInput(input)
            local absPos = barButton.AbsolutePosition.X
            local absSize = barButton.AbsoluteSize.X
            if absSize <= 0 then return end
            local alpha = math.clamp((input.Position.X - absPos) / absSize, 0, 1)
            applyValue(minValue + ((maxValue - minValue) * alpha), false)
        end

        applyValue(initialValue, true, true)

        barButton.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                sliderDragging = true
                Tween(knob, {Size = UDim2.fromOffset(13, 13)}, TWEEN_SNAP)
                Tween(knobStroke, {Transparency = 0.45}, TWEEN_SNAP)
                activeSlider = {
                    setFromInput = setFromInput,
                    onEnd = function()
                        sliderDragging = false
                        Tween(knob, {Size = UDim2.fromOffset(12, 12)}, TWEEN_SNAP)
                        Tween(knobStroke, {Transparency = 0.62}, TWEEN_SNAP)
                    end,
                }
                setFromInput(input)
            end
        end)

        return {
            Set = function(newValue, silent)
                applyValue(newValue, silent, false)
            end,
            Get = function()
                return value
            end,
        }
    end

    InvisPanelRefs.updateVisualState = function(on)
        if InvisPanelRefs.enabledRow then
            InvisPanelRefs.enabledRow.Set(on, true, true)
        end
    end

    InvisPanelRefs.enabledRow = addStateRow("Enabled", invisFeatureActive, function(state)
        if state ~= invisFeatureActive and _G.toggleInvisibleSteal then
            pcall(_G.toggleInvisibleSteal)
            InvisPanelRefs.updateVisualState(invisFeatureActive)
        end
    end)

    InvisPanelRefs.rotationSlider = addSliderRow("Rotation", 0, 360, InvisSettings.Angle, 1, function(v)
        InvisSettings.Angle = v
        saveInvisSettings()
        saveConfig()
    end)

    InvisPanelRefs.depthSlider = addSliderRow("Depth", 0, 5.4, InvisSettings.Depth, 0.1, function(v)
        InvisSettings.Depth = v
        saveInvisSettings()
        saveConfig()
    end)

    InvisPanelRefs.autoRecoverRow = addStateRow("Auto Recover Lagback", InvisSettings.AutoRecover, function(state)
        InvisSettings.AutoRecover = state
        saveInvisSettings()
        saveConfig()
    end)

    InvisPanelRefs.autoInvisStealRow = addStateRow("Auto Invis On Steal", InvisSettings.AutoOnSteal, function(state)
        InvisSettings.AutoOnSteal = state
        saveInvisSettings()
        saveConfig()
    end)

    UserInputService.InputChanged:Connect(function(input)
        if activeSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            activeSlider.setFromInput(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if activeSlider and activeSlider.onEnd then
                activeSlider.onEnd()
            end
            activeSlider = nil
        end
    end)

    enableSmoothDrag(headerBg, root)

    applyInvisSettingsToPanel()
end

setInvisibleStealPanelVisible = function(show)
    buildInvisibleStealPanel()
    if not invisibleGui then return end
    local scale = InvisPanelRefs.panelScale
    local root = InvisPanelRefs.rootFrame
    if show then
        invisibleGui.Enabled = true
        if scale then
            scale.Scale = 0.9
            Tween(scale, {Scale = 1}, TWEEN_SPRING)
        end
        if root then
            root.BackgroundTransparency = 1
        end
    else
        if scale and root then
            local tween = TweenService:Create(scale, TWEEN_SMOOTH, {Scale = 0.92})
            tween:Play()
            tween.Completed:Connect(function()
                if scale.Scale < 0.95 then
                    invisibleGui.Enabled = false
                    scale.Scale = 1
                end
            end)
        else
            invisibleGui.Enabled = false
        end
    end
end

-- ========== MAIN GUI ==========
gui = Instance.new("ScreenGui")
gui.Name = "PriorityDevMain"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
parentToSafeGui(gui)
gui.Enabled = true

local panelScale = Instance.new("UIScale", gui)
panelScale.Scale = 1

local panel = Instance.new("Frame", gui)
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(820, 520)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.BackgroundColor3 = HAZE.BG
panel.BorderSizePixel = 0
Round(panel, 16)
Stroke(panel, 1, HAZE.STROKE, 0.55)

local panelGlow = Instance.new("UIStroke", panel)
panelGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
panelGlow.Thickness = 2.5
panelGlow.Color = HAZE.ACCENT
panelGlow.Transparency = 0.82
addGlowStack(panel, HAZE.ACCENT2, 2)
addSheenOverlay(panel, 16)
task.spawn(function()
    while panelGlow.Parent do
        Tween(panelGlow, {Transparency = 0.68}, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut))
        task.wait(2)
        if not panelGlow.Parent then break end
        Tween(panelGlow, {Transparency = 0.88}, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut))
        task.wait(2)
    end
end)

local panelGradient = Instance.new("Frame", panel)
panelGradient.Size = UDim2.fromScale(1, 1)
panelGradient.BackgroundTransparency = 0.25
panelGradient.BorderSizePixel = 0
panelGradient.ZIndex = 0
Round(panelGradient, 16)
Gradient(panelGradient, {
    ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 18, 42)),
    ColorSequenceKeypoint.new(0.45, Color3.fromRGB(10, 10, 16)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 14, 28)),
}, 135)

local side = Instance.new("Frame", panel)
side.Name = "Sidebar"
side.Size = UDim2.new(0, 76, 1, -20)
side.Position = UDim2.fromOffset(10, 10)
side.BackgroundColor3 = HAZE.SURF
side.BorderSizePixel = 0
side.ZIndex = 2
Round(side, 12)
Stroke(side, 1, HAZE.STROKE, 0.65)

local logoWrap = Instance.new("Frame", side)
logoWrap.Size = UDim2.fromOffset(48, 48)
logoWrap.Position = UDim2.new(0.5, -24, 0, 12)
logoWrap.BackgroundColor3 = HAZE.SURF2
logoWrap.BorderSizePixel = 0
Round(logoWrap, 12)
Stroke(logoWrap, 1, HAZE.STROKE_ON, 0.45)
Gradient(logoWrap, {
    ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 26, 54)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 16, 28)),
}, 45)

local logoText = Instance.new("TextLabel", logoWrap)
logoText.Size = UDim2.fromScale(1, 1)
logoText.BackgroundTransparency = 1
logoText.Font = Enum.Font.GothamBlack
logoText.Text = "P"
logoText.TextSize = 24
logoText.TextColor3 = HAZE.ACCENT2
logoText.TextXAlignment = Enum.TextXAlignment.Center
logoText.TextYAlignment = Enum.TextYAlignment.Center

local versionBadge = Instance.new("TextLabel", side)
versionBadge.Size = UDim2.new(1, -12, 0, 14)
versionBadge.Position = UDim2.fromOffset(6, 66)
versionBadge.BackgroundTransparency = 1
versionBadge.Font = Enum.Font.GothamBold
versionBadge.Text = "v3.0"
versionBadge.TextSize = 10
versionBadge.TextColor3 = HAZE.MUTED

local tabHolder = Instance.new("Frame", side)
tabHolder.Size = UDim2.new(1, -12, 1, -150)
tabHolder.Position = UDim2.fromOffset(6, 88)
tabHolder.BackgroundTransparency = 1

local tabList = Instance.new("UIListLayout", tabHolder)
tabList.Padding = UDim.new(0, 8)
tabList.HorizontalAlignment = Enum.HorizontalAlignment.Center

local activeCountLabel = Instance.new("TextLabel", side)
activeCountLabel.Size = UDim2.new(1, -10, 0, 28)
activeCountLabel.Position = UDim2.new(0.5, 0, 1, -38)
activeCountLabel.AnchorPoint = Vector2.new(0.5, 0)
activeCountLabel.BackgroundColor3 = HAZE.SURF2
activeCountLabel.BackgroundTransparency = 0.15
activeCountLabel.BorderSizePixel = 0
activeCountLabel.Font = Enum.Font.GothamBold
activeCountLabel.TextSize = 10
activeCountLabel.TextColor3 = HAZE.DIM
activeCountLabel.Text = "0 active"
Round(activeCountLabel, 8)

local main = Instance.new("Frame", panel)
main.Name = "Main"
main.Size = UDim2.new(1, -106, 1, -20)
main.Position = UDim2.fromOffset(96, 10)
main.BackgroundTransparency = 1
main.ZIndex = 2

local sHeader = Instance.new("Frame", main)
sHeader.Name = "Header"
sHeader.Size = UDim2.new(1, 0, 0, 64)
sHeader.BackgroundColor3 = HAZE.SURF
sHeader.BorderSizePixel = 0
Round(sHeader, 12)
Stroke(sHeader, 1, HAZE.STROKE, 0.7)

local titleWrap = Instance.new("Frame", sHeader)
titleWrap.Size = UDim2.new(0.45, 0, 1, 0)
titleWrap.BackgroundTransparency = 1

local title = Instance.new("TextLabel", titleWrap)
title.Size = UDim2.new(1, -20, 0, 22)
title.Position = UDim2.fromOffset(16, 12)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.Text = "Priority.Dev"
title.TextColor3 = HAZE.TEXT
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left

local crumb = Instance.new("TextLabel", titleWrap)
crumb.Size = UDim2.new(1, -20, 0, 16)
crumb.Position = UDim2.fromOffset(16, 36)
crumb.BackgroundTransparency = 1
crumb.Font = Enum.Font.GothamMedium
crumb.Text = "HVH Hub  /  Functions"
crumb.TextColor3 = HAZE.DIM
crumb.TextSize = 12
crumb.TextXAlignment = Enum.TextXAlignment.Left

local searchWrap = Instance.new("Frame", sHeader)
searchWrap.Size = UDim2.fromOffset(250, 36)
searchWrap.Position = UDim2.new(1, -292, 0.5, -18)
searchWrap.BackgroundColor3 = HAZE.BG
searchWrap.BorderSizePixel = 0
Round(searchWrap, 10)
Stroke(searchWrap, 1, HAZE.STROKE, 0.75)

local searchBox = Instance.new("TextBox", searchWrap)
searchBox.Size = UDim2.new(1, -16, 1, 0)
searchBox.Position = UDim2.fromOffset(8, 0)
searchBox.BackgroundTransparency = 1
searchBox.BorderSizePixel = 0
searchBox.ClearTextOnFocus = false
searchBox.Font = Enum.Font.GothamMedium
searchBox.PlaceholderText = "Search modules..."
searchBox.PlaceholderColor3 = HAZE.MUTED
searchBox.Text = ""
searchBox.TextColor3 = HAZE.TEXT
searchBox.TextSize = 13
searchBox.TextXAlignment = Enum.TextXAlignment.Left
local searchPad = Instance.new("UIPadding", searchBox)
searchPad.PaddingLeft = UDim.new(0, 6)

local helpBtn = Instance.new("TextButton", sHeader)
helpBtn.Size = UDim2.fromOffset(36, 36)
helpBtn.Position = UDim2.new(1, -44, 0.5, -18)
helpBtn.BackgroundColor3 = HAZE.BG
helpBtn.BorderSizePixel = 0
helpBtn.AutoButtonColor = false
helpBtn.Font = Enum.Font.GothamBlack
helpBtn.Text = "?"
helpBtn.TextColor3 = HAZE.DIM
helpBtn.TextSize = 16
Round(helpBtn, 10)
Stroke(helpBtn, 1, HAZE.STROKE, 0.75)

local helpPanel = Instance.new("Frame", main)
helpPanel.Name = "HelpPanel"
helpPanel.Size = UDim2.new(1, 0, 0, 118)
helpPanel.Position = UDim2.fromOffset(0, 72)
helpPanel.BackgroundColor3 = HAZE.SURF
helpPanel.BorderSizePixel = 0
helpPanel.Visible = false
helpPanel.ZIndex = 5
Round(helpPanel, 12)
Stroke(helpPanel, 1, HAZE.STROKE_ON, 0.35)

local helpText = Instance.new("TextLabel", helpPanel)
helpText.Size = UDim2.new(1, -24, 1, -16)
helpText.Position = UDim2.fromOffset(12, 8)
helpText.BackgroundTransparency = 1
helpText.Font = Enum.Font.GothamMedium
helpText.TextSize = 11
helpText.TextColor3 = HAZE.DIM
helpText.TextXAlignment = Enum.TextXAlignment.Left
helpText.TextYAlignment = Enum.TextYAlignment.Top
helpText.TextWrapped = true
helpText.Text = "Insert - toggle menu\nClick key badge or right-click card - rebind\nSidebar tabs - filter by category\nPurple glow = module active"

local content = Instance.new("ScrollingFrame", main)
content.Name = "Content"
content.Size = UDim2.new(1, 0, 1, -84)
content.Position = UDim2.fromOffset(0, 76)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 4
content.ScrollBarImageColor3 = HAZE.ACCENT
content.CanvasSize = UDim2.new(0, 0, 0, 0)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y

local grid = Instance.new("UIGridLayout", content)
grid.CellSize = UDim2.fromOffset(338, 72)
grid.CellPadding = UDim2.fromOffset(14, 14)
grid.SortOrder = Enum.SortOrder.LayoutOrder

local contentPad = Instance.new("UIPadding", content)
contentPad.PaddingTop = UDim.new(0, 4)
contentPad.PaddingLeft = UDim.new(0, 2)
contentPad.PaddingRight = UDim.new(0, 10)
contentPad.PaddingBottom = UDim.new(0, 12)

local footer = Instance.new("TextLabel", main)
footer.Size = UDim2.new(1, 0, 0, 14)
footer.Position = UDim2.new(0, 0, 1, -2)
footer.BackgroundTransparency = 1
footer.Font = Enum.Font.GothamMedium
footer.Text = "INSERT to hide | Right-click card to rebind"
footer.TextColor3 = HAZE.MUTED
footer.TextSize = 10

local currentCategory = "All"
local tabButtons = {}
local functionCards = {}
local cardMeta = {}

local CATEGORIES = {
    { id = "All", icon = "*", label = "All" },
    { id = "Combat", icon = "F", label = "Fight" },
    { id = "Movement", icon = "M", label = "Move" },
    { id = "Auto", icon = "O", label = "Auto" },
}

local function updateActiveCount()
    local n = 0
    for _, state in pairs(buttonStates) do
        if state.getState and state.getState() then n += 1 end
    end
    activeCountLabel.Text = n .. " active"
    activeCountLabel.TextColor3 = n > 0 and HAZE.ACCENT2 or HAZE.DIM
end

local function applyFilters()
    local q = searchBox.Text:lower()
    for _, card in ipairs(functionCards) do
        local meta = cardMeta[card]
        local textBlob = card.Name:lower()
        for _, child in ipairs(card:GetDescendants()) do
            if child:IsA("TextLabel") then
                textBlob = textBlob .. " " .. child.Text:lower()
            end
        end
        local catOk = currentCategory == "All" or (meta and meta.category == currentCategory)
        local searchOk = q == "" or textBlob:find(q, 1, true) ~= nil
        card.Visible = catOk and searchOk
    end
end

local function setCategory(catId)
    currentCategory = catId
    crumb.Text = "HVH Hub  /  " .. catId
    for id, btn in pairs(tabButtons) do
        local active = id == catId
        Tween(btn, {
            BackgroundColor3 = active and HAZE.SURF2 or HAZE.SURF,
            BackgroundTransparency = active and 0 or 0.35,
        })
        btn.TextColor3 = active and HAZE.ACCENT2 or HAZE.MUTED
    end
    applyFilters()
end

for _, cat in ipairs(CATEGORIES) do
    local tab = Instance.new("TextButton", tabHolder)
    tab.Name = cat.id .. "Tab"
    tab.Size = UDim2.fromOffset(52, 44)
    tab.BackgroundColor3 = HAZE.SURF
    tab.BackgroundTransparency = 0.35
    tab.BorderSizePixel = 0
    tab.AutoButtonColor = false
    tab.Font = Enum.Font.GothamBlack
    tab.Text = cat.icon .. "\n" .. cat.label
    tab.TextSize = 11
    tab.TextColor3 = HAZE.MUTED
    tab.TextXAlignment = Enum.TextXAlignment.Center
    tab.TextYAlignment = Enum.TextYAlignment.Center
    Round(tab, 10)
    tabButtons[cat.id] = tab
    tab.MouseButton1Click:Connect(function()
        setCategory(cat.id)
    end)
    tab.MouseEnter:Connect(function()
        if currentCategory ~= cat.id then
            Tween(tab, { BackgroundTransparency = 0.15 }, TWEEN_SNAP)
        end
    end)
    tab.MouseLeave:Connect(function()
        if currentCategory ~= cat.id then
            Tween(tab, { BackgroundTransparency = 0.35 }, TWEEN_SNAP)
        end
    end)
end
setCategory("All")

function toggleGui(show)
    if show == nil then show = not gui.Enabled end
    if show then
        gui.Enabled = true
        panelScale.Scale = 0.94
        Tween(panelScale, { Scale = 1 }, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
    else
        Tween(panelScale, { Scale = 0.94 }, TWEEN_FAST)
        task.delay(0.16, function()
            if panelScale.Scale < 0.98 then gui.Enabled = false end
        end)
    end
end

helpBtn.MouseButton1Click:Connect(function()
    helpPanel.Visible = not helpPanel.Visible
    content.Position = helpPanel.Visible and UDim2.fromOffset(0, 198) or UDim2.fromOffset(0, 76)
    content.Size = helpPanel.Visible and UDim2.new(1, 0, 1, -206) or UDim2.new(1, 0, 1, -84)
end)

helpBtn.MouseEnter:Connect(function()
    Tween(helpBtn, { BackgroundColor3 = HAZE.SURF2 }, TWEEN_SNAP)
end)
helpBtn.MouseLeave:Connect(function()
    Tween(helpBtn, { BackgroundColor3 = HAZE.BG }, TWEEN_SNAP)
end)

searchBox.Focused:Connect(function()
    Tween(searchWrap, { BackgroundColor3 = HAZE.SURF2 }, TWEEN_SNAP)
end)
searchBox.FocusLost:Connect(function()
    Tween(searchWrap, { BackgroundColor3 = HAZE.BG }, TWEEN_SNAP)
end)

enableSmoothDrag(sHeader, panel)

-- ========== BUTTON FACTORY ==========
local MODULE_ICONS = {
    InfJump = "J",
    AntiRagdoll = "G",
    AutoBat = "B",
    Drop = "D",
    TpDown = "T",
    StealSpeed = "V",
    AutoJoiner = "M",
    AutoSteal = "S",
    AutoTurret = "N",
    InstaReset = "R",
    AutoLeave = "L",
    AutoCloner = "C",
    InvisibleSteal = "I",
    AntiEffect = "E",
}

local function makeBindableButton(order, text, actionName, category, isToggle, callback)
    local card = Instance.new("Frame", content)
    card.Name = actionName .. "Card"
    card.LayoutOrder = order
    card.BackgroundColor3 = HAZE.CARD
    card.BorderSizePixel = 0
    card.ClipsDescendants = true
    card.Active = true
    Round(card, 12)
    local cardStroke = Stroke(card, 1, HAZE.STROKE, 0.62)

    local accentBar = Instance.new("Frame", card)
    accentBar.Name = "AccentBar"
    accentBar.Size = UDim2.new(0, 4, 1, -20)
    accentBar.Position = UDim2.fromOffset(10, 10)
    accentBar.BackgroundColor3 = HAZE.ACCENT
    accentBar.BackgroundTransparency = 0.35
    accentBar.BorderSizePixel = 0
    Round(accentBar, 999)

    local titleY = 22
    local titleH = 20
    local iconSize = 28
    local iconY = titleY + math.floor((titleH - iconSize) / 2)

    local iconBubble = Instance.new("Frame", card)
    iconBubble.Size = UDim2.fromOffset(iconSize, iconSize)
    iconBubble.Position = UDim2.fromOffset(22, iconY)
    iconBubble.BackgroundColor3 = HAZE.SURF2
    iconBubble.BorderSizePixel = 0
    Round(iconBubble, 8)

    local iconLabel = Instance.new("TextLabel", iconBubble)
    iconLabel.Size = UDim2.fromScale(1, 1)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Font = Enum.Font.GothamBlack
    iconLabel.Text = MODULE_ICONS[actionName] or string.sub(text, 1, 1)
    iconLabel.TextSize = 13
    iconLabel.TextColor3 = HAZE.ACCENT2
    iconLabel.TextXAlignment = Enum.TextXAlignment.Center
    iconLabel.TextYAlignment = Enum.TextYAlignment.Center

    local nameLabel = Instance.new("TextLabel", card)
    nameLabel.Size = UDim2.new(1, -150, 0, titleH)
    nameLabel.Position = UDim2.fromOffset(58, titleY)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Text = text
    nameLabel.TextColor3 = HAZE.TEXT
    nameLabel.TextSize = 14
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextYAlignment = Enum.TextYAlignment.Center

    local bindBadge = Instance.new("TextButton", card)
    bindBadge.Size = UDim2.fromOffset(54, 24)
    bindBadge.Position = UDim2.new(1, -66, 0, 24)
    bindBadge.BackgroundColor3 = HAZE.BG
    bindBadge.BorderSizePixel = 0
    bindBadge.AutoButtonColor = false
    bindBadge.Font = Enum.Font.GothamBold
    bindBadge.TextSize = 10
    bindBadge.TextColor3 = HAZE.MUTED
    bindBadge.TextXAlignment = Enum.TextXAlignment.Center
    bindBadge.TextYAlignment = Enum.TextYAlignment.Center
    Round(bindBadge, 7)
    Stroke(bindBadge, 1, HAZE.STROKE, 0.8)

    local control = Instance.new("TextButton", card)
    control.Size = isToggle and UDim2.fromOffset(50, 26) or UDim2.fromOffset(72, 28)
    control.Position = UDim2.new(1, isToggle and -62 or -84, 0.5, isToggle and -13 or -14)
    control.BackgroundColor3 = HAZE.SURF2
    control.BorderSizePixel = 0
    control.AutoButtonColor = false
    control.Font = Enum.Font.GothamBold
    control.TextSize = 11
    control.TextColor3 = HAZE.TEXT
    control.TextXAlignment = Enum.TextXAlignment.Center
    control.TextYAlignment = Enum.TextYAlignment.Center
    Round(control, 999)

    local knob
    if isToggle then
        knob = Instance.new("Frame", control)
        knob.Size = UDim2.fromOffset(20, 20)
        knob.Position = UDim2.fromOffset(3, 3)
        knob.BackgroundColor3 = HAZE.TEXT
        knob.BorderSizePixel = 0
        Round(knob, 999)
    end

    local isOn = false
    local function refresh()
        local bindName = Binds[actionName] and Binds[actionName].Name or "?"
        if isOn then
            Tween(card, { BackgroundColor3 = HAZE.CARD_ON }, TWEEN_SNAP)
            cardStroke.Color = HAZE.STROKE_ON
            cardStroke.Transparency = 0.15
            accentBar.BackgroundTransparency = 0
            bindBadge.TextColor3 = HAZE.ACCENT2
            control.BackgroundColor3 = HAZE.ACCENT
            control.Text = isToggle and "" or "RUN"
            if knob then Tween(knob, { Position = UDim2.fromOffset(27, 3) }, TWEEN_SNAP) end
        else
            Tween(card, { BackgroundColor3 = HAZE.CARD }, TWEEN_SNAP)
            cardStroke.Color = HAZE.STROKE
            cardStroke.Transparency = 0.62
            accentBar.BackgroundTransparency = 0.35
            bindBadge.TextColor3 = HAZE.MUTED
            control.BackgroundColor3 = HAZE.SURF2
            control.Text = isToggle and "" or "RUN"
            if knob then Tween(knob, { Position = UDim2.fromOffset(3, 3) }, TWEEN_SNAP) end
        end
        bindBadge.Text = bindName
        updateActiveCount()
    end

    refresh()

    card.MouseEnter:Connect(function()
        if not isOn then
            Tween(card, { BackgroundColor3 = Color3.fromRGB(18, 17, 26) }, TWEEN_SNAP)
            Tween(cardStroke, { Transparency = 0.45 }, TWEEN_SNAP)
        end
    end)
    card.MouseLeave:Connect(function()
        if not isOn then refresh() end
    end)

    control.MouseButton1Click:Connect(function()
        if isToggle then
            isOn = not isOn
            refresh()
            if callback then callback(isOn) end
        else
            Tween(control, { Size = control.Size - UDim2.fromOffset(4, 2) }, TWEEN_SNAP)
            task.delay(0.08, function()
                Tween(control, { Size = isToggle and UDim2.fromOffset(50, 26) or UDim2.fromOffset(72, 28) }, TWEEN_SNAP)
            end)
            if callback then callback() end
        end
        task.delay(0.1, saveConfig)
    end)

    local function beginRebind()
        bindBadge.Text = "..."
        bindBadge.TextColor3 = HAZE.ACCENT2
        local conn
        conn = UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                local newKey = input.KeyCode
                BindAction[Binds[actionName]] = nil
                local conflictAction = BindAction[newKey]
                if conflictAction and conflictAction ~= actionName then
                    BindAction[newKey] = nil
                end
                Binds[actionName] = newKey
                BindAction[newKey] = actionName
                refresh()
                if conn then conn:Disconnect() end
                task.delay(0.1, saveConfig)
            end
        end)
        task.delay(5, function()
            if conn and conn.Connected then
                conn:Disconnect()
                refresh()
            end
        end)
    end

    bindBadge.MouseButton1Click:Connect(beginRebind)
    bindBadge.MouseButton2Click:Connect(beginRebind)
    card.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            beginRebind()
        end
    end)

    buttonStates[actionName] = {
        refresh = refresh,
        setState = function(s)
            isOn = s
            refresh()
        end,
        getState = function()
            return isOn
        end,
    }

    cardMeta[card] = { category = category, actionName = actionName }
    functionCards[#functionCards + 1] = card
    applyFilters()
    return card
end

-- ========== BUILD BUTTONS ==========
makeBindableButton(1, "Inf Jump", "InfJump", "Movement", true, function(on) infJumpActive = on; if on then startInfJump() else stopInfJump() end end)
makeBindableButton(2, "Anti Ragdoll", "AntiRagdoll", "Movement", true, function(on) antiRagdollEnabled = on; if on then startAntiRagdollV2() else stopAntiRagdollV2() end end)
makeBindableButton(3, "Anti Effect", "AntiEffect", "Combat", true, function(on) antiEffectEnabled = on; if on then startAntiEffect() else stopAntiEffect() end end)
makeBindableButton(4, "Auto Bat", "AutoBat", "Combat", true, function(on) if on then startAutoBat() else stopAutoBat() end end)
makeBindableButton(5, "Drop", "Drop", "Combat", false, function() runDrop() end)
makeBindableButton(6, "Tp Down", "TpDown", "Movement", false, function() runTpDown() end)
makeBindableButton(7, "Steal Speed", "StealSpeed", "Movement", true, function(on) stealSpeedEnabled = on; if on then startStealSpeed() else stopStealSpeed() end end)
makeBindableButton(8, "Auto Joiner", "AutoJoiner", "Auto", true, function(on) autoJoinerEnabled = on; if on then startAutoJoiner() else stopAutoJoiner() end end)
makeBindableButton(9, "Auto Steal", "AutoSteal", "Auto", true, function(on) autoStealEnabled = on; if on then startAutoSteal() else stopAutoSteal() end end)
makeBindableButton(10, "Auto Sentry", "AutoTurret", "Combat", true, function(on) autoTurretEnabled = on; if on then startAutoTurret() else stopAutoTurret() end end)
makeBindableButton(11, "Insta Reset", "InstaReset", "Movement", false, function() instantReset() end)
makeBindableButton(12, "Auto Leave", "AutoLeave", "Auto", true, function(on) autoLeaveEnabled = on; if on then startAutoLeave() else stopAutoLeave() end end)
makeBindableButton(13, "Auto Clone", "AutoCloner", "Movement", false, function() instantClone() end)
makeBindableButton(14, "Invisible Steal", "InvisibleSteal", "Movement", true, function(on)
    invisibleStealEnabled = on
    setInvisibleStealPanelVisible(on)
end)

searchBox:GetPropertyChangedSignal("Text"):Connect(applyFilters)
end

-- ========== INSERT TOGGLE ==========
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Insert then
        toggleGui(not gui.Enabled)
    end
end)

-- ========== KEYBINDS ==========
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local action = BindAction[input.KeyCode]
    if not action then return end
    if action == "Drop" then runDrop()
    elseif action == "TpDown" then runTpDown()
    elseif action == "InstaReset" then instantReset()
    elseif action == "AutoCloner" then instantClone()
    elseif action == "InfJump" then local s = buttonStates["InfJump"]; if s then local c = s.getState(); s.setState(not c); infJumpActive = not c; if infJumpActive then startInfJump() else stopInfJump() end end
    elseif action == "AntiRagdoll" then local s = buttonStates["AntiRagdoll"]; if s then local c = s.getState(); s.setState(not c); antiRagdollEnabled = not c; if antiRagdollEnabled then startAntiRagdollV2() else stopAntiRagdollV2() end end
    elseif action == "AutoBat" then local s = buttonStates["AutoBat"]; if s then local c = s.getState(); s.setState(not c); autoBatEnabled = not c; if autoBatEnabled then startAutoBat() else stopAutoBat() end end
    elseif action == "StealSpeed" then local s = buttonStates["StealSpeed"]; if s then local c = s.getState(); s.setState(not c); stealSpeedEnabled = not c; if stealSpeedEnabled then startStealSpeed() else stopStealSpeed() end end
    elseif action == "AutoSteal" then local s = buttonStates["AutoSteal"]; if s then local c = s.getState(); s.setState(not c); autoStealEnabled = not c; if autoStealEnabled then startAutoSteal() else stopAutoSteal() end end
    elseif action == "AutoJoiner" then local s = buttonStates["AutoJoiner"]; if s then local c = s.getState(); s.setState(not c); autoJoinerEnabled = not c; if autoJoinerEnabled then startAutoJoiner() else stopAutoJoiner() end end
    elseif action == "AutoTurret" then local s = buttonStates["AutoTurret"]; if s then local c = s.getState(); s.setState(not c); autoTurretEnabled = not c; if autoTurretEnabled then startAutoTurret() else stopAutoTurret() end end
    elseif action == "AutoLeave" then local s = buttonStates["AutoLeave"]; if s then local c = s.getState(); s.setState(not c); autoLeaveEnabled = not c; if autoLeaveEnabled then startAutoLeave() else stopAutoLeave() end end
    elseif action == "InvisibleSteal" then
        local s = buttonStates["InvisibleSteal"]
        if s then
            local c = s.getState()
            s.setState(not c)
            invisibleStealEnabled = not c
            setInvisibleStealPanelVisible(invisibleStealEnabled)
        end
    elseif action == "AntiEffect" then
        local s = buttonStates["AntiEffect"]
        if s then
            local c = s.getState()
            s.setState(not c)
            antiEffectEnabled = not c
            if antiEffectEnabled then startAntiEffect() else stopAntiEffect() end
        end
    end
end)

-- ========== AUTO ANTI DROP ==========
RunService.Stepped:Connect(function()
    local c = Player.Character
    if c then
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if hrp and hrp.Position.Y < -10 then
            hrp.Position = Vector3.new(hrp.Position.X, -6.5, hrp.Position.Z)
        end
    end
end)

-- ========== AUTO RESTART ON RESPAWN ==========
Player.CharacterAdded:Connect(function()
    task.wait(0.2)
    if infJumpActive then startInfJump() end
    if antiRagdollEnabled then startAntiRagdollV2() end
    if autoBatEnabled then startAutoBat() end
    if stealSpeedEnabled then startStealSpeed() end
    if autoStealEnabled then startAutoSteal() end
    if autoJoinerEnabled then startAutoJoiner() end
    if autoTurretEnabled then startAutoTurret() end
    if autoLeaveEnabled then startAutoLeave() end
    if invisibleStealEnabled then setInvisibleStealPanelVisible(true) end
end)

-- ========== PERIODIC SAVE ==========
task.spawn(function() while task.wait(10) do saveConfig() end end)

-- ========== LOAD CONFIG ==========
task.delay(0.5, function() loadConfig() end)

setInvisibleStealPanelVisible(true)

print("[Priority.Dev] v3.0 loaded")
print("[Insert] toggle GUI | Sidebar tabs filter modules")
print("[X] Jump | [G] AntiRag | [E] Bat | [R] Drop | [F] TpDown | [V] StealSpd")
print("[B] AutoSteal | [M] Join | [T] Sentry | [Q] Reset | [U] Leave | [N] Clone | [H] Invisible | [P] AntiEffect")
