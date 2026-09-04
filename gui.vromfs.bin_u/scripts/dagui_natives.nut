




from "dagor.debug" import logerr
import "controls" as controls
import "chard" as chard
import "chat" as chat
import "clan" as clan
import "worldwar" as worldwar
import "gameplayOptions" as gameplayOptions
import "warpoints" as warpoints
import "rendering" as rendering
import "scriptErrorHandler" as scriptErrorHandler
import "graphicsOptions" as graphicsOptions
import "dagui" as dagui
import "daguiScene" as daguiScene
import "hangar" as hangar
import "guiScriptUtils" as guiScriptUtils
import "unitCalculcation" as unitCalculcation
import "multiplayer" as multiplayer
import "periodicTasks" as periodicTasks
import "replays" as replays
import "mission" as mission
import "app" as app
import "blkGetters" as blkGetters
import "auth_wt" as authWt

let ps4 = require_optional("ps4") ?? {}
let yuplay2 = require_optional("yuplay2") ?? {}
let webBrowser = require_optional("webBrowser") ?? {}
let soundOptions = require_optional("soundOptions") ?? {}
let online = require_optional("online") ?? {}
let epic = require_optional("epic") ?? {}
let {xbox_complete_login = @(...) null, xbox_find_friends = @(...) null, xbox_find_friends_result = @(...) null} = require_optional("xbox") ?? {}
let voiceMessages = require_optional("voiceMessages") ?? {}

return freeze({}.__update(
  worldwar,
  online,
  clan,
  gameplayOptions,
  chat,
  chard,
  controls,
  soundOptions,
  webBrowser,
  yuplay2,
  warpoints,
  rendering,
  dagui,
  guiScriptUtils,
  daguiScene,
  ps4,
  unitCalculcation,
  voiceMessages,
  hangar,
  epic,
  {xbox_complete_login, xbox_find_friends, xbox_find_friends_result},
  replays,
  blkGetters,
  mission,
{
  reload_main_script_module = @() (dagui["reload_main_script_module"])()

  get_name_by_gamemode = guiScriptUtils["get_name_by_gamemode"]

  ps4_find_friends_result = ps4?["ps4_find_friends_result"] ?? @(...) null

  script_net_assert         = scriptErrorHandler["script_net_assert"]


  restart_game = app["restart_game"]

  is_freecam_enabled = app["is_freecam_enabled"]
  toggle_freecam = app.toggle_freecam

  can_receive_pve_trophy = guiScriptUtils["can_receive_pve_trophy"]

  send_error_log = logerr
  load_local_settings = authWt["load_local_settings"]
  mpstat_get_sort_func = multiplayer["mpstat_get_sort_func"]
  periodic_task_register = periodicTasks["periodic_task_register"]
  periodic_task_register_ex = periodicTasks["periodic_task_register_ex"]
  periodic_task_unregister = periodicTasks["periodic_task_unregister"]
  save_short_token = authWt["save_short_token"]
  set_option_radarAltitudeAlert = gameplayOptions["set_option_radarAltitudeAlert"]
  get_option_radarAltitudeAlert = gameplayOptions["get_option_radarAltitudeAlert"]
  is_eac_inited = app["is_eac_inited"]
  set_presence_to_player = guiScriptUtils["set_presence_to_player"]
  stat_get_exp = warpoints["stat_get_exp"]


  d3d_enable_vsync = graphicsOptions?["d3d_enable_vsync"] ?? @(...) null
  d3d_get_vsync_enabled = graphicsOptions?["d3d_get_vsync_enabled"] ?? @(...) ""
  debug_unlock_all = guiScriptUtils?["debug_unlock_all"] ?? @(...) null

  ps4_find_friends = ps4?["ps4_find_friends"] ?? @(...) null
  ps4_update_gui = ps4?["ps4_update_gui"] ?? @(...) null
  ps4_update_purchases_on_auth = ps4?["ps4_update_purchases_on_auth"] ?? @(...) null
}))
