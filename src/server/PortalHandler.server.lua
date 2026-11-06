local Players = game:GetService("Players")
local Travel = require(script.Parent:WaitForChild("WorldTravelService"))
local portals = workspace:WaitForChild("TravelPortals")
local bound = setmetatable({}, {__mode = "k"})

local function bind(part)
    if not part:IsA("BasePart") or bound[part] then
        return
    end

    bound[part] = true

    part.Touched:Connect(function(hit)
        local destination = part:GetAttribute("Destination")

        if destination ~= "Farm" and destination ~= "Resources" then
            return
        end

        local character = hit:FindFirstAncestorOfClass("Model")
        local player = character and Players:GetPlayerFromCharacter(character)
        local root = character and character:FindFirstChild("HumanoidRootPart")

        if not player or not root
            or (root.Position - part.Position).Magnitude > part.Size.Magnitude / 2 + 6 then
            return
        end

        local success, reason = Travel.Travel(player, destination)

        if not success and reason ~= "Busy" then
            warn("[PORTAL]", reason)
        end
    end)
end

for _, object in ipairs(portals:GetDescendants()) do
    bind(object)
end

portals.DescendantAdded:Connect(bind)