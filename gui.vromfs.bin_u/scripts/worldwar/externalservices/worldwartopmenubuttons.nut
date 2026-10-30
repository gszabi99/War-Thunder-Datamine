import "%scripts/worldWar/worldWarRender.nut" as g_world_war_render
import "%scripts/worldWar/worldWarUtils.nut" as g_world_war
from "%scripts/mainmenu/topMenuButtons.nut" import addButtonConfig
from "%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut" import getOperationById, hasAvailableMapToBattle, getMapByName
from "%scripts/unlocks/unlocksCache.nut" import getUnlocksByTypeInBlkOrder
from "%scripts/onlineShop/url.nut" import openUrlByObj
from "%scripts/baseGuiHandlerManagerWT.nut" import loadHandler
from "worldwar" import wwGetOperationId, wwIsOperationLoaded
from "worldwarConst" import RenderCategory
from "%scripts/dagui_library.nut" import *
from "%scripts/mainmenu/topMenuConsts.nut" import TOP_MENU_ELEMENT_TYPE
from "%globalScripts/loc_helpers.nut" import getVendorLocId
from "%scripts/seen/seenIds.nut" import SEEN

let { WwLeaderboard } = require("%scripts/worldWar/handler/wwLeaderboard.nut")

let template = {
  category = -1
  value = @() g_world_war_render.isCategoryEnabled(this.category)
  onChangeValueFunc = @(value) g_world_war_render.setCategory(this.category, value)
  isHidden = @(...) !g_world_war_render.isCategoryVisible(this.category)
  elementType = TOP_MENU_ELEMENT_TYPE.CHECKBOX
}

let list = {
  WW_MAIN_MENU = {
    text = "#worldWar/menu/mainMenu"
    onClickFunc = @(_obj, _handler) g_world_war.openOperationsOrQueues()
    elementType = TOP_MENU_ELEMENT_TYPE.BUTTON
  }
  WW_OPERATIONS = {
    text = "#worldWar/menu/selectOperation"
    onClickFunc = function(_obj, _handler) {
      let curOperation = getOperationById(wwGetOperationId())
      if (!curOperation)
        return g_world_war.openOperationsOrQueues()

      g_world_war.openOperationsOrQueues(false, getMapByName(curOperation.data.map))
    }
    isHidden = @(...) !hasFeature("WWOperationsList")
    elementType = TOP_MENU_ELEMENT_TYPE.BUTTON
  }
  WW_HANGAR = {
    text = "#worldWar/menu/quitToHangar"
    onClickFunc = function(_obj, handler) {
      g_world_war.stopWar()
      if (!wwIsOperationLoaded())
        handler?.goBack()
    }
    elementType = TOP_MENU_ELEMENT_TYPE.BUTTON
  }
  WW_FILTER_RENDER_ZONES = {
    category = RenderCategory.ERC_ZONES
    text = loc("worldwar/renderMap/render_zones")
    image = @() "#ui/gameuiskin#render_zones"
  }
  WW_FILTER_RENDER_ARROWS = {
    category = RenderCategory.ERC_ALL_ARROWS
    text = loc("worldwar/renderMap/render_arrows")
    image = @() "#ui/gameuiskin#btn_weapons.svg"
    isHidden = @(...) true
  }
  WW_FILTER_RENDER_ARROWS_FOR_SELECTED = {
    category = RenderCategory.ERC_ARROWS_FOR_SELECTED_ARMIES
    text = loc("worldwar/renderMap/render_arrows_for_selected")
    image = @() "#ui/gameuiskin#render_arrows"
  }
  WW_FILTER_RENDER_BATTLES = {
    category = RenderCategory.ERC_BATTLES
    text = loc("worldwar/renderMap/render_battles")
    image = @() "#ui/gameuiskin#battles_open"
  }
  WW_FILTER_RENDER_MAP_PICTURES = {
    category = RenderCategory.ERC_MAP_PICTURE
    text = loc("worldwar/renderMap/render_map_picture")
    image = @() "#ui/gameuiskin#battles_open"
    isHidden = @(...) true
  }
  WW_FILTER_RENDER_DEBUG = {
    value = @() g_world_war.isDebugModeEnabled()
    text = "#mainmenu/btnDebugUnlock"
    image = @() "#ui/gameuiskin#battles_closed"
    onChangeValueFunc = @(value) g_world_war.setDebugMode(value)
    isHidden = @(...) !hasFeature("worldWarMaster")
  }
  WW_LEADERBOARDS = {
    text = "#mainmenu/titleLeaderboards"
    onClickFunc = @(_obj, _handler) loadHandler(WwLeaderboard,
      { beginningMode = "ww_clans" })
    elementType = TOP_MENU_ELEMENT_TYPE.BUTTON
  }
  WW_ACHIEVEMENTS = {
    text = $"#{getVendorLocId("mainmenu/btnUnlockAchievement")}"
    onClickFunc = @(_obj, handler) handler?.onOpenAchievements()
    isHidden = @(...) getUnlocksByTypeInBlkOrder("achievement").findindex(
      @(u) u?.chapter && u.chapter == "worldwar" && u?.hidden != true) == null
    elementType = TOP_MENU_ELEMENT_TYPE.BUTTON
  }
  WW_VEHICLE_SET = {
    text = "#worldWar/menu/createVehicleSet"
    onClickFunc = @(_obj, handler) handler?.openVehiclesPresetModal()
    isHidden = @(...) !hasAvailableMapToBattle()
    elementType = TOP_MENU_ELEMENT_TYPE.BUTTON
    unseenIcon = @() SEEN.WW_OPERATION_AVAILABLE
  }
  WW_SCENARIO_DESCR = {
    text = "#worldwar/scenarioDescription"
    onClickFunc = @(_obj, handler) handler?.openOperationsListModal()
    isHidden = @(...) !hasAvailableMapToBattle()
    elementType = TOP_MENU_ELEMENT_TYPE.BUTTON
  }
  WW_OPERATION_LIST = {
    text = "#worldwar/operationsList"
    onClickFunc = @(_obj, handler) handler?.onOperationListSwitch()
    isHidden = @(...) !hasFeature("WWOperationsList")
    elementType = TOP_MENU_ELEMENT_TYPE.BUTTON
  }
  WW_WIKI = {
    onClickFunc = @(obj, _handler) openUrlByObj(obj)
    isDelayed = false
    link = @() ""
    isLink = @() true
    isFeatured = @() true
    elementType = TOP_MENU_ELEMENT_TYPE.BUTTON
  }
}

list.each(@(buttonCfg, name) addButtonConfig(template.__merge(buttonCfg), name))
