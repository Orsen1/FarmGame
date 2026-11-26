local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local player = Players.LocalPlayer
local Camera = {}

function Camera.open(plot, panelWidth, move)
    local camera = workspace.CurrentCamera
    local ground = plot.Ground
    local old = {Type = camera.CameraType, Subject = camera.CameraSubject, Frame = camera.CFrame,
        Focus = camera.Focus, Mouse = Input.MouseBehavior}
    local controls = require(player.PlayerScripts:WaitForChild("PlayerModule")):GetControls()
    local enabled = controls.controlsEnabled
    controls:Disable()
    camera.CameraType = Enum.CameraType.Scriptable
    Input.MouseBehavior = Enum.MouseBehavior.Default

    local low, high, openLow, openHigh
    local function include(floor, unlocked)
        local p = ground.CFrame:PointToObjectSpace(floor.Position)
        local center, half = Vector2.new(p.X,p.Z), Vector2.new(floor.Size.X,floor.Size.Z)/2
        low = low and low:Min(center-half) or center-half
        high = high and high:Max(center+half) or center+half
        if unlocked then
            openLow = openLow and openLow:Min(center-half) or center-half
            openHigh = openHigh and openHigh:Max(center+half) or center+half
        end
    end
    include(ground, true)
    for _, section in ipairs(plot.Sections:GetChildren()) do
        local floor = section:FindFirstChild("Ground")
        if floor then include(floor, section:GetAttribute("Unlocked")) end
    end
    local center = (openLow + openHigh)/2
    local function fit(span)
        local size = camera.ViewportSize
        local aspect = math.max(.25, (size.X-panelWidth()-24) / math.max(1,size.Y))
        return math.max(span.Y, span.X/aspect) * .60 / math.tan(math.rad(camera.FieldOfView / 2))
    end
    local initialFit = fit(openHigh-openLow)
    local height = initialFit
    local function zoom(scale)
        height = math.clamp(height*scale, 22, math.max(180, fit(high-low)*1.25))
    end
    local function pan(delta)
        local units = 2 * height * math.tan(math.rad(camera.FieldOfView/2)) / math.max(1,camera.ViewportSize.Y)
        center -= Vector2.new(delta.X, delta.Y*1.04) * units
        center = center:Max(low):Min(high)
    end
    local held = {}
    local dragPoint
    local buildingDrag
    local connections = {}
    local function on(signal, fn) table.insert(connections, signal:Connect(fn)) end
    local function touchPoint(input)
        return Vector2.new(input.Position.X, input.Position.Y) + GuiService:GetGuiInset()
    end
    local function endBuildingDrag(point)
        if not buildingDrag then return end
        buildingDrag = nil
        if point then move.Drop(point) else move.Cancel() end
    end
    local function beginBuildingDrag(input, point)
        if not buildingDrag and move.Start(point) then
            buildingDrag = {Input = input, Point = point}
        end
    end
    local function touchPair()
        local sum, first, gap, count = Vector2.zero, nil, nil, 0
        for _, point in pairs(held) do
            count += 1
            sum += point
            if first then gap = (point-first).Magnitude else first = point end
        end
        return count > 0 and sum/count or sum, gap
    end
    on(Input.InputBegan,function(input, processed)
        local kind = input.UserInputType
        if processed then return end
        if kind == Enum.UserInputType.MouseButton2 then
            endBuildingDrag()
            dragPoint = Input:GetMouseLocation()
        elseif kind == Enum.UserInputType.MouseButton1 and not dragPoint and not next(held) then
            beginBuildingDrag(input, Input:GetMouseLocation())
        elseif kind == Enum.UserInputType.Touch then
            local point = touchPoint(input)
            if buildingDrag then
                endBuildingDrag()
            elseif not next(held) and not dragPoint then
                beginBuildingDrag(input, point)
            end
            held[input] = point
        end
    end)
    on(Input.InputEnded,function(input)
        if buildingDrag and input == buildingDrag.Input then
            local point = input.UserInputState ~= Enum.UserInputState.Cancel
                and (input.UserInputType == Enum.UserInputType.Touch and touchPoint(input) or Input:GetMouseLocation())
            endBuildingDrag(point)
        end
        held[input] = nil
        if input.UserInputType == Enum.UserInputType.MouseButton2 then dragPoint = nil end
    end)
    on(Input.WindowFocusReleased,function()
        endBuildingDrag()
        dragPoint = nil
        table.clear(held)
    end)
    on(Input.InputChanged,function(input,processed)
        if input.UserInputType == Enum.UserInputType.MouseWheel and not processed then zoom(.83^input.Position.Z)
        elseif dragPoint and input.UserInputType == Enum.UserInputType.MouseMovement then
            local point = Input:GetMouseLocation()
            pan(point - dragPoint)
            dragPoint = point
        elseif buildingDrag and buildingDrag.Input.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseMovement then
            buildingDrag.Point = Input:GetMouseLocation()
        elseif held[input] then
            local before, oldGap = touchPair()
            local point = touchPoint(input)
            held[input] = point
            if buildingDrag and buildingDrag.Input == input then
                buildingDrag.Point = point
                return
            end
            local after, gap = touchPair()
            pan(after-before)
            if gap and oldGap and gap > 4 and oldGap > 4 then zoom(oldGap/gap) end
        end
    end)
    local elapsed = 0
    on(RunService.RenderStepped,function(dt)
        local function axis(a,b)
            return (Input:IsKeyDown(a) and 1 or 0) - (Input:IsKeyDown(b) and 1 or 0)
        end
        local direction = Vector2.new(axis(Enum.KeyCode.D,Enum.KeyCode.A),axis(Enum.KeyCode.S,Enum.KeyCode.W))
        if direction.Magnitude > 0 and not Input:GetFocusedTextBox() then
            center = (center + direction.Unit*height*dt*.7):Max(low):Min(high)
        end
        local newFit = fit(openHigh-openLow)
        if newFit ~= initialFit then
            zoom(newFit / initialFit)
            initialFit = newFit
        end
        local viewport = camera.ViewportSize
        local offset = height * math.tan(math.rad(camera.FieldOfView/2)) * panelWidth()/math.max(1,viewport.Y)
        local focus = ground.CFrame:PointToWorldSpace(Vector3.new(center.X+offset,ground.Size.Y/2,center.Y))
        local eye = focus + Vector3.yAxis*height + ground.CFrame.ZVector*height*.25
        local goal = CFrame.lookAt(eye, focus)
        elapsed += dt
        local alpha = 1 - (1 - math.min(1,elapsed/.32))^3
        camera.CFrame = old.Frame:Lerp(goal,alpha)
        camera.Focus = CFrame.new(focus)
        if buildingDrag and not move.Aim(buildingDrag.Point) then buildingDrag = nil end
    end)
    return {Zoom = zoom, Close = function()
        endBuildingDrag()
        for _, connection in ipairs(connections) do connection:Disconnect() end
        if camera.Parent then
            if old.Subject and old.Subject.Parent then camera.CameraSubject = old.Subject end
            camera.CFrame, camera.Focus = old.Frame, old.Focus
            camera.CameraType = old.Type
        end
        if enabled ~= false then controls:Enable() end
        Input.MouseBehavior = old.Mouse
    end}
end

return Camera
