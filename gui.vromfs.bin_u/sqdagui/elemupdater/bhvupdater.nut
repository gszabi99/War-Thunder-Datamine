#explicit-this
#no-root-fallback

let u = require("%sqStdLibs/helpers/u.nut")
let elemViewType = require("%sqDagui/elemUpdater/elemViewType.nut")
let elemEvents = require("%sqDagui/elemUpdater/elemUpdaterEvents.nut")
let Callback = require("%sqStdLibs/helpers/callback.nut").Callback
let { popBhvValueConfig } = require("%sqDagui/guiBhv/guiBhvValueConfig.nut")
let { check_obj } = require("%sqDagui/daguiUtil.nut")

local assertOnce = function(_uniqId, errorText) { throw(errorText) }

let BhvUpdater = class {
  eventMask    = EV_ON_CMD
  valuePID     = ::dagui_propid.add_name_id("value")

  function onAttach(obj) {
    if (obj?.value) {
      try {
        //script crash will cause game crash, because we nee retcode here.
        this.setNewConfig(obj, elemViewType.buildBhvConfig(obj.value))
      }
      catch (errorMessage) {
        assertOnce("bhvUpdater failed attach", $"bhvUpdater: failed to attach value: {errorMessage}")
      }
    }
    this.updateView(obj)
    return RETCODE_NOTHING
  }

  function setValue(obj, valueTbl) {
    let value = type(valueTbl) == "integer"
      ? popBhvValueConfig(valueTbl)
      : valueTbl
    if (this.setNewConfig(obj, elemViewType.buildBhvConfig(value)))
      this.updateView(obj)
    return u.isString(value) || u.isTable(value)
  }

  function setNewConfig(obj, config) {
    if (u.isEqual(config, obj.getUserData()))
      return false
    obj.setUserData(config) //this is single direct link to config.
                            //So destroy object, or change user data invalidate old subscriptions.
    if (config) {
      let subscriptions = config.viewType.model.makeFullPath(config.subscriptions)
      elemEvents.subscribe(subscriptions, Callback(this.getOnChangedCb(obj), config))
      config.lastEventId <- -1
    }
    return true
  }

  function getOnChangedCb(obj) {
    let bhvClass = this
    return @(eventId) check_obj(obj) && bhvClass.updateView(obj, eventId)
  }

  function updateView(obj, eventId = -2) {
    let config = obj.getUserData()
    if (!config || config.lastEventId == eventId)
      return

    config.lastEventId = eventId
    try {
      config.viewType.updateView(obj, config)
    }
    catch (errorMessage) {
      assertOnce("bhvUpdater failed view update", $"bhvUpdater: failed to update view {config.viewType.id}: {errorMessage}")
    }
  }
}

::replace_script_gui_behaviour("bhvUpdater", BhvUpdater)

return {
  setAssertFunction = @(func) assertOnce = func  //void func(uniqId, assertText)
}