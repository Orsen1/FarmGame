local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local rules = require(ReplicatedStorage:WaitForChild("PlacementScripts"):WaitForChild("PlacementRules"))
local PlacementModels = require(ReplicatedStorage:WaitForChild("PlacementScripts"):WaitForChild("PlacementModels"))
local ItemDefinitions = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("ItemDefinitions"))
local PlaceEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("PlaceEvent")
local PlacementController = {}

local placingItemName
local preview
local connection
local position
local sourceSlot
local controls
local rotation = 0
local snapEnabled = true

local canPlace = false
local pending = false

function PlacementController.cancelPlacement()
    if connection then
        connection:Disconnect()
        connection = nil
    end

    if preview then
        preview:Destroy()
        preview = nil
    end

    canPlace = false
    position = nil
    placingItemName = nil
    sourceSlot = nil

    if controls then
        controls:Destroy()
        controls = nil
    end

    ContextActionService:UnbindAction("ConfirmPlacement")
    ContextActionService:UnbindAction("CancelPlacement")
    ContextActionService:UnbindAction("RotatePlacement")
    ContextActionService:UnbindAction("TogglePlacementSnap")
end

local function confirmPlacement()
    if preview and canPlace and not pending then
        pending = true
        PlaceEvent:FireServer(placingItemName, position, rotation)
    end
end

local function hasSelectedItem()
    return sourceSlot and sourceSlot.ItemName.Value == placingItemName and sourceSlot.Amount.Value > 0
end

local function makeControls(rotate, toggleSnap, canSnap)
    local gui = Instance.new("ScreenGui")
    gui.Name = "PlacementControls"
    gui.DisplayOrder = 10
    gui.ResetOnSpawn = false

    local function label(class, parent, name, size, position)
        local object = Instance.new(class)
        object.Name = name
        object.Size = size
        object.Position = position
        object.BackgroundColor3 = Color3.fromRGB(255, 232, 169)
        object.BorderSizePixel = 0
        object.Parent = parent
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = object
        return object
    end

    local hint = label("TextLabel", gui, "KeyboardHint", UDim2.new(0.85, 0, 0, 32), UDim2.new(0.5, 0, 0, 8))
    hint.AnchorPoint = Vector2.new(0.5, 0)
    hint.TextColor3 = Color3.fromRGB(91, 54, 28)
    hint.Font = Enum.Font.GothamMedium
    hint.TextSize = 14
    local sizeLimit = Instance.new("UISizeConstraint")
    sizeLimit.MaxSize = Vector2.new(388, 32)
    sizeLimit.Parent = hint

    local touchPanel = Instance.new("Frame")
    touchPanel.Name = "TouchActions"
    touchPanel.AnchorPoint = Vector2.new(1, 0.5)
    touchPanel.Position = UDim2.new(1, -8, 0.46, 0)
    touchPanel.Size = UDim2.fromOffset(148, 100)
    touchPanel.BackgroundTransparency = 1
    touchPanel.Parent = gui
    local function button(name, text, x, y, callback)
        local object = label("TextButton", touchPanel, name, UDim2.fromOffset(71, 46), UDim2.fromOffset(x, y))
        object.Text = text
        object.Font = Enum.Font.GothamBold
        object.TextSize = 14
        object.TextColor3 = hint.TextColor3
        object.Activated:Connect(callback)
        return object
    end
    local turn = button("Rotate", "", 0, 0, rotate)
    local snap = button("Snap", "", 77, 0, toggleSnap)
    snap.Visible = canSnap
    button("Place", "Place", 0, 52, confirmPlacement)
    button("Cancel", "Cancel", 77, 52, PlacementController.cancelPlacement)

    local reticle = label("Frame", gui, "AimPoint", UDim2.fromOffset(8, 8), UDim2.fromScale(0.5, 0.5))
    reticle.AnchorPoint = Vector2.new(0.5, 0.5)
    gui.Parent = player:WaitForChild("PlayerGui")
    return gui, hint, touchPanel, turn, snap, reticle
end

function PlacementController.startPlacement(itemName, slotNumber)
    if pending then
        return
    end

    PlacementController.cancelPlacement()

    if typeof(itemName) ~= "string" then
        return
    end

    local definition = ItemDefinitions[itemName]

    if not definition or definition.Placeable ~= true then
        return
    end

    local template = PlacementModels.getTemplate(itemName)

    if not template or not template:IsA("Model") then
        warn("[PLACEMENT] Model is missing for", itemName)
        return
    end

    local plotName = player:GetAttribute("PlotName")
    local plot = plotName and workspace:WaitForChild("Plots"):FindFirstChild(plotName)

    local ground = plot and plot:FindFirstChild("Ground")

    if not ground or not ground:IsA("BasePart") then
        warn("[PLACEMENT] Your plot's Ground is missing")
        return
    end

    placingItemName = itemName
    local inventory = player:FindFirstChild("Inventory")
    sourceSlot = inventory and slotNumber and inventory:FindFirstChild("Slot" .. slotNumber)
    rotation = 0
    preview = template:Clone()

    local parts = {}

    for _, object in ipairs(preview:GetDescendants()) do
        if object:IsA("LuaSourceContainer") or object:IsA("ProximityPrompt") then
            object:Destroy()

        elseif object:IsA("BasePart") then
            object.Anchored = true
            object.CanCollide = false
            object.CanTouch = false
            object.CanQuery = false
            object.Transparency = math.max(object.Transparency, 0.5)

            table.insert(parts, object)
        end
    end

    local function bindButton(name, key, callback)
        ContextActionService:BindAction(name, function(_, state)
            if state == Enum.UserInputState.Begin then
                callback()
            end
            return Enum.ContextActionResult.Sink
        end, false, key)
    end

    local canSnap = definition.PlacementSnapGroup ~= nil
    local function rotate()
        if not pending then
            rotation = (rotation + 1) % 4
            canPlace = false
        end
    end
    local function toggleSnap()
        if not pending then
            snapEnabled = not snapEnabled
            canPlace = false
        end
    end
    local gui, hint, touchPanel, turn, snap, reticle = makeControls(rotate, toggleSnap, canSnap)
    controls = gui
    bindButton("ConfirmPlacement", Enum.KeyCode.E, confirmPlacement)
    bindButton("CancelPlacement", Enum.KeyCode.Q, PlacementController.cancelPlacement)
    bindButton("RotatePlacement", Enum.KeyCode.R, rotate)
    if canSnap then
        bindButton("TogglePlacementSnap", Enum.KeyCode.G, toggleSnap)
    end

    local function showStatus(snapped)
        local snapText = snapped and "Snapped" or (snapEnabled and "Snap: On" or "Snap: Off")
        turn.Text = "Turn " .. rotation * 90 .. "°"
        snap.Text = snapText
        hint.Text = "R  Rotate " .. rotation * 90 .. "°   ·   "
            .. (canSnap and ("G  " .. snapText .. "   ·   ") or "") .. "E  Place   ·   Q  Cancel"
    end

    connection = RunService.RenderStepped:Connect(function()
        if player:GetAttribute("DataLoaded") ~= true or plot:GetAttribute("OwnerUserId") ~= player.UserId
            or (sourceSlot and not hasSelectedItem()) then
            PlacementController.cancelPlacement()
            return
        end

        local camera = workspace.CurrentCamera
        if not camera then
            return
        end

        local touch = UserInputService.PreferredInput == Enum.PreferredInput.Touch
        hint.Visible = not touch
        touchPanel.Visible = touch
        reticle.Visible = touch

        local ray
        if touch then
            local aim = reticle.AbsolutePosition + reticle.AbsoluteSize / 2
            ray = camera:ScreenPointToRay(aim.X, aim.Y)
        else
            local mouse = UserInputService:GetMouseLocation()
            ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
        end

        local normal = ground.CFrame.UpVector

        local top = ground.CFrame:PointToWorldSpace(Vector3.new(0, ground.Size.Y / 2, 0))

        local denominator = ray.Direction:Dot(normal)
        local distance = -1

        if math.abs(denominator) > 0.0001 then
            distance = (top - ray.Origin):Dot(normal) / denominator
        end

        if distance <= 0 or distance > 500 then
            preview.Parent = nil
            canPlace = false
            showStatus(false)
            return
        end

        local aimPosition = ray.Origin + ray.Direction * distance
        local snapped = canSnap and snapEnabled
            and rules.getSnapPosition(plot, aimPosition, template, rotation, itemName, preview)
        position = snapped or aimPosition
        showStatus(snapped)
        local pivot, valid = rules.getPlacement(plot, position, template, rotation, preview)
        canPlace = valid

        if not pivot then
            preview.Parent = nil
            return
        end

        preview:PivotTo(pivot)
        preview.Parent = workspace

        local color = valid and (snapped and Color3.fromRGB(62, 202, 171) or Color3.fromRGB(75, 210, 100))
            or Color3.fromRGB(230, 75, 75)

        for _, part in ipairs(parts) do
            part.Color = color
        end
    end)
end

PlaceEvent.OnClientEvent:Connect(function(success, message)
    pending = false

    if success and not hasSelectedItem() then
        PlacementController.cancelPlacement()
    elseif not success then
        warn("[PLACEMENT] Failed to place item:", message)
    end
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.UserInputType == Enum.UserInputType.MouseButton1 then
        confirmPlacement()
    end
end)

player.CharacterRemoving:Connect(PlacementController.cancelPlacement)

return PlacementController
