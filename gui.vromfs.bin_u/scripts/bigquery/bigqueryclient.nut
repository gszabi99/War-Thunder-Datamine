from "%scripts/dagui_library.nut" import *
#strict
#allow-root-table

let { get_local_unixtime   } = require("dagor.time")
let { grnd                 } = require("dagor.random")
let { format               } = require("string")
let { to_string            } = require("json")
let { getDistr             } = require("auth_wt")
let { get_user_system_info } = require("sysinfo")

local bqStat = persist("bqStat", @(){sendStartOnce=false})


let function get_distr()
{
  local distr = getDistr()
  if (distr.len() > 0)
    return distr

  let config = ::get_settings_blk()
  distr = config?.distr ?? config?.originalConfigBlk.distr

  return (typeof distr == "string" && distr.len() > 0) ? distr : ""
}


let function add_sysinfo(table)
{
  let sysinfo = get_user_system_info()

  local uuid = ""
  foreach (u in ["uuid0", "uuid2"])  // biosUuid, systemHddId
  {
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

  assert(target_platform.len() > 0)
  table.os <- target_platform
}


let function add_user_info(table)
{
  add_sysinfo(table)

  let distr = get_distr()
  if (distr.len() > 0)
    table.distr <- distr

  let userId = ::get_player_user_id_str().tointeger()
  if (userId > 0)
    table.uid <- userId

  if (::steam_is_running())
    table.steam <- true

  let steamId = ::steam_get_my_id()
  if (steamId.len() > 0)
    table.steamId <- steamId

  if (::epic_is_running())
    table.epic <- true

  if (::is_dev_version)
    table.dev <- true
}


let function bq_client_noa(event, uniqueId, table)
{
  add_user_info(table)
  let params  = to_string(table)
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

  ::ww_leaderboard.request(request, function(response){})  // cloud-server
  log($"BQ CLIENT_NOA {event} {params} [{uniqueId}]")
}


let function bqSendStart()  // NOTE: call after 'reset PlayerProfile' in log
{
  if (bqStat.sendStartOnce)
    return

  local blk = ::get_common_local_settings_blk()

  if ("uniqueId" not in blk || typeof blk.uniqueId != "string" || blk.uniqueId.len() < 16)
  {
    blk.uniqueId <- format("%.8X%.8X", get_local_unixtime(), grnd()*grnd())
    assert(blk.uniqueId.len() == 16)
  }

  if ("runCount" not in blk || typeof blk.runCount != "integer" || blk.runCount < 0)
  {
    blk.runCount <- 0;
  }
  blk.runCount += 1

  ::save_common_local_settings()

  local table = {"run": blk.runCount}
  if (blk?.autologin == true)
    table.auto <- true

  bq_client_noa("start", blk.uniqueId, table)

  bqStat.sendStartOnce = true
}


let function bqSendLoginState(table)
{
  let blk = ::get_common_local_settings_blk()

  table.uniq <- blk?.uniqueId ?? ""
  table.run  <- blk?.runCount ?? -1
  if (blk?.autologin == true)
    table.auto <- true

  add_user_info(table)
  let params = to_string(table)

  ::add_big_query_record("login_state", params)
  log($"BQ CLIENT login_state {params}")
}


return {
  bqSendStart,
  bqSendLoginState
}
