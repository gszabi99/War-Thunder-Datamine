#explicit-this
#no-root-fallback

let { loc } = require("dagor.localize")
let Callback = require("%sqStdLibs/helpers/callback.nut").Callback
let { check_obj } = require("%sqDagui/daguiUtil.nut")

let msgList = {}

local buttonsDelayDefault = 30
local textLocIdDefault = ""

let class Msg {
  text = null //string. loc(textLocIdDefault) when not set
  onCancelCb = null
  buttonsDelay = null //int. buttonsDelayDefault when not set

  uid = ""
  showCount = 0
  sceneObj = null

  constructor(uid_, config) {
    this.uid = uid_
    this.incrementImpl(config)
  }

  isValid = @() this.showCount > 0 && check_obj(this.sceneObj)

  function applyConfig(config) {
    local hasSceneChanges = false
    foreach (key in ["text", "onCancelCb", "buttonsDelay"])
      if ((key in config) && this[key] != config[key]) {
        if (key != "onCancelCb")
          hasSceneChanges = true
        this[key] = config[key]
      }
    return hasSceneChanges
  }

  function increment(config) {
    if (!this.isValid())
      this.showCount = 0
    this.incrementImpl(config)
  }

  function incrementImpl(config) {
    this.showCount++
    let hasSceneChanges = this.applyConfig(config) || !check_obj(this.sceneObj)
    if (!hasSceneChanges)
      return

    let prevSceneObj = this.sceneObj //destroy previous message only after create new to not activate handlers behind on switch.

    let cancelCb = Callback(function() {
      if (this.onCancelCb)
        this.onCancelCb()
      this.destroy()
    }, this)

    this.sceneObj = ::scene_msg_box(
      $"progressMsg_{this.uid}" ,
      ::get_cur_gui_scene(),
      this.text ?? loc(textLocIdDefault),
      [["cancel", cancelCb]],
      "cancel",
      {
        waitAnim = true
        delayedButtons = this.buttonsDelay ?? buttonsDelayDefault
      }
    )

    ::destroyMsgBox(prevSceneObj)
  }

  function decrement() {
    this.showCount--
    if (!this.isValid())
      this.destroy()
  }

  function destroy() {
    if (this.uid in msgList)
      delete msgList[this.uid]
    ::destroyMsgBox(this.sceneObj)
  }
}

return {
  function create(uid, config) {
    if (uid in msgList)
      msgList[uid].increment(config)
    else
      msgList[uid] <- Msg(uid, config)
  }

  function destroy(uid, shouldCheckCounter = false) {
    let msg = msgList?[uid]
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