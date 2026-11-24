local ReplicatedStorage = game:GetService("ReplicatedStorage")
local interaction = require(ReplicatedStorage.Configs.InteractionConfig)
local WarehouseSite = {}
local yardEdge = -72.45

local function part(site, name, frame, size, color, material)
    local object = Instance.new("Part")
    object.Name, object.CFrame, object.Size = name, frame, size
    object.Anchored, object.Color, object.Material = true, color, material
    object.Parent = site
    return object
end

local function addFence(site, floor, groundSize)
    local fence = Instance.new("Folder")
    fence.Name = "Fence"
    fence.Parent = site
    local jointX = -groundSize.X / 2 + 0.4
    local frontZ = groundSize.Z / 2 - 0.4
    local points = {
        Vector3.new(jointX, 0, 0), Vector3.new(yardEdge, 0, 0),
        Vector3.new(yardEdge, 0, frontZ), Vector3.new(jointX, 0, frontZ)
    }
    local railColor = Color3.fromRGB(155, 111, 64)
    local postColor = Color3.fromRGB(114, 78, 44)
    for index = 1, #points - 1 do
        local first, last = points[index], points[index + 1]
        local edge = last - first
        for _, y in ipairs({1, 2.2}) do
            local midpoint = (first + last) / 2 + Vector3.new(0, y, 0)
            part(fence, "Rail", floor * CFrame.lookAt(midpoint, midpoint + edge),
                Vector3.new(0.35, 0.4, edge.Magnitude), railColor, Enum.Material.WoodPlanks)
        end
        local sections = math.ceil(edge.Magnitude / 6)
        local lastPost = index == #points - 1 and sections - 1 or sections
        for i = 1, lastPost do
            local point = first:Lerp(last, i / sections) + Vector3.new(0, 1.5, 0)
            part(fence, "Post", floor * CFrame.new(point), Vector3.new(0.7, 3, 0.7), postColor, Enum.Material.Wood)
        end
    end
end

local function addNameplate(marker, signFrame, side)
    local plate = part(marker, "Nameplate", signFrame * CFrame.new(0, 0, side * 0.29),
        Vector3.new(5.22, 1.3, 0.16), Color3.fromRGB(80, 50, 30), Enum.Material.SmoothPlastic)
    plate.CanCollide, plate.CanTouch, plate.CanQuery = false, false, false
    local surface = Instance.new("SurfaceGui")
    surface.Face = side == 1 and Enum.NormalId.Back or Enum.NormalId.Front
    surface.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
    surface.CanvasSize = Vector2.new(480, 120)
    surface.LightInfluence = 0.2
    surface.MaxDistance = 65
    surface.Parent = plate
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(0.9, 0.8)
    label.Position = UDim2.fromScale(0.05, 0.1)
    label.TextColor3 = Color3.fromRGB(255, 229, 181)
    label.Font, label.Text, label.TextScaled = Enum.Font.FredokaOne, "Warehouse", true
    label.Parent = surface
end

local function makePrompt(attachment, name, key, gamepad)
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = name
    prompt.KeyboardKeyCode = key
    prompt.GamepadKeyCode = gamepad
    prompt.MaxActivationDistance = interaction.BuildingDistance
    prompt.RequiresLineOfSight = false
    prompt.Style = Enum.ProximityPromptStyle.Custom
    prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
    prompt.Parent = attachment
    return prompt
end

function WarehouseSite.Ensure(plot)
    local site = plot:FindFirstChild("WarehouseSite")
    if site then return site end

    site = Instance.new("Folder")
    site.Name = "WarehouseSite"
    local ground = plot.Ground
    local floor = ground.CFrame * CFrame.new(0, ground.Size.Y / 2, 0)
    local stone = Color3.fromRGB(162, 151, 128)
    local curb = Color3.fromRGB(117, 108, 93)
    local wood = Color3.fromRGB(107, 67, 40)
    local farmEdge = -ground.Size.X / 2
    local yardWidth = farmEdge - yardEdge + 0.35
    local yardCenter = farmEdge - yardWidth / 2
    part(site, "Yard", floor * CFrame.new(yardCenter, -0.18, 19.5), Vector3.new(yardWidth, 0.36, 41), stone, Enum.Material.Pavement)
    part(site, "BackCurb", floor * CFrame.new(yardCenter, 0.08, -0.65), Vector3.new(yardWidth, 0.42, 0.7), curb, Enum.Material.Slate)
    part(site, "SideCurb", floor * CFrame.new(yardEdge, 0.08, 18), Vector3.new(0.7, 0.42, 37), curb, Enum.Material.Slate)
    addFence(site, floor, ground.Size)

    local marker = Instance.new("Model")
    marker.Name = "WarehouseMarker"
    marker:SetAttribute("ItemName", "WarehouseBlueprint")
    marker:SetAttribute("OwnerUserId", 0)
    marker.Parent = site
    local signFrame = floor * CFrame.new(-47.2, 2.75, 32) * CFrame.Angles(0, math.rad(52), 0)
    for _, x in ipairs({-2.35, 2.35}) do
        part(marker, "SignPost", signFrame * CFrame.new(x, -1.05, 0), Vector3.new(0.42, 3.4, 0.5), wood, Enum.Material.Wood)
    end
    local sign = part(marker, "Sign", signFrame, Vector3.new(5.8, 1.65, 0.45), wood, Enum.Material.WoodPlanks)
    addNameplate(marker, signFrame, 1)
    addNameplate(marker, signFrame, -1)
    local attachment = Instance.new("Attachment")
    attachment.Name = "InteractionAttachment"
    attachment.Position = Vector3.new(0, 0, 0.52)
    attachment.Parent = sign
    local buy = makePrompt(attachment, "WarehouseBuyPrompt", Enum.KeyCode.E, Enum.KeyCode.ButtonY)
    local returns = makePrompt(attachment, "ReturnsPrompt", Enum.KeyCode.F, Enum.KeyCode.ButtonX)
    buy.Enabled, returns.Enabled = false, false
    buy:SetAttribute("PairedPrompt", returns.Name)
    buy:SetAttribute("StackSide", -1)
    returns:SetAttribute("PairedPrompt", buy.Name)
    returns:SetAttribute("StackSide", 1)

    local fence = plot:FindFirstChild("Fence")
    if fence then
        for _, rail in ipairs(fence:GetChildren()) do
            if rail:IsA("BasePart") and rail.Name:match("Rail[12]$") and rail.Size.Z > ground.Size.Z - 2 then
                local position = ground.CFrame:PointToObjectSpace(rail.Position)
                if math.abs(position.X + ground.Size.X / 2) < 0.5 and math.abs(position.Z) < 0.5 then
                    rail.Size -= Vector3.new(0, 0, 6.6)
                    rail.CFrame -= ground.CFrame.ZVector * 3.3
                end
            end
        end
    end

    site.Parent = plot
    return site
end

function WarehouseSite.GetBuilding(plot)
    local site = plot and plot:FindFirstChild("WarehouseSite")
    return site and (site:FindFirstChild("Warehouse") or site:FindFirstChild("WarehouseBlueprint"))
end

function WarehouseSite.SetMarkerOwner(plot, userId)
    local marker = plot.WarehouseSite.WarehouseMarker
    marker:SetAttribute("OwnerUserId", userId)
    local attachment = marker.Sign.InteractionAttachment
    attachment.WarehouseBuyPrompt.Enabled = userId ~= 0
    attachment.ReturnsPrompt.Enabled = userId ~= 0
end

function WarehouseSite.GetPivot(plot)
    local ground = plot.Ground
    return ground.CFrame * CFrame.new(-56.1, ground.Size.Y / 2 + 0.015, 14.5) * CFrame.Angles(0, math.pi, 0)
end

function WarehouseSite.PrepareBuilding(object, ready)
    local action = object:FindFirstChild("ActionPrompt", true)
    local entrance = action.Parent
    if ready then
        local prompt = object:FindFirstChild("StoragePrompt", true)
        prompt.Parent = entrance
        prompt.MaxActivationDistance = interaction.BuildingDistance
        prompt.Style = Enum.ProximityPromptStyle.Custom
        prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
        prompt.Enabled = true
        action:Destroy()
    else
        local attachment = Instance.new("Attachment")
        attachment.Name = "ReturnsAttachment"
        attachment.CFrame = entrance.CFrame * CFrame.new(4.5, 0, 0)
        attachment.Parent = entrance.Parent
        makePrompt(attachment, "ReturnsPrompt", Enum.KeyCode.F, Enum.KeyCode.ButtonX)
    end
end

return WarehouseSite
