
--[[
    SMITH'S HUB V14
    github.com/glitchlend/Smiths-Hub

    MOVEMENT
      WalkSpeed
      JumpPower
      Acceleration Boost
      Gear Speed Boost

    AUTO FARM
      Candy ESP
      Auto Claw
      Auto Collect (saved markers only)

    LOGO
      GitHub-hosted PNG
      Temporary file, deleted after loading
]]

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local WS = game:GetService("Workspace")
local CP = game:GetService("ContentProvider")
local VIM = game:GetService("VirtualInputManager")

local Player = Players.LocalPlayer
local PG = Player:WaitForChild("PlayerGui")
local Env = (getgenv and getgenv()) or _G

-- CLEANUP PREVIOUS VERSIONS
for _, name in ipairs({
    "SmithHubV14Unload",
    "SmithHubV13Unload",
    "SmithBoostV3Cleanup",
    "SmithBoostV2Cleanup",
    "SmithBoostCleanup",
    "YSOBoostCleanup"
}) do
    if type(Env[name]) == "function" then
        pcall(Env[name])
    end
end

local LOGO_URL =
    "https://raw.githubusercontent.com/glitchlend/Smiths-Hub/main/logo.png"

local LOGO_TEMP_FILE = "SmithsHub_logo_temp.png"

local Config = {
    WalkSpeed = 16,
    JumpPower = 50,
    WalkChanged = false,
    JumpChanged = false,

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
    RetryFrames = 3
}

local alive = true
local connections = {}
local session = nil

local entries = {}
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

local function getHumanoid()
    local character = Player.Character
    return character and
        character:FindFirstChildOfClass("Humanoid")
end

-- =========================================
-- CHARACTER MOVEMENT
-- =========================================

local originalHumanoids = setmetatable({},{
    __mode="k"
})

local startingHumanoid = getHumanoid()

if startingHumanoid then
    Config.WalkSpeed = startingHumanoid.WalkSpeed
    Config.JumpPower = startingHumanoid.JumpPower
end

local function applyMovement()
    local hum = getHumanoid()
    if not hum then return end

    if not originalHumanoids[hum] then
        originalHumanoids[hum] = {
            WalkSpeed=hum.WalkSpeed,
            JumpPower=hum.JumpPower,
            UseJumpPower=hum.UseJumpPower
        }
    end

    if Config.WalkChanged then
        hum.WalkSpeed = Config.WalkSpeed
    end

    if Config.JumpChanged then
        hum.UseJumpPower = true
        hum.JumpPower = Config.JumpPower
    end
end

-- =========================================
-- VEHICLE ENGINE / GEAR BOOST
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
        gearCount=#ratios-neutralIndex,
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
        accelerating and Config.Acceleration or 1

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

    -- Scale every forward gear equally
    for i=s.firstGearIndex,#s.ratios do
        local original = s.ratios[i]

        if type(original) == "number" then
            s.tune.Ratios[i] =
                original/Config.GearSpeed
        end
    end

    if type(s.speedLimit) == "number" then
        s.tune.SpeedLimit =
            s.speedLimit > 0
            and s.speedLimit*Config.GearSpeed
            or s.speedLimit
    end
end

-- =========================================
-- CANDY ESP / SAVED MARKERS
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

local function findEntry(pos)
    for _,entry in pairs(entries) do
        if (entry.position-pos).Magnitude
            <= Config.MergeRadius then
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
        Enabled=Config.ESP
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
    -- Existing markers become saved if no longer streamed
    for _,entry in pairs(entries) do
        entry.prompt = nil
        entry.state = "saved"
    end

    for _,folder in ipairs(getCandyFolders()) do
        for _,obj in ipairs(folder:GetDescendants()) do
            if isCandyPrompt(obj) then
                local pos = promptPosition(obj)

                if pos then
                    local entry = findEntry(pos)

                    -- Only ESP can discover NEW locations
                    if not entry and Config.ESP then
                        local id = tostring(obj)

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

        entry.billboard.Enabled = Config.ESP
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
    if not (Config.AutoClaw or Config.AutoCollect) then
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

        if now-lastTapAt >= Config.TapCooldown
            and math.abs(gap) >= Config.RetryDistance
            and moved >= Config.RetryMove then

            recoveryFrames += 1
        else
            recoveryFrames = 0
        end

        if recoveryFrames >= Config.RetryFrames then
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
        clawX + speed*Config.TapLead - candyX

    local crossed =
        lastDifference ~= nil
        and diff*lastDifference <= 0
        and math.abs(diff) <= Config.CrossingTolerance
        and math.abs(lastDifference)
            <= Config.CrossingTolerance

    local aligned =
        math.abs(diff) <= Config.TapTolerance

    lastClawX = clawX
    lastClawT = now
    lastDifference = diff

    clawStatus = string.format(
        "Claw target: %.0f px",diff
    )

    if not aligned and not crossed then return end
    if now-lastTapAt < Config.TapCooldown then return end

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
-- AUTO COLLECT: SAVED MARKERS ONLY
-- =========================================

local function stopCollection()
    currentTarget = nil
    collectPhase = "idle"
    collectStatus = "Auto Collect: OFF"
end

local function findSavedTarget()
    local hum = getHumanoid()
    local root = hum and hum.RootPart

    if not root then return nil end

    local bestEntry
    local bestDistance = math.huge
    local now = os.clock()

    for _,entry in pairs(entries) do
        if entry.state == "saved"
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
        currentTarget.nextAttempt = os.clock()+30
    end

    currentTarget = nil
    collectPhase = "idle"
    collectStatus = reason
end

local function collectionStep()
    if not Config.AutoCollect then return end

    local hum = getHumanoid()
    local root = hum and hum.RootPart

    if not root then
        collectStatus = "Waiting for character"
        return
    end

    local now = os.clock()
    local activeClaw = getClaw() ~= nil

    if collectPhase == "playing" then
        if not activeClaw then
            -- Attempt ended; don't revisit immediately.
            -- Remove marker only if its prompt has disappeared.
            if currentTarget then
                if not currentTarget.prompt then
                    removeEntry(currentTarget.id)
                else
                    currentTarget.nextAttempt = now+30
                end
            end

            currentTarget = nil
            collectPhase = "idle"
            collectStatus = "Claw attempt finished"
        end
        return
    end

    if collectPhase == "triggered" then
        if activeClaw then
            collectPhase = "playing"
            collectStatus = "Playing claw minigame"
        elseif now-collectStarted > 12 then
            skipTarget("Minigame timeout; skipping")
        end
        return
    end

    if activeClaw then
        collectStatus = "Waiting for current minigame"
        return
    end

    -- ONLY select SAVED, previously discovered markers
    if not currentTarget then
        currentTarget = findSavedTarget()

        if not currentTarget then
            collectStatus = "No saved candy markers"
            return
        end

        collectStarted = now
        collectPhase = "travelling"

        -- Teleport only to its already known position
        root.CFrame = CFrame.new(
            currentTarget.position
            + Vector3.new(0,3,0)
        )

        root.AssemblyLinearVelocity = Vector3.zero

        collectStatus = "Travelling to saved candy"
        return
    end

    if collectPhase == "travelling" then
        -- Give local streaming time to load the candy
        if now-collectStarted < 0.7 then
            return
        end

        if currentTarget.prompt
            and currentTarget.prompt.Parent
            and currentTarget.prompt.Enabled then

            if type(fireproximityprompt) ~= "function" then
                skipTarget("Executor lacks fireproximityprompt")
                return
            end

            local prompt = currentTarget.prompt

            -- Move close to the actual loaded prompt
            local pos = promptPosition(prompt)

            if pos then
                root.CFrame = CFrame.new(
                    pos+Vector3.new(0,2,0)
                )
            end

            local ok = pcall(function()
                fireproximityprompt(prompt)
            end)

            if ok then
                collectPhase = "triggered"
                collectStarted = now
                collectStatus = "Opening saved candy"
            else
                skipTarget("Prompt failed; skipping")
            end

        elseif now-collectStarted > 8 then
            skipTarget("Candy not streamed; skipping")
        else
            collectStatus = "Waiting for saved candy to load"
        end
    end
end

-- =========================================
-- GUI
-- =========================================

local guiParent = PG

if type(gethui) == "function" then
    local ok,result = pcall(gethui)
    if ok and result then guiParent = result end
end

local gui = make("ScreenGui",guiParent,{
    Name="SmithsHubV14",
    ResetOnSpawn=false,
    IgnoreGuiInset=true,
    DisplayOrder=9000,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling
})

local window = make("Frame",gui,{
    Size=UDim2.fromOffset(660,325),
    Position=UDim2.new(0.5,-330,0.3,0),
    BackgroundColor3=BG,
    BorderSizePixel=0,
    Active=true
})
corner(window,12)

local border = make("UIStroke",window,{
    Color=ORANGE,
    Thickness=2
})

local header = make("Frame",window,{
    Size=UDim2.new(1,0,0,48),
    BackgroundTransparency=1,
    Active=true
})

-- LOGO PLACEHOLDERS
local headerLogo = make("ImageLabel",header,{
    Position=UDim2.fromOffset(12,7),
    Size=UDim2.fromOffset(34,34),
    BackgroundTransparency=1,
    Image="",
    ScaleType=Enum.ScaleType.Fit
})

local headerFallback = make("TextLabel",header,{
    Position=UDim2.fromOffset(12,7),
    Size=UDim2.fromOffset(34,34),
    BackgroundColor3=PANEL,
    Text="S",
    TextColor3=WHITE,
    Font=Enum.Font.GothamBlack,
    TextSize=23
})
corner(headerFallback,7)

make("TextLabel",header,{
    Text="SMITH'S HUB  |  V14",
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

-- TEMPORARY GITHUB LOGO LOADING
local function loadGitHubLogo()
    local assetLoader =
        getcustomasset or getsynasset

    if type(writefile) ~= "function"
        or type(delfile) ~= "function"
        or type(assetLoader) ~= "function" then

        warn("[Smith's Hub] Custom image APIs unavailable")
        return
    end

    task.spawn(function()
        local ok,asset = pcall(function()
            local bytes = game:HttpGet(LOGO_URL)

            assert(
                type(bytes) == "string"
                    and #bytes > 100,
                "Invalid image download"
            )

            writefile(LOGO_TEMP_FILE,bytes)
            return assetLoader(LOGO_TEMP_FILE)
        end)

        if ok and type(asset) == "string" and alive then
            headerLogo.Image = asset
            miniLogo.Image = asset

            headerFallback.Visible = false
            mini.Text = ""

            -- Wait for Roblox to load the local asset.
            pcall(function()
                CP:PreloadAsync({
                    headerLogo,
                    miniLogo
                })
            end)
        else
            warn(
                "[Smith's Hub] Logo failed:",
                tostring(asset)
            )
        end

        -- Remove temporary executor workspace file.
        -- The executor/Roblox may retain an asset cache.
        pcall(function()
            if type(isfile) ~= "function"
                or isfile(LOGO_TEMP_FILE) then
                delfile(LOGO_TEMP_FILE)
            end
        end)
    end)
end

-- DRAGGING
local function draggable(handle,target)
    local dragging = false
    local moved = false
    local activeInput
    local startMouse
    local startPos

    connect(handle.InputBegan,function(input)
        if input.UserInputType ==
            Enum.UserInputType.MouseButton1
            or input.UserInputType ==
            Enum.UserInputType.Touch then

            dragging = true
            moved = false
            activeInput = input
            startMouse = input.Position
            startPos = target.Position
        end
    end)

    connect(UIS.InputChanged,function(input)
        if not dragging then return end

        if input == activeInput
            or (activeInput
                and activeInput.UserInputType ==
                    Enum.UserInputType.MouseButton1
                and input.UserInputType ==
                    Enum.UserInputType.MouseMovement) then

            local delta = input.Position-startMouse
            if delta.Magnitude > 8 then moved = true end

            target.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset+delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset+delta.Y
            )
        end
    end)

    connect(UIS.InputEnded,function(input)
        if input == activeInput
            or (activeInput
                and activeInput.UserInputType ==
                    Enum.UserInputType.MouseButton1
                and input.UserInputType ==
                    Enum.UserInputType.MouseButton1) then

            dragging = false
            activeInput = nil
        end
    end)

    return function()
        return moved
    end
end

draggable(header,window)
local miniMoved = draggable(mini,mini)

-- TAB BAR
local nav = make("Frame",window,{
    Position=UDim2.fromOffset(16,55),
    Size=UDim2.new(1,-32,0,39),
    BackgroundColor3=DARK,
    BorderSizePixel=0
})
corner(nav,8)

local function tabButton(text,x)
    local btn = make("TextButton",nav,{
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

local movementTab = tabButton("MOVEMENT",0)
local farmTab = tabButton("AUTO FARM",0.5)

local movementPage = make("Frame",window,{
    Position=UDim2.fromOffset(16,105),
    Size=UDim2.new(1,-32,1,-120),
    BackgroundTransparency=1
})

local farmPage = make("Frame",window,{
    Position=UDim2.fromOffset(16,105),
    Size=UDim2.new(1,-32,1,-120),
    BackgroundTransparency=1,
    Visible=false
})

local function setTab(movement)
    movementPage.Visible = movement
    farmPage.Visible = not movement

    movementTab.BackgroundColor3 =
        movement and ORANGE or PANEL
    farmTab.BackgroundColor3 =
        movement and PANEL or ORANGE
end

connect(movementTab.MouseButton1Click,function()
    setTab(true)
end)

connect(farmTab.MouseButton1Click,function()
    setTab(false)
end)

setTab(true)

-- SLIDER FACTORY
local function slider(parent,x,y,width,title,min,max,step,initial,callback)
    make("TextLabel",parent,{
        Text=title,
        Position=UDim2.fromOffset(x,y),
        Size=UDim2.fromOffset(width-85,22),
        BackgroundTransparency=1,
        TextColor3=WHITE,
        Font=Enum.Font.GothamSemibold,
        TextSize=13,
        TextXAlignment=Enum.TextXAlignment.Left
    })

    local valueLabel = make("TextLabel",parent,{
        Text="",
        Position=UDim2.fromOffset(x+width-85,y),
        Size=UDim2.fromOffset(85,22),
        BackgroundTransparency=1,
        TextColor3=ORANGE,
        Font=Enum.Font.GothamBold,
        TextSize=13,
        TextXAlignment=Enum.TextXAlignment.Right
    })

    local track = make("Frame",parent,{
        Position=UDim2.fromOffset(x,y+33),
        Size=UDim2.fromOffset(width,7),
        BackgroundColor3=PANEL,
        BorderSizePixel=0
    })
    corner(track,5)

    local fill = make("Frame",track,{
        Size=UDim2.fromScale(0,1),
        BackgroundColor3=ORANGE,
        BorderSizePixel=0
    })
    corner(fill,5)

    local knob = make("Frame",track,{
        Size=UDim2.fromOffset(17,17),
        Position=UDim2.new(0,-8,0.5,-8),
        BackgroundColor3=WHITE,
        BorderSizePixel=0
    })
    corner(knob,9)

    local hitbox = make("Frame",parent,{
        Position=UDim2.fromOffset(x,y+24),
        Size=UDim2.fromOffset(width,26),
        BackgroundTransparency=1,
        Active=true,
        ZIndex=4
    })

    local function set(v,apply)
        v = math.clamp(
            math.floor((v-min)/step+0.5)*step+min,
            min,max
        )

        local alpha = (v-min)/(max-min)

        fill.Size = UDim2.fromScale(alpha,1)
        knob.Position = UDim2.new(alpha,-8,0.5,-8)

        if step < 1 then
            valueLabel.Text=string.format("%.1fx",v)
        else
            valueLabel.Text=tostring(math.floor(v))
        end

        if apply then callback(v) end
    end

    local activeInput
    local dragging = false

    local function update(xpos)
        if track.AbsoluteSize.X <= 0 then return end

        local alpha = math.clamp(
            (xpos-track.AbsolutePosition.X)
                /track.AbsoluteSize.X,
            0,1
        )

        set(min+alpha*(max-min),true)
    end

    connect(hitbox.InputBegan,function(input)
        if input.UserInputType ==
            Enum.UserInputType.MouseButton1
            or input.UserInputType ==
            Enum.UserInputType.Touch then

            dragging = true
            activeInput = input
            update(input.Position.X)
        end
    end)

    connect(UIS.InputChanged,function(input)
        if not dragging then return end

        if input == activeInput
            or (activeInput
                and activeInput.UserInputType ==
                    Enum.UserInputType.MouseButton1
                and input.UserInputType ==
                    Enum.UserInputType.MouseMovement) then

            update(input.Position.X)
        end
    end)

    connect(UIS.InputEnded,function(input)
        if input == activeInput
            or (activeInput
                and activeInput.UserInputType ==
                    Enum.UserInputType.MouseButton1
                and input.UserInputType ==
                    Enum.UserInputType.MouseButton1) then

            dragging = false
            activeInput = nil
        end
    end)

    set(initial,false)
end

-- MOVEMENT: TWO COLUMNS
slider(
    movementPage,14,14,278,
    "WalkSpeed",0,200,1,Config.WalkSpeed,
    function(v)
        Config.WalkSpeed = v
        Config.WalkChanged = true
        applyMovement()
    end
)

slider(
    movementPage,14,106,278,
    "JumpPower",0,200,1,Config.JumpPower,
    function(v)
        Config.JumpPower = v
        Config.JumpChanged = true
        applyMovement()
    end
)

slider(
    movementPage,330,14,278,
    "Acceleration Boost",1,5,0.1,1,
    function(v)
        Config.Acceleration = v
    end
)

slider(
    movementPage,330,106,278,
    "Gear Speed Boost",1,5,0.1,1,
    function(v)
        Config.GearSpeed = v
    end
)

-- AUTO FARM: THREE BUTTONS
local function toggleButton(x,title,enabled,callback)
    local btn = make("TextButton",farmPage,{
        Text=title..": "..(enabled and "ON" or "OFF"),
        Position=UDim2.fromOffset(x,17),
        Size=UDim2.fromOffset(194,58),
        BackgroundColor3=enabled and ORANGE or OFF,
        BorderSizePixel=0,
        TextColor3=WHITE,
        Font=Enum.Font.GothamBold,
        TextSize=13
    })
    corner(btn,9)

    connect(btn.MouseButton1Click,function()
        enabled = not enabled
        btn.Text=title..": "..(enabled and "ON" or "OFF")
        btn.BackgroundColor3=enabled and ORANGE or OFF
        callback(enabled)
    end)

    return btn
end

toggleButton(12,"CANDY ESP",true,function(v)
    Config.ESP=v

    for _,entry in pairs(entries) do
        if entry.billboard then
            entry.billboard.Enabled=v
        end
    end
end)

toggleButton(217,"AUTO CLAW",false,function(v)
    Config.AutoClaw=v
    resetClaw()
end)

toggleButton(422,"AUTO COLLECT",false,function(v)
    Config.AutoCollect=v

    if not v then
        stopCollection()
    else
        collectStatus="Searching saved markers"
    end
end)

local farmInfo = make("TextLabel",farmPage,{
    Text="VISIBLE: 0  |  SAVED: 0",
    Position=UDim2.fromOffset(12,94),
    Size=UDim2.new(1,-24,0,25),
    BackgroundTransparency=1,
    TextColor3=WHITE,
    Font=Enum.Font.GothamSemibold,
    TextSize=13,
    TextXAlignment=Enum.TextXAlignment.Left
})

local collectInfo = make("TextLabel",farmPage,{
    Text="Auto Collect: OFF",
    Position=UDim2.fromOffset(12,126),
    Size=UDim2.new(1,-24,0,25),
    BackgroundTransparency=1,
    TextColor3=GREY,
    Font=Enum.Font.Gotham,
    TextSize=12,
    TextXAlignment=Enum.TextXAlignment.Left
})

local clawInfo = make("TextLabel",farmPage,{
    Text="Auto Claw: OFF",
    Position=UDim2.fromOffset(12,156),
    Size=UDim2.new(1,-24,0,25),
    BackgroundTransparency=1,
    TextColor3=GREY,
    Font=Enum.Font.Gotham,
    TextSize=12,
    TextXAlignment=Enum.TextXAlignment.Left
})

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

-- START LOGO LOADING
loadGitHubLogo()

-- =========================================
-- UPDATE LOOPS
-- =========================================

local hue = 0
local movementTimer = 0
local vehicleTimer = 0
local scanTimer = 0
local collectTimer = 0
local uiTimer = 0

connect(RS.Heartbeat,function(dt)
    if not alive then return end

    dt=math.min(dt,0.1)

    hue=(hue+dt*0.17)%1
    local rgb=Color3.fromHSV(hue,0.85,1)
    border.Color=rgb
    miniBorder.Color=rgb

    movementTimer += dt

    if movementTimer >= 0.25 then
        movementTimer=0
        applyMovement()
    end

    vehicleTimer += dt

    if vehicleTimer >= 0.05 then
        local elapsed=vehicleTimer
        vehicleTimer=0

        local car,seat,module=findVehicle()

        if not car then
            restoreVehicle()
        else
            if session and (
                session.car ~= car
                or session.seat ~= seat
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

    if scanTimer >= Config.ScanRate then
        scanTimer=0

        local ok,err=pcall(scanCandies)
        if not ok then
            warn("[Smith's Hub] ESP:",err)
        end
    end

    collectTimer += dt

    if collectTimer >= 0.25 then
        collectTimer=0

        if Config.AutoCollect then
            local ok,err=pcall(collectionStep)

            if not ok then
                collectStatus="Collection error"
                warn("[Smith's Hub] Collect:",err)
            end
        end
    end

    uiTimer += dt

    if uiTimer >= 0.2 then
        uiTimer=0

        farmInfo.Text=string.format(
            "VISIBLE CANDIES: %d  |  SAVED: %d",
            visibleCount,
            savedCount
        )

        collectInfo.Text=collectStatus

        clawInfo.Text=
            (Config.AutoClaw or Config.AutoCollect)
            and clawStatus
            or "Auto Claw: OFF"
    end
end)

connect(RS.RenderStepped,function()
    if not alive then return end

    if Config.AutoClaw or Config.AutoCollect then
        local ok,err=pcall(clawStep)

        if not ok then
            clawStatus="Claw error: "..tostring(err)
        end
    end
end)

-- =========================================
-- UNLOAD
-- =========================================

local function unload()
    if not alive then return end
    alive=false

    stopCollection()
    restoreVehicle()

    for hum,original in pairs(originalHumanoids) do
        if hum and hum.Parent then
            pcall(function()
                if Config.WalkChanged then
                    hum.WalkSpeed=original.WalkSpeed
                end

                if Config.JumpChanged then
                    hum.JumpPower=original.JumpPower
                    hum.UseJumpPower=original.UseJumpPower
                end
            end)
        end
    end

    for _,c in ipairs(connections) do
        pcall(function()
            c:Disconnect()
        end)
    end

    clearMarkers()
    gui:Destroy()

    if Env.SmithHubV14Unload==unload then
        Env.SmithHubV14Unload=nil
    end

    print("[SMITH'S HUB V14] Unloaded")
end

Env.SmithHubV14Unload=unload

connect(close.MouseButton1Click,unload)

print("[SMITH'S HUB V14] Loaded")
