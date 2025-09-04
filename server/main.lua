if not Config then
    print('^1[tota_permid] ^8ERROR: ^7config.lua has not been loaded. Please check your config file (bad config).')
    return
end

local PlayerDataCache = {}
local PlayersLoading = {}

local function dprint(fmt, ...)
    if Config.Debug then
        print(('[tota_permid][sv] ' .. tostring(fmt)):format(...))
    end
end

local function NormalizeKey(k) return tostring(k) end

local function GetIdentifierByPrefix(src, prefix)
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id and id:sub(1, #prefix) == prefix then
            return id
        end
    end
    return nil
end

local function GetLicense(src)
    return GetIdentifierByPrefix(src, 'license:') or GetIdentifierByPrefix(src, 'steam:') or GetIdentifierByPrefix(src, 'license2:')
end

local function GetDiscord(src)
    local d = GetIdentifierByPrefix(src, 'discord:')
    if d then return d:gsub('discord:', '') end
    return nil
end

local function SyncCacheWithClient(targetSrc)
    TriggerClientEvent('tota:client:updateCache', targetSrc, PlayerDataCache)
    dprint('Sincronizando caché con cliente %s', tostring(targetSrc))
end

local function SyncCacheWithAll()
    TriggerClientEvent('tota:client:updateCache', -1, PlayerDataCache)
    local c = 0 for _ in pairs(PlayerDataCache) do c=c+1 end
    dprint('Sincronizando caché con todos (%d entradas)', c)
end

local function GenerateAndAssignNewPermId(source, license, discord, cb)
    cb = cb or function() end
    if Config.IdAssignmentMethod == 'increment' then
        local q = ("SELECT MAX(permid) as maxId FROM `%s`"):format(Config.Database.UsersTable)
        MySQL.Async.fetchAll(q, {}, function(r)
            local maxId = (r and r[1] and tonumber(r[1].maxId)) or 0
            local newId = maxId + 1
            local upd = ("UPDATE `%s` SET permid = @id, discord = @discord WHERE `%s` = @license")
                :format(Config.Database.UsersTable, Config.Database.LicenseColumn)
            MySQL.Async.execute(upd, { ['@id']=newId, ['@discord']=discord or '', ['@license']=license }, function(affected)
                if affected > 0 then
                    dprint('Asignado PermID %s a %s', newId, tostring(source))
                    cb(true, newId)
                else cb(false, nil) end
            end)
        end)
    else
        local attempts = 0
        local function tryOnce()
            attempts = attempts + 1
            if attempts > 15 then cb(false, nil) return end
            local candidate = math.random(1, Config.MaxPermId)
            local check = ("SELECT permid FROM `%s` WHERE permid = @id LIMIT 1"):format(Config.Database.UsersTable)
            MySQL.Async.fetchAll(check, { ['@id'] = candidate }, function(res)
                if res and res[1] then
                    tryOnce()
                else
                    local upd = ("UPDATE `%s` SET permid = @id, discord = @discord WHERE `%s` = @license")
                        :format(Config.Database.UsersTable, Config.Database.LicenseColumn)
                    MySQL.Async.execute(upd, { ['@id']=candidate, ['@discord']=discord or '', ['@license']=license }, function(aff)
                        if aff > 0 then cb(true, candidate) else tryOnce() end
                    end)
                end
            end)
        end
        tryOnce()
    end
end

local function EnsurePermId(source, license, discord, cb)
    cb = cb or function() end
    local q = ("SELECT permid FROM `%s` WHERE `%s` = @license AND permid IS NOT NULL LIMIT 1")
        :format(Config.Database.UsersTable, Config.Database.LicenseColumn)
    MySQL.Async.fetchAll(q, { ['@license'] = license }, function(res)
        if res and res[1] and res[1].permid then
            local existing = tonumber(res[1].permid)
            local upd = ("UPDATE `%s` SET discord = @discord WHERE `%s` = @license")
                :format(Config.Database.UsersTable, Config.Database.LicenseColumn)
            MySQL.Async.execute(upd, { ['@discord'] = discord or '', ['@license'] = license })
            cb(true, existing)
        else
            GenerateAndAssignNewPermId(source, license, discord, cb)
        end
    end)
end

local function LoadPlayerIntoCache(source, license, permId)
    local key = NormalizeKey(source)
    local discord = GetDiscord(source) or 'N/A'
    PlayerDataCache[key] = {
        name = GetPlayerName(source) or ('Player_'..key),
        permId = tonumber(permId),
        license = license,
        discord = discord
    }

    if discord and discord ~= 'N/A' then
        local upd = ("UPDATE `%s` SET discord = @discord WHERE `%s` = @license")
            :format(Config.Database.UsersTable, Config.Database.LicenseColumn)
        MySQL.Async.execute(upd, { ['@discord'] = discord, ['@license'] = license })
    end

    dprint('Cargado en caché: src=%s perm=%s', key, tostring(permId))
    SyncCacheWithClient(tonumber(key))
    SyncCacheWithAll()
end

local function HandleFinalPlayerData(source, license, discord)
    EnsurePermId(source, license, discord, function(ok, perm)
        if ok and perm then
            LoadPlayerIntoCache(source, license, perm)
        else
            dprint('Fallo al asegurar PermID para %s', tostring(source))
        end
    end)
end

AddEventHandler('playerJoining', function()
    local src = source
    local attempts, license, discord = 0, nil, nil
    while attempts < 10 and not license do
        license = GetIdentifierByPrefix(src, 'license:') or GetIdentifierByPrefix(src, 'steam:')
        discord = GetIdentifierByPrefix(src, 'discord:')
        if not license then attempts = attempts + 1 Wait(150) end
    end
    if not license then
        dprint('playerJoining: no se obtuvo license para %s', tostring(src))
        return
    end
    PlayersLoading[tostring(src)] = {
        license = license,
        discord = discord and discord:gsub('discord:', '') or nil
    }
end)

local function OnPlayerFullyLoaded(src)
    local key = tostring(src)
    if not PlayersLoading[key] then
        local license = GetLicense(src)
        if not license then
            dprint('OnPlayerFullyLoaded: no license para %s', tostring(src)); return
        end
        PlayersLoading[key] = { license = license, discord = GetDiscord(src) }
    end
    local pdata = PlayersLoading[key]
    HandleFinalPlayerData(src, pdata.license, pdata.discord)
    PlayersLoading[key] = nil
end

if Config.Framework == 'esx' then
    AddEventHandler('esx:playerLoaded', function(src) OnPlayerFullyLoaded(src) end)
elseif Config.Framework == 'qbcore' then
    AddEventHandler('QBCore:Server:OnPlayerLoaded', function() OnPlayerFullyLoaded(source) end)
end

AddEventHandler('onResourceStart', function(resName)
    if GetCurrentResourceName() ~= resName then return end
    Wait(1000)
    dprint('Procesando jugadores conectados...')
    for _, pid in ipairs(GetPlayers()) do
        OnPlayerFullyLoaded(tonumber(pid))
    end
end)

AddEventHandler('playerDropped', function()
    local key = NormalizeKey(source)
    if PlayerDataCache[key] then
        PlayerDataCache[key] = nil
        dprint('Jugador %s desconectado, limpiado cache', key)
        SyncCacheWithAll()
    end
    if PlayersLoading[key] then PlayersLoading[key] = nil end
end)

RegisterNetEvent('tota:server:clientIsReady', function()
    SyncCacheWithClient(source)
end)

RegisterNetEvent('tota:server:requestCache', function()
    SyncCacheWithClient(source)
end)

RegisterNetEvent('tota:server:requestPlayerData', function(targetServerId)
    local src = source
    local key = NormalizeKey(tonumber(targetServerId) or targetServerId)
    if PlayerDataCache[key] then
        TriggerClientEvent('tota:client:receivePlayerData', src, tonumber(targetServerId), PlayerDataCache[key])
        dprint('Enviados datos fallback de %s a %s', tostring(targetServerId), tostring(src))
    else
        dprint('requestPlayerData: no hay datos para %s', tostring(key))
    end
end)

RegisterNetEvent('tota:server:performAdminAction', function(data)
    local src = source
    if not Framework.HasPermission(src) then
        Framework.ShowNotification(src, 'No tienes permiso para usar esto.')
        return
    end

    local targetId = tonumber(data.targetId)
    local action = tostring(data.action or '')
    if not targetId then Framework.ShowNotification(src, 'Target inválido.') return end

    local key = NormalizeKey(targetId)
    if not PlayerDataCache[key] then Framework.ShowNotification(src, 'Jugador no está en caché.') return end

    local targetName = GetPlayerName(targetId) or ('Player_'..key)

    if action == 'kick' then
        DropPlayer(targetId, Config.KickMessage or 'Expulsado por admin.')
        Framework.ShowNotification(src, 'Jugador '..targetName..' expulsado.')
    elseif action == 'kill' then
        Config.KillPlayer(targetId)
        Framework.ShowNotification(src, 'Jugador '..targetName..' asesinado.')
    elseif action == 'revive' then
        Config.RevivePlayer(targetId)
        Framework.ShowNotification(src, 'Jugador '..targetName..' revivido.')
    elseif action == 'freeze' then
        TriggerClientEvent('tota:client:toggleFreeze', targetId)
        Framework.ShowNotification(src, 'Toggle freeze en '..targetName)
    elseif action == 'spectate' then
        TriggerClientEvent('tota:client:spectatePlayer', src, targetId)
        Framework.ShowNotification(src, 'Iniciando especteo en '..targetName)
    elseif action == 'bring' then
        local coords = GetEntityCoords(GetPlayerPed(src))
        TriggerClientEvent('tota:client:teleport', targetId, coords)
        Framework.ShowNotification(src, 'Has traído a '..targetName)
    elseif action == 'goto' then
        local coords = GetEntityCoords(GetPlayerPed(targetId))
        TriggerClientEvent('tota:client:teleport', src, coords)
        Framework.ShowNotification(src, 'Te has teleportado a '..targetName)
    elseif action == 'giveCar' then
        local model = tostring(data.model or '')
        if model ~= '' then
            TriggerClientEvent('tota:client:spawnVehicle', targetId, model)
            Framework.ShowNotification(src, 'Vehículo '..model..' entregado a '..targetName)
        else Framework.ShowNotification(src, 'Modelo inválido.') end
    else
        Framework.ShowNotification(src, 'Acción desconocida.')
    end
end)

RegisterCommand(Config.AdminPanelCommand or 'idpanel', function(src)
    if not Framework.HasPermission(src) then
        Framework.ShowNotification(src, 'No tienes permiso.')
        return
    end
    TriggerClientEvent('tota:client:toggleAdminPanel', src, PlayerDataCache)
end, false)

RegisterCommand('resyncpanel', function(src)
    if not Framework.HasPermission(src) then return end
    TriggerClientEvent('tota:client:toggleAdminPanel', src, PlayerDataCache)
    Wait(200)
    TriggerClientEvent('tota:client:toggleAdminPanel', src, PlayerDataCache)
    Framework.ShowNotification(src, 'Panel resincronizado.')
end, false)

exports('GetSourceFromPermId', function(permId)
    permId = tonumber(permId)
    if not permId then return false end
    for sid, data in pairs(PlayerDataCache) do
        if tonumber(data.permId) == permId then
            return tonumber(sid)
        end
    end
    return false
end)

dprint('Servidor cargado y listo.')
