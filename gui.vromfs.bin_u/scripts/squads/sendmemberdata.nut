from "%scripts/dagui_library.nut" import *

let { setTimeout, clearTimer } = require("dagor.workcycle")
let { userIdInt64 } = require("%scripts/user/profileStates.nut")
let { request_matching } = require("%scripts/matching/api.nut")

let cache = {}
local timer = null

function sendFullDataToMatching(data) {
  request_matching("msquad.set_member_data", null, null, { userId = userIdInt64.get(), data })
}

function updateDataOnMatching() {
  request_matching("msquad.update_member_data_json", null, null, { data = cache })
  cache.clear()
  clearTimer(timer)
  timer = null
}

function collectDataForSending(data) {
  cache.__update(data)
  if (timer == null)
    timer = setTimeout(2, @() updateDataOnMatching())
}

function sendMemberDataToMatching(data, needSendFullData) {
  if (needSendFullData) {
    cache.clear()
    sendFullDataToMatching(data)
    return
  }

  if (data.len() == 0)
    return

  collectDataForSending(data)
}

return {
  sendMemberDataToMatching
}