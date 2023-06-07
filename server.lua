local SQL_QUERIES = {
    INSERT_RADAR = 'INSERT INTO radari (id, maxBrzina, kazna, x, y, z, h) VALUES (@id, @maxBrzina, @kazna, @x, @y, @z, @h)',
    DELETE_RADAR = 'DELETE FROM radari WHERE id = @id',
    SELECT_RADAR = 'SELECT * FROM radari'
}

local function fetchRadars(callback)
    MySQL.Async.fetchAll(SQL_QUERIES.SELECT_RADAR, {}, callback)
end

local function centralnaObradaGresaka(func)
    local status, error = pcall(func)
    if not status then
        print("Dogodila se greska: "..error)
    end
end

RegisterServerEvent('47radars:sacuvajradar')
AddEventHandler('47radars:sacuvajradar', function(id, maxBrzina, kazna, x, y, z, h)
    centralnaObradaGresaka(function()
        MySQL.Async.execute(SQL_QUERIES.INSERT_RADAR, { ['@id'] = id, ['@maxBrzina'] = maxBrzina, ['@kazna'] = kazna, ['@x'] = x, ['@y'] = y, ['@z'] = z, ['@h'] = h}, function(rowsChanged)
            if rowsChanged > 0 then
                print('[^3SQL^0]: Radar sa ID ^4' .. id .. '^0, maksimalnom brzinom od ^4' .. maxBrzina .. ' i kaznom od ^4' .. kazna ..' ^0je ^2spremljen^0 u databazu.')
            else
                print('[^1ERROR^0]: Doslo je do greske prilikom ^1brisanja^0 radara iz databaze.')
            end
        end)
    end)
end)

RegisterServerEvent('47radars:obrisiradar')
AddEventHandler('47radars:obrisiradar', function(radarId)
    centralnaObradaGresaka(function()
        MySQL.Async.execute(SQL_QUERIES.DELETE_RADAR, { ['@id'] = radarId }, function(rowsChanged)
            if rowsChanged > 0 then
                print('[^3SQL^0]: Radar sa ID ^4' .. radarId .. '^0 je ^1izbrisan^0 iz databaze.')
            else
                print('[^1ERROR^0]: Doslo je do greske prilikom ^1brisanja^0 radara iz databaze.')
            end
        end)
    end)
end)

RegisterServerEvent('47radars:prekoracenjeBrzine')
AddEventHandler('47radars:prekoracenjeBrzine', function(kazna, trenutnaBrzina, dozvoljenaBrzina)
    centralnaObradaGresaka(function()
        local xPlayer = ESX.GetPlayerFromId(source)
        local prekoracenaBrzina = math.floor(trenutnaBrzina) - math.floor(dozvoljenaBrzina)
        local novaKazna = kazna + prekoracenaBrzina

        if xPlayer then
            xPlayer.removeAccountMoney('bank', novaKazna)
            print("Dozvoljena brzina sa tolerancijom: " .. math.floor(dozvoljenaBrzina) .. " km/h, Trenutna brzina: " .. math.floor(trenutnaBrzina) .. " km/h, Prekoracena brzina: " .. prekoracenaBrzina .. " km/h, Kazna: " .. novaKazna .. "$")
        else
            print("Ne mogu pronaci igraca.")
        end
    end)
end)


AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end
    centralnaObradaGresaka(function()
        fetchRadars(function(result)
            print('[^3SQL^0]: Ucitano ^4' .. #result .. '^0 radara iz databaze.')
            for _, player in ipairs(GetPlayers()) do
                local src = tonumber(player)
                ucitaj(src)
            end
        end)
    end)
end)

AddEventHandler('playerConnecting', function()
    centralnaObradaGresaka(function()
        local src = source
        Wait(5000)
        ucitaj(src)
    end)
end)

function ucitaj(src)
    fetchRadars(function(result)
        TriggerClientEvent('47radars:ucitajradare', src, result)
    end)
end