from "%scripts/dagui_library.nut" import *

let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let time = require("%scripts/time.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { get_charserver_time_sec } = require("chard")

const LAST_SEEN_SAVE_ID = "seen/help/wwar_slotbar_groups"

gui_handlers.WwHelpSlotbarGroupsModal <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/help/helpWndCustom.blk"

  function initScreen() {
    let title = " ".concat(loc("hotkeys/ID_HELP"), loc("ui/mdash"), loc("worldwar/vehicleGroups"))
    this.scene.findObject("wnd_title").setValue(title)

    this.guiScene.replaceContent(this.scene.findObject("wnd_content"), "%gui/help/wwarSlotbarGroups.blk", this)
    this.fillLinkLines()
  }

  function fillLinkLines() {
    let linkContainer = this.scene.findObject("wnd_content")
    let linkLinesConfig = {
      startObjContainer = linkContainer
      endObjContainer = linkContainer
      lineInterval = "@helpLineInterval"
      obstacles = null
      links = [
        { start = "gen_preset_btn_label", end = "gen_preset_btn_frame" }
        { start = "sel_unit_label", end = "sel_unit_point" }
        { start = "sel_group_label", end = "sel_group_point" }
        { start = "change_unit_label", end = "change_unit_frame" }
        { start = "unit_premium_label", end = "unit_premium_frame" }
        { start = "unit_unavailable_label", end = "unit_unavailable_frame" }
        { start = "change_group_label", end = "change_group_frame" }
        { start = "crew_skills_label", end = "crew_skills_frame" }
        { start = "crew_level_label", end = "crew_level_point" }
      ]
    }

    let markup = ::LinesGenerator.getLinkLinesMarkup(linkLinesConfig)
    let obj = this.scene.findObject("link_lines_block")
    obj.show(true)
    this.guiScene.replaceContentFromText(obj, markup, markup.len(), this)
  }
}

local lastSeen = null

function isUnseen() {
  lastSeen = lastSeen ?? loadLocalAccountSettings(LAST_SEEN_SAVE_ID, 0)
  return lastSeen < get_charserver_time_sec() - (4 * time.TIME_WEEK_IN_SECONDS)
}

function open() {
  lastSeen = get_charserver_time_sec()
  saveLocalAccountSettings(LAST_SEEN_SAVE_ID, lastSeen)
  handlersManager.loadHandler(gui_handlers.WwHelpSlotbarGroupsModal)
}

return {
  isUnseen = isUnseen
  open = open
}
