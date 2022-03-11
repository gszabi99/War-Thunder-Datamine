local { clearBorderSymbols } = require("std/string.nut")
local { setFocusToNextObj } = require("sqDagui/daguiUtil.nut")

class ::gui_handlers.modifyUrlMissionWnd extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/missions/modifyUrlMission.blk"

  validateNameRegexp = regexp2(@"[""'*/\\\^`~]")

  urlMission = null //when null - create new urlMission

  curName = ""
  curUrl = ""
  isValuesValid = false

  tabFocusArray = [
    "name_editbox",
    "url_editbox",
  ]

  function initScreen()
  {
    local title = urlMission ? ::loc("urlMissions/modify") : ::loc("urlMissions/add")
    scene.findObject("title").setValue(title)

    if (urlMission)
    {
      scene.findObject("name_editbox").setValue(urlMission.name)
      scene.findObject("url_editbox").setValue(urlMission.url)
    } else
      scene.findObject("btn_apply").setValue(::loc("chat/create"))

    ::select_editbox(scene.findObject("name_editbox"))
  }

  function onChangeName(obj)
  {
    if (!obj)
      return

    curName = obj.getValue() || ""
    local validatedName = getValidatedCurName()

    if (curName != validatedName)
    {
      obj.setValue(validatedName)
      return
    }

    curName = validatedName
    checkValues()
  }

    function onChangeUrl(obj)
  {
    if (!obj)
      return
    curUrl = obj.getValue() || ""
    checkValues()
  }

  function checkValues()
  {
    isValuesValid = !::is_chat_message_empty(curName)
                    && !::is_chat_message_empty(curUrl)

    scene.findObject("btn_apply").enable(isValuesValid)
  }

  function onApply()
  {
    if (!isValuesValid)
      return ::showInfoMsgBox(::loc("msg/allFieldsMustBeFilled"))

    local res = true
    local name = clearBorderSymbols(curName, [" "])
    local url = clearBorderSymbols(curUrl, [" "])
    if (urlMission)
      res = ::g_url_missions.modifyMission(urlMission, name, url)
    else
      res = ::g_url_missions.createMission(name, url)

    if (res)
      goBack()
  }

  function getValidatedCurName()
  {
    return validateNameRegexp.replace("", curName)
  }

  onKbdWrapDown = @() setFocusToNextObj(scene, tabFocusArray, 1)
}
