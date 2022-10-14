let {show_profile_card} = require("%xboxLib/impl/user.nut")
let {request_xuid_for_uid} = require("%xboxLib/externalIds.nut")
let {uid2xbox} = require("%xboxLib/userIds.nut")
let {subscribe} = require("eventbus")

let eventNameUid = "showXboxUserInfo"
let eventNameXuid = "showXboxUserInfoXuid"


let function show_user_info_xuid(live_xuid) {
  if (live_xuid)
    show_profile_card(live_xuid.tointeger(), null)
}


let function show_user_info_uid(userId) {
  let uid = userId.tostring()
  if (uid in uid2xbox.value) {
    show_user_info_xuid(uid2xbox.value[uid])
  } else {
    request_xuid_for_uid(uid, function(_, xuid) {
      show_user_info_xuid(xuid)
    })
  }
}


subscribe(eventNameUid, @(msg) show_user_info_uid(msg.userId.tointeger()))
subscribe(eventNameXuid, @(msg) show_user_info_xuid(msg.xuid.tointeger()))
