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

Framework.Notify = function(message, t)
    if Config.Framework == 'esx' and _G.ESX then
        _G.ESX.ShowNotification(message)
    elseif Config.Framework == 'qbcore' and _G.QBCore then
        _G.QBCore.Functions.Notify(message, t or "primary")
    else
        print("[CLIENT][Notify] " .. tostring(message))
    end
end

Framework.OnPlayerLoaded = function(cb)
    if Config.Framework == 'esx' then
        AddEventHandler('esx:playerLoaded', function(xPlayer) cb(xPlayer) end)
    elseif Config.Framework == 'qbcore' then
        RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() cb(_G.QBCore.Functions.GetPlayerData()) end)
    else
        CreateThread(function()
            Wait(2000)
            cb({})
        end)
    end
end

Framework.GetPlayerData = function()
    if Config.Framework == 'esx' and _G.ESX then
        return _G.ESX.GetPlayerData()
    elseif Config.Framework == 'qbcore' and _G.QBCore then
        return _G.QBCore.Functions.GetPlayerData()
    end
    return {}
end