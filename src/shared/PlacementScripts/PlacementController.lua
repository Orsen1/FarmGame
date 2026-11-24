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
local touchConnection
local position
local touchPosition
local sourceSlot
local controls
local placementError
local rotation = 0
local snapEnabled = true

local canPlace = false
local pending = false
local ink = Color3.fromRGB(94, 59, 32)
local paper = Color3.fromRGB(255, 236, 190)
local green = Color3.fromRGB(76, 129, 57)
local muted = Color3.fromRGB(213, 186, 144)
local red = Color3.fromRGB(156, 58, 42)

function PlacementController.cancelPlacement()
    if connection then
        connection:Disconnect()
        connection = nil
    end
    if touchConnection then
        touchConnection:Disconnect()
        touchConnection = nil
    end

    if preview then
        preview:Destroy()
        preview = nil
    end

    canPlace = false
    position = nil
    touchPosition = nil
    placementError = nil
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
        placementError = nil
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
    gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets

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
    touchPanel.AnchorPoint = Vector2.new(.5, 1)
    touchPanel.Size = UDim2.new(1, -24, 0, 89)
    touchPanel.BackgroundColor3 = paper
    touchPanel.BorderSizePixel = 0
    touchPanel.Active = true
    touchPanel.Visible = false
    local limit = Instance.new("UISizeConstraint")
    limit.MaxSize = Vector2.new(354, 89)
    limit.Parent = touchPanel
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = touchPanel
    local stroke = Instance.new("UIStroke")
    stroke.Color = ink
    stroke.Thickness = 2
    stroke.Parent = touchPanel
    touchPanel.Parent = gui

    local status = label("TextLabel", touchPanel, "Status", UDim2.new(1, -18, 0, 25), UDim2.fromOffset(9, 4))
    status.BackgroundTransparency = 1
    status.Font = Enum.Font.FredokaOne
    status.TextSize = 14
    status.TextColor3 = ink
    status.TextWrapped = true

    local count = canSnap and 4 or 3
    local function button(name, text, index, color, callback)
        local object = label("TextButton", touchPanel, name, UDim2.new(1 / count, -12, 0, 48),
            UDim2.new((index - .5) / count, 0, 0, 32))
        object.AnchorPoint = Vector2.new(.5, 0)
        object.BackgroundColor3 = color
        object.Text = text
        object.Font = Enum.Font.FredokaOne
        object.TextSize = 14
        object.TextColor3 = color == green and Color3.new(1, 1, 1) or ink
        object.Activated:Connect(callback)
        return object
    end
    local buttonPaper = Color3.fromRGB(233, 193, 130)
    local turn = button("Rotate", "Rotate", 1, buttonPaper, rotate)
    local snap = canSnap and button("Snap", "", 2, buttonPaper, toggleSnap)
    button("Cancel", "Cancel", count - 1, buttonPaper, PlacementController.cancelPlacement)
    local place = button("Place", "Place", count, green, confirmPlacement)
    gui.Parent = player:WaitForChild("PlayerGui")
    return gui, hint, touchPanel, status, turn, snap, place
end

local function groundPoint(ground, ray)
    local normal = ground.CFrame.UpVector
    local top = ground.Position + normal * ground.Size.Y / 2
    local direction = ray.Direction:Dot(normal)
    if math.abs(direction) < .0001 then return end
    local distance = (top - ray.Origin):Dot(normal) / direction
    if distance > 0 and distance <= 500 then return ray.Origin + ray.Direction * distance end
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
            if object:IsA("PartOperation") then object.UsePartColor = true end

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
    local nextTouchCheck = 0
    local function rotate()
        if not pending then
            rotation = (rotation + 1) % 4
            canPlace = false
            placementError = nil
            nextTouchCheck = 0
        end
    end
    local function toggleSnap()
        if not pending then
            snapEnabled = not snapEnabled
            canPlace = false
            placementError = nil
            nextTouchCheck = 0
        end
    end
    local gui, hint, touchPanel, status, turn, snap, place = makeControls(rotate, toggleSnap, canSnap)
    controls = gui
    bindButton("ConfirmPlacement", Enum.KeyCode.E, confirmPlacement)
    bindButton("CancelPlacement", Enum.KeyCode.Q, PlacementController.cancelPlacement)
    bindButton("RotatePlacement", Enum.KeyCode.R, rotate)
    if canSnap then
        bindButton("TogglePlacementSnap", Enum.KeyCode.G, toggleSnap)
    end

    local inventoryGui = gui.Parent:FindFirstChild("InventoryGui")
    local hotbar = inventoryGui and inventoryGui:FindFirstChild("HotbarFrame")
    local function showStatus(snapped, reason)
        local snapText = snapped and "Snapped" or (snapEnabled and "Snap: On" or "Snap: Off")
        turn.Text = "Rotate " .. rotation * 90 .. "°"
        if snap then snap.Text = snapText end
        hint.Text = "R  Rotate " .. rotation * 90 .. "°   ·   "
            .. (canSnap and ("G  " .. snapText .. "   ·   ") or "") .. "E  Place   ·   Q  Cancel"
        if not touchPanel.Visible then return end
        local hotbarTop = hotbar and hotbar.AbsolutePosition.Y - gui.AbsolutePosition.Y or gui.AbsoluteSize.Y * .78
        touchPanel.Position = UDim2.new(.5, 0, 0, hotbarTop - 12)
        status.Text = pending and "Placing..." or placementError or not touchPosition and "Tap your land to aim"
            or reason or (snapped and "Snapped to a nearby bed" or "Tap another spot or press Place")
        status.TextColor3 = (reason or placementError) and red or ink
        place.Text = pending and "Placing..." or "Place"
        place.Interactable = canPlace and not pending
        place.BackgroundColor3 = place.Interactable and green or muted
        place.TextColor3 = place.Interactable and Color3.new(1, 1, 1) or ink
        turn.Interactable = not pending
        if snap then snap.Interactable = not pending end
    end

    touchConnection = UserInputService.TouchTapInWorld:Connect(function(point, processed)
        if processed or pending or UserInputService.PreferredInput ~= Enum.PreferredInput.Touch then return end
        local camera = workspace.CurrentCamera
        local target = camera and groundPoint(ground, camera:ViewportPointToRay(point.X, point.Y))
        if target then
            touchPosition = target
            placementError = nil
            canPlace = false
            nextTouchCheck = 0
        end
    end)

    local lastPivot, lastColor, lastSnap, lastReason
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
        local aimPosition
        if touch then
            aimPosition = touchPosition
        else
            local mouse = UserInputService:GetMouseLocation()
            aimPosition = groundPoint(ground, camera:ViewportPointToRay(mouse.X, mouse.Y))
        end

        if not aimPosition then
            preview.Parent = nil
            canPlace = false
            showStatus(false)
            return
        end

        if touch then
            local now = os.clock()
            if now < nextTouchCheck then
                showStatus(lastSnap, lastReason)
                return
            end
            nextTouchCheck = now + .1
        end

        local snapped = canSnap and snapEnabled
            and rules.getSnapPosition(plot, aimPosition, template, rotation, itemName, preview)
        position = snapped or aimPosition
        local pivot, valid, reason = rules.getPlacement(plot, position, template, rotation, preview)
        canPlace = valid
        if reason == "Keep the whole object inside your unlocked land" then reason = "Keep it inside your unlocked land" end
        lastSnap, lastReason = snapped, not valid and reason or nil
        showStatus(lastSnap, lastReason)

        if not pivot then
            preview.Parent = nil
            return
        end

        if lastPivot ~= pivot then
            preview:PivotTo(pivot)
            lastPivot = pivot
        end
        preview.Parent = workspace

        local color = valid and (snapped and Color3.fromRGB(62, 202, 171) or Color3.fromRGB(75, 210, 100))
            or Color3.fromRGB(230, 75, 75)

        if color ~= lastColor then
            for _, part in ipairs(parts) do part.Color = color end
            lastColor = color
        end
    end)
end

PlaceEvent.OnClientEvent:Connect(function(success, message)
    pending = false

    if success then
        if not hasSelectedItem() then
            PlacementController.cancelPlacement()
        else
            touchPosition = nil
            canPlace = false
        end
    elseif not success then
        if preview then placementError = message end
        warn("[PLACEMENT] Failed to place item:", message)
    end
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.UserInputType == Enum.UserInputType.MouseButton1 and
        UserInputService.PreferredInput ~= Enum.PreferredInput.Touch then
        confirmPlacement()
    end
end)

player.CharacterRemoving:Connect(PlacementController.cancelPlacement)

return PlacementController
