fx_version 'cerulean'
game 'gta5'

author 'Tota Network'
description 'Sistema de ID Permanente optimizado con panel de administración avanzado para ESX y QBCore.'
version 'legacy'

shared_scripts {
  'config.lua'
}

server_scripts {
  '@mysql-async/lib/MySQL.lua',
  '@oxmysql/lib/MySQL.lua',
  'server/bridge.lua',
  'server/main.lua'
}

client_scripts {
  'exports.lua',
  'client/bridge.lua',
  'client/main.lua',
  'client/nui.lua'
}

ui_page 'ui/index.html'

files {
  'ui/index.html',
  'ui/style.css',
  'ui/script.js'
}