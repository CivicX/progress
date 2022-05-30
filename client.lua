--[[
    ? = optional

    data: {
        title?: string
        text?: string
        duration?: number (ms)
        onProgress?: function (on every whole progress step)
        useWhileDead?: boolean
        controlDisables?: {
            movement?: boolean
            vehicleMovement?: boolean
            mouse?: boolean
            combat?: boolean
        }
        animation?: {
            dict?: string
            anim?: string
            flags?: number
            task?: string
        }
        prop?: {
            model: number
            bone?: number
            coords?: vector3
            rotation?: vector3
        }

        //Only for async
        onFinish?: function
    }
]]

local isActive = false
local p;
local onFinish;
local onProgress;
local playingAnim = false
local controlDisables;
local propHandle
local propNet

local function spawnProp(playerPed, prop)
    local model = prop.model
    local playerCoords = GetEntityCoords(playerPed)

    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end

    propHandle = CreateObject(model, playerCoords, true, true, true)
    SetEntityAlpha(propHandle, 0, false)
    propNet = ObjToNet(propHandle)

    SetNetworkIdExistsOnAllMachines(propNet, true)
    NetworkSetNetworkIdDynamic(propNet, true)
    SetNetworkIdCanMigrate(propNet, false)

    AttachEntityToEntity(
        propHandle,
        playerPed,
        GetPedBoneIndex(playerPed, prop.bone or 60309),
        prop.coords or vector3(0.0, 0.0, 0.0),
        prop.rotation or vector3(0.0, 0.0, 0.0),
        1, 1, 0, 1, 0, 1
    )

    SetModelAsNoLongerNeeded(model)

    CreateThread(function()
        for i = 0, 255, 51 do
            SetEntityAlpha(propHandle, i, false)
            Wait(25)
        end
    end)
end

local function startAnim(playerPed, animation)
    if animation.dict and animation.anim then
        RequestAnimDict(animation.dict)
        while not HasAnimDictLoaded(animation.dict) do
            Wait(0)
            print("loading")
        end
        TaskPlayAnim(
            playerPed,
            animation.dict,
            animation.anim,
            3.0,
            1.0,
            -1,
            animation.flags or 0,
            0, 0, 0, 0
        )
    else
        TaskStartScenarioInPlace(playerPed, animation.task, 0, true)
    end

    playingAnim = true
end

local function disableControls()
    Citizen.CreateThread(function()
        while isActive do
            if controlDisables.disableMouse then
                DisableControlAction(0, 1, true) -- LookLeftRight
                DisableControlAction(0, 2, true) -- LookUpDown
                DisableControlAction(0, 106, true) -- VehicleMouseControlOverride
            end
        
            if controlDisables.disableMovement then
                DisableControlAction(0, 30, true) -- disable left/right
                DisableControlAction(0, 31, true) -- disable forward/back
                DisableControlAction(0, 36, true) -- INPUT_DUCK
                DisableControlAction(0, 21, true) -- disable sprint
            end
        
            if controlDisables.disableCarMovement then
                DisableControlAction(0, 63, true) -- veh turn left
                DisableControlAction(0, 64, true) -- veh turn right
                DisableControlAction(0, 71, true) -- veh forward
                DisableControlAction(0, 72, true) -- veh backwards
                DisableControlAction(0, 75, true) -- disable exit vehicle
            end
        
            if controlDisables.disableCombat then
                DisablePlayerFiring(PlayerPedId(), true) -- Disable weapon firing
                DisableControlAction(0, 24, true) -- disable attack
                DisableControlAction(0, 25, true) -- disable aim
                DisableControlAction(1, 37, true) -- disable weapon select
                DisableControlAction(0, 47, true) -- disable weapon
                DisableControlAction(0, 58, true) -- disable weapon
                DisableControlAction(0, 140, true) -- disable melee
                DisableControlAction(0, 141, true) -- disable melee
                DisableControlAction(0, 142, true) -- disable melee
                DisableControlAction(0, 143, true) -- disable melee
                DisableControlAction(0, 263, true) -- disable melee
                DisableControlAction(0, 264, true) -- disable melee
                DisableControlAction(0, 257, true) -- disable melee
            end
            Wait(0)
        end
    end)
end

local function cleanup()
    if propHandle and DoesEntityExist(propHandle) then
        CreateThread(function()
            for i = 255, 0, -51 do
                SetEntityAlpha(propHandle, i, false)
                Wait(25)
            end
            DetachEntity(propHandle)
            DeleteEntity(propHandle)
            propHandle = nil
        end)
    end

    if playingAnim then
        ClearPedTasks(PlayerPedId())
        playingAnim = false
    end
end


local function start(data, syncType)
    if isActive then return false end
    isActive = true

    if syncType == "sync" then
        p = promise.new()
    end

    local playerPed = PlayerPedId()

    Citizen.CreateThread(function()

        local onProgressExists = type(data.onProgress) == "function"
        local onFinishExists = type(data.onFinish) == "function"

        
        if data.prop then
            spawnProp(playerPed, data.prop)
        end

        if data.animation then
            startAnim(playerPed, data.animation)
        end

        controlDisables = data.controlDisables
        if controlDisables then
            disableControls()
        end

        SendNUIMessage({
            action = "start",
            title = data.title,
            text = data.text,
            duration = data.duration,
            onProgress = onProgressExists
        })

        if onFinishExists then
            onFinish = data.onFinish
        end

        if onProgressExists then
            onProgress = data.onProgress
        end
    end)

    if syncType == "sync" then
        return Citizen.Await(p)
    end
end

local function StartSync(data)
    return start(data, "sync")
end
exports("StartSync", StartSync)
RegisterNetEvent("progress:StartSync", StartSync)

local function StartAsync(data)
    start(data, "async")
end
exports("StartAsync", StartAsync)
RegisterNetEvent("progress:StartAsync", StartAsync)

local function Stop()
    if not isActive then return end;
    isActive = false

    cleanup()

    SendNUIMessage({
        action = "stop",
    })

    Wait(300) -- let it fade out

    if p then
        p:resolve(true)
        p = nil
    end

    if onFinish then
        onFinish()
    end
end
exports("Stop", Stop)
RegisterNetEvent("progress:Stop", Stop)

RegisterNUICallback("finished", function(_, cb)
    isActive = false

    cleanup()

    if not p then
        if onFinish then
            onFinish()
            onFinish = nil
        end
        return cb("ok")
    end

    p:resolve(true)
    p = nil


    cb("ok")
end)

RegisterNUICallback("progress", function(data, cb)
    if not onProgress then return cb("ok") end

    onProgress(data.percentage)

    cb("ok")
end)


-- RegisterCommand("bandage", function()
--     StartSync({
--         title = "Bandage",
--         text = "Applying...",
--         duration = 2500,
--         prop = {
--             model = `prop_ld_health_pack`,
--             coords = vector3(-0.1, 0.0, 0.0),
--             rotation = vector3(45.0, 0.0, 0.0)
--         },
--         animation = {
--             dict = "missheistdockssetup1clipboard@idle_a",
--             anim = "idle_a",
--             flags = 49
--         },
--         controlDisables = {
--             disableMovement = true,
--             disableCarMovement = true,
--             disableCombat = true
--         }
--     })

--     print("I AM FUCKING DONE BRO!!")
-- end)