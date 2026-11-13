local Motion = {}

local function ease(value)
    return 0.5 - math.cos(math.clamp(value, 0, 1) * math.pi) * 0.5
end

function Motion.angle(folder, settings, now)
    if folder:GetAttribute("AnimalWorkType") ~= "HoofCare" or not folder:GetAttribute("MilkerUserId") then return 0 end
    local elapsed = now - (folder:GetAttribute("MilkingStartedAt") or now)
    local duration = folder:GetAttribute("MilkingDuration") or settings.Duration
    local amount
    if elapsed < settings.TurnDuration then
        amount = ease(elapsed / settings.TurnDuration)
    elseif elapsed < settings.ReturnAt then
        amount = 1
    else
        amount = 1 - ease((elapsed - settings.ReturnAt) / (duration - settings.ReturnAt))
    end
    return settings.TiltAngle * amount
end

function Motion.frame(object, folder, settings, now)
    local pivot = CFrame.new(settings.Pivot)
    return object:GetPivot() * pivot * CFrame.Angles(0, 0, Motion.angle(folder, settings, now)) * pivot:Inverse()
end

return Motion
