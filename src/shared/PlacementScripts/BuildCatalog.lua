local HttpService = game:GetService("HttpService")
local definitions = require(script.Parent.Parent.Configs.ItemDefinitions)
local Catalog = {}
local areas = {"Inventory", "StorageInventory"}

local function available(player, area)
    if area == "Inventory" or area == "StorageInventory" and player:GetAttribute("WarehouseReady") then
        return player:FindFirstChild(area)
    end
end

function Catalog.StoredBuilding(item, encoded)
    if typeof(encoded) ~= "string" then return end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, encoded)
    if ok and typeof(data) == "table" and data.StoredBuildingVersion == 1 and data.ItemName == item and
        typeof(data.BuildingId) == "string" and #data.BuildingId > 0 then return data end
end

function Catalog.Entries(player)
    local entries, stacks = {}, {}
    for _, area in ipairs(areas) do
        local folder = available(player, area)
        local count = area == "Inventory" and 6 or definitions.Warehouse.StorageSlots
        for index = 1, folder and count or 0 do
            local slot = folder:FindFirstChild("Slot" .. index)
            local name = slot and slot:FindFirstChild("ItemName")
            local amount = slot and slot:FindFirstChild("Amount")
            local item = name and name.Value
            local definition = definitions[item]
            if not definition or not definition.Placeable or not amount or amount.Value <= 0 then continue end
            local data = slot:GetAttribute("ObjectData")
            local entry = not data and stacks[item]
            if entry then
                entry.Amount += amount.Value
            else
                local stored = area == "StorageInventory" and Catalog.StoredBuilding(item, data)
                entry = {Item = item, Amount = amount.Value, Area = area, Index = index, Data = data,
                    Kind = stored and "StoredBuilding" or data and "Relocation" or "Stack",
                    Key = stored and stored.BuildingId or data and area .. ":" .. index or item,
                    BedLevel = stored and stored.BedLevel or nil, ConstructionStage = stored and stored.ConstructionStage or nil}
                table.insert(entries, entry)
                if not data then stacks[item] = entry end
            end
        end
    end
    table.sort(entries, function(a, b)
        if a.Item == b.Item then return a.Key < b.Key end
        return definitions[a.Item].DisplayName < definitions[b.Item].DisplayName
    end)
    return entries
end

function Catalog.Resolve(player, item, area, index, expected)
    if area == "Catalog" then
        for _, source in ipairs(areas) do
            local folder = available(player, source)
            local count = source == "Inventory" and 6 or definitions.Warehouse.StorageSlots
            for i = 1, folder and count or 0 do
                local slot = folder:FindFirstChild("Slot" .. i)
                if slot and slot.ItemName.Value == item and slot.Amount.Value > 0 and not slot:GetAttribute("ObjectData") then
                    return slot
                end
            end
        end
        return
    end
    local folder = available(player, area)
    if not folder or typeof(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > definitions.Warehouse.StorageSlots then return end
    local slot = folder:FindFirstChild("Slot" .. index)
    if slot and slot.ItemName.Value == item and slot.Amount.Value > 0 and slot:GetAttribute("ObjectData") == expected then
        return slot
    end
end

return Catalog
