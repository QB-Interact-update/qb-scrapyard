local isBusy = false
local blips, peds = {}, {}

local function loadAnimDict(dict)
    while (not HasAnimDictLoaded(dict)) do
        RequestAnimDict(dict)
        Wait(5)
    end
end

local function IsVehicleValid(vehicleModel)
    local retval = false
    if Config.CurrentVehicles ~= nil and next(Config.CurrentVehicles) ~= nil then
        for k in pairs(Config.CurrentVehicles) do
            if Config.CurrentVehicles[k] ~= nil and GetHashKey(Config.CurrentVehicles[k]) == vehicleModel then
                retval = true
            end
        end
    end
    return retval
end

local function inVehicleCheck()
    if IsPedInAnyVehicle(PlayerPedId(), false) then
        return IsVehicleValid(GetEntityModel(GetVehiclePedIsIn(PlayerPedId(), false)))
    end
    return false
end

local function GetVehicleKey(vehicleModel)
    local retval = 0
    if Config.CurrentVehicles ~= nil and next(Config.CurrentVehicles) ~= nil then
        for k in pairs(Config.CurrentVehicles) do
            if GetHashKey(Config.CurrentVehicles[k]) == vehicleModel then
                retval = k
            end
        end
    end
    return retval
end

local function ScrapVehicleAnim(time)
    time = (time / 1000)
    loadAnimDict("mp_car_bomb")
    TaskPlayAnim(PlayerPedId(), "mp_car_bomb", "car_bomb_mechanic" ,3.0, 3.0, -1, 16, 0, false, false, false)
    local openingDoor = true
    CreateThread(function()
        while openingDoor do
            TaskPlayAnim(PlayerPedId(), "mp_car_bomb", "car_bomb_mechanic", 3.0, 3.0, -1, 16, 0, 0, 0, 0)
            Wait(2000)
            time = time - 2
            if time <= 0 or not isBusy then
                openingDoor = false
                StopAnimTask(PlayerPedId(), "mp_car_bomb", "car_bomb_mechanic", 1.0)
            end
        end
    end)
end

local function CreateListEmail()
    if Config.CurrentVehicles ~= nil and next(Config.CurrentVehicles) ~= nil then
        local vehicleList = ""
        for k, v in pairs(Config.CurrentVehicles) do
            if Config.CurrentVehicles[k] ~= nil then
                local vehicleInfo = QBCore.Shared.Vehicles[v]
                if vehicleInfo ~= nil then
                    vehicleList = vehicleList  .. vehicleInfo["brand"] .. " " .. vehicleInfo["name"] .. "<br />"
                end
            end
        end
        TriggerServerEvent('qb-phone:server:sendNewMail', {
            sender = Lang:t('email.sender'),
            subject = Lang:t('email.subject'),
            message = Lang:t('email.message').. vehicleList,
            button = {}
        })
    else
        QBCore.Functions.Notify(Lang:t('error.demolish_vehicle'), "error")
    end
end

local function ScrapVehicle(location)
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), true)
    if vehicle ~= 0 and vehicle ~= nil then
        if not isBusy then
            if GetPedInVehicleSeat(vehicle, -1) == PlayerPedId() then
                if IsVehicleValid(GetEntityModel(vehicle)) then
                    local vehiclePlate = QBCore.Functions.GetPlate(vehicle)
                    local canChop = QBCore.Functions.TriggerCallback('qb-scrapyard:server:canScrap', location, vehiclePlate)
                    if not canChop then
                        QBCore.Functions.Notify(Lang:t('error.cannot_scrap'), "error")
                        return
                    end
                    isBusy = true
                    local scrapTime = math.random(28000, 37000)
                    ScrapVehicleAnim(scrapTime)
                    QBCore.Functions.Progressbar("scrap_vehicle", Lang:t('text.demolish_vehicle'), scrapTime, false, true, {
                        disableMovement = true,
                        disableCarMovement = true,
                        disableMouse = false,
                        disableCombat = true,
                    }, {}, {}, {}, function() -- Done
                        TriggerServerEvent("qb-scrapyard:server:ScrapVehicle", location, GetVehicleKey(GetEntityModel(vehicle)))
                        SetEntityAsMissionEntity(vehicle, true, true)
                        DeleteVehicle(vehicle)
                        isBusy = false
                    end, function() -- Cancel
                        isBusy = false
                        QBCore.Functions.Notify(Lang:t('error.canceled'), "error")
                    end)
                else
                    QBCore.Functions.Notify(Lang:t('error.cannot_scrap'), "error")
                end
            else
                QBCore.Functions.Notify(Lang:t('error.not_driver'), "error")
            end
        end
    end
end

RegisterNetEvent("QBCore:Client:OnPlayerLoaded", function()
    TriggerServerEvent("qb-scrapyard:server:LoadVehicleList")
end)

CreateThread(function()
    for id in pairs(Config.Locations) do
        blips[id] = AddBlipForCoord(Config.Locations[id]["main"].x, Config.Locations[id]["main"].y, Config.Locations[id]["main"].z)
        SetBlipSprite(blips[id], 380)
        SetBlipDisplay(blips[id], 4)
        SetBlipScale(blips[id], 0.7)
        SetBlipAsShortRange(blips[id], true)
        SetBlipColour(blips[id], 9)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName(Lang:t('text.scrapyard'))
        EndTextCommandSetBlipName(blips[id])
    end
end)

CreateThread(function()
    for k,v in pairs(Config.Locations) do
        if v.deliver then
            local options = {
                {
                    icon = "fa fa-wrench",
                    label = Lang:t('text.disassemble_vehicle_target'),
                    action = function()
                        ScrapVehicle(k)
                    end,
                    canInteract = function()
                        return inVehicleCheck()
                    end
                }
            }
            local opt = v.deliver
            if Config.UseTarget then
                exports["qb-target"]:AddBoxZone("yard"..k, opt.coords, opt.length or 6.0, opt.width or 4.0, {
                    name = "yard"..k,
                    heading = opt.heading or 180.0,
                    minZ = opt.coords.z - 1,
                    maxZ = opt.coords.z + 1,
                }, {
                    options = options,
                    distance = 3
                })
            else
                exports['qb-interact']:addInteractZone({
                    name = "yard"..k,
                    coords = opt.coords,
                    length = opt.length or 6.0,
                    width = opt.width or 4.0,
                    heading = opt.heading or 180.0,
                    height = 4.0,
                    debugPoly = false,
                    options = options,
                })
            end
        end
        if v.list then
            local options = {
                {
                    icon = "fa fa-list",
                    label = Lang:t('text.email_list_target'),
                    action = function()
                        CreateListEmail()
                    end,
                }
            }
            local opt = v.list
            RequestModel(GetHashKey(opt.pedModel or 's_m_y_construct_01'))
            while not HasModelLoaded(GetHashKey(opt.pedModel or 's_m_y_construct_01')) do
                Wait(1)
            end
            peds[k] = CreatePed(4, GetHashKey(opt.pedModel or 's_m_y_construct_01'), opt.coords.x, opt.coords.y, opt.coords.z - 1.0, opt.heading or 180.0, false, true)
            SetEntityInvincible(peds[k], true)
            FreezeEntityPosition(peds[k], true)
            SetBlockingOfNonTemporaryEvents(peds[k], true)

            if Config.UseTarget then
                exports["qb-target"]:AddTargetEntity(peds[k], {
                    options = options,
                    distance = 3
                })
            else
                exports['qb-interact']:addEntityZone(peds[k], {
                    length = 2,
                    width = 2,
                    debugPoly = false,
                    options = options,
                })
            end
        end
    end
end)

RegisterNetEvent('qb-scapyard:client:setNewVehicles', function(vehicleList)
    Config.CurrentVehicles = vehicleList
end)