
#strict
#allow-root-table

import "ww_leaderboard" as ww_leaderboard
from "chard" import save_common_local_settings
from "%sqstd/platform.nut" import platformId
from "dagor.time" import get_local_unixtime, ref_time_ticks
from "dagor.random" import rnd, get_rnd_seed, set_rnd_seed
from "string" import format
from "json" import object_to_json_string
from "auth_wt" import getDistr
from "sysinfo" import get_user_system_info
from "blkGetters" import get_settings_blk, get_common_local_settings_blk
from "steam" import steam_is_running, steam_get_my_id
from "soundModCheck" import is_sound_mods_enabled
from "%scripts/dagui_natives.nut" import epic_is_running
from "%scripts/dagui_library.nut" import *
from "app" import is_dev_version
from "types" import String, Integer
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")

local bqStat = persist("bqStat", @() { sendStartOnce = false })


function get_distr() {
  local distr = getDistr()
  if (distr.len() > 0)
    return distr

  let config = get_settings_blk()
  distr = config?.distr ?? config?.originalConfigBlk.distr

  return (distr instanceof String && distr.len() > 0) ? distr : ""
}


function add_sysinfo(table) {
  let sysinfo = get_user_system_info()

  local uuid = ""
  foreach (u in ["uuid0", "uuid2"]) {  
    local str = sysinfo?[u] ?? ""
    str = str.slice(str.len() / 2)
    uuid = $"{uuid}{str}"
  }

  if (uuid.len() > 0)
    table.uuid <- uuid

  if (sysinfo?.osCompatibility == true)
    table.compat <- true

  if (sysinfo?.is64bitClient == false)
    table.game32 <- true

  assert(platformId.len() > 0)
  table.os <- platformId
}


function add_user_info(table) {
  add_sysinfo(table)

  let distr = get_distr()
  if (distr.len() > 0)
    table.distr <- distr

  if (steam_is_running()) {
    table.steam <- true

    let steamId = steam_get_my_id()
    if (steamId > 0)
      table.steamId <- steamId
  }

  if (epic_is_running())
    table.epic <- true

  if (is_sound_mods_enabled())
    table.soundMod <- true

  if (is_dev_version())
    table.dev <- true
}


function bq_client_no_auth(event, uniqueId, table) {
  add_user_info(table)

  let params = object_to_json_string(table, false)
  let request =
  {
    action = "noa_bigquery_client_noauth"
    add_token = false
    headers =
    {
      appid = 1067,
      uniqueId,
      event,
      params
    }
    data = {}
  }

  ww_leaderboard.request(request, function(_response) {})  
  log($"BQ CLIENT_NO_AUTH {event} {params} [{uniqueId}]")
}


function generate_unique_id() {
  
  let seed = get_rnd_seed()
  set_rnd_seed(ref_time_ticks())
  let uniqueId = format("%.8X%.8X", get_local_unixtime(), rnd() * rnd())
  set_rnd_seed(seed)
  return uniqueId
}


function bqSendNoAuth(event, start = false) {  
  local blk = get_common_local_settings_blk()
  local save = false

  if ("uniqueId" not in blk || !(blk.uniqueId instanceof String) || blk.uniqueId.len() < 16) {
    blk.uniqueId <- generate_unique_id()
    if (blk.uniqueId.len() < 16)
      logerr("BQ CLIENT bqSendNoAuth: uniqueId has small count of chars")
    save = true
  }

  if ("runCount" not in blk || !(blk.runCount instanceof Integer) || blk.runCount < 0) {
    blk.runCount <- 0;
    save = true
  }

  if (start)
    blk.runCount += 1

  if (start || save)
    save_common_local_settings()

  local table = { "run" : blk.runCount }
  if (blk?.autologin == true)
    table.auto <- true

  bq_client_no_auth(event, blk.uniqueId, table)
}


function bqSendNoAuthStart() {
  if (bqStat.sendStartOnce)
    return
  bqSendNoAuth("start", true)
  bqStat.sendStartOnce = true
}


function bqSendNoAuthWeb(event) {
  bqSendNoAuth(hasFeature("AllowExternalLink") ? $"web:{event}"
                                               : $"web:{event}:disabled")
}


function bqSendLoginState(table) {
  let blk = get_common_local_settings_blk()

  table.uniq <- blk?.uniqueId ?? ""
  table.run  <- blk?.runCount ?? -1
  if (blk?.autologin == true)
    table.auto <- true

  add_user_info(table)
  let params = object_to_json_string(table)

  sendBqEvent("CLIENT_LOGIN_2", "login_state", table)
  log($"BQ CLIENT login_state {params}")
}


return {
  bqSendNoAuth,
  bqSendNoAuthStart,
  bqSendNoAuthWeb,

  bqSendLoginState
}
