local RADAR_CONFIG = {
    MAX_ID = 1000,
    COOLDOWN = 5000,
    RANGE = 30.0,
    TOLERANCE = 1.03
}

local WHITELIST = { 'policija', 'bolnica' }

local PORUKE = {
    INVALID_VALUES = 'Morate unijeti ispravne vrijednosti za maksimalnu brzinu i novcanu kaznu!',
    RADAR_CREATED = 'Radar uspjesno napravljen sa ID %d, maksimalnom brzinom od %d km/h i kaznom od %d$!',
    RADAR_DELETED = 'Radar sa ID %d je uspjesno obrisan!',
    RADAR_NOT_NEAR = 'Radar nije u blizini!'
}

local kreiraniRadari = {}

local function sendMessage(message)
    TriggerEvent('chat:addMessage', {
        color = { 255, 0, 0 },
        multiline = true,
        args = { 'SERVER', message }
    })
end

local function generateRadarId()
    local id = math.random(1, RADAR_CONFIG.MAX_ID)
    while kreiraniRadari[id] do
        id = math.random(1, RADAR_CONFIG.MAX_ID)
    end 
    return id
end

local function Ignoreposao(posao)
    for _, posaoIgnore in ipairs(WHITELIST) do
        if posao == posaoIgnore then
            return true
        end
    end
    return false
end

local function centralnaObradaGresaka(func)
    local status, error = pcall(func)
    if not status then
        print("Dogodila se greska: "..error)
    end
end

RegisterCommand('napraviradar', function(source, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer.getGroup() ~= 'admin' then
        return
    end
    centralnaObradaGresaka(function()
        local maxBrzina = tonumber(args[1])
        local kazna = tonumber(args[2])

        if not maxBrzina or not kazna then
            sendMessage(PORUKE.INVALID_VALUES)
            return
        end

        local playerPed = PlayerPedId()
        local x, y, z = table.unpack(GetEntityCoords(playerPed))
        local h = GetEntityHeading(playerPed)
        local id = generateRadarId()

        local prizemlji, podZ = GetGroundZFor_3dCoord(x, y, z)
        if prizemlji then
            z = podZ
        end

        local radar = CreateObject(GetHashKey("prop_elecbox_08"), x, y, z, true, false, true)
        FreezeEntityPosition(radar, true)
        SetEntityHeading(radar, h)

        kreiraniRadari[id] = { id = id, maxBrzina = maxBrzina, kazna = kazna, x = x, y = y, z = z, h = h, radar = radar }

        TriggerServerEvent('47radars:sacuvajradar', id, maxBrzina, kazna, x, y, z, h)
        sendMessage(string.format(PORUKE.RADAR_CREATED, id, maxBrzina, kazna))
    end)
end)

RegisterCommand('obrisiradar', function(source, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer.getGroup() ~= 'admin' then
        return
    end
    centralnaObradaGresaka(function()
        local najbliziradar = locirajradar()

        if najbliziradar then
            local radarId = nil
            for id, radarInfo in pairs(kreiraniRadari) do
                if radarInfo.radar == najbliziradar then
                    radarId = id
                    DeleteObject(najbliziradar)
                    kreiraniRadari[id] = nil
                    break
                end
            end

            TriggerServerEvent('47radars:obrisiradar', radarId)
            sendMessage(string.format(PORUKE.RADAR_DELETED, radarId))
        else
            sendMessage(PORUKE.RADAR_NOT_NEAR)
        end
    end)
end)

RegisterNetEvent('47radars:ucitajradare')
AddEventHandler('47radars:ucitajradare', function(radari)
    centralnaObradaGresaka(function()
        kreiraniRadari = {}
        for i, radarInfo in ipairs(radari) do
            local id = radarInfo.id
            local maxBrzina = radarInfo.maxBrzina
            local kazna = radarInfo.kazna
            local x = radarInfo.x
            local y = radarInfo.y
            local z = radarInfo.z
            local h = radarInfo.h

            local radar = CreateObject(GetHashKey("prop_elecbox_08"), x, y, z, true, false, true)
            FreezeEntityPosition(radar, true)
            SetEntityHeading(radar, h)

            kreiraniRadari[id] = { id = id, maxBrzina = maxBrzina, kazna = kazna, x = x, y = y, z = z, h = h, radar = radar }
        end
    end)
end)

function locirajradar()
    local playerPed = PlayerPedId()
    local najbliziradar = nil
    local najbliziradardist = 10.0

    for id, radarInfo in pairs(kreiraniRadari) do
        local radar = radarInfo.radar
        local radarCoords = GetEntityCoords(radar)
        local dist = #(GetEntityCoords(playerPed) - radarCoords)

        if dist < najbliziradardist then
            najbliziradar = radar
            najbliziradardist = dist
        end
    end

    return najbliziradar
end

CreateThread(function()
    centralnaObradaGresaka(function()
        while true do
            Wait(1000)

            local playerPed = PlayerPedId()
            if IsPedInAnyVehicle(playerPed, false) then
                local vozilo = GetVehiclePedIsIn(playerPed, false)
                local trenutnaBrzina = GetEntitySpeed(vozilo) * 3.6
                local driverPed = GetPedInVehicleSeat(vozilo, -1)
                local uhvacenRadar = false

                for _, radarInfo in pairs(kreiraniRadari) do
                    local distancaDoRadara = Vdist(GetEntityCoords(playerPed), radarInfo.x, radarInfo.y, radarInfo.z)
                    if distancaDoRadara <= RADAR_CONFIG.RANGE then 
                        local dozvoljenaBrzina = radarInfo.maxBrzina * RADAR_CONFIG.TOLERANCE
                        local xPlayer = ESX.GetPlayerFromId(source)
                        local posao = xPlayer.getJob()
                        if not Ignoreposao(posao) and trenutnaBrzina > dozvoljenaBrzina then
                            local prekoracenaBrzina = math.floor(trenutnaBrzina) - math.floor(dozvoljenaBrzina)
                            if playerPed == driverPed then
                                TriggerServerEvent('47radars:prekoracenjeBrzine', radarInfo.kazna, trenutnaBrzina, dozvoljenaBrzina)
                                SetNotificationTextEntry("STRING")
                                AddTextComponentString("~h~Dozvoljena brzina: " .. math.floor(dozvoljenaBrzina) .." km/h ~n~Prekoracio si brzinu za: " .. prekoracenaBrzina .. " km/h")
                                SetNotificationMessage("CHAR_BLOCKED", "CHAR_BLOCKED", true, 1, "RADAR INFO", "~r~~h~Uhvacen si na radaru!")
                                DrawNotification(false, false)
                            end

                            PlaySoundFrontend(-1, "ScreenFlash", "MissionFailedSounds", 1)
                            StartScreenEffect("FocusOut", 0, false)
                            Wait(2000)
                            StopScreenEffect("FocusOut")

                            uhvacenRadar = true
                            break
                        end
                    end
                end

                if uhvacenRadar then
                    Wait(RADAR_CONFIG.COOLDOWN)
                end
            end
        end
    end)
end)