local u = require("sqStdLibs/helpers/u.nut")
local elemViewType = require("sqDagui/elemUpdater/elemViewType.nut")
local elemEvents = require("sqDagui/elemUpdater/elemUpdaterEvents.nut")
local Callback = require("sqStdLibs/helpers/callback.nut").Callback

local assertOnce = function(uniqId, errorText) { throw(errorText) }

local BhvUpdater = class
{
  eventMask    = ::EV_ON_CMD
  valuePID     = ::dagui_propid.add_name_id("value")

  function onAttach(obj)
  {
    if (obj?.value)
    {
      try //script crash will cause game crash, because we nee retcode here.
      {
        setNewConfig(obj, elemViewType.buildBhvConfig(obj.value))
      }
      catch (errorMessage)
      {
        assertOnce("bhvUpdater failed attach", "bhvUpdater: failed to attach value: " + errorMessage)
      }
    }
    updateView(obj)
    return ::RETCODE_NOTHING
  }

  function setValue(obj, valueTbl)
  {
    if (setNewConfig(obj, elemViewType.buildBhvConfig(valueTbl)))
      updateView(obj)
    return u.isString(valueTbl) || u.isTable(valueTbl)
  }

  function setNewConfig(obj, config)
  {
    if (u.isEqual(config, obj.getUserData()))
      return false
    obj.setUserData(config) //this is single direct link to config.
                            //So destroy object, or change user data invalidate old subscriptions.
    if (config)
    {
      local subscriptions = config.viewType.model.makeFullPath(config.subscriptions)
      elemEvents.subscribe(subscriptions, Callback(getOnChangedCb(obj), config))
      config.lastEventId <- -1
    }
    return true
  }

  function getOnChangedCb(obj)
  {
    local bhvClass = this
    return @(eventId) ::check_obj(obj) && bhvClass.updateView(obj, eventId)
  }

  function updateView(obj, eventId = -2)
  {
    local config = obj.getUserData()
    if (!config || config.lastEventId == eventId)
      return

    config.lastEventId = eventId
    try
    {
      config.viewType.updateView(obj, config)
    }
    catch (errorMessage)
    {
      assertOnce("bhvUpdater failed view update", "bhvUpdater: failed to update view " + config.viewType.id + ": " + errorMessage)
    }
  }
}

::replace_script_gui_behaviour("bhvUpdater", BhvUpdater)

return {
  setAssertFunction = @(func) assertOnce = func  //void func(uniqId, assertText)
}