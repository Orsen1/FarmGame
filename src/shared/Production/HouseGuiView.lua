local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local config = require(ReplicatedStorage.Configs.StarterHouseConfig)
local definitions = require(ReplicatedStorage.Configs.ItemDefinitions)
local HouseView = {}
HouseView.__index = HouseView
local ink, panel, card = Color3.fromRGB(89, 55, 26), Color3.fromRGB(255, 220, 150), Color3.fromRGB(255, 239, 199)
local border, green = Color3.fromRGB(169, 111, 50), Color3.fromRGB(116, 154, 65)

local function make(class, parent, properties)
    local object = Instance.new(class)
    for key, value in pairs(properties) do object[key] = value end
    object.Parent = parent
    return object
end

local function text(parent, name, value, size)
    return make("TextLabel", parent, {Name = name, Text = value, TextSize = size or 18,
        Font = Enum.Font.FredokaOne, TextColor3 = ink, BackgroundTransparency = 1,
        TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left})
end

local function decorate(object)
    make("UICorner", object, {CornerRadius = UDim.new(0, 12)})
    make("UIStroke", object, {Name = "Outline", Color = border, Thickness = 2,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
end

local function button(parent, name, value)
    local object = make("TextButton", parent, {Name = name, Text = value, TextSize = 18,
        Font = Enum.Font.FredokaOne, TextColor3 = ink, TextWrapped = true,
        BackgroundColor3 = card, BorderSizePixel = 0, AutoButtonColor = true})
    decorate(object)
    return object
end

function HouseView.new(view, send)
    local self = setmetatable({View = view, Send = send, Buttons = {}, Rows = {}}, HouseView)
    self.Nav = make("CanvasGroup", view.Root, {Name = "HouseNavigation", Visible = false,
        BackgroundColor3 = panel, BorderSizePixel = 0})
    decorate(self.Nav)
    self.Home = button(self.Nav, "Overview", "Farmhouse")
    self.Home.BackgroundTransparency = 1
    self.Home.Outline.Enabled = false
    self.Home.Activated:Connect(function() send("HouseTarget", "Overview") end)
    self.Level = text(self.Nav, "Level", "Abandoned", 16)
    for _, entry in ipairs(config.Objects) do
        local b = button(self.Nav, entry.Id, entry.DisplayName)
        b.Activated:Connect(function() view:PressFeedback(b);send("HouseTarget", entry.Id) end)
        self.Buttons[entry.Id] = b
    end
    self.Upgrade = button(self.Nav, "Upgrade", "Restore home")
    self.Upgrade.Activated:Connect(function() view:PressFeedback(self.Upgrade);send("HouseTarget", "Upgrade") end)
    self.Info = make("Frame", view.Body, {Name = "HouseInfo", Visible = false, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1})
    self.Heading = text(self.Info, "Heading", "", 23)
    self.Heading.Size = UDim2.new(1, 0, 0, 32)
    self.Description = text(self.Info, "Description", "", 17)
    self.Description.Position, self.Description.Size = UDim2.fromOffset(0, 36), UDim2.new(1, 0, 0, 76)
    self.Materials = make("ScrollingFrame", self.Info, {Name = "Materials", Position = UDim2.fromOffset(0, 38),
        Size = UDim2.new(1, 0, 1, -120), BackgroundTransparency = 1, BorderSizePixel = 0,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Active = true,
        ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4, ScrollBarImageColor3 = border})
    make("UIListLayout", self.Materials, {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder})
    self.Message = text(self.Info, "Message", "", 16)
    self.Message.Position, self.Message.Size = UDim2.new(0, 0, 1, -78), UDim2.new(1, 0, 0, 27)
    self.Deposit = button(self.Info, "AddMaterials", "Add materials")
    self.Deposit.Position, self.Deposit.Size = UDim2.new(0, 0, 1, -48), UDim2.new(1, 0, 0, 48)
    self.Deposit.Activated:Connect(function() view:PressFeedback(self.Deposit);send("HouseBuild") end)
    self.Collect = button(view.Root, "HouseCollect", "Collect")
    self.Collect.Visible = false
    self.Collect.Activated:Connect(function() view:PressFeedback(self.Collect);send("HouseCollect") end)
    return self
end

function HouseView:Show(house)
    self.TransitionId = (self.TransitionId or 0) + 1
    self.House, self.PreviousLevel = house, house:GetAttribute("HouseLevel") or -1
    self.Yaw, self.Pitch = math.rad(35), math.rad(22)
    self.Nav.Visible = true
    self.Nav.GroupTransparency = 1
    TweenService:Create(self.Nav, TweenInfo.new(.25), {GroupTransparency = 0}):Play()
end

function HouseView:Hide(immediate)
    self.TransitionId = (self.TransitionId or 0) + 1
    local id = self.TransitionId
    self.Info.Visible, self.Collect.Visible = false, false
    if immediate then self.Nav.Visible = false
    else
        TweenService:Create(self.Nav, TweenInfo.new(.15), {GroupTransparency = 1}):Play()
        task.delay(.15, function() if self.TransitionId == id then self.Nav.Visible = false end end)
    end
    self.View.HouseContentHeight = nil
    self.House = nil
end

function HouseView:Layout()
    local size = self.View.Root.AbsoluteSize
    local portrait = self.View.Portrait
    local compactMaterials = portrait or self.View.Compact
    local buttons = {}
    for _, entry in ipairs(config.Objects) do table.insert(buttons, self.Buttons[entry.Id]) end
    table.insert(buttons, self.Upgrade)
    if portrait then
        self.Nav.Position, self.Nav.Size = UDim2.fromOffset(12, 68), UDim2.new(1, -24, 0, 110)
        self.Home.Position, self.Home.Size = UDim2.fromOffset(10, 4), UDim2.new(.6, -10, 0, 34)
        self.Level.Position, self.Level.Size = UDim2.new(.6, 0, 0, 4), UDim2.new(.4, -10, 0, 34)
        for index, b in ipairs(buttons) do
            b.Position, b.Size = UDim2.new((index - 1) / #buttons, 8, 0, 44), UDim2.new(1 / #buttons, -16, 0, 56)
            b.TextSize = 17
        end
    else
        local width = size.X < 950 and 158 or 205
        local top = size.Y < 360 and 60 or 72
        local height = math.min(268, size.Y - top - 12)
        local buttonHeight = math.min(56, (height - 94) / #buttons)
        self.Nav.Position, self.Nav.Size = UDim2.fromOffset(12, top), UDim2.fromOffset(width, height)
        self.Home.Position, self.Home.Size = UDim2.fromOffset(10, 4), UDim2.new(1, -20, 0, 34)
        self.Level.Position, self.Level.Size = UDim2.fromOffset(12, 36), UDim2.new(1, -24, 0, 24)
        for index, b in ipairs(buttons) do
            b.Position, b.Size = UDim2.fromOffset(10, 70 + (index - 1) * (buttonHeight + 8)), UDim2.new(1, -20, 0, buttonHeight)
            b.TextSize = 18
        end
    end
    self.Collect.Size = UDim2.fromOffset(148, 42)
    self.Collect.Position = portrait and UDim2.new(1, -160, 0, 211) or UDim2.new(1, -164, 0, 12)
    local layout = self.Materials:FindFirstChildOfClass("UIListLayout")
    layout.FillDirection = compactMaterials and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
    self.Materials.AutomaticCanvasSize = compactMaterials and Enum.AutomaticSize.X or Enum.AutomaticSize.Y
    self.Materials.ScrollingDirection = compactMaterials and Enum.ScrollingDirection.X or Enum.ScrollingDirection.Y
    for _, row in pairs(self.Rows) do
        row.Size = compactMaterials and UDim2.fromOffset(math.max(72, (self.Materials.AbsoluteSize.X - 12) / 3), 110) or UDim2.new(1, -8, 0, 56)
        row.Icon.Position = compactMaterials and UDim2.new(.5, -18, 0, 0) or UDim2.fromOffset(0, 2)
        row.ItemName.Position = compactMaterials and UDim2.fromOffset(0, 40) or UDim2.fromOffset(44, 0)
        row.ItemName.Size = compactMaterials and UDim2.new(1, 0, 0, 22) or UDim2.new(1, -112, 0, 28)
        row.ItemName.TextXAlignment = compactMaterials and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
        row.Amount.AnchorPoint = compactMaterials and Vector2.zero or Vector2.new(1, 0)
        row.Amount.Position = compactMaterials and UDim2.fromOffset(0, 62) or UDim2.fromScale(1, 0)
        row.Amount.Size = compactMaterials and UDim2.new(1, 0, 0, 22) or UDim2.fromOffset(68, 28)
        row.Amount.TextXAlignment = compactMaterials and Enum.TextXAlignment.Center or Enum.TextXAlignment.Right
        row.Owned.Position = compactMaterials and UDim2.fromOffset(0, 86) or UDim2.fromOffset(44, 28)
        row.Owned.Size = compactMaterials and UDim2.new(1, 0, 0, 22) or UDim2.new(1, -44, 0, 24)
        row.Owned.TextSize = compactMaterials and 14 or 15
        row.Owned.TextXAlignment = compactMaterials and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
    end
end

function HouseView:Refresh(state)
    if not self.House then return end
    local house, selection = self.House, state.HouseSelection or "Overview"
    local level = house:GetAttribute("HouseLevel") or -1
    if level > self.PreviousLevel then
        local shine = make("Highlight", house, {Adornee = house, FillColor = Color3.fromRGB(255, 209, 102),
            OutlineColor = Color3.fromRGB(255, 235, 174), FillTransparency = .72, OutlineTransparency = .1})
        TweenService:Create(shine, TweenInfo.new(1), {FillTransparency = 1, OutlineTransparency = 1}):Play()
        game:GetService("Debris"):AddItem(shine, 1)
    end
    self.PreviousLevel = level
    self.Level.Text = level < 0 and "Abandoned" or "Level " .. level
    self.Level.TextColor3 = level < 0 and ink or green
    local selected
    for _, entry in ipairs(config.Objects) do
        local b = self.Buttons[entry.Id]
        b.Text = entry.DisplayName .. "\n" .. (level < entry.MinimumLevel and "Locked" or "Ready")
        TweenService:Create(b, TweenInfo.new(.12), {BackgroundColor3 = selection == entry.Id and Color3.fromRGB(232, 190, 112) or card}):Play()
        if selection == entry.Id then selected = entry end
    end
    local upgrade = config.Levels[level + 1]
    local stage = house:GetAttribute("HouseUpgradeStage") or 0
    local step = upgrade and upgrade.Stages[stage + 1]
    self.Upgrade.Text = upgrade and upgrade.DisplayName or "Upgrades\nRestored"
    TweenService:Create(self.Upgrade, TweenInfo.new(.12), {BackgroundColor3 = selection == "Upgrade" and Color3.fromRGB(232, 190, 112) or card}):Play()
    local inspect = selection == "Upgrade" or selected and level < selected.MinimumLevel
    self.View.Panel.Visible = selection ~= "Overview"
    self.Info.Visible = inspect == true
    self.View.HouseContentHeight = inspect and (selection == "Upgrade" and step and ((self.View.Portrait or self.View.Compact) and 230 or 310) or 142) or nil
    self.View:Layout()
    if inspect then
        self.View.List.Visible, self.View.Work.Visible = false, false
        self.View.Panel.Title.Text = selection == "Upgrade" and (upgrade and upgrade.DisplayName or "Farmhouse") or selected.DisplayName
        self.Materials.Visible, self.Deposit.Visible, self.Message.Visible = step ~= nil and selection == "Upgrade", step ~= nil and selection == "Upgrade", step ~= nil and selection == "Upgrade"
        self.Description.Visible = selection ~= "Upgrade" or not step
        if selection ~= "Upgrade" then
            self.Heading.Text = "Out of order"
            self.Description.Text = selected.MinimumLevel == 0 and "Restore the farmhouse to use this workspace." or "Available at home level " .. selected.MinimumLevel .. "."
        elseif not step then
            self.Heading.Text = "Fully restored"
            self.Description.Text = "More home upgrades will be added later."
        else
            self.Heading.Text = "Materials"
            local key = level .. ":" .. stage
            if self.MaterialKey ~= key then
                self.MaterialKey = key
                for _, row in pairs(self.Rows) do row:Destroy() end
                self.Rows = {}
                local names = {} for name in pairs(step.Inputs) do table.insert(names, name) end table.sort(names)
                for order, name in ipairs(names) do
                    local row = self.View.Templates.ItemRow:Clone()
                    row.Name, row.Visible, row.LayoutOrder = name, true, order
                    row.Size = UDim2.new(1, -8, 0, 56)
                    row.Icon.Image, row.ItemName.Text = definitions[name].Icon, definitions[name].DisplayName
                    row.ItemName.Size, row.ItemName.TextSize = UDim2.new(1, -112, 0, 28), 18
                    row.Amount.Size, row.Amount.TextSize = UDim2.fromOffset(68, 28), 18
                    local owned = text(row, "Owned", "", 15)
                    owned.Position, owned.Size = UDim2.fromOffset(44, 28), UDim2.new(1, -44, 0, 24)
                    row.Parent = self.Materials
                    self.Rows[name] = row
                end
            end
            local counts = {}
            for _, slot in ipairs(self.View.Inventory:GetChildren()) do
                counts[slot.ItemName.Value] = (counts[slot.ItemName.Value] or 0) + slot.Amount.Value
            end
            local canAdd = false
            for name, required in pairs(step.Inputs) do
                local deposited, owned = house:GetAttribute("ConstructionDeposited_" .. name) or 0, counts[name] or 0
                self.Rows[name].Amount.Text = deposited .. "/" .. required
                self.Rows[name].Amount.TextColor3 = deposited >= required and green or ink
                self.Rows[name].Owned.Text = "In bag: " .. owned
                if deposited < required and owned > 0 then canAdd = true end
            end
            self.Deposit.Interactable = canAdd
            self.Deposit.BackgroundColor3 = canAdd and Color3.fromRGB(232, 168, 69) or Color3.fromRGB(192, 169, 131)
            self.Message.Text = state.Message ~= "ChooseRecipe" and state.Message or "Add materials in small batches"
        end
    elseif selected then
        self.View.List.EmptyLabel.Text = "Recipes will be added later"
    end
    self.Collect.Visible = selected ~= nil and level >= selected.MinimumLevel
    if self.Collect.Visible then
        local count = 0
        for _, item in state.Station.OutputInventory:GetChildren() do if item:IsA("IntValue") then count += item.Value end end
        self.Collect.Text, self.Collect.Interactable = "Collect (" .. count .. ")", count > 0
        self.Collect.Visible = count > 0
    end
    self:Layout()
end

function HouseView:Drag(delta)
    self.Yaw -= delta.X * config.OrbitSensitivity
    self.Pitch = math.clamp(self.Pitch + delta.Y * config.OrbitSensitivity, math.rad(10), math.rad(55))
end

function HouseView:Frame(frame, fov, distance)
    local size = workspace.CurrentCamera.ViewportSize
    local inset = GuiService:GetGuiInset()
    local halfHeight = distance * math.tan(math.rad(fov / 2))
    if self.View.Portrait then
        local top = self.Nav.AbsolutePosition.Y + self.Nav.AbsoluteSize.Y + inset.Y + 12
        local bottom = self.View.Panel.Visible and self.View.Panel.AbsolutePosition.Y + inset.Y - 12 or size.Y - 12
        local center = math.clamp((top + bottom) / (2 * size.Y), .3, .75)
        return frame + frame.UpVector * (center - .5) * 2 * halfHeight
    end
    local left = self.Nav.AbsolutePosition.X + self.Nav.AbsoluteSize.X + inset.X + 12
    local right = self.View.Panel.Visible and self.View.Panel.AbsolutePosition.X + inset.X - 12 or size.X - 12
    return frame + frame.RightVector * (.5 - (left + right) / (2 * size.X)) * 2 * halfHeight * size.X / size.Y
end

function HouseView:Camera(state)
    if not self.House then return end
    local root = self.House.PlacementRoot
    if state.HouseSelection == "Overview" then
        local point = root:FindFirstChild(self.View.Portrait and "HomeCameraPointPortrait" or "HomeCameraPoint")
        local frame = CFrame.lookAt(point.WorldPosition, root.HomeCameraTarget.WorldPosition)
        return self:Frame(frame, 70, (point.WorldPosition - root.HomeCameraTarget.WorldPosition).Magnitude), 70
    elseif state.HouseSelection == "Upgrade" then
        local size = workspace.CurrentCamera.ViewportSize
        local aspect = size.X / math.max(size.Y, 1)
        local available = self.View.Portrait and .9 or math.max(.3, 1 - (self.Nav.AbsoluteSize.X + self.View.Panel.AbsoluteSize.X + 70) / size.X)
        local distance = math.max(self.View.Portrait and config.ExteriorPortraitDistance or config.ExteriorDistance, 16 / (math.tan(math.rad(25)) * aspect * available))
        if self.View.Portrait then
            local freeHeight = math.max(100, self.View.Panel.AbsolutePosition.Y - self.Nav.AbsolutePosition.Y - self.Nav.AbsoluteSize.Y - 24)
            distance = math.max(distance, 13 * size.Y / (math.tan(math.rad(25)) * freeHeight))
        end
        local target = root.CFrame:PointToWorldSpace(Vector3.new(2.5, 7.5, 1))
        local offset = Vector3.new(math.sin(self.Yaw) * math.cos(self.Pitch), math.sin(self.Pitch), math.cos(self.Yaw) * math.cos(self.Pitch)) * distance
        local frame = CFrame.lookAt(target + root.CFrame:VectorToWorldSpace(offset), target)
        return self:Frame(frame, 50, distance), 50
    end
end

return HouseView
