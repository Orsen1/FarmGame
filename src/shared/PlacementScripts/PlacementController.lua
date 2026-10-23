local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local rules = require(ReplicatedStorage:WaitForChild("PlacementScripts"):WaitForChild("PlacementRules"))
local models = ReplicatedStorage:WaitForChild("PlaceableModels")
local ItemDefinitions = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("ItemDefinitions"))
local PlaceEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("PlaceEvent")
local PlacementController = {}

local placingItemName
local preview
local connection
local position

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

    ContextActionService:UnbindAction("ConfirmPlacement")
    ContextActionService:UnbindAction("CancelPlacement")
end

local function confirmPlacement()
    if preview and canPlace and not pending then
        pending = true
        PlaceEvent:FireServer(placingItemName, position)
    end
end 

function PlacementController.startPlacement(itemName)
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

    local template = models:FindFirstChild(itemName)

    if not template or not template:IsA("Model") then
        warn("[PLACEMENT] Model is missing for", itemName)
        return
    end

    local plotName = player:GetAttribute("PlotName")
    local plot = plotName and workspace:WaitForChild("Plots")
        :FindFirstChild(plotName)

    local ground = plot and plot:FindFirstChild("Ground")

    if not ground or not ground:IsA("BasePart") then
        warn("[PLACEMENT] Your plot's Ground is missing")
        return
    end

    placingItemName = itemName
    preview = template:Clone()

    local parts = {}

    for _, object in ipairs(preview:GetDescendants()) do
        if object:IsA("LuaSourceContainer")
            or object:IsA("ProximityPrompt") then
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

    local touch = UserInputService.TouchEnabled
        and not UserInputService.MouseEnabled

    local function bindButton(name, title, key, y, callback)
        ContextActionService:BindAction(name, function(_, state)
            if state == Enum.UserInputState.Begin then
                callback()
            end

            return Enum.ContextActionResult.Sink
        end, true, key)

        ContextActionService:SetTitle(name, title)
        ContextActionService:SetPosition(name, UDim2.fromScale(0.75, y))
    end

    bindButton(
        "ConfirmPlacement", "Place", Enum.KeyCode.E,
        0.45, confirmPlacement
    )

    bindButton(
        "CancelPlacement", "Cancel", Enum.KeyCode.Q,
        0.62, PlacementController.cancelPlacement
    )

    connection = RunService.RenderStepped:Connect(function()
        if player:GetAttribute("DataLoaded") ~= true
            or plot:GetAttribute("OwnerUserId") ~= player.UserId then
            PlacementController.cancelPlacement()
            return
        end

        local camera = workspace.CurrentCamera
        if not camera then
            return
        end

        local ray

        if touch then
            ray = camera:ViewportPointToRay(
                camera.ViewportSize.X / 2,
                camera.ViewportSize.Y / 2
            )
        else
            local mouse = UserInputService:GetMouseLocation()
            ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
        end

        local normal = ground.CFrame.UpVector

        local top = ground.CFrame:PointToWorldSpace(
            Vector3.new(0, ground.Size.Y / 2, 0)
        )

        local denominator = ray.Direction:Dot(normal)
        local distance = -1

        if math.abs(denominator) > 0.0001 then
            distance = (top - ray.Origin):Dot(normal) / denominator
        end

        if distance <= 0 or distance > 500 then
            preview.Parent = nil
            canPlace = false
            return
        end

        position = ray.Origin + ray.Direction * distance

        local pivot, valid = rules.getPlacement(plot, position, template, preview)
        canPlace = valid

        if not pivot then
            preview.Parent = nil
            return
        end

        preview:PivotTo(pivot)
        preview.Parent = workspace

        local color = valid
            and Color3.fromRGB(75, 210, 100)
            or Color3.fromRGB(230, 75, 75)

        for _, part in ipairs(parts) do
            part.Color = color
        end
    end)
end

PlaceEvent.OnClientEvent:Connect(function(success, message)
    pending = false

    if success then
        PlacementController.cancelPlacement()
    else
        warn("[PLACEMENT] Failed to place item:", message)
    end
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if not processed
        and input.UserInputType == Enum.UserInputType.MouseButton1 then
        confirmPlacement()
    end
end)

player.CharacterRemoving:Connect(PlacementController.cancelPlacement)

return PlacementController