from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { clearBorderSymbols } = require("%sqstd/string.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

::gui_handlers.AddRadioModalHandler <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/popup/addRadio.blk"

  editStationName = ""

  function initScreen()
  {
    ::select_editbox(scene.findObject("newradio_name"))
    let nameRadio = loc("options/internet_radio_" + ((editStationName == "") ? "add" : "edit"))
    let titleRadio = scene.findObject("internet_radio_title")
    titleRadio.setValue(nameRadio)
    let btnAddRadio = scene.findObject("btn_add_radio")
    btnAddRadio.setValue(nameRadio)
    if (editStationName != "")
    {
      let editName = scene.findObject("newradio_name")
      editName.setValue(editStationName)
      let editUrl = scene.findObject("newradio_url")
      let url = ::get_internet_radio_path(editStationName)
      editUrl.setValue(url)
    }
  }

  function onChanged()
  {
    local msg = getMsgByEditbox("url")
    if (msg == "")
      msg = getMsgByEditbox("name")
    let btnAddRadio = scene.findObject("btn_add_radio")
    btnAddRadio.enable((msg != "") ? false : true)
    btnAddRadio.tooltip = msg
  }

  function getMsgByEditbox(name)
  {
    let isEmpty = ::is_chat_message_empty(scene.findObject("newradio_"+name).getValue())
    return isEmpty ? loc("options/no_"+name+"_radio") : ""
  }

  onFocusUrl = @() ::select_editbox(scene.findObject("newradio_url"))

  function onAddRadio()
  {
    let value = scene.findObject("newradio_name").getValue()
    if (::is_chat_message_empty(value))
      return

    let name = clearBorderSymbols(value, [" "])
    local url = scene.findObject("newradio_url").getValue()
    if(url != "")
      url = clearBorderSymbols(url, [" "])

    if (name == "")
      return this.msgBox("warning",
          loc("options/no_name_radio"),
          [["ok", function() {}]], "ok")
    if (url == "")
      return this.msgBox("warning",
          loc("options/no_url_radio"),
          [["ok", function() {}]], "ok")

    let listRadio = ::get_internet_radio_stations()
    if (editStationName != "")
    {
      ::edit_internet_radio_station(editStationName, name, url)
    } else {
      foreach (radio in listRadio)
      {
        if (radio == name)
          return this.msgBox("warning",
            loc("options/msg_name_exists_radio"),
            [["ok", function() {}]], "ok")
        if (radio == url)
          return this.msgBox("warning",
            loc("options/msg_url_exists_radio"),
            [["ok", function() {}]], "ok")
      }
      ::add_internet_radio_station(name, url);
    }
    goBack()
    ::broadcastEvent("UpdateListRadio", {})
  }
}

return {
  openAddRadioWnd = @(editStationName = "") ::handlersManager.loadHandler(
    ::gui_handlers.AddRadioModalHandler,
    { editStationName = editStationName }
  )
}