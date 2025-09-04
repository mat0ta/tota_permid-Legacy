Framework = {}
_G.ESX = nil
_G.QBCore = nil

if Config.Framework == 'esx' then
    CreateThread(function()
        while _G.ESX == nil do
            TriggerEvent('esx:getSharedObject', function(obj) _G.ESX = obj end)
            Wait(100)
        end
    end)
elseif Config.Framework == 'qbcore' then
    _G.QBCore = exports['qb-core']:GetCoreObject()
end

while (Config.Framework == 'esx' and _G.ESX == nil) or (Config.Framework == 'qbcore' and _G.QBCore == nil) do Citizen.Wait(10) end

Framework.GetPlayer = function(source)
    if Config.Framework == 'esx' then
        return _G.ESX.GetPlayerFromId(source)
    elseif Config.Framework == 'qbcore' then
        return _G.QBCore.Functions.GetPlayer(source)
    end
    return nil
end

Framework.GetIdentifier = function(source)
    local player = Framework.GetPlayer(source)
    if not player then return nil end

    if Config.Framework == 'esx' then
        return player.identifier
    elseif Config.Framework == 'qbcore' then
        return player.PlayerData.citizenid
    end
    return nil
end

Framework.HasPermission = function(source, permission)
    if Config.Framework == 'esx' then
        local xPlayer = _G.ESX.GetPlayerFromId(source)
        return xPlayer and xPlayer.getGroup() == permission
    elseif Config.Framework == 'qbcore' then
        return true
    end
    return false
end

Framework.ShowNotification = function(source, message)
    if Config.Framework == 'esx' then
        TriggerClientEvent('esx:showNotification', source, message)
    elseif Config.Framework == 'qbcore' then
        TriggerClientEvent('QBCore:Notify', source, message)
    end
end