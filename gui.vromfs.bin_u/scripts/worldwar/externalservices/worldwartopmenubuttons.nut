local { addButtonConfig } = require("scripts/mainmenu/topMenuButtonsConfigs.nut")
local { getOperationById, getMapByName
} = require("scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")

local template = {
  category = -1
  value = @() ::g_world_war_render.isCategoryEnabled(category)
  onChangeValueFunc = @(value) ::g_world_war_render.setCategory(category, value)
  isHidden = @(...) !::g_world_war_render.isCategoryVisible(category)
  elementType = TOP_MENU_ELEMENT_TYPE.CHECKBOX
}

local list = {
  WW_MAIN_MENU = {
    text = "#worldWar/menu/mainMenu"
    onClickFunc = @(obj, handler) ::g_world_war.openOperationsOrQueues()
    elementType = TOP_MENU_ELEMENT_TYPE.BUTTON
  }
  WW_OPERATIONS = {
    text = "#worldWar/menu/selectOperation"
    onClickFunc = function(obj, handler)
    {
      local curOperation = getOperationById(::ww_get_operation_id())
      if (!curOperation)
        return ::g_world_war.openOperationsOrQueues()

      ::g_world_war.openOperationsOrQueues(false, getMapByName(curOperation.data.map))
    }
    isHidden = @(...) !::has_feature("WWOperationsList")
    elementType = TOP_MENU_ELEMENT_TYPE.BUTTON
  }
  WW_HANGAR = {
    text = "#worldWar/menu/quitToHangar"
    onClickFunc = @(obj, handler) ::g_world_war.stopWar()
    elementType = TOP_MENU_ELEMENT_TYPE.BUTTON
  }
  WW_FILTER_RENDER_ZONES = {
    category = ::ERC_ZONES
    text = ::loc("worldwar/renderMap/render_zones")
    image = @() "#ui/gameuiskin#render_zones"
  }
  WW_FILTER_RENDER_ARROWS = {
    category = ::ERC_ALL_ARROWS
    text = ::loc("worldwar/renderMap/render_arrows")
    image = @() "#ui/gameuiskin#btn_weapons.svg"
    isHidden = @(...) true
  }
  WW_FILTER_RENDER_ARROWS_FOR_SELECTED = {
    category = ::ERC_ARROWS_FOR_SELECTED_ARMIES
    text = ::loc("worldwar/renderMap/render_arrows_for_selected")
    image = @() "#ui/gameuiskin#render_arrows"
  }
  WW_FILTER_RENDER_BATTLES = {
    category = ::ERC_BATTLES
    text = ::loc("worldwar/renderMap/render_battles")
    image = @() "#ui/gameuiskin#battles_open"
  }
  WW_FILTER_RENDER_MAP_PICTURES = {
    category = ::ERC_MAP_PICTURE
    text = ::loc("worldwar/renderMap/render_map_picture")
    image = @() "#ui/gameuiskin#battles_open"
    isHidden = @(...) true
  }
  WW_FILTER_RENDER_DEBUG = {
    value = @() ::g_world_war.isDebugModeEnabled()
    text = "#mainmenu/btnDebugUnlock"
    image = @() "#ui/gameuiskin#battles_closed"
    onChangeValueFunc = @(value) ::g_world_war.setDebugMode(value)
    isHidden = @(...) !::has_feature("worldWarMaster")
  }
}

list.each(@(buttonCfg, name) addButtonConfig(template.__merge(buttonCfg), name))
