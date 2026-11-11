local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Configs.AnimalConfig)
local Motion = require(ReplicatedStorage.Animals.AnimalMotion)
local templates = ReplicatedStorage:WaitForChild("AnimalModels")
local plots = workspace:WaitForChild("Plots")
local visuals = {}
local container = Instance.new("Folder")
container.Name = "AnimalVisuals"
container.Parent = workspace

local function bind(folder)
    if visuals[folder] or not folder:IsA("Folder") or not folder.Parent or folder.Parent.Name ~= "Animals" then return end
    local itemName = folder:GetAttribute("ItemName")
    local template = templates:FindFirstChild(itemName or "")
    local coop = folder.Parent.Parent
    if not template or not coop:IsA("Model") then return end
    local model = template:Clone()
    local root = model:GetPivot()
    local body, head = model.Body, model.Body.Head
    local state = {Model = model, Coop = coop, Motion = Motion.read(folder), Body = body, Head = head,
        Left = model.LeftLeg, Right = model.RightLeg, BodyOffset = root:ToObjectSpace(body:GetPivot()),
        HeadOffset = body:GetPivot():ToObjectSpace(head:GetPivot()),
        LeftOffset = root:ToObjectSpace(model.LeftLeg:GetPivot()), RightOffset = root:ToObjectSpace(model.RightLeg:GetPivot()),
        Settings = Config.Animals[itemName], Sit = 0, Stride = 0}
    state.Connection = folder:GetAttributeChangedSignal("Revision"):Connect(function() state.Motion = Motion.read(folder) end)
    visuals[folder] = state
    model.Parent = container
end

plots.DescendantAdded:Connect(function(object)
    if object:IsA("Folder") then task.defer(bind, object) end
end)
for _, object in ipairs(plots:GetDescendants()) do if object:IsA("Folder") then bind(object) end end

RunService.RenderStepped:Connect(function(dt)
    local camera = workspace.CurrentCamera
    if not camera then return end
    local now = workspace:GetServerTimeNow()
    for folder, state in pairs(visuals) do
        if not folder:IsDescendantOf(plots) or not state.Coop.Parent then
            state.Connection:Disconnect();state.Model:Destroy();visuals[folder] = nil
        else
            local motion = state.Motion
            local position = state.Coop:GetPivot():PointToWorldSpace(Motion.position(motion, now))
            local visible = motion.Activity ~= "Waiting" and (position - camera.CFrame.Position).Magnitude <= Config.VisualDistance
            if not visible then
                state.Model.Parent = nil
            else
                local age = math.max(0, now - motion.StartedAt)
                local alpha = 1 - math.exp(-dt * 12)
                state.Sit += ((motion.Activity == "Sit" and 1 or 0) - state.Sit) * alpha
                state.Stride += ((motion.Activity == "Walk" and 1 or 0) - state.Stride) * alpha
                local step = math.sin(age * state.Settings.StepRate + motion.Phase) * state.Stride
                local frame = state.Coop:GetPivot() * CFrame.new(Motion.position(motion, now)) * CFrame.Angles(0, Motion.yaw(motion, now), 0)
                state.Model:PivotTo(frame)
                local body = frame * state.BodyOffset * CFrame.new(0, math.abs(step) * 0.035 - state.Sit * 0.32, 0) * CFrame.Angles(0, 0, step * 0.045)
                state.Body:PivotTo(body)
                local look = math.sin(age * 1.6 + motion.Phase) * (motion.Activity == "Look" and 0.55 or 0.12)
                state.Head:PivotTo(body * state.HeadOffset * CFrame.Angles(step * 0.06, look, 0))
                state.Left:PivotTo(frame * state.LeftOffset * CFrame.Angles(step * 0.55 - state.Sit * 1.2, 0, 0))
                state.Right:PivotTo(frame * state.RightOffset * CFrame.Angles(-step * 0.55 - state.Sit * 1.2, 0, 0))
                state.Model.Parent = container
            end
        end
    end
end)
