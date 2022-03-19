local { popBhvValueConfig } = require("sqDagui/guiBhv/guiBhvValueConfig.nut")
local { isTable, isArray } = require("sqStdLibs/helpers/u.nut")

/*
  behaviour config params it is table or array of tables with value pairs:
    watch  - watched for subscribe this
    updateFunc - method for update object by watched value
*/

local function assertOnce(uniqId, errorText) {
  throw(errorText)
}

local bhvUpdateByWatched = class {
  eventMask    = ::EV_ON_CMD
  valuePID     = ::dagui_propid.add_name_id("value")

  function onAttach(obj) {
    if ((obj?.value ?? "") != "")
      updateSubscriptions(obj, obj.value.tointeger())
    return ::RETCODE_NOTHING
  }

  function onDetach(obj) {
    removeSubscriptions(obj)
    return ::RETCODE_NOTHING
  }

  function setValue(obj, value) {
    removeSubscriptions(obj)
    updateSubscriptions(obj, value)
  }

  function removeSubscriptions(obj) {
    local subscriptions = obj.getUserData()
    if ((subscriptions?.len() ?? 0) == 0)
      return

    foreach (subscription in subscriptions)
      subscription.watch.unsubscribe(subscription.updateObjectFunc)
  }

  function updateSubscriptions(obj, value) {
    local subscriptions = []
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
      local watch = config?.watch
      local updateFunc = config?.updateFunc
      if (watch == null || updateFunc == null)
        continue

      local updateObjectFunc = @(watchValue) updateFunc(obj, watchValue)
      updateObjectFunc(watch.value)
      watch.subscribe(updateObjectFunc)
      subscriptions.append({
        watch = watch
        updateObjectFunc = updateObjectFunc
      })
    }

    obj.setUserData(subscriptions)
  }
}

::replace_script_gui_behaviour("bhvUpdateByWatched", bhvUpdateByWatched)

return {
  setAssertFunction = @(func) assertOnce = func  //void func(uniqId, assertText)
}
