#strict
#allow-root-table

let { get_local_unixtime } = require("dagor.time")
let { grnd               } = require("dagor.random")
let { format             } = require("string")
let { to_string          } = require("json")
let { get_user_system_info } = require("sysinfo")


let function add_uuid(table)
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
}

let bqStat = persist("bqStat", @(){sendStartOnce=false, uniqueId="", runCount=0})


let function add_user_info(table)
{
  add_uuid(table)

  let distr = ::get_settings_blk()?.distr ?? ""
  if (distr.len() > 0)
    table.distr <- distr

  let userId = ::get_player_user_id_str().tointeger()
  if (userId > 0)
    table.uid <- userId

  assert(::target_platform.len() > 0)
  table.os <- ::target_platform

  if (::steam_is_running())
    table.steam <- true

  let steamId = ::steam_get_my_id()
  if (steamId.len() > 0)
    table.steamId <- steamId
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
  ::dagor.debug($"BQ CLIENT_NOA {event} {params} [{uniqueId}]")
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

  bqStat.uniqueId = blk.uniqueId
  bqStat.runCount = blk.runCount

  bq_client_noa("start", blk.uniqueId, {"run": blk.runCount})

  bqStat.sendStartOnce = true
}


let function bqSendLoginState(table)
{
  assert(bqStat.sendStartOnce)

  table.uniq <- bqStat.uniqueId
  table.run  <- bqStat.runCount

  add_user_info(table)
  let params = to_string(table)

  ::add_big_query_record("login_state", params)
  ::dagor.debug($"BQ CLIENT login_state {params}")
}


return {
  bqSendStart,
  bqSendLoginState
}
