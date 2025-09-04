if Config.Framework ~= 'esx' then return end

local ESX = exports["es_extended"]:getSharedObject()

ESX.RegisterCommand('giveitemperm', 'admin', function(source, args, showError)
    local permId = tonumber(args[1])
    local item = args[2]
    local count = tonumber(args[3])

    if not permId or not item or not count then
        showError("Uso inválido: /giveitemperm [PermID] [item] [cantidad]")
        return
    end

    local targetSource = exports.tota_permid:GetSourceFromPermId(permId)

    if not targetSource then
        showError("El jugador con ese ID permanente no está conectado.")
        return
    end

    local xPlayer = ESX.GetPlayerFromId(targetSource)
    local sourcePlayer = ESX.GetPlayerFromId(source)

    if xPlayer then
        xPlayer.addInventoryItem(item, count)
        TriggerClientEvent('esx:showNotification', targetSource, string.format("Has recibido %s %s de un administrador.", count, item))
        sourcePlayer.showNotification(string.format("Has entregado %s %s a %s (PermID: %s).", count, item, xPlayer.getName(), permId))
    else
        showError("No se pudo encontrar el objeto del jugador.")
    end
end, false, { help = "Dar un objeto a un jugador por su ID permanente.", params = {{name = "PermID"}, {name = "item"}, {name = "cantidad"}}})

-- Comando para teletransportarse a un jugador usando su PermID
ESX.RegisterCommand('tpperm', 'admin', function(source, args, showError)
    local permId = tonumber(args[1])
    if not permId then
        showError("Uso inválido: /tpperm [PermID]")
        return
    end

    local targetSource = exports.tota_permid:GetSourceFromPermId(permId)

    if not targetSource then
        showError("El jugador con ese ID permanente no está conectado.")
        return
    end

    local targetCoords = GetEntityCoords(GetPlayerPed(targetSource))
    SetEntityCoords(GetPlayerPed(source), targetCoords.x, targetCoords.y, targetCoords.z)
    ESX.GetPlayerFromId(source).showNotification(string.format("Te has teletransportado al jugador con PermID %s.", permId))
end, false, { help = "Teletransportarse a un jugador por su ID permanente.", params = {{name = "PermID"}}})