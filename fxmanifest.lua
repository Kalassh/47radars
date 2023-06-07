fx_version 'cerulean'
game 'gta5'

author 'Kalashnikov#3535'
description '47radars'
version 'v1.0.0'

client_script 'client.lua'

server_script {
    '@mysql-async/lib/MySQL.lua',
    'server.lua'
}
