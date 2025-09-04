local isAdminPanelOpen = false

RegisterNetEvent('tota:client:toggleAdminPanel', function(playerData)
    isAdminPanelOpen = not isAdminPanelOpen
    
    SetNuiFocus(isAdminPanelOpen, isAdminPanelOpen)
    SendNUIMessage({
        action = 'togglePanel',
        show = isAdminPanelOpen,
        players = playerData
    })

    if Config.Debug then
        print('[tota_permid] Evento toggleAdminPanel recibido. Estado NUI: ' .. tostring(isAdminPanelOpen))
    end
end)

RegisterNUICallback('closePanel', function(_, cb)
    isAdminPanelOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'togglePanel', show = false })
    cb('ok')
end)

RegisterNUICallback('performAdminAction', function(data, cb)
    TriggerServerEvent('tota_permid:server:performAdminAction', data)
    cb({ success = true, message = 'Solicitud enviada al servidor.' })
end)