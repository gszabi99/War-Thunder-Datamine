#strict
#allow-root-table

let { get_local_unixtime } = require("dagor.time")
let { grnd               } = require("dagor.random")
let { format             } = require("string")
let { to_string          } = require("json")


let function add_user_info(table)
{
  let distr = ::get_settings_blk()?.distr ?? ""
  if (distr.len() > 0)
    table.distr <- distr

  let userId = ::get_player_user_id_str().tointeger()
  if (userId > 0)
    table.uid <- userId

  assert(::target_platform.len() > 0)
  table.os <- ::target_platform
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


let function bqSendStart()
{
  // NOTE: call after 'reset PlayerProfile' in log
  local uniqueId = ::load_local_shared_settings("uniqueId")
  if (uniqueId == null || typeof uniqueId != "string" || uniqueId.len() < 16)
  {
    uniqueId = format("%.8X%.8X", get_local_unixtime(), grnd()*grnd())
    assert(uniqueId.len() == 16)
    ::save_local_shared_settings("uniqueId", uniqueId)
  }
  local runCount = ::load_local_shared_settings("runCount", 0)
  runCount += 1
  ::save_local_shared_settings("runCount", runCount)

  bq_client_noa("start", uniqueId, {"run": runCount})
}


let function bqSendLoginState(table)
{
  table.uniq <- ::load_local_shared_settings("uniqueId", "")
  table.run  <- ::load_local_shared_settings("runCount", -1)
  add_user_info(table)
  let params = to_string(table)

  ::add_big_query_record("login_state", params)
  ::dagor.debug($"BQ CLIENT login_state {params}")
}


return {
  bqSendStart,
  bqSendLoginState
}
