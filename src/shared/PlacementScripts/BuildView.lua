local View = {}
View.Ink = Color3.fromRGB(89, 59, 38)
View.Paper = Color3.fromRGB(255, 237, 194)
View.Green = Color3.fromRGB(81, 133, 70)
View.Gold = Color3.fromRGB(231, 190, 124)
View.Red = Color3.fromRGB(163, 68, 47)

function View.make(class, parent, properties)
    local object = Instance.new(class)
    for key, value in pairs(properties) do object[key] = value end
    object.Parent = parent
    return object
end

function View.trim(object, radius, color)
    View.make("UICorner", object, {CornerRadius = UDim.new(0, radius)})
    return View.make("UIStroke", object, {ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Color = color or View.Ink, Thickness = 1.5})
end

function View.text(class, parent, name, text, size, background)
    local object = View.make(class, parent, {Name = name, Text = text, TextSize = size, Font = Enum.Font.FredokaOne,
        TextColor3 = View.Ink, BorderSizePixel = 0, BackgroundTransparency = background and 0 or 1,
        BackgroundColor3 = background or View.Paper})
    if background then View.trim(object, 8) end
    return object
end

function View.grid(name, parent, color, opacity)
    local tile = View.make("Part", parent, {Name = name, Anchored = true, CanCollide = false, CanTouch = false,
        CanQuery = false, CastShadow = false, Transparency = 1, Size = Vector3.new(1, 1, .01)})
    local surface = View.make("SurfaceGui", tile, {Face = Enum.NormalId.Front, LightInfluence = 0,
        SizingMode = Enum.SurfaceGuiSizingMode.FixedSize, AlwaysOnTop = opacity > .1})
    local background = View.make("Frame", surface, {Size = UDim2.fromScale(1, 1), BorderSizePixel = 0,
        BackgroundColor3 = color, BackgroundTransparency = 1 - opacity})
    local border = opacity > .1 and View.make("SelectionBox", tile, {Adornee = tile, LineThickness = .042,
        SurfaceTransparency = 1, Color3 = color})
    local width, depth
    return function(frame, extent, step, tint)
        local x, z = math.round(extent.X / step), math.round(extent.Z / step)
        tile.Size = Vector3.new(extent.X, extent.Z, .01)
        tile.CFrame = frame * CFrame.Angles(math.pi / 2, 0, 0)
        if width ~= x or depth ~= z then
            background:ClearAllChildren()
            surface.CanvasSize = Vector2.new(x * 24, z * 24)
            for axis = 1, 2 do
                local count = axis == 1 and x or z
                for i = 0, count do
                    local p = math.min(i * 24, count * 24 - 1)
                    View.make("Frame", background, {BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1),
                        BackgroundTransparency = opacity > .1 and .35 or .73,
                        Position = UDim2.fromOffset(axis == 1 and p or 0, axis == 2 and p or 0),
                        Size = axis == 1 and UDim2.new(0, 1, 1, 0) or UDim2.new(1, 0, 0, 1)})
                end
            end
            width, depth = x, z
        end
        background.BackgroundColor3 = tint or color
        if border then border.Color3 = tint or color end
    end, tile
end

return View
