local function generateList()
    Config.CurrentVehicles = {}
    local count = Config.VehicleCount
    repeat 
        local veh = Config.Vehicles[math.random(1, #Config.Vehicles)]
        if not vehHash[veh] then
            Config.CurrentVehicles[veh] = veh
            count = count - 1
        end
        Wait(0)
    until count <= 0
    TriggerClientEvent('qb-scapyard:client:setNewVehicles', -1, Config.CurrentVehicles)
end

CreateThread(function()
    while true do
        Wait(1000)
        generateList()
        Wait((1000 * 60) * 60)
    end
end)

local function checkDistance(src, location, dist)
    local pCoords, lCoords = GetEntityCoords(GetPlayerPed(src)), vector3(location.x, location.y, location.z)
    local distance = #(pCoords - lCoords)
    if distance <= dist then
        return true
    else
        return false
    end
end

RegisterNetEvent('qb-scrapyard:server:LoadVehicleList', function()
    local src = source
    TriggerClientEvent('qb-scapyard:client:setNewVehicles', src, Config.CurrentVehicles)
end)


QBCore.Functions.CreateCallback('qb-scrapyard:server:canScrap', function(source, cb, location, plate)
    local src = source
    if not checkDistance(src, Config.Locations[location].deliver.coords, 10.0) then
        cb(false)
        return
    end
    local result = MySQL.scalar.await('SELECT plate FROM player_vehicles WHERE plate = ?', { plate })
    if result and result[1] then
        cb(false)
    else
        cb(true)
    end
    return
end)


RegisterNetEvent('qb-scrapyard:server:ScrapVehicle', function(loc, listKey)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not checkDistance(src, Config.Locations[loc].deliver.coords, 10.0) then
        return
    end
    if Config.CurrentVehicles[listKey] ~= nil then
        local rewards = ItemsList[math.random(1, #ItemsList)]
        local rewardAmount = math.random(rewards.min, rewards.max)
        Player.Functions.AddItem(rewards.item, rewardAmount)
        TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[rewards.item], "add", rewardAmount)
    end
end)

