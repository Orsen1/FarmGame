local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Actions = game:GetService("ContextActionService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Rules = require(script.Parent.PlacementRules)
local Models = require(script.Parent.PlacementModels)
local Catalog = require(script.Parent.BuildCatalog)
local BedLayout = require(script.Parent.GardenBedLayout)
local BedConfig = require(ReplicatedStorage.Configs.GardenBedConfig)
local View = require(script.Parent.BuildView)
local definitions = require(ReplicatedStorage.Configs.ItemDefinitions)
local remote = ReplicatedStorage.RemoteEvents:WaitForChild("PlaceEvent")
local changed = Instance.new("BindableEvent")
local Controller = {Changed = changed.Event}
local active, pending
local green, red, blue = Color3.fromRGB(84, 195, 103), Color3.fromRGB(224, 83, 62), Color3.fromRGB(103, 171, 225)

function Controller.cancelPlacement(message)
    if not active then return end
    local state = active
    active = nil
    for _, connection in ipairs(state.Connections) do connection:Disconnect() end
    for _, action in ipairs({"ConfirmPlacement", "CancelPlacement", "RotatePlacement"}) do Actions:UnbindAction(action) end
    for _, strip in ipairs(state.Strips) do strip[2]:Destroy() end
    state.Scene:Destroy()
    state.Gui:Destroy()
    changed:Fire(message)
end

function Controller.selection()
    return active and active.Entry.Key
end

local function makeGhost(item, level, parent, template)
    local model = (template or Rules.LevelTemplate(item, level)):Clone()
    if BedConfig.Types[item] and level > 1 then BedLayout.Expand(model, item, level) end
    for _, object in ipairs(model:GetDescendants()) do
        if object:IsA("LuaSourceContainer") or object:IsA("ProximityPrompt") or object:IsA("LayerCollector") then
            object:Destroy()
        elseif object:IsA("BasePart") then
            object.Anchored, object.CanCollide, object.CanTouch, object.CanQuery = true, false, false, false
            object.CastShadow = false
            object.Transparency = math.max(object.Transparency, .48)
        end
    end
    model.Parent = parent
    return model, View.make("Highlight", model, {Adornee = model, DepthMode = Enum.HighlightDepthMode.Occluded,
        FillTransparency = .78, OutlineTransparency = .18})
end

local function aim(ground, point)
    local camera = workspace.CurrentCamera
    if not camera then return end
    local ray = camera:ViewportPointToRay(point.X, point.Y)
    local normal = ground.CFrame.UpVector
    local slope = ray.Direction:Dot(normal)
    if math.abs(slope) < .0001 then return end
    local distance = (ground.Position + normal * ground.Size.Y / 2 - ray.Origin):Dot(normal) / slope
    if distance > 0 and distance < 1400 then return ray.Origin + ray.Direction * distance end
end

local function overGui(point)
    local guiPoint = point - GuiService:GetGuiInset()
    for _, object in ipairs(playerGui:GetGuiObjectsAtPosition(guiPoint.X, guiPoint.Y)) do
        if object:IsA("GuiButton") or object:IsA("ScrollingFrame") or object.Active then return true end
    end
    return false
end

local function actions(state, onRotate, onLevel, onMax, onConfirm)
    local gui = state.Gui
    local frame = View.make("Frame", gui, {Name = "Actions", AnchorPoint = Vector2.new(.5, 1),
        Active = true, BackgroundColor3 = View.Paper, BorderSizePixel = 0})
    View.trim(frame, 11)
    local info = View.text("TextLabel", frame, "Status", "", 14)
    info.Position, info.Size = UDim2.fromOffset(4, 2), UDim2.new(1, -8, 0, 33)
    info.TextWrapped = true
    local buttons = {}
    local function button(name, title, color, callback)
        local b = View.text("TextButton", frame, name, title, 14, color)
        if color == View.Green then b.TextColor3 = Color3.new(1, 1, 1) end
        b.Activated:Connect(callback)
        table.insert(buttons, b)
        return b
    end
    button("Rotate", "Rotate", View.Gold, onRotate)
    if state.Max > state.First then
        button("Level", "Levels", View.Gold, onLevel)
        button("Max", "Max Lv.", View.Gold, onMax)
    end
    button("Cancel", "Cancel", View.Gold, Controller.cancelPlacement)
    local place = not state.Source and button("Place", "Place", View.Green, onConfirm)
    for i, b in ipairs(buttons) do
        b.Position, b.Size = UDim2.new((i - 1) / #buttons, 4, 0, 38), UDim2.new(1 / #buttons, -8, 0, 44)
    end
    local function layout()
        local width = math.min(gui.AbsoluteSize.X - 16, #buttons * 83)
        frame.Size = UDim2.fromOffset(width, 87)
        local touch = Input.PreferredInput == Enum.PreferredInput.Touch
        local inventory = playerGui:FindFirstChild("InventoryGui")
        local bar = inventory and inventory:FindFirstChild("HotbarFrame")
        if state.Overview then
            frame.Position = UDim2.new(.5, 0, 1, -6)
        elseif touch and bar then
            frame.Position = UDim2.new(.5, 0, 0, bar.AbsolutePosition.Y - gui.AbsolutePosition.Y - 8)
        else
            frame.Position = UDim2.new(.5, 0, 0, 94)
        end
    end
    return info, place, layout
end

local function remaining(state)
    if state.Source then
        return Rules.movableItem(state.Plot, state.Source, player.UserId)
            and state.Source:GetAttribute("BedLevel") == state.BedLevel
    end
    local e = state.Entry
    if state.Overview and not e.Data then return Catalog.Resolve(player, e.Item, "Catalog") end
    return Catalog.Resolve(player, e.Item, e.Area, e.Index, e.Data)
end

local function showExtra(state, current, size, future, nextSize, color)
    local offset = current:PointToObjectSpace(future.Position)
    local x0, x1 = offset.X - nextSize.X / 2, offset.X + nextSize.X / 2
    local z0, z1 = offset.Z - nextSize.Z / 2, offset.Z + nextSize.Z / 2
    local left, right = math.max(x0, -size.X / 2), math.min(x1, size.X / 2)
    local function strip(i, a, b, c, d)
        local draw, tile = table.unpack(state.Strips[i])
        if b - a < .01 or d - c < .01 then tile.Parent = nil; return end
        tile.Parent = state.Scene
        draw(current * CFrame.new((a+b)/2, 0, (c+d)/2), Vector3.new(b-a, 0, d-c), Rules.CellSize, color)
    end
    strip(1, x0, left, z0, z1)
    strip(2, right, x1, z0, z1)
    strip(3, left, right, z0, math.min(z1, -size.Z/2))
    strip(4, left, right, math.max(z0, size.Z/2), z1)
end

function Controller.startPlacement(item, slotNumber, catalogEntry, source, grabPoint)
    if pending or player:GetAttribute("BuildMode") and not (catalogEntry or source) then return end
    Controller.cancelPlacement()
    if not definitions[item] or not definitions[item].Placeable then return end
    local plot = workspace.Plots:FindFirstChild(player:GetAttribute("PlotName") or "")
    local template = Models.getTemplate(item, source and source:GetAttribute("ConstructionStage"))
    if not plot or not plot:FindFirstChild("Ground") or not template then return end
    local slot = not (catalogEntry or source) and player.Inventory:FindFirstChild("Slot" .. slotNumber)
    local bedLevel = source and source:GetAttribute("BedLevel")
    local first, max = Rules.Levels(item)
    first = bedLevel or first
    local state = {Entry = catalogEntry or {Item = item, Area = "Inventory", Index = slotNumber,
        Data = slot and slot:GetAttribute("ObjectData"), Key = source or item}, Overview = catalogEntry ~= nil or source ~= nil,
        Source = source, Plot = plot, BedLevel = bedLevel, Scene = Instance.new("Folder"), Connections = {},
        First = first, Max = max, Strips = {}}
    state.Scene.Name = "BuildPreview"
    state.Gui = View.make("ScreenGui", playerGui, {Name = "PlacementControls", ResetOnSpawn = false,
        DisplayOrder = 53, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets})
    active = state
    local rotation, level, nextCheck = 0, first, 0
    local ghost, highlight = makeGhost(item, level, state.Scene, template)
    local draw = View.grid("OccupiedCells", state.Scene, green, .25)
    for i = 1, 4 do
        state.Strips[i] = {View.grid("FutureCells", state.Scene, blue, .22)}
        state.Strips[i][2].Parent = state.Scene
        state.Strips[i][2].Size = Vector3.new(.01,.01,.01)
    end
    local target = state.Overview and plot.Ground.Position or nil
    if source then
        target, rotation = Rules.moveOrigin(plot, source, item, first)
        View.make("Highlight", state.Scene, {Adornee = source, FillTransparency = 1, OutlineColor = View.Gold,
            DepthMode = Enum.HighlightDepthMode.Occluded})
    end
    local pinned = (source or Input.PreferredInput == Enum.PreferredInput.Touch) and target or nil
    local valid, failure
    local info, place, layout
    local function refreshLevel(new)
        if pending then return end
        level, nextCheck = new, 0
        ghost:Destroy()
        ghost, highlight = makeGhost(item, level, state.Scene, level == first and template or nil)
    end
    local function rotate()
        if not pending then rotation, valid, nextCheck, failure = (rotation + 1) % 4, false, 0, nil end
    end
    local function confirm()
        if not valid or not target or pending then return end
        pending, failure = state, nil
        local e = state.Entry
        if source then
            remote:FireServer(source, target, rotation)
        else
            remote:FireServer(item, target, rotation, state.Overview and not e.Data and "Catalog" or e.Area, e.Index, e.Data)
        end
    end
    if source then
        local origin, originalRotation = target, rotation
        local grabbed = aim(plot.Ground, grabPoint)
        local offset = grabbed and origin - grabbed or Vector3.zero
        local function dragPosition(point)
            local position = aim(plot.Ground, point)
            return position and position + offset
        end
        state.DragAim = function(point)
            if not pending then pinned = dragPosition(point) end
        end
        state.Drop = function(point)
            if pending then return end
            local size = workspace.CurrentCamera.ViewportSize
            if not remaining(state) or point.X < 0 or point.Y < 0 or point.X > size.X or point.Y > size.Y
                or overGui(point) or rotation == originalRotation and (point - grabPoint).Magnitude < 3 then
                Controller.cancelPlacement()
                return
            end
            local position = dragPosition(point)
            local destination, allowed, reason = Rules.getMovePlacement(plot, source, item, position, rotation)
            if not allowed then
                Controller.cancelPlacement(reason)
                return
            end
            if rotation == originalRotation and destination == Rules.getMovePlacement(plot, source, item, origin, rotation) then
                Controller.cancelPlacement()
                return
            end
            pinned, target, valid = position, position, true
            confirm()
        end
    end
    info, place, layout = actions(state, rotate, function()
        refreshLevel(level == max and first or level + 1)
    end, function() refreshLevel(max) end, confirm)
    local function bind(name, key, callback)
        Actions:BindActionAtPriority(name, function(_, inputState)
            if inputState == Enum.UserInputState.Begin then callback() end
            return Enum.ContextActionResult.Sink
        end, false, 3100, key)
    end
    if not source then bind("ConfirmPlacement", Enum.KeyCode.E, confirm) end
    bind("CancelPlacement", Enum.KeyCode.Q, Controller.cancelPlacement)
    bind("RotatePlacement", Enum.KeyCode.R, rotate)
    local function listen(signal, callback)
        table.insert(state.Connections, signal:Connect(callback))
    end
    if not source then
        listen(Input.TouchTapInWorld, function(point, processed)
            if not processed and not pending then
                pinned, failure, nextCheck, valid = aim(plot.Ground, point), nil, 0, false
            end
        end)
        listen(Input.InputBegan, function(input, processed)
            if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 or Input.PreferredInput == Enum.PreferredInput.Touch then return end
            if state.Overview then
                pinned, failure, nextCheck, valid = aim(plot.Ground, Input:GetMouseLocation()), nil, 0, false
            else
                confirm()
            end
        end)
    end
    listen(RunService.RenderStepped, function()
        if not plot.Parent or player:GetAttribute("PlotName") ~= plot.Name or plot:GetAttribute("OwnerUserId") ~= player.UserId
            or player:GetAttribute("DataLoaded") ~= true then Controller.cancelPlacement(); return end
        if os.clock() < nextCheck then return end
        nextCheck = os.clock() + .065
        if not remaining(state) then Controller.cancelPlacement(); return end
        layout()
        local touch = Input.PreferredInput == Enum.PreferredInput.Touch
        local mouse = Input:GetMouseLocation()
        local point = pinned
        if not source and not point and not touch then
            point = overGui(mouse) and target or aim(plot.Ground, mouse)
        end
        local reason
        if point then
            if target and (point-target).Magnitude > .1 then failure = nil end
            target = point
            local pivot, ok, message, cells, extent
            if source then
                pivot, ok, message, cells, extent = Rules.getMovePlacement(plot, source, item, target, rotation)
            else
                pivot, ok, message, cells, extent = Rules.getPlacement(plot, target, template, rotation, state.Scene)
            end
            valid, reason = ok, not ok and message
            if pivot then
                ghost:PivotTo(pivot)
                state.Scene.Parent = workspace
                local base = cells * CFrame.new(0, -extent.Y / 2 + .055, 0)
                draw(base, extent, Rules.CellSize, ok and green or red)
                local other, area, futureOk = cells, extent, ok
                if level ~= first then other, area, futureOk = Rules.levelArea(plot, item, pivot, level, source or state.Scene) end
                showExtra(state, base, extent, other, area, futureOk and blue or red)
                highlight.FillColor = level == first and (ok and green or red) or (futureOk and blue or red)
                highlight.OutlineColor = highlight.FillColor
                local sizes = string.format("%d × %d", math.round(area.X / Rules.CellSize), math.round(area.Z / Rules.CellSize))
                local actionName = source and "Move" or "Place"
                local caption = level ~= first and string.format("%s Lv.%d  •  Preview Lv.%d", actionName, first, level)
                    or definitions[item].DisplayName
                local moveHint = touch and "Release to place" or "Release to place  ·  R rotate"
                info.Text = caption .. "  ·  " .. sizes .. "\n" .. (pending and (source and "Moving…" or "Placing…") or failure or reason or
                    level ~= first and (futureOk and "Future size fits here" or "Future size is blocked") or
                    source and moveHint or
                    (touch and "Tap land to aim" or state.Overview and "Click to aim  ·  R rotate  ·  E place" or "R rotate  ·  E place  ·  Q cancel"))
            end
        else
            state.Scene.Parent, valid = nil, false
            info.Text = string.format("%s  ·  Lv.%d%s\nTap your land to aim", definitions[item].DisplayName, first,
                level ~= first and ("  ·  Preview Lv." .. level) or "")
        end
        info.TextColor3 = (failure or reason) and View.Red or View.Ink
        if place then
            place.Interactable = valid == true and not pending
            place.BackgroundColor3 = place.Interactable and View.Green or Color3.fromRGB(163, 150, 118)
        end
    end)
    state.Finish = function(success, message)
        if source then Controller.cancelPlacement(not success and message or nil)
        elseif not success then failure = message or "Unable to place here"
        elseif not remaining(state) then Controller.cancelPlacement()
        else pinned, target, valid = nil, nil, false end
        nextCheck = 0
    end
    layout()
    changed:Fire()
end

function Controller.startMove(object, plot, point)
    if active or pending or not player:GetAttribute("BuildMode") then return end
    if overGui(point) then return end
    local item = Rules.movableItem(plot, object, player.UserId)
    if not item then return end
    Controller.startPlacement(item, nil, nil, object, point)
    return active ~= nil
end

function Controller.aimMove(point)
    if not active or not active.DragAim then return false end
    active.DragAim(point)
    return true
end

function Controller.dropMove(point)
    if active and active.Drop then active.Drop(point) end
end

function Controller.cancelMove()
    if active and active.Source and pending ~= active then Controller.cancelPlacement() end
end

remote.OnClientEvent:Connect(function(success, message)
    local request = pending
    pending = nil
    if request and request == active then request.Finish(success, message) end
end)
player.CharacterRemoving:Connect(Controller.cancelPlacement)

return Controller
