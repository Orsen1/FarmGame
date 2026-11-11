local Motion = {}

function Motion.read(folder)
    return {
        From = folder:GetAttribute("From") or Vector3.zero,
        To = folder:GetAttribute("To") or Vector3.zero,
        StartedAt = folder:GetAttribute("StartedAt") or 0,
        Duration = folder:GetAttribute("Duration") or 0,
        YawFrom = folder:GetAttribute("YawFrom") or 0,
        YawTo = folder:GetAttribute("YawTo") or 0,
        Activity = folder:GetAttribute("Activity") or "Waiting",
        Phase = folder:GetAttribute("Phase") or 0,
    }
end

function Motion.position(state, now)
    if state.Activity ~= "Walk" or state.Duration <= 0 then return state.From end
    return state.From:Lerp(state.To, math.clamp((now - state.StartedAt) / state.Duration, 0, 1))
end

function Motion.yaw(state, now)
    local fraction = math.clamp((now - state.StartedAt) / 0.3, 0, 1)
    local difference = (state.YawTo - state.YawFrom + math.pi) % (math.pi * 2) - math.pi
    return state.YawFrom + difference * fraction
end

return Motion
