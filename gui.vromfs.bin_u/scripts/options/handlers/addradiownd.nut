from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { clearBorderSymbols } = require("%sqstd/string.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

::gui_handlers.AddRadioModalHandler <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/popup/addRadio.blk"

  editStationName = ""

  function initScreen()
  {
    ::select_editbox(this.scene.findObject("newradio_name"))
    let nameRadio = loc("options/internet_radio_" + ((this.editStationName == "") ? "add" : "edit"))
    let titleRadio = this.scene.findObject("internet_radio_title")
    titleRadio.setValue(nameRadio)
    let btnAddRadio = this.scene.findObject("btn_add_radio")
    btnAddRadio.setValue(nameRadio)
    if (this.editStationName != "")
    {
      let editName = this.scene.findObject("newradio_name")
      editName.setValue(this.editStationName)
      let editUrl = this.scene.findObject("newradio_url")
      let url = ::get_internet_radio_path(this.editStationName)
      editUrl.setValue(url)
    }
  }

  function onChanged()
  {
    local msg = this.getMsgByEditbox("url")
    if (msg == "")
      msg = this.getMsgByEditbox("name")
    let btnAddRadio = this.scene.findObject("btn_add_radio")
    btnAddRadio.enable((msg != "") ? false : true)
    btnAddRadio.tooltip = msg
  }

  function getMsgByEditbox(name)
  {
    let isEmpty = ::is_chat_message_empty(this.scene.findObject("newradio_"+name).getValue())
    return isEmpty ? loc("options/no_"+name+"_radio") : ""
  }

  onFocusUrl = @() ::select_editbox(this.scene.findObject("newradio_url"))

  function onAddRadio()
  {
    let value = this.scene.findObject("newradio_name").getValue()
    if (::is_chat_message_empty(value))
      return

    let name = clearBorderSymbols(value, [" "])
    local url = this.scene.findObject("newradio_url").getValue()
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
    if (this.editStationName != "")
    {
      ::edit_internet_radio_station(this.editStationName, name, url)
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
    this.goBack()
    ::broadcastEvent("UpdateListRadio", {})
  }
}

return {
  openAddRadioWnd = @(editStationName = "") ::handlersManager.loadHandler(
    ::gui_handlers.AddRadioModalHandler,
    { editStationName = editStationName }
  )
}