from "%scripts/dagui_natives.nut" import xbox_on_login, is_online_available
from "%scripts/dagui_library.nut" import *
let logX = require("%sqstd/log.nut")().with_prefix("[XBOX_PURCH] ")
let {is_any_user_active} = require("%gdkLib/impl/user.nut")
let {addTask} = require("%scripts/tasker.nut")
let {isInHangar} = require("gameplayBinding")
let { updateEntitlementsLimited } = require("%scripts/onlineShop/entitlementsUpdate.nut")
let {native_login} = require("%scripts/gdk/loginState.nut")


local callbackReturnFunc = null


function xbox_on_purchases_updated() {
  if (!is_online_available())
    return

  addTask(updateEntitlementsLimited(),
                     {
                       showProgressBox = true
                       progressBoxText = loc("charServer/checking")
                     },
                     Callback(function() {
                       if (callbackReturnFunc) {
                         callbackReturnFunc()
                         callbackReturnFunc = null
                       }
                     }, this)
                    )
}


let set_xbox_on_purchase_cb = @(cb) callbackReturnFunc = cb


function update_purchases() {
  logX("Update purchases")
  if (!(is_any_user_active() && isInHangar())) {
    logX("Not in hangar or no user active => skip update")
    return
  }
  native_login(false, "xbox_purch_login", function(result) {
    let success = result == YU2_OK
    logX($"Login succeeded: {success}")
    if (success) {
      xbox_on_purchases_updated()
    }
  })
}


return {
  update_purchases
  set_xbox_on_purchase_cb
}