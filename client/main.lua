if not Config then
    print('[tota_permid] ERROR: config.lua no cargado.')
    return
end

local PlayerCache = {}
local pendingPlayerRequests = {}
local lastCacheRequest = 0
local isOverheadIdVisible = false
local OverheadDrawDistance = 20.0
local isPlayerFrozen = false
local isSpectating, spectatingTarget = false, nil
local savedCoords = nil
local nuiOpen = false

local function dprint(fmt, ...)
    if Config.Debug then print(('[tota_permid][cl] ' .. tostring(fmt)):format(...)) end
end

local function NormalizeKey(k) return
    tostring(k)
end
local function Notify(msg, t)
    if Framework and Framework.Notify then
        Framework.Notify(msg, t)
    else
        print('[tota_permid] '..tostring(msg))
    end
end

local function RequestServerCache()
    local now = GetGameTimer()
    if now - lastCacheRequest < 1000 then return end
    lastCacheRequest = now
    TriggerServerEvent('tota:server:requestCache')
    dprint('Solicitada caché al servidor.')
end

RegisterNetEvent('tota:client:updateCache', function(serverCache)
    local newCache, count = {}, 0
    if serverCache then
        for k, v in pairs(serverCache) do
            newCache[NormalizeKey(k)] = v
            count = count + 1
        end
    end
    PlayerCache = newCache
    dprint('Caché actualizada: %d jugadores', count)

    for srvId, callbacks in pairs(pendingPlayerRequests) do
        local k = NormalizeKey(srvId)
        if PlayerCache[k] then
            for _, cb in ipairs(callbacks) do cb(PlayerCache[k]) end
            pendingPlayerRequests[srvId] = nil
        end
    end
end)

RegisterNetEvent('tota:client:receivePlayerData', function(serverId, playerData)
    local key = NormalizeKey(serverId)
    PlayerCache[key] = playerData
    if pendingPlayerRequests[serverId] then
        for _, cb in ipairs(pendingPlayerRequests[serverId]) do cb(playerData) end
        pendingPlayerRequests[serverId] = nil
    end
end)

local function GetPlayerData(serverId, callback)
    local key = NormalizeKey(serverId)
    if PlayerCache[key] then
        if callback then callback(PlayerCache[key]) end
        return PlayerCache[key]
    end
    if callback then
        if not pendingPlayerRequests[serverId] then pendingPlayerRequests[serverId] = {} end
        table.insert(pendingPlayerRequests[serverId], callback)
        if #pendingPlayerRequests[serverId] == 1 then
            TriggerServerEvent('tota:server:requestPlayerData', serverId)
        end
    end
    return nil
end

local function onClientPlayerLoaded()
    Wait(1500)
    TriggerServerEvent('tota:server:clientIsReady')
    Wait(500)
    RequestServerCache()
end

if Framework and Framework.OnPlayerLoaded then
    Framework.OnPlayerLoaded(onClientPlayerLoaded)
else
    -- Fallback por si el bridge no está cargado aún
    CreateThread(function() Wait(2500) onClientPlayerLoaded() end)
end

CreateThread(function()
    Wait(5000)
    if next(PlayerCache) == nil then
        dprint('Backup: pidiendo cache tras 5s.')
        RequestServerCache()
    end
end)

-- =========================================================
-- Overhead ID
-- =========================================================
local function DrawTextSimple(x, y, text, scale, font, center, r, g, b, a)
    SetTextScale(scale, scale)
    SetTextFont(font or 4)
    SetTextProportional(1)
    SetTextCentre(center and true or false)
    SetTextColour(r or 255, g or 255, b or 255, a or 255)
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end

local function DrawOverheadLabel(worldX, worldY, worldZ, idLine, nameLine, distance)
    local onScreen, sx, sy = World3dToScreen2d(worldX, worldY, worldZ + 0.0)
    if not onScreen then return end

    local maxScale, minScale = 0.42, 0.28
    local distClamp = math.max(1.0, math.min(distance, 80.0))
    local scale = maxScale - ((distClamp / OverheadDrawDistance) * (maxScale - minScale))
    if scale < minScale then scale = minScale end

    local idText   = tostring(idLine or '')
    local nameText = tostring(nameLine or '')

    DrawTextSimple(sx + 0.0012, sy + 0.0012, idText, scale, 4, true, 0, 0, 0, 160)
    DrawTextSimple(sx, sy, idText, scale, 4, true, 255, 225, 120, 255)

    if nameText ~= '' then
        local y2 = sy + 0.025
        DrawTextSimple(sx + 0.0012, y2 + 0.0012, nameText, scale * 0.9, 4, true, 0, 0, 0, 160)
        DrawTextSimple(sx, y2, nameText, scale * 0.9, 4, true, 255, 255, 255, 235)
    end
end

RegisterCommand(Config.OverheadIdCommand or 'ids', function()
    isOverheadIdVisible = not isOverheadIdVisible
    Notify('IDs sobre la cabeza ' .. (isOverheadIdVisible and 'activado' or 'desactivado') .. '.', 'primary')
    dprint('OverHead %s', isOverheadIdVisible and 'ON' or 'OFF')
end, false)

CreateThread(function()
    while true do
        if isOverheadIdVisible then
            local myPed = PlayerPedId()
            local myCoords = GetEntityCoords(myPed)
            local players = GetActivePlayers()
            for _, pid in ipairs(players) do
                local serverId = GetPlayerServerId(pid)
                local data = PlayerCache[NormalizeKey(serverId)]
                local tgtPed = GetPlayerPed(pid)
                if DoesEntityExist(tgtPed) then
                    local coords = GetEntityCoords(tgtPed)
                    local dist = #(myCoords - coords)
                    if dist < OverheadDrawDistance then
                        if data and data.permId then
                            local namePart = (Config.ShowName and (data.name or '') or '')
                            local idLine = string.format('[%s | %s]', tostring(serverId), tostring(data.permId))
                            DrawOverheadLabel(coords.x, coords.y, coords.z + 1.05, idLine, namePart, dist)
                        else
                            GetPlayerData(serverId, function(_) end)
                        end
                    end
                end
            end
            Wait(5)
        else
            Wait(350)
        end
    end
end)

-- =========================================================
-- Admin: TP / Freeze / Vehículo
-- =========================================================
RegisterNetEvent('tota:client:teleport', function(coords)
    SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z, false, false, false, true)
    Notify('Has sido teletransportado por un administrador.', 'primary')
end)

RegisterNetEvent('tota:client:toggleFreeze', function()
    isPlayerFrozen = not isPlayerFrozen
    FreezeEntityPosition(PlayerPedId(), isPlayerFrozen)
    Notify('Has sido ' .. (isPlayerFrozen and 'congelado' or 'descongelado') .. ' por un admin.', isPlayerFrozen and 'warning' or 'primary')
end)

RegisterNetEvent('tota:client:spawnVehicle', function(model)
    local modelHash = GetHashKey(model)
    if not IsModelInCdimage(modelHash) or not IsModelAVehicle(modelHash) then
        Notify('Modelo de vehículo inválido: ' .. tostring(model), 'error')
        return
    end

    CreateThread(function()
        RequestModel(modelHash)
        local timeout = GetGameTimer() + 5000
        while not HasModelLoaded(modelHash) and GetGameTimer() < timeout do Wait(0) end
        if not HasModelLoaded(modelHash) then
            Notify('No se pudo cargar el modelo: ' .. tostring(model), 'error')
            return
        end

        local ped = PlayerPedId()
        local pCoords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        local veh = CreateVehicle(modelHash, pCoords.x, pCoords.y, pCoords.z, heading, true, false)
        if DoesEntityExist(veh) then
            SetEntityAsMissionEntity(veh, true, true)
            SetVehicleOnGroundProperly(veh)
            TaskWarpPedIntoVehicle(ped, veh, -1)
            Notify('Has recibido un vehículo de un administrador.', 'success')
        else
            Notify('Error creando el vehículo.', 'error')
        end
        SetModelAsNoLongerNeeded(modelHash)
    end)
end)

local function StartSpectating(targetPed)
    local ped = PlayerPedId()
    savedCoords = GetEntityCoords(ped)

    local tCoords = GetEntityCoords(targetPed)
    RequestCollisionAtCoord(tCoords.x, tCoords.y, tCoords.z)
    SetEntityVisible(ped, false)
    SetEntityCollision(ped, false, false)
    FreezeEntityPosition(ped, true)

    SetEntityCoords(ped, tCoords.x, tCoords.y, tCoords.z + 10.0)
    Wait(250)
    NetworkSetInSpectatorMode(true, targetPed)

    isSpectating = true
end

local function StopSpectating()
    local ped = PlayerPedId()
    NetworkSetInSpectatorMode(false, ped)
    FreezeEntityPosition(ped, false)
    SetEntityCollision(ped, true, true)
    SetEntityVisible(ped, true)

    if savedCoords then
        RequestCollisionAtCoord(savedCoords.x, savedCoords.y, savedCoords.z)
        SetEntityCoords(ped, savedCoords.x, savedCoords.y, savedCoords.z)
        savedCoords = nil
    end

    isSpectating, spectatingTarget = false, nil
end

RegisterNetEvent('tota:client:spectatePlayer', function(adminSource, targetId)
    if GetPlayerServerId(PlayerId()) ~= adminSource then return end

    if isSpectating and spectatingTarget == targetId then
        StopSpectating()
        Notify("Specteo desactivado.")
        return
    end

    if isSpectating then StopSpectating() end

    if targetId == GetPlayerServerId(PlayerId()) then
        Notify("No puedes espectearte a ti mismo.", "error")
        return
    end

    local targetPlayer = GetPlayerFromServerId(targetId)
    if targetPlayer == -1 then
        Notify("El jugador no está disponible o no está streameado.", "error")
        return
    end

    local targetPed = GetPlayerPed(targetPlayer)
    if not DoesEntityExist(targetPed) then
        Notify("El jugador no está disponible.", "error")
        return
    end

    spectatingTarget = targetId
    StartSpectating(targetPed)
    Notify("Ahora especteando a "..GetPlayerName(targetPlayer)..". Pulsa [X] para salir.")
end)

CreateThread(function()
    while true do
        Wait(0)
        if isSpectating and IsControlJustPressed(0, 73) then -- X
            StopSpectating()
            Notify("Specteo desactivado.")
        end
    end
end)

RegisterCommand("spectateoff", function()
    if isSpectating then
        StopSpectating()
        Notify("Specteo desactivado.")
    end
end, false)

RegisterKeyMapping("spectateoff", "Salir del especteo", "keyboard", "X")

RegisterNetEvent('tota:client:toggleAdminPanel', function(serverCache)
    PlayerCache = serverCache or PlayerCache
    SendNUIMessage({ action = 'openPanel', cache = PlayerCache })
    SetNuiFocus(true, true)
    nuiOpen = true
end)

RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    nuiOpen = false
    cb('ok')
end)

RegisterNUICallback('performAction', function(data, cb)
    TriggerServerEvent('tota:server:performAdminAction', data)
    cb('ok')
end)

RegisterNUICallback('requestPlayerData', function(data, cb)
    local id = tonumber(data.serverId)
    if not id then cb({ ok = false }) return end
    local info = GetPlayerData(id, function(p) cb({ ok = true, data = p }) end)
    if info then cb({ ok = true, data = info }) end
end)

AddEventHandler('onClientResourceStop', function(res)
    if GetCurrentResourceName() ~= res then return end
    PlayerCache, pendingPlayerRequests = {}, {}
    if nuiOpen then SetNuiFocus(false, false) nuiOpen = false end
    if isSpectating then StopSpectating() end
end)

exports('GetServerIdFromPermId', function(permId)
    if not permId then return false end
    for sid, data in pairs(PlayerCache) do
        if tonumber(data.permId) == tonumber(permId) then return tonumber(sid) end
    end
    return false
end)

exports('GetPlayerDataWithFallback', function(serverId, cb)
    return GetPlayerData(serverId, cb)
end)

exports('HasPlayerInCache', function(serverId)
    return PlayerCache[NormalizeKey(serverId)] ~= nil
end)

exports('GetPlayerCache', function() return PlayerCache end)

exports('SpectatePlayer', function(serverId)
    TriggerEvent('tota:client:spectatePlayer', GetPlayerServerId(PlayerId()), tonumber(serverId))
end)

exports('IsSpectating', function()
    return isSpectating, spectatingTarget
end)

dprint('Cliente cargado con OverHead y Especteo arreglado.')
