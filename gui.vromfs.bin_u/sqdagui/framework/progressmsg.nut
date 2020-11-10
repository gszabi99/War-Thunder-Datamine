local Callback = require("sqStdLibs/helpers/callback.nut").Callback

local msgList = {}

local buttonsDelayDefault = 30
local textLocIdDefault = ""

local Msg = class {
  text = null //string. ::loc(textLocIdDefault) when not set
  onCancelCb = null
  buttonsDelay = null //int. buttonsDelayDefault when not set

  uid = ""
  showCount = 0
  sceneObj = null

  constructor(_uid, config)
  {
    uid = _uid
    incrementImpl(config)
  }

  isValid = @() showCount > 0 && ::check_obj(sceneObj)

  function applyConfig(config)
  {
    local hasSceneChanges = false
    foreach(key in ["text", "onCancelCb", "buttonsDelay"])
      if ((key in config) && this[key] != config[key])
      {
        if (key != "onCancelCb")
          hasSceneChanges = true
        this[key] = config[key]
      }
    return hasSceneChanges
  }

  function increment(config)
  {
    if (!isValid())
      showCount = 0
    incrementImpl(config)
  }

  function incrementImpl(config)
  {
    showCount++
    local hasSceneChanges = applyConfig(config) || !::check_obj(sceneObj)
    if (!hasSceneChanges)
      return

    local prevSceneObj = sceneObj //destroy previous message only after create new to not activate handlers behind on switch.

    local cancelCb = Callback(function() {
      if (onCancelCb)
        onCancelCb()
      destroy()
    }, this)

    sceneObj = ::scene_msg_box(
      "progressMsg_" + uid,
      ::get_cur_gui_scene(),
      text ?? ::loc(textLocIdDefault),
      [["cancel", cancelCb]],
      "cancel",
      {
        waitAnim = true
        delayedButtons = buttonsDelay ?? buttonsDelayDefault
      }
    )

    ::destroyMsgBox(prevSceneObj)
  }

  function decrement()
  {
    showCount--
    if (!isValid())
      destroy()
  }

  function destroy()
  {
    if (uid in msgList)
      delete msgList[uid]
    ::destroyMsgBox(sceneObj)
  }
}

return {
  create = @(uid, config) uid in msgList ? msgList[uid].increment(config) : msgList[uid] <- Msg(uid, config)

  destroy = function(uid, shouldCheckCounter = false) {
    local msg = msgList?[uid]
    if (!msg)
      return
    if (shouldCheckCounter)
      msg.decrement()
    else
      msg.destroy()
  }

  setButtonsDelayDefault   = function(value) { buttonsDelayDefault = value }
  setTextLocIdDefault      = function(value) { textLocIdDefault = value }
}