
-- SMITH'S HUB V15.3
-- github.com/glitchlend/Smiths-Hub
-- Movement: Acceleration + Gear Speed
-- Auto Farm: ESP + Auto Claw + Auto Collect (visible + saved)
-- Animated 3-second welcome screen
-- Claw-close confirmation + 2-second collection cooldown

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local TS = game:GetService("TweenService")
local WS = game:GetService("Workspace")
local CP = game:GetService("ContentProvider")
local VIM = game:GetService("VirtualInputManager")

local Player = Players.LocalPlayer
local PG = Player:WaitForChild("PlayerGui")
local ENV = (getgenv and getgenv()) or _G

for _, name in ipairs({
    "SmithHubV153Unload",
    "SmithHubV152Unload",
    "SmithHubV15Unload",
    "SmithHubV14Unload",
    "SmithHubV13Unload",
    "SmithBoostV3Cleanup",
    "SmithBoostV2Cleanup",
    "SmithBoostCleanup",
    "YSOBoostCleanup"
}) do
    if type(ENV[name]) == "function" then
        pcall(ENV[name])
    end
end

local LOGO_URL =
    "https://raw.githubusercontent.com/glitchlend/Smiths-Hub/main/logo.png"

local TEMP_LOGO = "SmithsHub_Logo_Temp.png"

local C = {
    Acceleration = 1,
    GearSpeed = 1,

    ESP = true,
    AutoClaw = false,
    AutoCollect = false,

    ScanRate = 0.55,
    MergeRadius = 2.5,

    TapLead = 0.010,
    TapTolerance = 5,
    CrossingTolerance = 8,
    TapCooldown = 2,
    RetryMove = 2,
    RetryDistance = 35,
    RetryFrames = 3,

    -- Auto Collect waits for the claw/result screen to close, then settles.
    NextCandyDelay = 2,
    ClawCloseConfirm = 0.5,
    TargetRetryDelay = 30
}

local alive = true
local connections = {}
local session = nil
local entries = {}
local entryCounter = 0

local visibleCount = 0
local savedCount = 0

local currentTarget = nil
local collectPhase = "idle"
local collectStarted = 0
local collectStatus = "Auto Collect: OFF"
local clawStatus = "Auto Claw: OFF"

local BG = Color3.fromRGB(19,19,25)
local PANEL = Color3.fromRGB(36,36,45)
local DARK = Color3.fromRGB(27,27,35)
local WHITE = Color3.fromRGB(245,245,245)
local GREY = Color3.fromRGB(165,165,175)
local ORANGE = Color3.fromRGB(255,145,35)
local CYAN = Color3.fromRGB(0,255,241)
local OFF = Color3.fromRGB(67,67,78)

local function connect(signal,callback)
    local c = signal:Connect(callback)
    table.insert(connections,c)
    return c
end

local function make(class,parent,props)
    local obj = Instance.new(class)
    for k,v in pairs(props or {}) do
        obj[k] = v
    end
    obj.Parent = parent
    return obj
end

local function corner(obj,r)
    make("UICorner",obj,{
        CornerRadius=UDim.new(0,r)
    })
end

local function tween(obj,duration,props,style)
    local info = TweenInfo.new(
        duration,
        style or Enum.EasingStyle.Quart,
        Enum.EasingDirection.Out
    )
    local t = TS:Create(obj,info,props)
    t:Play()
    return t
end

local function getHumanoid()
    local char = Player.Character
    return char and
        char:FindFirstChildOfClass("Humanoid")
end

-- =========================================
-- VEHICLE BOOST
-- =========================================

local POWER_FIELDS = {
    "PeakTorque",
    "IdleTorque",
    "RedlineTorque",
    "VVLTorque",
    "E_Torque",
    "E_RedlineTorque",
    "T_Efficiency",
    "S_Efficiency",
    "Horsepower",
    "Torque",
    "HPLimit"
}

local function restoreVehicle()
    local s = session
    if not s then return end

    pcall(function()
        for field,value in pairs(s.power) do
            s.tune[field] = value
        end

        for i,ratio in ipairs(s.ratios) do
            s.tune.Ratios[i] = ratio
        end

        s.tune.SpeedLimit = s.speedLimit
    end)

    session = nil
end

local function findVehicle()
    local hum = getHumanoid()
    local seat = hum and hum.SeatPart

    if not seat or seat.Name ~= "DriveSeat" then
        return nil
    end

    local node = seat.Parent

    while node and node ~= WS do
        local module = node:FindFirstChild("A-Chassis Tune")
        if module and module:IsA("ModuleScript") then
            return node,seat,module
        end
        node = node.Parent
    end

    return nil
end

local function chassisValues(car)
    local fallback

    for _,obj in ipairs(PG:GetDescendants()) do
        if obj.Name == "Values"
            and obj:FindFirstChild("Gear")
            and obj:FindFirstChild("RPM") then

            local interface = obj.Parent

            if interface
                and interface.Name == "A-Chassis Interface" then

                local ref = interface:FindFirstChild("Car")

                if ref and ref:IsA("ObjectValue") then
                    if ref.Value == car then
                        return obj
                    end
                else
                    fallback = obj
                end
            end
        end
    end

    return fallback
end

local function loadVehicle(car,seat,module)
    local values = chassisValues(car)
    if not values then return false end

    local ok,tune = pcall(require,module)

    if not ok or type(tune) ~= "table"
        or type(tune.Ratios) ~= "table" then
        return false
    end

    local neutralIndex

    for i,ratio in ipairs(tune.Ratios) do
        if type(ratio) == "number"
            and math.abs(ratio) < 0.00001 then
            neutralIndex = i
            break
        end
    end

    if not neutralIndex then return false end

    local ratios = {}
    local power = {}

    for i,ratio in ipairs(tune.Ratios) do
        ratios[i] = ratio
    end

    for _,field in ipairs(POWER_FIELDS) do
        if type(tune[field]) == "number" then
            power[field] = tune[field]
        end
    end

    if next(power) == nil then
        return false
    end

    session = {
        car=car,
        seat=seat,
        module=module,
        values=values,
        tune=tune,
        ratios=ratios,
        power=power,
        speedLimit=tune.SpeedLimit,
        firstGearIndex=neutralIndex+1,
        currentPower=1
    }

    return true
end

local function updateVehicle(s,dt)
    local gearObj = s.values:FindFirstChild("Gear")
    if not gearObj then return end

    local throttleObj =
        s.values:FindFirstChild("InputThrottle")
        or s.values:FindFirstChild("Throttle")

    local brakeObj =
        s.values:FindFirstChild("InputBrake")
        or s.values:FindFirstChild("Brake")

    local throttle = throttleObj and throttleObj.Value or 0
    local brake = brakeObj and brakeObj.Value or 0

    local accelerating =
        gearObj.Value > 0
        and throttle > 0.05
        and brake < 0.1

    local desired =
        accelerating and C.Acceleration or 1

    local response = math.clamp(dt*8,0,1)

    s.currentPower = s.currentPower
        + (desired-s.currentPower)*response

    for field,original in pairs(s.power) do
        if field == "HPLimit" and original <= 0 then
            s.tune[field] = original
        else
            s.tune[field] =
                original*s.currentPower
        end
    end

    -- All forward gears scale equally
    for i=s.firstGearIndex,#s.ratios do
        local original = s.ratios[i]

        if type(original) == "number" then
            s.tune.Ratios[i] =
                original/C.GearSpeed
        end
    end

    if type(s.speedLimit) == "number" then
        s.tune.SpeedLimit =
            s.speedLimit > 0
            and s.speedLimit*C.GearSpeed
            or s.speedLimit
    end
end

-- =========================================
-- CANDY ESP
-- =========================================

local function getCandyFolders()
    local events = WS:FindFirstChild("EVENTS")
    local halloween = events
        and events:FindFirstChild("Halloween 2026")

    local folders = {}
    if not halloween then return folders end

    for _,name in ipairs({
        "Candies",
        "CandiesZone",
        "CandiesZones"
    }) do
        local folder = halloween:FindFirstChild(name)
        if folder then
            table.insert(folders,folder)
        end
    end

    return folders
end

local function isCandyPrompt(obj)
    if not obj:IsA("ProximityPrompt")
        or not obj.Enabled then
        return false
    end

    local text = (
        obj.Name.." "..
        obj.ActionText.." "..
        obj.ObjectText
    ):lower()

    return text:find("candy",1,true)
        or text:find("collect",1,true)
        or text:find("halloween",1,true)
end

local function promptPosition(prompt)
    local node = prompt.Parent

    while node and node ~= WS do
        if node:IsA("BasePart") then
            return node.Position
        end

        if node:IsA("Attachment") then
            return node.WorldPosition
        end

        if node:IsA("Model") then
            local ok,cf = pcall(function()
                return node:GetPivot()
            end)
            if ok then return cf.Position end
        end

        node = node.Parent
    end

    return nil
end

-- Locations completed in this script session. Only one shared table.
local collectedPositions = {}

local function alreadyCollected(pos)
    if not pos then return false end
    for _,savedPos in ipairs(collectedPositions) do
        if (savedPos-pos).Magnitude <= C.MergeRadius then
            return true
        end
    end
    return false
end


local function findEntry(pos)
    for _,entry in pairs(entries) do
        if (entry.position-pos).Magnitude
            <= C.MergeRadius then
            return entry
        end
    end
end

local function createMarker(entry)
    local holder = make("Part",WS,{
        Name="SmithsHubCandyMarker",
        Size=Vector3.new(0.2,0.2,0.2),
        Position=entry.position,
        Anchored=true,
        CanCollide=false,
        CanTouch=false,
        CanQuery=false,
        Transparency=1
    })

    local billboard = make("BillboardGui",PG,{
        Name="SmithsHubCandyESP",
        Adornee=holder,
        Size=UDim2.fromOffset(150,40),
        StudsOffsetWorldSpace=Vector3.new(0,2.5,0),
        AlwaysOnTop=true,
        Enabled=C.ESP
    })

    local label = make("TextLabel",billboard,{
        Size=UDim2.fromScale(1,1),
        BackgroundTransparency=1,
        Text="CANDY",
        TextColor3=CYAN,
        TextStrokeColor3=Color3.new(0,0,0),
        TextStrokeTransparency=0.1,
        Font=Enum.Font.GothamBold,
        TextSize=13
    })

    entry.holder = holder
    entry.billboard = billboard
    entry.label = label
end

local function removeEntry(id)
    local entry = entries[id]
    if not entry then return end

    if entry.billboard then
        entry.billboard:Destroy()
    end

    if entry.holder then
        entry.holder:Destroy()
    end

    entries[id] = nil
end

local function scanCandies()
    -- Remove collected markers even if they had already become saved.
    -- This also prevents old entries from surviving another scan.
    local staleIds = {}
    for id,entry in pairs(entries) do
        if alreadyCollected(entry.position) then
            table.insert(staleIds,id)
        else
            entry.prompt = nil
            entry.state = "saved"
        end
    end
    for _,id in ipairs(staleIds) do
        removeEntry(id)
    end

    for _,folder in ipairs(getCandyFolders()) do
        for _,obj in ipairs(folder:GetDescendants()) do
            if isCandyPrompt(obj) then
                local pos = promptPosition(obj)

                -- Don't rediscover candy we've already completed.
                if pos and not alreadyCollected(pos) then
                    local entry = findEntry(pos)

                    -- No new discovery with ESP disabled
                    if not entry and C.ESP then
                        entryCounter += 1

                        local id = entryCounter

                        entry = {
                            id=id,
                            position=pos,
                            state="visible",
                            prompt=nil,
                            nextAttempt=0
                        }

                        entries[id] = entry
                        createMarker(entry)
                    end

                    if entry then
                        entry.position = pos
                        entry.prompt = obj
                        entry.state = "visible"

                        if entry.holder then
                            entry.holder.Position = pos
                        end
                    end
                end
            end
        end
    end

    visibleCount = 0
    savedCount = 0

    for _,entry in pairs(entries) do
        if entry.state == "visible" then
            visibleCount += 1
            entry.label.Text = "CANDY"
            entry.label.TextColor3 = CYAN
        else
            savedCount += 1
            entry.label.Text = "SAVED CANDY"
            entry.label.TextColor3 = ORANGE
        end

        entry.billboard.Enabled = C.ESP
    end
end

local function clearMarkers()
    local ids = {}

    for id in pairs(entries) do
        table.insert(ids,id)
    end

    for _,id in ipairs(ids) do
        removeEntry(id)
    end
end

-- =========================================
-- AUTO CLAW
-- =========================================

local clawPhase = "ready"
local wasClawVisible = false
local recoveryFrames = 0
local recoveryLastX = nil
local lastClawX = nil
local lastClawT = nil
local lastDifference = nil
local lastTapAt = -100

local function resetClaw()
    clawPhase = "ready"
    wasClawVisible = false
    recoveryFrames = 0
    recoveryLastX = nil
    lastClawX = nil
    lastClawT = nil
    lastDifference = nil
end

local function guiVisible(obj)
    if not obj or not obj:IsA("GuiObject") then
        return false
    end

    local node = obj

    while node and node ~= PG do
        if node:IsA("GuiObject")
            and not node.Visible then
            return false
        end

        if node:IsA("ScreenGui")
            and not node.Enabled then
            return false
        end

        node = node.Parent
    end

    return node == PG
end

local function hasAncestor(obj,name)
    local node = obj.Parent

    while node and node ~= PG do
        if node.Name == name then
            return true
        end
        node = node.Parent
    end

    return false
end

local function getClaw()
    local g = PG:FindFirstChild("CandyClaw")

    if not g or not g:IsA("ScreenGui")
        or not g.Enabled then
        return nil
    end

    local carriage
    local candy
    local panel = g:FindFirstChild("Panel",true)
    local best = -1

    for _,obj in ipairs(g:GetDescendants()) do
        if obj:IsA("GuiObject") then
            if obj.Name == "Carriage"
                and hasAncestor(obj,"Machine") then
                carriage = obj

            elseif obj.Name == "Candy" then
                local score =
                    (hasAncestor(obj,"Claw Snap") and 10 or 0)
                    + (guiVisible(obj) and 5 or 0)

                if score > best then
                    best = score
                    candy = obj
                end
            end
        end
    end

    if not carriage or not candy or not panel then
        return nil
    end

    if not guiVisible(carriage)
        or not guiVisible(candy) then
        return nil
    end

    return carriage,candy,panel
end

local function tapClaw(x,y)
    local ok = pcall(function()
        VIM:SendMouseButtonEvent(
            x,y,0,true,game,0
        )

        task.defer(function()
            pcall(function()
                VIM:SendMouseButtonEvent(
                    x,y,0,false,game,0
                )
            end)
        end)
    end)

    return ok
end

local function clawStep()
    if not (C.AutoClaw or C.AutoCollect) then
        return
    end

    local carriage,candy,panel = getClaw()

    if not carriage then
        resetClaw()
        clawStatus = "Waiting for claw minigame"
        return
    end

    if not wasClawVisible then
        resetClaw()
        wasClawVisible = true
    end

    local now = os.clock()

    local clawX =
        carriage.AbsolutePosition.X
        + carriage.AbsoluteSize.X/2

    local candyX =
        candy.AbsolutePosition.X
        + candy.AbsoluteSize.X/2

    local gap = clawX-candyX

    if clawPhase == "recovering" then
        local moved = recoveryLastX
            and math.abs(clawX-recoveryLastX)
            or 0

        recoveryLastX = clawX

        if now-lastTapAt >= C.TapCooldown
            and math.abs(gap) >= C.RetryDistance
            and moved >= C.RetryMove then
            recoveryFrames += 1
        else
            recoveryFrames = 0
        end

        if recoveryFrames >= C.RetryFrames then
            clawPhase = "ready"
            lastClawX = nil
            lastClawT = nil
            lastDifference = nil
            recoveryFrames = 0
        end

        return
    end

    local speed = 0

    if lastClawX and lastClawT
        and now > lastClawT then
        speed = math.clamp(
            (clawX-lastClawX)/(now-lastClawT),
            -3000,
            3000
        )
    end

    local diff =
        clawX + speed*C.TapLead - candyX

    local crossed =
        lastDifference ~= nil
        and diff*lastDifference <= 0
        and math.abs(diff) <= C.CrossingTolerance
        and math.abs(lastDifference)
            <= C.CrossingTolerance

    local aligned =
        math.abs(diff) <= C.TapTolerance

    lastClawX = clawX
    lastClawT = now
    lastDifference = diff

    clawStatus = string.format(
        "Claw target: %.0f px",diff
    )

    if not aligned and not crossed then return end
    if now-lastTapAt < C.TapCooldown then return end

    local x = math.floor(
        panel.AbsolutePosition.X
        + panel.AbsoluteSize.X*0.5
    )

    local y = math.floor(
        panel.AbsolutePosition.Y
        + panel.AbsoluteSize.Y*0.86
    )

    lastTapAt = now

    if tapClaw(x,y) then
        clawPhase = "recovering"
        recoveryLastX = clawX
        recoveryFrames = 0
        clawStatus = "Claw tap sent"
    end
end

-- =========================================
-- AUTO COLLECT (VISIBLE + SAVED DISCOVERED MARKERS)
-- =========================================

-- When the claw closes, verify it stays closed briefly,
-- then wait ANOTHER two seconds before travelling.
local nextCandyAt = 0
local clawClosedSince = nil

-- Unlike getClaw(), this also checks the result/payout period.
-- The moving carriage may disappear before the CandyClaw UI closes.
local function isClawUIOpen()
    local g = PG:FindFirstChild("CandyClaw")

    if not g or not g:IsA("ScreenGui") or not g.Enabled then
        return false
    end

    local panel = g:FindFirstChild("Panel", true)

    if panel and panel:IsA("GuiObject")
        and guiVisible(panel) then
        return true
    end

    -- Some versions hide the game panel while displaying results.
    for _,obj in ipairs(g:GetDescendants()) do
        if obj:IsA("GuiObject") and guiVisible(obj) then
            local name = obj.Name:lower()
            if name:find("result",1,true)
                or name:find("reward",1,true)
                or name:find("payout",1,true)
                or name:find("complete",1,true)
                or name:find("win",1,true) then
                return true
            end
        end
    end

    -- With the Panel hidden and no result visible, the game has closed.
    -- If this GUI has no Panel, treat Enabled as open to be safe.
    return panel == nil
end

local function stopCollection()
    currentTarget = nil
    collectPhase = "idle"
    collectStarted = 0
    clawClosedSince = nil
    nextCandyAt = 0
    collectStatus = "Auto Collect: OFF"
end

-- Select already discovered candies, regardless of whether they
-- are currently streamed in (visible) or remembered (saved).
local function findCollectTarget()
    local hum = getHumanoid()
    local root = hum and hum.RootPart

    if not root then return nil end

    local bestEntry
    local bestDistance = math.huge
    local now = os.clock()

    for _,entry in pairs(entries) do
        local eligible =
            entry.state == "visible"
            or entry.state == "saved"

        if eligible and entry.position
            and now >= (entry.nextAttempt or 0) then

            local distance =
                (root.Position-entry.position).Magnitude

            if distance < bestDistance then
                bestDistance = distance
                bestEntry = entry
            end
        end
    end

    return bestEntry
end

local function skipTarget(reason)
    if currentTarget then
        currentTarget.nextAttempt =
            os.clock() + C.TargetRetryDelay
    end

    currentTarget = nil
    collectPhase = "idle"
    collectStarted = 0
    clawClosedSince = nil
    collectStatus = reason
end

local function finishClaw()
    local now = os.clock()

    if currentTarget then
        local pos = currentTarget.position

        -- Remember this location, so a streamed prompt cannot add it again.
        if pos and not alreadyCollected(pos) then
            table.insert(collectedPositions,pos)
        end

        -- Delete every entry close to the completed target, including
        -- saved entries. Don't change entries while iterating them.
        local removeIds = {}
        for id,entry in pairs(entries) do
            if id == currentTarget.id or (pos and
                (entry.position-pos).Magnitude <= C.MergeRadius) then
                table.insert(removeIds,id)
            end
        end
        for _,id in ipairs(removeIds) do
            removeEntry(id)
        end
    end

    currentTarget = nil
    collectPhase = "cooldown"
    clawClosedSince = nil
    nextCandyAt = now + C.NextCandyDelay
    collectStatus = "Claw finished | Marker cleared | Waiting 2 seconds"
end

local function collectionStep()
    if not C.AutoCollect then return end

    local hum = getHumanoid()
    local root = hum and hum.RootPart

    if not root then
        collectStatus = "Waiting for character"
        return
    end

    local now = os.clock()
    local clawOpen = isClawUIOpen()

    -- While the claw or payout screen is active, never teleport.
    if collectPhase == "playing" then
        if clawOpen then
            clawClosedSince = nil
            collectStatus = "Claw active | Waiting for result screen"
            return
        end

        -- The carriage can disappear mid-animation. Require a
        -- sustained close before starting the payout cooldown.
        if not clawClosedSince then
            clawClosedSince = now
            collectStatus = "Confirming claw has fully closed"
            return
        end

        if now - clawClosedSince < C.ClawCloseConfirm then
            return
        end

        finishClaw()
        return
    end

    if collectPhase == "cooldown" then
        if clawOpen then
            -- Late result screen: do not count this time as cooldown.
            collectPhase = "playing"
            clawClosedSince = nil
            collectStatus = "Waiting for result/payout screen"
            return
        end

        local remaining = nextCandyAt - now
        if remaining > 0 then
            collectStatus = string.format(
                "Payout delay | Next candy in %.1f s",
                remaining
            )
            return
        end

        collectPhase = "idle"
        nextCandyAt = 0
        collectStatus = "Ready for next candy"
    end

    if collectPhase == "triggered" then
        if clawOpen then
            collectPhase = "playing"
            clawClosedSince = nil
            collectStatus = "Playing claw minigame"
        elseif now - collectStarted > 12 then
            skipTarget("Minigame timeout; skipping")
        else
            collectStatus = "Waiting for claw to open"
        end
        return
    end

    -- An already-open claw must finish before starting any new candy.
    if clawOpen then
        collectStatus = "Waiting for existing claw to close"
        return
    end

    if not currentTarget then
        currentTarget = findCollectTarget()

        if not currentTarget then
            collectStatus = "No available visible or saved candies"
            return
        end

        collectStarted = now
        collectPhase = "travelling"

        -- Only travel to locations previously detected by ESP;
        -- no map sweep, random searching, or unexplored locations.
        root.CFrame = CFrame.new(
            currentTarget.position
            + Vector3.new(0,3,0)
        )

        root.AssemblyLinearVelocity = Vector3.zero

        collectStatus = currentTarget.state == "visible"
            and "Travelling to visible candy"
            or "Travelling to saved candy"
        return
    end

    if collectPhase == "travelling" then
        if now - collectStarted < 0.7 then
            return
        end

        if isClawUIOpen() then
            collectStatus = "Waiting for existing claw to close"
            return
        end

        local prompt = currentTarget.prompt

        if prompt and prompt.Parent and prompt.Enabled then
            if type(fireproximityprompt) ~= "function" then
                skipTarget("Executor lacks fireproximityprompt")
                return
            end

            local pos = promptPosition(prompt)

            if pos then
                root.CFrame = CFrame.new(
                    pos + Vector3.new(0,2,0)
                )
                root.AssemblyLinearVelocity = Vector3.zero
            end

            local ok,err = pcall(function()
                fireproximityprompt(prompt)
            end)

            if ok then
                collectPhase = "triggered"
                collectStarted = now
                collectStatus = "Opening candy | Waiting for claw"
            else
                warn("[Smith's Hub] Candy prompt:",err)
                skipTarget("Prompt failed; trying another candy")
            end

        elseif now - collectStarted > 8 then
            skipTarget("Candy not streamed; trying another")
        else
            collectStatus = "Waiting for candy to stream"
        end
    end
end

-- =========================================
-- GUI CREATION
-- =========================================

local guiParent = PG

if type(gethui) == "function" then
    local ok,result = pcall(gethui)
    if ok and result then guiParent = result end
end

local gui = make("ScreenGui",guiParent,{
    Name="SmithsHubV153",
    ResetOnSpawn=false,
    IgnoreGuiInset=true,
    DisplayOrder=9000,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling
})

local window = make("Frame",gui,{
    Size=UDim2.fromOffset(660,350),
    Position=UDim2.new(0.5,-330,0.32,0),
    BackgroundColor3=BG,
    BorderSizePixel=0,
    Active=true,
    Visible=false
})
corner(window,12)

local border = make("UIStroke",window,{
    Color=ORANGE,
    Thickness=2
})

local windowScale = make("UIScale",window,{
    Scale=0.92
})

local header = make("Frame",window,{
    Size=UDim2.new(1,0,0,48),
    BackgroundTransparency=1,
    Active=true
})

local headerLogo = make("ImageLabel",header,{
    Position=UDim2.fromOffset(12,7),
    Size=UDim2.fromOffset(34,34),
    BackgroundTransparency=1,
    Image="",
    ScaleType=Enum.ScaleType.Fit,
    ZIndex=3
})

local headerFallback = make("TextLabel",header,{
    Position=UDim2.fromOffset(12,7),
    Size=UDim2.fromOffset(34,34),
    BackgroundColor3=PANEL,
    Text="S",
    TextColor3=WHITE,
    Font=Enum.Font.GothamBlack,
    TextSize=23,
    ZIndex=2
})
corner(headerFallback,7)

make("TextLabel",header,{
    Text="SMITH'S HUB  |  V15.3",
    Position=UDim2.fromOffset(56,2),
    Size=UDim2.fromOffset(300,44),
    BackgroundTransparency=1,
    TextColor3=WHITE,
    Font=Enum.Font.GothamBold,
    TextSize=17,
    TextXAlignment=Enum.TextXAlignment.Left
})

local function headerButton(text,x,color)
    local button = make("TextButton",header,{
        Text=text,
        Position=UDim2.new(1,x,0,9),
        Size=UDim2.fromOffset(30,28),
        BackgroundColor3=color,
        TextColor3=WHITE,
        Font=Enum.Font.GothamBold,
        TextSize=20,
        BorderSizePixel=0
    })
    corner(button,6)
    return button
end

local minimize = headerButton("−",-80,PANEL)
local close = headerButton(
    "×",-43,Color3.fromRGB(150,44,48)
)

local mini = make("TextButton",gui,{
    Text="S",
    Size=UDim2.fromOffset(52,52),
    Position=window.Position,
    BackgroundColor3=BG,
    BorderSizePixel=0,
    TextColor3=WHITE,
    Font=Enum.Font.GothamBlack,
    TextSize=26,
    Active=true,
    Visible=false
})
corner(mini,11)

local miniLogo = make("ImageLabel",mini,{
    Size=UDim2.new(1,-8,1,-8),
    Position=UDim2.fromOffset(4,4),
    BackgroundTransparency=1,
    Image="",
    ScaleType=Enum.ScaleType.Fit
})

local miniBorder = make("UIStroke",mini,{
    Color=ORANGE,
    Thickness=2
})

-- =========================================
-- 3 SECOND WELCOME ANIMATION
-- =========================================

local splash = make("Frame",gui,{
    Name="WelcomeOverlay",
    Size=UDim2.fromScale(1,1),
    Position=UDim2.fromScale(0,0),
    BackgroundColor3=Color3.fromRGB(8,9,15),
    BackgroundTransparency=0.25,
    BorderSizePixel=0,
    ZIndex=20
})

local splashCard = make("Frame",splash,{
    AnchorPoint=Vector2.new(0.5,0.5),
    Position=UDim2.fromScale(0.5,0.5),
    Size=UDim2.fromOffset(76,76),
    BackgroundColor3=BG,
    BorderSizePixel=0,
    ClipsDescendants=true,
    ZIndex=21
})
corner(splashCard,18)

local splashBorder = make("UIStroke",splashCard,{
    Color=ORANGE,
    Thickness=2.5
})

local splashLogo = make("ImageLabel",splashCard,{
    AnchorPoint=Vector2.new(0.5,0.5),
    Position=UDim2.fromScale(0.5,0.5),
    Size=UDim2.fromOffset(52,52),
    Image="",
    BackgroundTransparency=1,
    ScaleType=Enum.ScaleType.Fit,
    ZIndex=24
})

local splashFallback = make("TextLabel",splashCard,{
    AnchorPoint=Vector2.new(0.5,0.5),
    Position=UDim2.fromScale(0.5,0.5),
    Size=UDim2.fromOffset(52,52),
    BackgroundColor3=PANEL,
    Text="S",
    TextColor3=WHITE,
    Font=Enum.Font.GothamBlack,
    TextSize=34,
    ZIndex=23
})
corner(splashFallback,12)

local welcomeTitle = make("TextLabel",splashCard,{
    Text="WELCOME TO SMITH'S HUB",
    Position=UDim2.fromOffset(115,39),
    Size=UDim2.fromOffset(380,42),
    BackgroundTransparency=1,
    TextTransparency=1,
    TextColor3=WHITE,
    Font=Enum.Font.GothamBold,
    TextSize=21,
    TextXAlignment=Enum.TextXAlignment.Left,
    ZIndex=23
})

local welcomeSubtitle = make("TextLabel",splashCard,{
    Text="Movement  •  Auto Farm",
    Position=UDim2.fromOffset(116,88),
    Size=UDim2.fromOffset(370,25),
    BackgroundTransparency=1,
    TextTransparency=1,
    TextColor3=GREY,
    Font=Enum.Font.GothamMedium,
    TextSize=13,
    TextXAlignment=Enum.TextXAlignment.Left,
    ZIndex=23
})

local loadingText = make("TextLabel",splashCard,{
    Text="LOADING SMITH'S HUB...",
    Position=UDim2.fromOffset(116,122),
    Size=UDim2.fromOffset(370,20),
    BackgroundTransparency=1,
    TextTransparency=1,
    TextColor3=ORANGE,
    Font=Enum.Font.Gotham,
    TextSize=11,
    TextXAlignment=Enum.TextXAlignment.Left,
    ZIndex=23
})

local progressTrack = make("Frame",splashCard,{
    Position=UDim2.fromOffset(116,151),
    Size=UDim2.fromOffset(365,5),
    BackgroundColor3=PANEL,
    BackgroundTransparency=1,
    BorderSizePixel=0,
    ZIndex=23
})
corner(progressTrack,4)

local progressFill = make("Frame",progressTrack,{
    Size=UDim2.fromScale(0,1),
    BackgroundColor3=ORANGE,
    BorderSizePixel=0,
    ZIndex=24
})
corner(progressFill,4)

-- Download GitHub logo once and share it across GUI.
local function loadLogo()
    local assetLoader = getcustomasset or getsynasset

    if type(writefile) ~= "function"
        or type(delfile) ~= "function"
        or type(assetLoader) ~= "function" then
        warn("[Smith's Hub] Custom logo APIs unavailable")
        return
    end

    task.spawn(function()
        local ok,asset = pcall(function()
            local bytes = game:HttpGet(LOGO_URL)
            assert(type(bytes)=="string" and #bytes>100)

            writefile(TEMP_LOGO,bytes)
            return assetLoader(TEMP_LOGO)
        end)

        if ok and type(asset)=="string" and alive then
            headerLogo.Image=asset
            miniLogo.Image=asset
            splashLogo.Image=asset

            -- Try to load asset before removing temporary file.
            pcall(function()
                CP:PreloadAsync({
                    headerLogo,
                    miniLogo,
                    splashLogo
                })
            end)

            if alive then
                headerFallback.Visible=false
                splashFallback.Visible=false
                mini.Text=""
            end
        else
            warn("[Smith's Hub] Logo unavailable:",
                tostring(asset))
        end

        pcall(function()
            if type(isfile)~="function"
                or isfile(TEMP_LOGO) then
                delfile(TEMP_LOGO)
            end
        end)
    end)
end

loadLogo()

-- Stage 1: logo stays centered for 0.5s
task.delay(0.5,function()
    if not alive or not splashCard.Parent then return end

    -- Stage 2: panel expands outward from logo
    tween(splashCard,0.68,{
        Size=UDim2.fromOffset(520,180)
    })

    tween(splashLogo,0.68,{
        Position=UDim2.new(0,63,0.5,0)
    })

    tween(splashFallback,0.68,{
        Position=UDim2.new(0,63,0.5,0)
    })
end)

task.delay(1.15,function()
    if not alive or not splashCard.Parent then return end

    -- Stage 3: reveal welcome message
    tween(welcomeTitle,0.35,{
        TextTransparency=0
    })

    tween(welcomeSubtitle,0.45,{
        TextTransparency=0
    })

    tween(loadingText,0.45,{
        TextTransparency=0
    })

    tween(progressTrack,0.3,{
        BackgroundTransparency=0
    })

    tween(progressFill,1.35,{
        Size=UDim2.fromScale(1,1)
    },Enum.EasingStyle.Sine)
end)

task.delay(2.65,function()
    if not alive or not splashCard.Parent then return end

    -- Fade the intro out
    tween(splash,0.32,{
        BackgroundTransparency=1
    })

    tween(splashCard,0.32,{
        BackgroundTransparency=1
    })

    tween(splashBorder,0.32,{
        Transparency=1
    })

    for _,label in ipairs({
        welcomeTitle,
        welcomeSubtitle,
        loadingText
    }) do
        tween(label,0.25,{
            TextTransparency=1
        })
    end

    tween(splashLogo,0.25,{
        ImageTransparency=1
    })

    tween(splashFallback,0.25,{
        TextTransparency=1,
        BackgroundTransparency=1
    })

    tween(progressTrack,0.25,{
        BackgroundTransparency=1
    })

    tween(progressFill,0.25,{
        BackgroundTransparency=1
    })
end)

task.delay(3,function()
    if not alive then return end

    if splash.Parent then
        splash:Destroy()
    end

    window.Visible=true

    tween(windowScale,0.38,{
        Scale=1
    },Enum.EasingStyle.Back)
end)

-- =========================================
-- DRAGGING
-- =========================================

local function draggable(handle,target)
    local dragging=false
    local moved=false
    local activeInput
    local startMouse
    local startPos

    connect(handle.InputBegan,function(input)
        if input.UserInputType ==
            Enum.UserInputType.MouseButton1
            or input.UserInputType ==
            Enum.UserInputType.Touch then

            dragging=true
            moved=false
            activeInput=input
            startMouse=input.Position
            startPos=target.Position
        end
    end)

    connect(UIS.InputChanged,function(input)
        if not dragging then return end

        if input==activeInput
            or (activeInput
                and activeInput.UserInputType ==
                    Enum.UserInputType.MouseButton1
                and input.UserInputType ==
                    Enum.UserInputType.MouseMovement) then

            local delta=input.Position-startMouse
            if delta.Magnitude>8 then moved=true end

            target.Position=UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset+delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset+delta.Y
            )
        end
    end)

    connect(UIS.InputEnded,function(input)
        if input==activeInput
            or (activeInput
                and activeInput.UserInputType ==
                    Enum.UserInputType.MouseButton1
                and input.UserInputType ==
                    Enum.UserInputType.MouseButton1) then

            dragging=false
            activeInput=nil
        end
    end)

    return function()
        return moved
    end
end

draggable(header,window)
local miniMoved=draggable(mini,mini)

-- =========================================
-- TABS
-- =========================================

local nav=make("Frame",window,{
    Position=UDim2.fromOffset(16,55),
    Size=UDim2.new(1,-32,0,39),
    BackgroundColor3=DARK,
    BorderSizePixel=0
})
corner(nav,8)

local function tabButton(text,x)
    local btn=make("TextButton",nav,{
        Text=text,
        Position=UDim2.new(x,3,0,3),
        Size=UDim2.new(0.5,-6,1,-6),
        BackgroundColor3=PANEL,
        BorderSizePixel=0,
        TextColor3=WHITE,
        Font=Enum.Font.GothamBold,
        TextSize=13
    })
    corner(btn,7)
    return btn
end

local movementTab=tabButton("MOVEMENT",0)
local farmTab=tabButton("AUTO FARM",0.5)

local movementPage=make("Frame",window,{
    Position=UDim2.fromOffset(16,105),
    Size=UDim2.new(1,-32,1,-120),
    BackgroundTransparency=1
})

local farmPage=make("Frame",window,{
    Position=UDim2.fromOffset(16,105),
    Size=UDim2.new(1,-32,1,-120),
    BackgroundTransparency=1,
    Visible=false
})

local function setTab(movement)
    movementPage.Visible=movement
    farmPage.Visible=not movement

    movementTab.BackgroundColor3=
        movement and ORANGE or PANEL

    farmTab.BackgroundColor3=
        movement and PANEL or ORANGE
end

connect(movementTab.MouseButton1Click,function()
    setTab(true)
end)

connect(farmTab.MouseButton1Click,function()
    setTab(false)
end)

setTab(true)

-- =========================================
-- MOVEMENT: ONLY TWO VEHICLE SLIDERS
-- =========================================

local function slider(parent,x,y,width,title,callback)
    make("TextLabel",parent,{
        Text=title,
        Position=UDim2.fromOffset(x,y),
        Size=UDim2.fromOffset(width-85,22),
        BackgroundTransparency=1,
        TextColor3=WHITE,
        Font=Enum.Font.GothamSemibold,
        TextSize=14,
        TextXAlignment=Enum.TextXAlignment.Left
    })

    local valueLabel=make("TextLabel",parent,{
        Text="1.0x",
        Position=UDim2.fromOffset(x+width-85,y),
        Size=UDim2.fromOffset(85,22),
        BackgroundTransparency=1,
        TextColor3=ORANGE,
        Font=Enum.Font.GothamBold,
        TextSize=14,
        TextXAlignment=Enum.TextXAlignment.Right
    })

    local track=make("Frame",parent,{
        Position=UDim2.fromOffset(x,y+45),
        Size=UDim2.fromOffset(width,8),
        BackgroundColor3=PANEL,
        BorderSizePixel=0
    })
    corner(track,5)

    local fill=make("Frame",track,{
        Size=UDim2.fromScale(0,1),
        BackgroundColor3=ORANGE,
        BorderSizePixel=0
    })
    corner(fill,5)

    local knob=make("Frame",track,{
        Size=UDim2.fromOffset(19,19),
        Position=UDim2.new(0,-9,0.5,-9.5),
        BackgroundColor3=WHITE,
        BorderSizePixel=0
    })
    corner(knob,10)

    local hitbox=make("Frame",parent,{
        Position=UDim2.fromOffset(x,y+34),
        Size=UDim2.fromOffset(width,30),
        BackgroundTransparency=1,
        Active=true,
        ZIndex=4
    })

    local function set(v)
     v=math.clamp(
         math.floor(v*10+0.5)/10,
         0.1,20
)

        	local alpha=(v-0.1)/19.9

        fill.Size=UDim2.fromScale(alpha,1)
        knob.Position=UDim2.new(alpha,-9,0.5,-9.5)

        valueLabel.Text=string.format("%.1fx",v)
        callback(v)
    end

    local activeInput
    local dragging=false

    local function update(xpos)
        if track.AbsoluteSize.X<=0 then return end

        local alpha=math.clamp(
            (xpos-track.AbsolutePosition.X)
                /track.AbsoluteSize.X,
            0,1
        )

        set(0.1+alpha*19.9)
    end

    connect(hitbox.InputBegan,function(input)
        if input.UserInputType ==
            Enum.UserInputType.MouseButton1
            or input.UserInputType ==
            Enum.UserInputType.Touch then

            dragging=true
            activeInput=input
            update(input.Position.X)
        end
    end)

    connect(UIS.InputChanged,function(input)
        if not dragging then return end

        if input==activeInput
            or (activeInput
                and activeInput.UserInputType ==
                    Enum.UserInputType.MouseButton1
                and input.UserInputType ==
                    Enum.UserInputType.MouseMovement) then

            update(input.Position.X)
        end
    end)

    connect(UIS.InputEnded,function(input)
        if input==activeInput
            or (activeInput
                and activeInput.UserInputType ==
                    Enum.UserInputType.MouseButton1
                and input.UserInputType ==
                    Enum.UserInputType.MouseButton1) then

            dragging=false
            activeInput=nil
        end
    end)

    set(1)
end

slider(
    movementPage,16,34,270,
    "Acceleration Boost",
    function(v)
        C.Acceleration=v
    end
)

slider(
    movementPage,334,34,270,
    "Gear Speed Boost",
    function(v)
        C.GearSpeed=v
    end
)

make("TextLabel",movementPage,{
    Text="Automatic A-Chassis detection  •  Normal steering and gear shifting",
    Position=UDim2.fromOffset(16,126),
    Size=UDim2.new(1,-32,0,24),
    BackgroundTransparency=1,
    TextColor3=GREY,
    Font=Enum.Font.Gotham,
    TextSize=12,
    TextXAlignment=Enum.TextXAlignment.Left
})

-- =========================================
-- AUTO FARM: THREE TOGGLES
-- =========================================

local function toggleButton(x,title,enabled,callback)
    local btn=make("TextButton",farmPage,{
        Text=title..": "..(enabled and "ON" or "OFF"),
        Position=UDim2.fromOffset(x,15),
        Size=UDim2.fromOffset(194,58),
        BackgroundColor3=enabled and ORANGE or OFF,
        BorderSizePixel=0,
        TextColor3=WHITE,
        Font=Enum.Font.GothamBold,
        TextSize=13
    })
    corner(btn,9)

    connect(btn.MouseButton1Click,function()
        enabled=not enabled

        btn.Text=title..": "..(enabled and "ON" or "OFF")
        btn.BackgroundColor3=enabled and ORANGE or OFF

        callback(enabled)
    end)

    return btn
end

toggleButton(12,"CANDY ESP",true,function(v)
    C.ESP=v

    for _,entry in pairs(entries) do
        if entry.billboard then
            entry.billboard.Enabled=v
        end
    end
end)

toggleButton(217,"AUTO CLAW",false,function(v)
    C.AutoClaw=v
    resetClaw()
end)

toggleButton(422,"AUTO COLLECT",false,function(v)
    C.AutoCollect=v

    if not v then
        stopCollection()
    else
        -- Refresh markers immediately. Both visible and saved count.
        local ok,err = pcall(scanCandies)
        if not ok then
            warn("[Smith's Hub] Candy scan:",err)
        end
        collectStatus="Searching visible and saved candies"
    end
end)

local farmInfo=make("TextLabel",farmPage,{
    Text="VISIBLE: 0  |  SAVED: 0",
    Position=UDim2.fromOffset(12,89),
    Size=UDim2.new(1,-24,0,23),
    BackgroundTransparency=1,
    TextColor3=WHITE,
    Font=Enum.Font.GothamSemibold,
    TextSize=13,
    TextXAlignment=Enum.TextXAlignment.Left
})

local collectInfo=make("TextLabel",farmPage,{
    Text="Auto Collect: OFF",
    Position=UDim2.fromOffset(12,119),
    Size=UDim2.new(1,-24,0,22),
    BackgroundTransparency=1,
    TextColor3=GREY,
    Font=Enum.Font.Gotham,
    TextSize=12,
    TextXAlignment=Enum.TextXAlignment.Left
})

local clawInfo=make("TextLabel",farmPage,{
    Text="Auto Claw: OFF",
    Position=UDim2.fromOffset(12,145),
    Size=UDim2.new(1,-24,0,22),
    BackgroundTransparency=1,
    TextColor3=GREY,
    Font=Enum.Font.Gotham,
    TextSize=12,
    TextXAlignment=Enum.TextXAlignment.Left
})

-- STREAMINGENABLED NOTICE
-- Candies must stream in nearby before the ESP can discover them.
local streamingNotice=make("TextLabel",farmPage,{
    Name="StreamingNotice",
    Text="STREAMING ENABLED: Get close enough to candies for them to load before they can be detected and collected.",
    Position=UDim2.fromOffset(12,183),
    Size=UDim2.new(1,-24,0,42),
    BackgroundColor3=DARK,
    BorderSizePixel=0,
    TextColor3=GREY,
    Font=Enum.Font.GothamMedium,
    TextSize=11,
    TextWrapped=true,
    TextXAlignment=Enum.TextXAlignment.Center
})
corner(streamingNotice,7)

connect(minimize.MouseButton1Click,function()
    mini.Position=window.Position
    window.Visible=false
    mini.Visible=true
end)

connect(mini.MouseButton1Click,function()
    if not miniMoved() then
        window.Position=mini.Position
        mini.Visible=false
        window.Visible=true
    end
end)

-- =========================================
-- UPDATE LOOPS
-- =========================================

local hue=0
local vehicleTimer=0
local scanTimer=0
local uiTimer=0

connect(RS.Heartbeat,function(dt)
    if not alive then return end

    dt=math.min(dt,0.1)

    hue=(hue+dt*0.17)%1
    local rgb=Color3.fromHSV(hue,0.85,1)

    border.Color=rgb
    miniBorder.Color=rgb

    if splashBorder.Parent then
        splashBorder.Color=rgb
    end

    vehicleTimer += dt

    if vehicleTimer>=0.05 then
        local elapsed=vehicleTimer
        vehicleTimer=0

        local car,seat,module=findVehicle()

        if not car then
            restoreVehicle()
        else
            if session and (
                session.car~=car
                or session.seat~=seat
            ) then
                restoreVehicle()
            end

            if not session then
                loadVehicle(car,seat,module)
            end

            if session then
                if session.values.Parent then
                    local ok,err=pcall(
                        updateVehicle,session,elapsed
                    )

                    if not ok then
                        warn("[Smith's Hub] Vehicle:",err)
                        restoreVehicle()
                    end
                else
                    restoreVehicle()
                end
            end
        end
    end

    scanTimer += dt

    if scanTimer>=C.ScanRate then
        scanTimer=0
        local ok,err=pcall(scanCandies)

        if not ok then
            warn("[Smith's Hub] ESP:",err)
        end
    end

    uiTimer += dt

    if uiTimer>=0.2 then
        uiTimer=0

        farmInfo.Text=string.format(
            "VISIBLE CANDIES: %d  |  SAVED: %d",
            visibleCount,
            savedCount
        )

        collectInfo.Text=collectStatus

        clawInfo.Text=
            (C.AutoClaw or C.AutoCollect)
            and clawStatus
            or "Auto Claw: OFF"
    end
end)

-- INDEPENDENT AUTO-COLLECT LOOP
-- Not gated by vehicle or ESP update logic.
local collectionTimer = 0
connect(RS.Heartbeat,function(dt)
    if not alive or not C.AutoCollect then
        collectionTimer = 0
        return
    end

    collectionTimer += math.min(dt,0.1)
    if collectionTimer < 0.25 then return end
    collectionTimer = 0

    local ok,err = pcall(collectionStep)
    if not ok then
        collectStatus = "Auto Collect ERROR"
        warn("[Smith's Hub] Collection:",err)
    end
end)

connect(RS.RenderStepped,function()
    if not alive then return end

    if C.AutoClaw or C.AutoCollect then
        local ok,err=pcall(clawStep)

        if not ok then
            clawStatus="Claw error: "..tostring(err)
        end
    end
end)

-- =========================================
-- CLEANUP
-- =========================================

local function unload()
    if not alive then return end
    alive=false

    stopCollection()
    restoreVehicle()

    for _,c in ipairs(connections) do
        pcall(function()
            c:Disconnect()
        end)
    end

    clearMarkers()
    gui:Destroy()

    if ENV.SmithHubV153Unload==unload then
        ENV.SmithHubV153Unload=nil
    end

    print("[SMITH'S HUB V15.3] Unloaded")
end

ENV.SmithHubV153Unload=unload

connect(close.MouseButton1Click,unload)

print("[SMITH'S HUB V15.3] Loaded")
