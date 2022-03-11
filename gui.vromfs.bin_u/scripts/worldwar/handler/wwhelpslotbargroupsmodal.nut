local time = require("scripts/time.nut")

const LAST_SEEN_SAVE_ID = "seen/help/wwar_slotbar_groups"

class ::gui_handlers.WwHelpSlotbarGroupsModal extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/help/helpWndCustom.blk"

  function initScreen()
  {
    local title = " ".concat(::loc("hotkeys/ID_HELP"), ::loc("ui/mdash"), ::loc("worldwar/vehicleGroups"))
    scene.findObject("wnd_title").setValue(title)

    guiScene.replaceContent(scene.findObject("wnd_content"), "gui/help/wwarSlotbarGroups.blk", this)
    fillLinkLines()
  }

  function fillLinkLines()
  {
    local linkContainer = scene.findObject("wnd_content")
    local linkLinesConfig = {
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

    local markup = ::LinesGenerator.getLinkLinesMarkup(linkLinesConfig)
    local obj = scene.findObject("link_lines_block")
    obj.show(true)
    guiScene.replaceContentFromText(obj, markup, markup.len(), this)
  }
}

local lastSeen = null

local function isUnseen() {
  lastSeen = lastSeen ?? ::load_local_account_settings(LAST_SEEN_SAVE_ID, 0)
  return lastSeen < ::get_charserver_time_sec() - (4 * time.TIME_WEEK_IN_SECONDS)
}

local function open() {
  lastSeen = ::get_charserver_time_sec()
  ::save_local_account_settings(LAST_SEEN_SAVE_ID, lastSeen)
  ::handlersManager.loadHandler(::gui_handlers.WwHelpSlotbarGroupsModal)
}

return {
  isUnseen = isUnseen
  open = open
}
