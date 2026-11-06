-- SMITH'S TWISTED V3.2
-- Actual logo + X to unload + independent minimised icon.
-- Measurements marked ~ use unverified game-scale assumptions.

local CFG = {
    InfoHeight = 500,
    MetresPerStud = 0.3048,
    WindToMPH = 1,
    WidthToStuds = 1,
    ForecastSeconds = 60,
    MaxTrailSegments = 90,
}

local LOGO_URL =
    "https://raw.githubusercontent.com/glitchlend/Smiths-Hub/main/assets/logo.png"
local LOGO_FILE = "SmithsHub_Twisted_Logo.png"

local Players = game:GetService("Players")
local Run = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local ContentProvider = game:GetService("ContentProvider")
local player = Players.LocalPlayer

local env = getgenv and getgenv() or _G
local KEY = "SmithTwistedStandalone"

if env[KEY] and type(env[KEY].Destroy) == "function" then
    pcall(env[KEY].Destroy)
end

local alive = true
local connections = {}
local records = {}
local chosen = {}
local chooseNew = true

local options = {
    Info = false,
    Chams = false,
    Trail = false,
    Forecast = false,
    Bright = false,
    Metric = true,
}

local CYAN = Color3.fromRGB(55, 215, 255)
local ORANGE = Color3.fromRGB(255, 175, 60)

local function make(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props) do
        obj[k] = v
    end
    obj.Parent = parent
    return obj
end

local function listen(signal, fn)
    local c = signal:Connect(fn)
    table.insert(connections, c)
    return c
end

local function round(obj)
    make("UICorner", {
        CornerRadius = UDim.new(0, 8),
    }, obj)
end

local parent = game:GetService("CoreGui")
if type(gethui) == "function" then
    local ok, result = pcall(gethui)
    if ok and typeof(result) == "Instance" then
        parent = result
    end
end

local gui = make("ScreenGui", {
    Name = "SmithTwistedV3",
    ResetOnSpawn = false,
    DisplayOrder = 50,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, parent)

local visuals = make("Folder", {Name = "Visuals"}, gui)

local menu = make("Frame", {
    Name = "Menu",
    Size = UDim2.fromOffset(280, 500),
    Position = UDim2.new(0, 20, 0.2, 0),
    BackgroundColor3 = Color3.fromRGB(19, 24, 32),
    BackgroundTransparency = 0.1,
    BorderSizePixel = 0,
    Active = true,
}, gui)
round(menu)

local function label(parentObj, message, position, size, fontSize)
    return make("TextLabel", {
        Text = message,
        Position = position,
        Size = size,
        Font = Enum.Font.GothamMedium,
        TextSize = fontSize or 13,
        TextColor3 = CYAN,
        TextWrapped = true,
        BackgroundTransparency = 1,
    }, parentObj)
end

local title = label(
    menu, "SMITH'S TWISTED V3.2",
    UDim2.fromOffset(8, 0),
    UDim2.new(1, -80, 0, 35),
    13
)
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextWrapped = false

local icon = make("TextButton", {
    Name = "MinimisedIcon",
    Text = "S",
    Font = Enum.Font.GothamBold,
    TextSize = 25,
    TextColor3 = CYAN,
    BackgroundColor3 = Color3.fromRGB(19, 24, 32),
    BorderSizePixel = 0,
    Size = UDim2.fromOffset(46, 46),
    Position = UDim2.new(0, 20, 0.2, -52),
    Visible = false,
    ClipsDescendants = true,
}, gui)
round(icon)

local iconLogo = make("ImageLabel", {
    Name = "Logo",
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1),
    Position = UDim2.fromOffset(0, 0),
    Image = "",
    ScaleType = Enum.ScaleType.Fit,
    Visible = false,
    Active = false,
    ZIndex = 2,
}, icon)
round(iconLogo)

local minimise = make("TextButton", {
    Name = "Minimise",
    Text = "−",
    Font = Enum.Font.GothamBold,
    TextSize = 22,
    TextColor3 = CYAN,
    BackgroundColor3 = Color3.fromRGB(36, 43, 55),
    BorderSizePixel = 0,
    Size = UDim2.fromOffset(28, 26),
    Position = UDim2.new(1, -66, 0, 4),
    ZIndex = 5,
}, menu)
round(minimise)

local close = make("TextButton", {
    Name = "Close",
    Text = "×",
    Font = Enum.Font.GothamBold,
    TextSize = 22,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    BackgroundColor3 = Color3.fromRGB(155, 42, 52),
    BorderSizePixel = 0,
    Size = UDim2.fromOffset(28, 26),
    Position = UDim2.new(1, -34, 0, 4),
    ZIndex = 5,
}, menu)
round(close)

listen(minimise.Activated, function()
    menu.Visible = false
end)

listen(menu:GetPropertyChangedSignal("Visible"), function()
    icon.Visible = not menu.Visible
end)

local function draggable(handle, target, click)
    local active, start, origin, touch, moved
    handle.Active = true

    listen(handle.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            active, moved = true, false
            start, origin, touch = input.Position, target.Position, input
        end
    end)

    listen(Input.InputChanged, function(input)
        if not active then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input ~= touch then return end

        local delta = input.Position - start
        if delta.Magnitude > 5 then moved = true end

        if moved then
            target.Position = UDim2.new(
                origin.X.Scale, origin.X.Offset + delta.X,
                origin.Y.Scale, origin.Y.Offset + delta.Y
            )
        end
    end)

    listen(Input.InputEnded, function(input)
        if active and (input == touch
            or input.UserInputType == Enum.UserInputType.MouseButton1) then
            active = false
            if not moved and click then click() end
        end
    end)
end

draggable(title, menu)
draggable(icon, icon, function()
    menu.Visible = true
end)

local function button(text, y, callback)
    local b = make("TextButton", {
        Text = text,
        Size = UDim2.new(1, -20, 0, 29),
        Position = UDim2.fromOffset(10, y),
        BackgroundColor3 = Color3.fromRGB(36, 43, 55),
        BorderSizePixel = 0,
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
    }, menu)

    round(b)
    listen(b.Activated, function()
        callback(b)
    end)
    return b
end

-- Fullbright restores captured settings on disable/unload.
local savedLight
local savedAtmos = {}

local brightTargets = {
    Brightness = 3,
    ClockTime = 14,
    GlobalShadows = false,
    Ambient = Color3.fromRGB(210, 210, 210),
    OutdoorAmbient = Color3.fromRGB(210, 210, 210),
    FogStart = 1000000,
    FogEnd = 10000000,
    ExposureCompensation = 0,
}

local function captureAtmos(obj)
    if obj:IsA("Atmosphere") and not savedAtmos[obj] then
        savedAtmos[obj] = {
            Density = obj.Density,
            Haze = obj.Haze,
        }
    end
end

local function restoreLight()
    if savedLight then
        for k, v in pairs(savedLight) do
            Lighting[k] = v
        end
        savedLight = nil
    end

    for obj, props in pairs(savedAtmos) do
        if obj.Parent then
            obj.Density, obj.Haze = props.Density, props.Haze
        end
    end
    table.clear(savedAtmos)
end

local function startLight()
    savedLight = {}
    for k in pairs(brightTargets) do
        savedLight[k] = Lighting[k]
    end
    for _, obj in ipairs(Lighting:GetDescendants()) do
        captureAtmos(obj)
    end
end

listen(Lighting.DescendantAdded, function(obj)
    if options.Bright then captureAtmos(obj) end
end)

local BIND = "SmithTwistedV3Lighting"

Run:BindToRenderStep(BIND, Enum.RenderPriority.Last.Value + 10, function()
    if not alive or not options.Bright then return end

    for k, v in pairs(brightTargets) do
        if Lighting[k] ~= v then Lighting[k] = v end
    end

    for obj in pairs(savedAtmos) do
        if obj.Parent then
            if obj.Density ~= 0 then obj.Density = 0 end
            if obj.Haze ~= 0 then obj.Haze = 0 end
        end
    end
end)

local function toggle(key, name, y)
    button(name .. ": OFF", y, function(b)
        options[key] = not options[key]
        b.Text = name .. ": " .. (options[key] and "ON" or "OFF")
        b.BackgroundColor3 = options[key]
            and Color3.fromRGB(25, 80, 90)
            or Color3.fromRGB(36, 43, 55)

        if key == "Bright" then
            if options.Bright then
                startLight()
            else
                restoreLight()
            end
        end
    end)
end

toggle("Info", "Tornado info / ESP", 38)
toggle("Chams", "Tornado chams", 72)
toggle("Trail", "Previous path", 106)
toggle("Forecast", "Predicted path", 140)
toggle("Bright", "Fullbright", 174)

button("Units: METRIC", 208, function(b)
    options.Metric = not options.Metric
    b.Text = "Units: " .. (options.Metric and "METRIC" or "IMPERIAL")
end)

local api = {}

function api.Destroy()
    if not alive then return end
    alive = false
    Run:UnbindFromRenderStep(BIND)

    for _, c in ipairs(connections) do
        c:Disconnect()
    end
    for _, r in pairs(records) do
        if r.RowConnection then
            r.RowConnection:Disconnect()
        end
    end

    local ok, err = pcall(restoreLight)
    if not ok then
        warn("[SmithTwisted] Lighting restore: " .. tostring(err))
    end

    gui:Destroy()
    table.clear(records)
    table.clear(chosen)

    if env[KEY] == api then env[KEY] = nil end
end

env[KEY] = api
button("Unload", 242, api.Destroy)
listen(close.Activated, api.Destroy)
listen(gui.Destroying, api.Destroy)

-- Load the actual PNG from GitHub.
-- Keep the local image file so reopening the icon can still load it.
task.spawn(function()
    local ok, err = pcall(function()
        local assetLoader = getcustomasset or getsynasset

        if type(writefile) ~= "function"
            or type(assetLoader) ~= "function" then
            error("Executor does not support writefile/getcustomasset.")
        end

        local bytes = game:HttpGet(LOGO_URL)
        if not alive then return end

        if type(bytes) ~= "string"
            or bytes:sub(1, 8) ~= "\137PNG\r\n\26\n" then
            error("assets/logo.png did not return a valid PNG.")
        end

        writefile(LOGO_FILE, bytes)
        local asset = assetLoader(LOGO_FILE)

        if type(asset) ~= "string" or asset == "" then
            error("Executor did not return an image asset.")
        end
        if not alive then return end

        iconLogo.Image = asset
        local failed = false

        ContentProvider:PreloadAsync({iconLogo}, function(_, status)
            if status ~= Enum.AssetFetchStatus.Success then
                failed = true
            end
        end)

        if not alive then return end
        if failed or not iconLogo.IsLoaded then
            error("The logo downloaded but could not be displayed.")
        end

        icon.Text = ""
        iconLogo.Visible = true
    end)

    if not ok and alive then
        icon.Text = "S"
        iconLogo.Visible = false
        warn("[SmithTwisted] Logo unavailable: " .. tostring(err))
    end
end)

local status = label(
    menu, "Select the storms you want to track",
    UDim2.fromOffset(8, 275),
    UDim2.new(1, -16, 0, 35),
    11
)

label(
    menu, "STORM IDs",
    UDim2.fromOffset(8, 310),
    UDim2.new(1, -16, 0, 22),
    13
)

local all = button("Select all", 335, function()
    chooseNew = true
    for storm in pairs(records) do
        chosen[storm] = true
    end
end)
all.Size = UDim2.new(0.5, -15, 0, 29)

local none = button("Deselect all", 335, function()
    chooseNew = false
    for storm in pairs(records) do
        chosen[storm] = false
    end
end)
none.Size = UDim2.new(0.5, -15, 0, 29)
none.Position = UDim2.new(0.5, 5, 0, 335)

local list = make("ScrollingFrame", {
    Position = UDim2.fromOffset(10, 373),
    Size = UDim2.new(1, -20, 0, 117),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    CanvasSize = UDim2.fromOffset(0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, menu)

make("UIListLayout", {
    Padding = UDim.new(0, 5),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, list)

local function read(parentObj, name)
    local obj = parentObj and parentObj:FindFirstChild(name)
    if obj and obj:IsA("ValueBase") then
        return obj.Value
    end
end

local function number(n)
    return typeof(n) == "number"
        and n == n
        and math.abs(n) < math.huge
end

local function flat(v)
    return Vector3.new(v.X, 0, v.Z)
end

local function lengthText(studs)
    if not number(studs) then return "?" end
    local metres = studs * CFG.MetresPerStud

    return options.Metric
        and string.format("~%.0f m", metres)
        or string.format("~%.0f ft", metres / 0.3048)
end

local function speedText(mph)
    if not number(mph) then return "?" end

    return options.Metric
        and string.format("~%.0f km/h", mph * 1.609344)
        or string.format("~%.0f mph", mph)
end

local function ef(w)
    if not number(w) then return "?" end
    if w > 200 then return "EF5" end
    if w >= 166 then return "EF4" end
    if w >= 136 then return "EF3" end
    if w >= 111 then return "EF2" end
    if w >= 86 then return "EF1" end
    if w >= 65 then return "EF0" end
    return "Below EF0"
end

local function kind(storm, config)
    for _, obj in ipairs({config, storm}) do
        for _, key in ipairs({"tornado_type", "TornadoType", "shape"}) do
            local result = obj:GetAttribute(key) or read(obj, key)
            if typeof(result) == "string" and result ~= "" then
                return result
            end
        end
    end

    return read(config, "multi") == true
        and "Multivortex | shape unknown"
        or "Shape unknown"
end

local function newLine(parentObj, color)
    return make("LineHandleAdornment", {
        Adornee = workspace.Terrain,
        AlwaysOnTop = true,
        ZIndex = 2,
        Color3 = color,
        Thickness = 2,
        Transparency = 0.1,
        Visible = false,
    }, parentObj)
end

local function setLine(obj, a, b, visible)
    local distance = (b - a).Magnitude
    obj.Visible = visible and distance > 0.1

    if distance > 0.1 then
        obj.CFrame = CFrame.lookAt(a, b)
        obj.Length = distance
    end
end

local function clearTrail(r)
    for _, segment in ipairs(r.Trail) do
        for _, obj in ipairs(segment) do
            obj:Destroy()
        end
    end
    table.clear(r.Trail)
    r.Sample = nil
end

local function newRecord(storm, anchor)
    local folder = make("Folder", {Name = storm.Name}, visuals)

    local bb = make("BillboardGui", {
        Adornee = anchor,
        Size = UDim2.fromOffset(290, 110),
        StudsOffsetWorldSpace = Vector3.new(0, CFG.InfoHeight, 0),
        AlwaysOnTop = true,
        LightInfluence = 0,
        MaxDistance = 1000000,
        Enabled = false,
    }, folder)

    local bg = make("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(19, 24, 32),
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
    }, bb)
    round(bg)

    local text = label(
        bg, "",
        UDim2.fromOffset(7, 4),
        UDim2.new(1, -14, 1, -8),
        12
    )

    local row = make("TextButton", {
        Size = UDim2.new(1, -6, 0, 30),
        BackgroundColor3 = Color3.fromRGB(36, 43, 55),
        TextColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, list)
    round(row)

    if chosen[storm] == nil then
        chosen[storm] = chooseNew
    end

    local r = {
        Folder = folder,
        Anchor = anchor,
        Billboard = bb,
        Label = text,
        Row = row,
        Trail = {},
        Prediction = {},
        Highlights = {},
        LastMeshScan = -math.huge,
        LastSample = 0,
    }

    r.RowConnection = row.Activated:Connect(function()
        chosen[storm] = not chosen[storm]
    end)

    for i = 1, 5 do
        r.Prediction[i] = newLine(folder, ORANGE)
    end

    return r
end

local function removeRecord(storm)
    local r = records[storm]
    if not r then return end

    r.RowConnection:Disconnect()
    r.Row:Destroy()
    r.Folder:Destroy()
    records[storm] = nil
end

local function updateChams(r, enabled, now)
    if not enabled then
        for part, h in pairs(r.Highlights) do
            h:Destroy()
            r.Highlights[part] = nil
        end
        r.LastMeshScan = -math.huge
        return
    end

    if now - r.LastMeshScan < 1 then return end
    r.LastMeshScan = now
    local wanted = {}

    for _, name in ipairs({"tornado", "subvorts"}) do
        local branch = r.Anchor:FindFirstChild(name)
        if branch then
            for _, part in ipairs(branch:GetDescendants()) do
                if part:IsA("BasePart")
                    and part.Name == "TornadoMesh"
                    and part.Transparency < 1 then
                    wanted[part] = true
                end
            end
        end
    end

    for part, h in pairs(r.Highlights) do
        if not wanted[part] then
            h:Destroy()
            r.Highlights[part] = nil
        end
    end

    local total = 0
    for _, other in pairs(records) do
        for _ in pairs(other.Highlights) do
            total += 1
        end
    end

    for part in pairs(wanted) do
        if not r.Highlights[part] and total < 200 then
            r.Highlights[part] = make("Highlight", {
                Adornee = part,
                DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
                FillColor = CYAN,
                FillTransparency = 0.65,
                OutlineTransparency = 1,
                Enabled = true,
            }, r.Folder)
            total += 1
        end
    end
end

local function sampleTrail(r, pos, width, now, show)
    if now - r.LastSample < 1 then return end

    if not r.Sample then
        r.Sample = {P = pos, W = width}
        r.LastSample = now
        return
    end

    local old = r.Sample
    local delta = flat(pos - old.P)
    if delta.Magnitude < 15 then return end

    local direction = delta.Unit
    local normal = Vector3.new(-direction.Z, 0, direction.X)

    local oldEdges = old.Edges or {
        old.P,
        old.P + normal * old.W / 2,
        old.P - normal * old.W / 2,
    }

    local newEdges = {
        pos,
        pos + normal * width / 2,
        pos - normal * width / 2,
    }

    local segment = {}
    for i = 1, 3 do
        segment[i] = newLine(r.Folder, CYAN)
        setLine(segment[i], oldEdges[i], newEdges[i], show)
    end

    table.insert(r.Trail, segment)
    if #r.Trail > CFG.MaxTrailSegments then
        for _, obj in ipairs(table.remove(r.Trail, 1)) do
            obj:Destroy()
        end
    end

    r.Sample = {P = pos, W = width, Edges = newEdges}
    r.LastSample = now
end

local function update()
    local related = workspace:FindFirstChild("storm_related")
    local storms = related and related:FindFirstChild("storms")
    local seen, sorted = {}, {}
    local now = os.clock()

    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")

    if storms then
        for _, storm in ipairs(storms:GetChildren()) do
            local rotation = storm:FindFirstChild("rotation")
            local anchor = rotation and rotation:FindFirstChild("TornadoPart")
            local configs = storm:FindFirstChild("configs")
            local config = configs and configs:FindFirstChild("tornado")

            if anchor and anchor:IsA("BasePart") and config then
                seen[storm] = true
                table.insert(sorted, storm)

                local r = records[storm]
                if r and r.Anchor ~= anchor then
                    removeRecord(storm)
                    r = nil
                end

                if not r then
                    r = newRecord(storm, anchor)
                    records[storm] = r
                end

                local enabled = chosen[storm]
                local pos = anchor.Position
                local grounded = read(config, "otg") == true
                local track = rotation:GetAttribute("TornadoTrackName")
                local widthObj = config:FindFirstChild("width")
                local rawWidth = widthObj and widthObj:GetAttribute("sfc")
                local width = number(rawWidth)
                    and math.max(0, rawWidth * CFG.WidthToStuds) or nil

                local rawWind = read(config, "winds")
                local wind = number(rawWind)
                    and math.max(0, rawWind * CFG.WindToMPH) or nil

                if r.Track ~= track then
                    clearTrail(r)
                    r.Pos, r.Velocity = nil, nil
                    r.Track = track
                end

                if r.Pos and r.Time then
                    local delta = flat(pos - r.Pos)
                    local dt = now - r.Time

                    if delta.Magnitude > 5000 then
                        clearTrail(r)
                        r.Velocity = nil
                    elseif dt > 0 then
                        local velocity = delta / dt
                        r.Velocity = r.Velocity
                            and r.Velocity:Lerp(velocity, 0.25)
                            or velocity
                    end
                end

                if not grounded or not enabled then
                    r.Sample = nil
                end
                r.Pos, r.Time, r.Grounded = pos, now, grounded

                local movementMPH = r.Velocity
                    and r.Velocity.Magnitude
                        * CFG.MetresPerStud * 2.236936

                local distance
                if root and root:IsA("BasePart") then
                    distance = flat(pos - root.Position).Magnitude
                end

                r.Label.Text = string.format(
                    "STORM ID: %s\n%s | %s estimated | Width %s\n%s\nWind %s | Travel %s\nDistance: %s",
                    storm.Name,
                    grounded and "ON GROUND" or "ALOFT / INACTIVE",
                    ef(wind),
                    lengthText(width),
                    kind(storm, config),
                    speedText(wind),
                    speedText(movementMPH),
                    lengthText(distance)
                )

                r.Billboard.Enabled = enabled and options.Info
                updateChams(r, enabled and options.Chams, now)

                local start = pos + Vector3.new(0, 10, 0)
                if enabled and grounded and width then
                    sampleTrail(r, start, width, now, options.Trail)
                end

                for _, segment in ipairs(r.Trail) do
                    for _, obj in ipairs(segment) do
                        obj.Visible = enabled and options.Trail
                    end
                end

                local velocity = r.Velocity
                if enabled and options.Forecast and grounded and width
                    and velocity and velocity.Magnitude > 0.5 then

                    local direction = velocity.Unit
                    local normal = Vector3.new(-direction.Z, 0, direction.X)
                    local half = width / 2
                    local distanceAhead = velocity.Magnitude * CFG.ForecastSeconds
                    local tip = start + direction * distanceAhead
                    local headLength = math.min(
                        distanceAhead * 0.25,
                        math.max(80, width * 0.4)
                    )
                    local base = tip - direction * headLength

                    setLine(r.Prediction[1], start, tip, true)
                    setLine(
                        r.Prediction[2],
                        start + normal * half,
                        base + normal * half,
                        true
                    )
                    setLine(
                        r.Prediction[3],
                        start - normal * half,
                        base - normal * half,
                        true
                    )
                    setLine(r.Prediction[4], base + normal * half, tip, true)
                    setLine(r.Prediction[5], base - normal * half, tip, true)
                else
                    for _, obj in ipairs(r.Prediction) do
                        obj.Visible = false
                    end
                end
            end
        end
    end

    for storm in pairs(records) do
        if not seen[storm] then
            removeRecord(storm)
            chosen[storm] = nil
        end
    end

    table.sort(sorted, function(a, b)
        return a.Name < b.Name
    end)

    local count = 0
    for index, storm in ipairs(sorted) do
        local r = records[storm]
        local enabled = chosen[storm]

        if enabled then count += 1 end
        r.Row.LayoutOrder = index
        r.Row.Text = string.format(
            "  [%s] %s | %s",
            enabled and "X" or " ",
            storm.Name,
            r.Grounded and "Ground" or "Aloft"
        )
        r.Row.BackgroundColor3 = enabled
            and Color3.fromRGB(25, 80, 90)
            or Color3.fromRGB(36, 43, 55)
    end

    status.Text = string.format(
        "%d / %d storms selected\nCyan: history | Orange: estimated heading",
        count, #sorted
    )
end

local elapsed, lastError = 0, nil

listen(Run.Heartbeat, function(dt)
    elapsed += dt
    if elapsed < 0.2 then return end
    elapsed = 0

    local ok, err = pcall(update)
    if not ok then
        status.Text = "Update error — see console"
        if tostring(err) ~= lastError then
            lastError = tostring(err)
            warn("[SmithTwisted V3.2] " .. lastError)
        end
    else
        lastError = nil
    end
end)

print("[SmithTwisted] V3.2 loaded. All feature toggles start OFF.")
