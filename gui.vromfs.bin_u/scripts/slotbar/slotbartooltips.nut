from "%scripts/dagui_library.nut" import *
from "%scripts/dagui_natives.nut" import is_mouse_last_time_used

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { addTooltipTypes } = require("%scripts/utils/genericTooltipTypes.nut")
let { isSlotbarOverrided, getSlotbarOverrideMods } = require("%scripts/slotbar/slotbarOverride.nut")
let { toPixels } = require("%sqDagui/daguiUtil.nut")
let { getCurrentGameModeEdiff } = require("%scripts/gameModes/gameModeManagerState.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { getUnitClassIco, getUnitTooltipImage } = require("%scripts/unit/unitInfoTexts.nut")
let { getUnitRole, getUnitRoleIconAndTypeCaption } = require("%scripts/unit/unitInfoRoles.nut")
let { format } = require("string")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { floor } = require("math")
let { fillAirInfo } = require("%scripts/airInfo.nut")
let fontScaleOption = require("%scripts/options/fonts.nut")


let getAirInfoTooltipId = @(id) $"air_info_tooltip_{id}"

addTooltipTypes({
  UNIT = {
    isCustomTooltipFill = true
    isModalTooltip = true
    fillTooltip = function(obj, handler, id, params) {
      let actionsList = handlersManager.findHandlerClassInScene(gui_handlers.ActionsList)
      if (actionsList && actionsList?.params.needCloseTooltips) {
        let transparentDirection = to_integer_safe(actionsList?.scene["_transp-direction"], 0, false)
        if (transparentDirection > -1) {
          if (!showConsoleButtons.get() || (is_mouse_last_time_used() && !params?.isOpenByHoldBtn))
            return false
          actionsList.close()
        }
      }

      if (!checkObj(obj))
        return false

      let unit = getAircraftByName(id)
      if (!unit)
        return false

      let guiScene = obj.getScene()
      let blkPath = hasFeature("UnitModalInfo")
        ? "%gui/unitInfo/unitModalInfo.blk"
        : "%gui/unitInfo/unitInfo.blk"
      guiScene.replaceContent(obj, blkPath, handler)
      let contentObj = obj.findObject("air_info_tooltip")
      contentObj.id = getAirInfoTooltipId(id)
      return this.fillTooltipContent(obj, handler, id, params)
    }
    fillTooltipContent = function(obj, handler, id, params) {
      let contentObj = obj.findObject(getAirInfoTooltipId(id))
      if (!(contentObj?.isValid() ?? false))
        return

      let { maxHeight = null } = params
      let unitImgObj = contentObj.findObject("aircraft-image-nest")
      unitImgObj.height = "40%sh"

      let infoObj = contentObj.findObject("aircraft-tooltip-top_info")
      infoObj.height = null
      infoObj["overflow-y"] = null
      obj["max-height"] = null

      obj.getScene().setUpdatesEnabled(false, false)
      let unit = getAircraftByName(id)
      let airInfoParams = !isSlotbarOverrided() ? params
        : params.__merge({
            overrideMods = getSlotbarOverrideMods()?[unit.shopCountry][unit.name]
          })
      fillAirInfo(unit, true, contentObj, handler, airInfoParams)
      showObjById("aircraft-countryImg", false, contentObj)
      obj.getScene().setUpdatesEnabled(true, true)
      obj.getScene().applyPendingChanges(true)

      let objHeight = obj.getSize()[1]
      let imgHeight = unitImgObj.getSize()[1]

      let freeHeight = maxHeight ?? toPixels(obj.getScene(), "1@rh")
      if (freeHeight >= objHeight)
        return true

      local overflow = objHeight - freeHeight
      if (overflow > 0) {
        let imgLessHeight = min(overflow, imgHeight / 2)
        unitImgObj.height = imgHeight - imgLessHeight
        overflow -= imgLessHeight
      }
      if (overflow > 0) {
        infoObj.height = infoObj.getSize()[1] - overflow
        infoObj["overflow-y"] = "auto"
      }
      obj["max-height"] = freeHeight

      return true
    }
    onEventUnitModsRecount = function(eventParams, obj, handler, id, params) {
      if (id == eventParams?.unit.name)
        this.fillTooltipContent(obj, handler, id, params)
    }
    onEventSecondWeaponModsUpdated = function(eventParams, obj, handler, id, params) {
      if (id == eventParams?.unit.name)
        this.fillTooltipContent(obj, handler, id, params)
    }
  }

  UNIT_PACK = {
    isCustomTooltipFill = true
    getTooltipId = function(group, params = null) {
      return this._buildId({ units = group?.units, name = group?.name }, params)
    }
    fillTooltip = function(obj, handler, group, params) {
      let curEdiff = params?.getEdiffFunc() ?? getCurrentGameModeEdiff()
      let scale = fontScaleOption.getCurrent().sizeMultiplier ?? 1.0
      let view = {
        headerText = loc("shop/packWithName", { packName = loc($"shop/group/{group.name}") })
        name = group.name
        scale = scale <= 0.5 ? 1.25
          : scale <= 0.67 ? 1.33
          : 1.0 / scale
        units = []
      }

      foreach (unitId in group.units) {
        let unit = getAircraftByName(unitId)
        if (!unit)
          continue

        view.units.append({
          unitName = getUnitName(unitId)
          icon = getUnitClassIco(unitId)
          shopItemType = getUnitRole(unit)
          image = getUnitTooltipImage(unit)
          unitRank = "{0}{1} {2}".subst(loc("shop/age"), loc("ui/colon"),
            colorize("@shopAircraftOwned", get_roman_numeral(unit.rank)))
          battleRating = "{0}{1} {2}".subst(loc("shop/battle_rating"), loc("ui/colon"),
            colorize("@shopAircraftOwned", format("%.1f", unit.getBattleRating(curEdiff))))
          typeText = getUnitRoleIconAndTypeCaption(unit)
        })
      }

      view.count <- view.units.len()

      let murkup = handyman.renderCached("%gui/tooltips/unitPackTooltip.tpl", view)
      obj.getScene().replaceContentFromText(obj, murkup, murkup.len(), handler)
      return true
    }
  }
  UNIT_GROUP = {
    isCustomTooltipFill = true
    getTooltipId = function(group, params = null) {
      return this._buildId({ units = group?.units.keys(), name = group?.name }, params)
    }
    fillTooltip = function(obj, handler, group, _params) {
      if (!checkObj(obj))
        return false

      let name = loc("ui/quotes", { text = loc(group.name) })
      let list = []
      foreach (str in group.units) {
        let unit = getAircraftByName(str)
        if (!unit)
          continue

        list.append({
          unitName = getUnitName(str)
          icon = getUnitClassIco(str)
          shopItemType = getUnitRole(unit)
        })
      }

      let columns = []
      let unitsInArmyRowsMax = max(floor(list.len() / 2).tointeger(), 3)
      let hasMultipleColumns = list.len() > unitsInArmyRowsMax
      if (!hasMultipleColumns)
        columns.append({ groupList = list })
      else {
        columns.append({ groupList = list.slice(0, unitsInArmyRowsMax), isFirst = true })
        columns.append({ groupList = list.slice(unitsInArmyRowsMax) })
      }

      let data = handyman.renderCached("%gui/tooltips/unitGroupTooltip.tpl", {
        title = $"{loc("unitsGroup/groupContains", { name = name})}{loc("ui/colon")}",
        hasMultipleColumns = hasMultipleColumns,
        columns = columns
      })
      obj.getScene().replaceContentFromText(obj, data, data.len(), handler)
      return true
    }
  }
})
