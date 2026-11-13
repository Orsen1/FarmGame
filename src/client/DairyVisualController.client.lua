local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local definitions = require(ReplicatedStorage.Configs.ItemDefinitions)
local recipes = require(ReplicatedStorage.Configs.ProductionRecipes)
local plots = workspace:WaitForChild("Plots")
local stations = {}

local function prop(state, kind)
    if state.PropKind == kind then return end
    if state.Prop then state.Prop:Destroy();state.Prop = nil end
    state.PropKind = kind
    if not kind then return end
    local model = Instance.new("Model")
    model.Name = "DairyPour"
    local template = kind == "MilkBucket" and ReplicatedStorage.Tools.MilkBucket or state.Object.Equipment.CreamCup
    for _, child in ipairs(template:GetDescendants()) do
        if child:IsA("BasePart") then
            local part = child:Clone()
            part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
            part.Transparency = 0
            part.Parent = model
            if part.Name == "Handle" then model.PrimaryPart = part end
        end
    end
    model:ScaleTo(kind == "MilkBucket" and 0.75 or 1.3)
    state.Prop = model
end

local function bind(object)
    if stations[object] or not object:IsA("Model") then return end
    local definition = definitions[object:GetAttribute("ItemName") or object.Name]
    if not definition or not definition.MilkTank then return end
    local equipment = object:FindFirstChild("Equipment")
    local root = object:FindFirstChild("PlacementRoot")
    if not equipment or not root then return end
    local rotor, piston = equipment.Separator.Rotor, equipment.Churn.Piston
    local gui = Instance.new("BillboardGui")
    gui.Name = "DairyStatus"
    gui.Size = UDim2.fromOffset(180, 48)
    gui.Adornee = root
    gui.StudsOffset = Vector3.new(0, 6.8, 0)
    gui.AlwaysOnTop = true
    gui.MaxDistance = 40
    local text = Instance.new("TextLabel")
    text.Size = UDim2.fromScale(1, 1)
    text.BackgroundColor3 = Color3.fromRGB(255, 224, 160)
    text.TextColor3 = Color3.fromRGB(89, 55, 26)
    text.Font = Enum.Font.FredokaOne
    text.TextSize = 17
    text.BorderSizePixel = 0
    text.Parent = gui
    local corner = Instance.new("UICorner");corner.CornerRadius = UDim.new(0, 10);corner.Parent = text
    local border = Instance.new("UIStroke");border.Color = Color3.fromRGB(169, 111, 50);border.Thickness = 1.5; border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border;border.Parent = text
    gui.Parent = root
    local stream = Instance.new("Part")
    stream.Name = "DairyStream"
    stream.Color = Color3.fromRGB(255, 246, 222)
    stream.Anchored, stream.CanCollide, stream.CanTouch, stream.CanQuery = true, false, false, false
    stream.Transparency = 1
    stream.Size = Vector3.new(0.07, 0.6, 0.07)
    stream.Parent = object
    stations[object] = {Object = object, Root = root, Rotor = rotor, Piston = piston, Definition = definition,
        RotorFrame = root.CFrame:ToObjectSpace(rotor:GetPivot()), PistonFrame = root.CFrame:ToObjectSpace(piston:GetPivot()),
        Surface = equipment.MilkTank.MilkSurface,
        SurfaceFrame = root.CFrame:ToObjectSpace(equipment.MilkTank.MilkSurface.CFrame), Level = 0,
        Gui = gui, Text = text, Stream = stream}
end

local scan = 0
RunService.Heartbeat:Connect(function(dt)
    scan += dt
    if scan < 0.5 then return end
    scan = 0
    for _, plot in ipairs(plots:GetChildren()) do
        local objects = plot:FindFirstChild("PlacedObjects")
        for _, object in ipairs(objects and objects:GetChildren() or {}) do bind(object) end
    end
end)

RunService.RenderStepped:Connect(function(dt)
    local now = workspace:GetServerTimeNow()
    for object, state in pairs(stations) do
        if not object:IsDescendantOf(plots) then
            if state.Prop then state.Prop:Destroy() end
            state.Gui:Destroy();state.Stream:Destroy();stations[object] = nil
        else
            state.Gui.Enabled = object:GetAttribute("OperatorUserId") ~= Players.LocalPlayer.UserId
            local stock = object:GetAttribute("MilkStock") or 0
            state.Level += (stock / state.Definition.MilkTank.Capacity - state.Level) * (1 - math.exp(-dt * 5))
            state.Surface.Transparency = state.Level > 0.01 and 0 or 1
            state.Surface.CFrame = state.Root.CFrame * state.SurfaceFrame - state.Root.CFrame.UpVector * (2.65 * (1 - state.Level))
            local phase = object:GetAttribute("ProductionPhase")
            local recipe = recipes[object:GetAttribute("ActiveRecipe")]
            local elapsed = now - (object:GetAttribute("ProductionStartedAt") or now)
            local busy = object:GetAttribute("Busy") == true
            local rotor = state.Root.CFrame * state.RotorFrame * CFrame.Angles(0,
                busy and recipe and recipe.Visual == "Separator" and elapsed * 5 or 0, 0)
            local piston = state.Root.CFrame * state.PistonFrame * CFrame.new(0,
                busy and recipe and recipe.Visual == "Churn" and math.sin(elapsed * 5) * 0.22 or 0, 0)
            if rotor ~= state.LastRotor then state.Rotor:PivotTo(rotor);state.LastRotor = rotor end
            if piston ~= state.LastPiston then state.Piston:PivotTo(piston);state.LastPiston = piston end
            local depositAge = now - (object:GetAttribute("MilkDepositAt") or 0)
            local kind, target, pouring
            if phase == "Loading" and recipe then
                kind = recipe.Visual == "Separator" and "MilkBucket" or "Cream"
                target = recipe.Visual == "Separator" and Vector3.new(-0.8, 2.9, 1) or Vector3.new(3.2, 2.65, 1)
                pouring = math.clamp(elapsed / (object:GetAttribute("ProductionDuration") or 3), 0, 1)
            elseif depositAge < 1.6 then
                kind, target, pouring = "MilkBucket", Vector3.new(-5.2, 3.4, 1.6), depositAge / 1.6
            end
            prop(state, kind)
            if state.Prop then
                state.Prop:PivotTo(state.Root.CFrame * CFrame.new(target + Vector3.new(0.3, 1.2, 0)) *
                    CFrame.Angles(0, 0, math.sin(pouring * math.pi) * -0.9))
                state.Prop.Parent = workspace
                state.Stream.CFrame = state.Root.CFrame * CFrame.new(target + Vector3.new(0, 0.35, 0))
                state.Stream.Transparency = pouring > 0.12 and pouring < 0.9 and 0.1 or 1
            else
                state.Stream.Transparency = 1
            end
            local output = object.OutputInventory
            local total = 0
            for _, value in ipairs(output:GetChildren()) do if value:IsA("IntValue") then total += value.Value end end
            for modelName, itemName in pairs({CreamCup = "Cream", ButterDisplay = "Butter"}) do
                local value = output:FindFirstChild(itemName)
                for _, part in ipairs(object.Equipment[modelName]:GetDescendants()) do
                    if part:IsA("BasePart") then part.Transparency = value and value.Value > 0 and 0 or 1 end
                end
            end
            local caption = string.format("Milk %d / %d", stock, state.Definition.MilkTank.Capacity)
            if busy and recipe then
                local seconds = math.max(0, math.ceil((object:GetAttribute("ProductionDuration") or 0) - elapsed))
                caption ..= string.format("\n%s %d:%02d", phase == "Loading" and "Loading" or definitions[next(recipe.Outputs)].DisplayName,
                    math.floor(seconds / 60), seconds % 60)
            elseif total > 0 then caption ..= "\nReady to collect" end
            if state.Text.Text ~= caption then state.Text.Text = caption end
        end
    end
end)
