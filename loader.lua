-- SMITH'S HUB — GAME SELECTOR

local BASE = "https://raw.githubusercontent.com/glitchlend/Smiths-Hub/main/"
local LOGO_URL = BASE .. "assets/logo.png"
local LOGO_FILE = "SmithsHub_logo.png"

local TweenService = game:GetService("TweenService")
local Input = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")

local env = getgenv and getgenv() or _G
local KEY = "SmithsHubLoader"

if env[KEY] and type(env[KEY].Destroy) == "function" then
    pcall(env[KEY].Destroy)
end

local alive = true
local busy = false
local connections = {}
local tweens = {}
local buttons = {}
local api = {}

local CYAN = Color3.fromRGB(55, 215, 255)
local MUTED = Color3.fromRGB(150, 164, 185)
local WHITE = Color3.fromRGB(240, 245, 255)

local function make(class, props, parent)
    local obj = Instance.new(class)
    for key, value in pairs(props) do
        obj[key] = value
    end
    obj.Parent = parent
    return obj
end

local function listen(signal, fn)
    local connection = signal:Connect(fn)
    table.insert(connections, connection)
    return connection
end

local function corner(obj, radius)
    make("UICorner", {
        CornerRadius = UDim.new(0, radius or 12),
    }, obj)
end

local function tween(obj, duration, props)
    local animation = TweenService:Create(
        obj,
        TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        props
    )
    table.insert(tweens, animation)
    animation:Play()
    return animation
end

local parent = game:GetService("CoreGui")
if type(gethui) == "function" then
    local ok, result = pcall(gethui)
    if ok and typeof(result) == "Instance" then
        parent = result
    end
end

local gui = make("ScreenGui", {
    Name = "SmithsHubLoader",
    ResetOnSpawn = false,
    DisplayOrder = 100,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, parent)

function api.Destroy()
    if not alive then return end
    alive = false

    for _, connection in ipairs(connections) do
        connection:Disconnect()
    end
    for _, animation in ipairs(tweens) do
        animation:Cancel()
    end

    gui:Destroy()
    if env[KEY] == api then
        env[KEY] = nil
    end
end

env[KEY] = api
listen(gui.Destroying, api.Destroy)

local panel = make("Frame", {
    Name = "Panel",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(420, 440),
    BackgroundColor3 = Color3.fromRGB(12, 17, 25),
    BorderSizePixel = 0,
    Active = true,
}, gui)
corner(panel, 18)

make("UIStroke", {
    Color = CYAN,
    Thickness = 1.5,
    Transparency = 0.35,
}, panel)

make("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(155, 175, 210)),
    }),
    Rotation = 70,
}, panel)

local scale = make("UIScale", {Scale = 0.88}, panel)

local function fitScale()
    local camera = workspace.CurrentCamera
    local size = camera and camera.ViewportSize or Vector2.new(1280, 720)
    return math.clamp(
        math.min((size.X - 24) / 420, (size.Y - 24) / 440),
        0.25, 1
    )
end

local targetScale = fitScale()
scale.Scale = targetScale * 0.88
tween(scale, 0.55, {Scale = targetScale})

local function text(message, position, size, fontSize, color)
    return make("TextLabel", {
        Text = message,
        Position = position,
        Size = size,
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        TextSize = fontSize,
        TextColor3 = color or WHITE,
        TextWrapped = true,
    }, panel)
end

local dragHandle = make("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, -50, 0, 42),
    Active = true,
}, panel)

text(
    "SMITH'S HUB",
    UDim2.fromOffset(20, 12),
    UDim2.fromOffset(150, 20),
    12, MUTED
).TextXAlignment = Enum.TextXAlignment.Left

local close = make("TextButton", {
    Text = "×",
    Font = Enum.Font.GothamMedium,
    TextSize = 24,
    TextColor3 = MUTED,
    BackgroundColor3 = Color3.fromRGB(26, 34, 46),
    BorderSizePixel = 0,
    Size = UDim2.fromOffset(30, 30),
    Position = UDim2.new(1, -42, 0, 12),
}, panel)
corner(close, 8)

listen(close.Activated, function()
    -- Once execution begins, closing this menu cannot cancel that script.
    if not busy then api.Destroy() end
end)

local dragging, dragInput, dragStart, dragOrigin

listen(dragHandle.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragInput = input
        dragStart = input.Position
        dragOrigin = panel.Position
    end
end)

listen(Input.InputChanged, function(input)
    if not dragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input ~= dragInput then return end

    local delta = input.Position - dragStart
    panel.Position = UDim2.new(
        dragOrigin.X.Scale, dragOrigin.X.Offset + delta.X,
        dragOrigin.Y.Scale, dragOrigin.Y.Offset + delta.Y
    )
end)

listen(Input.InputEnded, function(input)
    if input == dragInput
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

local logoBox = make("Frame", {
    Position = UDim2.new(0.5, -57, 0, 48),
    Size = UDim2.fromOffset(114, 114),
    BackgroundColor3 = Color3.fromRGB(19, 28, 41),
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, panel)
corner(logoBox, 20)

make("UIStroke", {
    Color = CYAN,
    Thickness = 1,
    Transparency = 0.5,
}, logoBox)

local fallback = make("TextLabel", {
    Text = "S",
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    TextColor3 = CYAN,
    Font = Enum.Font.GothamBlack,
    TextSize = 72,
}, logoBox)

local logo = make("ImageLabel", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    ScaleType = Enum.ScaleType.Fit,
    Image = "",
    Visible = false,
}, logoBox)

text(
    "SMITH'S HUB",
    UDim2.fromOffset(20, 176),
    UDim2.new(1, -40, 0, 35),
    28, WHITE
).Font = Enum.Font.GothamBold

text(
    "CHOOSE YOUR GAME",
    UDim2.fromOffset(20, 215),
    UDim2.new(1, -40, 0, 20),
    11, CYAN
)

local status = text(
    "Select the game you are currently playing.",
    UDim2.fromOffset(24, 371),
    UDim2.new(1, -48, 0, 40),
    12, MUTED
)

local progressTrack = make("Frame", {
    Position = UDim2.new(0, 24, 1, -18),
    Size = UDim2.new(1, -48, 0, 3),
    BackgroundColor3 = Color3.fromRGB(32, 43, 58),
    BorderSizePixel = 0,
}, panel)
corner(progressTrack, 3)

local progress = make("Frame", {
    Size = UDim2.fromScale(0, 1),
    BackgroundColor3 = CYAN,
    BorderSizePixel = 0,
}, progressTrack)
corner(progress, 3)

-- Download the actual PNG, then register it as a local image asset.
task.spawn(function()
    local ok, err = pcall(function()
        local registerAsset = getcustomasset or getsynasset
        if type(registerAsset) ~= "function"
            or type(writefile) ~= "function" then
            error("This executor lacks writefile/getcustomasset support.")
        end

        local data = game:HttpGet(LOGO_URL)
        if type(data) ~= "string"
            or data:sub(1, 8) ~= "\137PNG\r\n\26\n" then
            error("assets/logo.png did not return a valid PNG.")
        end

        if not alive then return end
        writefile(LOGO_FILE, data)
        local asset = registerAsset(LOGO_FILE)

        if not alive then return end
        logo.Image = asset
        logo.Visible = true

        ContentProvider:PreloadAsync({logo})

        if not alive then return end
        if not logo.IsLoaded then
            error("The image was registered but could not be displayed.")
        end
        fallback.Visible = false
    end)

    if not ok then
        warn("[Smiths Hub] Logo: " .. tostring(err))
        if alive then
            logo.Visible = false
            fallback.Visible = true
        end
    end
end)

local function setBusy(value)
    busy = value
    close.TextTransparency = value and 0.65 or 0

    for _, b in ipairs(buttons) do
        b.AutoButtonColor = not value
        b.TextTransparency = value and 0.35 or 0
    end
end

local function loadGame(name, path)
    if busy or not alive then return end
    setBusy(true)

    status.TextColor3 = CYAN
    status.Text = "Downloading " .. name .. "..."
    progress.Size = UDim2.fromScale(0, 1)
    tween(progress, 0.35, {Size = UDim2.fromScale(0.3, 1)})

    task.spawn(function()
        local stage = "download"

        local ok, err = pcall(function()
            local source = game:HttpGet(BASE .. path)
            if not alive then return end

            if type(source) ~= "string" or not source:find("%S") then
                error("GitHub returned an empty file.")
            end

            if not source:find("\n")
                and source:match("^%s*%-%-") then
                error("The GitHub file still contains only a placeholder.")
            end

            stage = "compile"
            status.Text = "Preparing " .. name .. "..."
            tween(progress, 0.25, {Size = UDim2.fromScale(0.65, 1)})

            if type(loadstring) ~= "function" then
                error("This executor does not provide loadstring.")
            end

            local runScript, compileError = loadstring(
                source, "@SmithsHub/" .. path
            )
            if not runScript then
                error(compileError or "Script could not be compiled.")
            end

            if not alive then return end
            stage = "run"
            status.Text = "Starting " .. name .. "..."
            runScript()
        end)

        if not alive then return end

        if not ok then
            warn("[Smiths Hub] " .. name .. " " .. stage .. " error: " .. tostring(err))
            status.TextColor3 = Color3.fromRGB(255, 135, 135)
            status.Text = name .. " failed to " .. stage
                .. ". See console for details."
            tween(progress, 0.2, {Size = UDim2.fromScale(0, 1)})
            setBusy(false)
            return
        end

        status.TextColor3 = CYAN
        status.Text = name .. " loaded."
        tween(progress, 0.2, {Size = UDim2.fromScale(1, 1)})
        task.wait(0.35)

        if alive then api.Destroy() end
    end)
end

local function gameButton(name, subtitle, y, path)
    local b = make("TextButton", {
        Text = name .. "  —  " .. subtitle,
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        TextColor3 = WHITE,
        BackgroundColor3 = Color3.fromRGB(25, 36, 51),
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(24, y),
        Size = UDim2.new(1, -48, 0, 50),
        AutoButtonColor = true,
    }, panel)
    corner(b, 10)

    make("UIStroke", {
        Color = CYAN,
        Thickness = 1,
        Transparency = 0.75,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, b)

    table.insert(buttons, b)

    listen(b.Activated, function()
        loadGame(name, path)
    end)
end

gameButton("YSO", "Young Street Ontario", 250, "games/yso.lua")
gameButton("TWISTED", "Storm chasing", 310, "games/twisted.lua")
