//checked for plus_string
from "%scripts/dagui_library.nut" import *


let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let regexp2 = require("regexp2")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { is_chat_message_empty } = require("chat")
let { clearBorderSymbols } = require("%sqstd/string.nut")
let { setFocusToNextObj } = require("%sqDagui/daguiUtil.nut")
let { select_editbox } = require("%scripts/baseGuiHandlerManagerWT.nut")

gui_handlers.modifyUrlMissionWnd <- class extends gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/missions/modifyUrlMission.blk"

  validateNameRegexp = regexp2(@"[""'*/\\\^`~]")

  urlMission = null //when null - create new urlMission

  curName = ""
  curUrl = ""
  isValuesValid = false

  tabFocusArray = [
    "name_editbox",
    "url_editbox",
  ]

  function initScreen() {
    let title = this.urlMission ? loc("urlMissions/modify") : loc("urlMissions/add")
    this.scene.findObject("title").setValue(title)

    if (this.urlMission) {
      this.scene.findObject("name_editbox").setValue(this.urlMission.name)
      this.scene.findObject("url_editbox").setValue(this.urlMission.url)
    }
    else
      this.scene.findObject("btn_apply").setValue(loc("chat/create"))

    select_editbox(this.scene.findObject("name_editbox"))
  }

  function onChangeName(obj) {
    if (!obj)
      return

    this.curName = obj.getValue() || ""
    let validatedName = this.getValidatedCurName()

    if (this.curName != validatedName) {
      obj.setValue(validatedName)
      return
    }

    this.curName = validatedName
    this.checkValues()
  }

    function onChangeUrl(obj) {
    if (!obj)
      return
    this.curUrl = obj.getValue() || ""
    this.checkValues()
  }

  function checkValues() {
    this.isValuesValid = !is_chat_message_empty(this.curName)
      && !is_chat_message_empty(this.curUrl)

    this.scene.findObject("btn_apply").enable(this.isValuesValid)
  }

  function onApply() {
    if (!this.isValuesValid)
      return showInfoMsgBox(loc("msg/allFieldsMustBeFilled"))

    local res = true
    let name = clearBorderSymbols(this.curName, [" "])
    let url = clearBorderSymbols(this.curUrl, [" "])
    if (this.urlMission)
      res = ::g_url_missions.modifyMission(this.urlMission, name, url)
    else
      res = ::g_url_missions.createMission(name, url)

    if (res)
      this.goBack()
  }

  function getValidatedCurName() {
    return this.validateNameRegexp.replace("", this.curName)
  }

  onKbdWrapDown = @() setFocusToNextObj(this.scene, this.tabFocusArray, 1)
}
