if Config.Framework ~= 'qbcore' then return end

local QBCore = exports['qb-core']:GetCoreObject()

-- Comando para dar un objeto a un jugador usando su PermID
QBCore.Commands.Add('giveitemperm', 'Dar un objeto a un jugador por su ID permanente.', {{name='permid', help='ID Permanente del jugador'}, {name='item', help='Nombre del objeto'}, {name='amount', help='Cantidad'}}, true, function(source, args)
    local permId = tonumber(args[1])
    local item = args[2]
    local amount = tonumber(args[3])

    -- Usamos nuestro nuevo export para encontrar al jugador
    local targetSource = exports.tota_permid:GetSourceFromPermId(permId)

    if not targetSource then
        TriggerClientEvent('QBCore:Notify', source, "El jugador con ese ID permanente no está conectado.", 'error')
        return
    end

    local targetPlayer = QBCore.Functions.GetPlayer(targetSource)
    if targetPlayer then
        targetPlayer.Functions.AddItem(item, amount)
        TriggerClientEvent('QBCore:Notify', targetSource, string.format("Has recibido %s %s de un administrador.", amount, item), 'success')
        TriggerClientEvent('QBCore:Notify', source, string.format("Has entregado %s %s a %s (PermID: %s).", amount, item, targetPlayer.PlayerData.charinfo.firstname, permId), 'success')
    else
        TriggerClientEvent('QBCore:Notify', source, "No se pudo encontrar el objeto del jugador.", 'error')
    end
end, 'admin')

-- Comando para teletransportarse a un jugador usando su PermID
QBCore.Commands.Add('tpperm', 'Teletransportarse a un jugador por su ID permanente.', {{name='permid', help='ID Permanente del jugador'}}, true, function(source, args)
    local permId = tonumber(args[1])

    local targetSource = exports.tota_permid:GetSourceFromPermId(permId)
    if not targetSource then
        TriggerClientEvent('QBCore:Notify', source, "El jugador con ese ID permanente no está conectado.", 'error')
        return
    end

    local targetCoords = GetEntityCoords(GetPlayerPed(targetSource))
    SetEntityCoords(GetPlayerPed(source), targetCoords.x, targetCoords.y, targetCoords.z)
    TriggerClientEvent('QBCore:Notify', source, string.format("Te has teletransportado al jugador con PermID %s.", permId), 'success')
end, 'admin')