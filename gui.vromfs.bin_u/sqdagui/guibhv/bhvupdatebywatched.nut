from "%sqDagui/daguiNativeApi.nut" import *

let { popBhvValueConfig } = require("%sqDagui/guiBhv/guiBhvValueConfig.nut")
let { isTable, isArray } = require("%sqStdLibs/helpers/u.nut")







local assertOnce = function(_uniqId, errorText) {
  throw(errorText)
}

let bhvUpdateByWatched = class {
  eventMask    = EV_ON_CMD
  valuePID     = dagui_propid_add_name_id("value")

  function onAttach(obj) {
    if ((obj?.value ?? "") != "")
      this.updateSubscriptions(obj, obj.value.tointeger())
    return RETCODE_NOTHING
  }

  function onDetach(obj) {
    this.removeSubscriptions(obj)
    return RETCODE_NOTHING
  }

  function setValue(obj, value) {
    this.removeSubscriptions(obj)
    this.updateSubscriptions(obj, value)
  }

  function removeSubscriptions(obj) {
    let subscriptions = obj.getUserData()
    if ((subscriptions?.len() ?? 0) == 0)
      return

    foreach (subscription in subscriptions)
      subscription.watch.unsubscribe(subscription.updateObjectFunc)
  }

  function updateSubscriptions(obj, value) {
    let subscriptions = []
    local configs = popBhvValueConfig(value)
    if (configs == null)
      return

    if (!isTable(configs) && !isArray(configs)) {
      assertOnce("bhvUpdater_not_valid_config", "bhvUpdater: pop not valid config")
      return
    }

    if (!isArray(configs))
      configs = [configs]

    foreach (config in configs) {
      let watch = config?.watch
      let updateFunc = config?.updateFunc
      if (watch == null || updateFunc == null)
        continue

      let updateObjectFunc = @(watchValue) updateFunc(obj, watchValue)
      updateObjectFunc(watch.get())
      watch.subscribe(updateObjectFunc)
      subscriptions.append({
        watch = watch
        updateObjectFunc = updateObjectFunc
      })
    }

    obj.setUserData(subscriptions)
  }
}

replace_script_gui_behaviour("bhvUpdateByWatched", bhvUpdateByWatched)

return {
  setAssertFunction = @(func) assertOnce = func  
}
