from "%scripts/tasker.nut" import addTask
from "%scripts/onlineShop/entitlementsUpdate.nut" import updateEntitlementsLimited
from "%scripts/gdk/loginState.nut" import native_login
from "%gdkLib/impl/user.nut" import is_any_user_active
from "gameplayBinding" import isInHangar
from "%globalScripts/yuplay2Consts.nut" import *
from "%scripts/dagui_natives.nut" import is_online_available
from "%scripts/dagui_library.nut" import *

let logX = require("%sqstd/log.nut")().with_prefix("[XBOX_PURCH] ")


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


return freeze({
  update_purchases
  set_xbox_on_purchase_cb
})