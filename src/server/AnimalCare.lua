local AnimalCare = {}

local function validTime(value)
    return typeof(value) == "number" and value >= 0 and value <= 9007199254740991
end

function AnimalCare.workDuration(config)
    return config.Milking and config.Milking.ProductionDuration or config.EggDuration
end

local function canProduce(state, config, animal)
    if config.Milking then return animal.MilkReady ~= true end
    return state.Eggs < config.EggCapacity
end

function AnimalCare.load(animals, eggs, feed, config)
    if typeof(animals) ~= "table" or #animals > config.Capacity or
        typeof(eggs) ~= "number" or eggs % 1 ~= 0 or eggs < 0 or eggs > config.EggCapacity or
        typeof(feed) ~= "number" or feed % 1 ~= 0 or feed < 0 or feed > config.FeedCapacity then
        return nil, "Invalid saved coop."
    end
    local state = {Animals = {}, Eggs = eggs, FeedStock = feed}
    for index, animal in pairs(animals) do
        if typeof(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #animals or
            typeof(animal) ~= "table" or animal.ItemName ~= config.ItemName then
            return nil, "Invalid saved animal."
        end
        local work = animal.WorkRemaining
        local food = animal.FoodRemaining
        if work == nil then
            work = animal.EggRemaining or AnimalCare.workDuration(config)
            food = animal.EggRemaining ~= nil and config.FedDuration or 0
        end
        if not validTime(work) or not validTime(food) then return nil, "Invalid saved animal timer." end
        if config.Milking and animal.MilkReady == nil and work == 0 then
            work = AnimalCare.workDuration(config)
        end
        if animal.MilkReady ~= nil and typeof(animal.MilkReady) ~= "boolean" then
            return nil, "Invalid saved milk state."
        end
        state.Animals[index] = {ItemName = config.ItemName,
            WorkRemaining = math.min(work, AnimalCare.workDuration(config)), FoodRemaining = math.min(food, config.FedDuration)}
        if config.Milking then
            state.Animals[index].MilkReady = animal.MilkReady == true
            if animal.MilkReady then state.Animals[index].WorkRemaining = 0 end
        end
    end
    return state
end

function AnimalCare.advance(state, config, elapsed)
    elapsed = math.max(0, elapsed)
    for _ = 1, config.FeedCapacity + config.EggCapacity + #state.Animals * 3 + 4 do
        local changed = false
        for _, animal in ipairs(state.Animals) do
            if animal.FoodRemaining <= 0 and state.FeedStock > 0 then
                state.FeedStock -= 1
                animal.FoodRemaining = config.FedDuration
                changed = true
            end
            if animal.WorkRemaining <= 0 and canProduce(state, config, animal) then
                if config.Milking then
                    animal.MilkReady = true
                else
                    state.Eggs += 1
                    animal.WorkRemaining = config.EggDuration
                end
                changed = true
            end
        end
        if elapsed <= 0 then break end
        local step = elapsed
        local eating = false
        for _, animal in ipairs(state.Animals) do
            if animal.FoodRemaining > 0 then
                eating = true
                step = math.min(step, animal.FoodRemaining)
                if canProduce(state, config, animal) then step = math.min(step, animal.WorkRemaining) end
            end
        end
        if not eating then break end
        for _, animal in ipairs(state.Animals) do
            if animal.FoodRemaining > 0 then
                if canProduce(state, config, animal) then animal.WorkRemaining = math.max(0, animal.WorkRemaining - step) end
                animal.FoodRemaining = math.max(0, animal.FoodRemaining - step)
            end
        end
        elapsed -= step
        if step == 0 and not changed then break end
    end
end

return AnimalCare
