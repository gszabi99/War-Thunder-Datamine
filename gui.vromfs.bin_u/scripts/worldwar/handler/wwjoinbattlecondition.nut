from "%globalScripts/wwNativeConsts.nut" import *
from "%scripts/dagui_library.nut" import *
from "%scripts/worldWar/worldWarConst.nut" import *

let { register_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { BaseGuiHandlerWT } = require("%scripts/baseGuiHandlerWT.nut")
let wwActionsWithUnitsList = require("%scripts/worldWar/inOperation/wwActionsWithUnitsList.nut")
let { handlerType } = require("%scripts/sqDagui/framework/handlerType.nut")

let { getCustomViewCountryData } = require("%scripts/worldWar/inOperation/wwOperationCustomAppearance.nut")
let { getWwSetting } = require("%scripts/worldWar/worldWarCfgState.nut")

let WwJoinBattleCondition = class (BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneTplName = "%gui/worldWar/battleJoinCondition.tpl"

  battle = null
  side = SIDE_NONE

  static maxUnitsInColumn = 8

  function getSceneTplView() {
    let unitAvailability = getWwSetting("checkUnitAvailability",
      WW_BATTLE_UNITS_REQUIREMENTS.BATTLE_UNITS)

    let team = this.battle.getTeamBySide(this.side)
    local wwUnitsList = []
    if (unitAvailability == WW_BATTLE_UNITS_REQUIREMENTS.OPERATION_UNITS ||
        unitAvailability == WW_BATTLE_UNITS_REQUIREMENTS.BATTLE_UNITS) {
      let requiredUnits = this.battle.getUnitsRequiredForJoin(team, this.side)
      wwUnitsList = wwActionsWithUnitsList.loadUnitsFromNameCountTbl(requiredUnits).filter(@(unit) !unit.isControlledByAI())
      wwUnitsList = wwActionsWithUnitsList.getUnitsListViewParams({
        wwUnits = wwUnitsList,
        params = { addPreset = false, needShopInfo = true }
        needSort = false
      })
    }

    let columns = []
    if (wwUnitsList.len() <= this.maxUnitsInColumn)
      columns.append({ unitString = wwUnitsList })
    else {
      let unitsInColumn = wwUnitsList.len() > 2 * this.maxUnitsInColumn
        ? wwUnitsList.len() - wwUnitsList.len() / 2
        : this.maxUnitsInColumn
      columns.append({ unitString = wwUnitsList.slice(0, unitsInColumn), first = true })
      columns.append({ unitString = wwUnitsList.slice(unitsInColumn) })
    }

    let viewCountryData = getCustomViewCountryData(team.country)
    return {
      countryInfoText = loc("worldwar/help/country_info",
        { country = colorize("@newTextColor", loc(viewCountryData.locId)) })
      battleConditionText = loc($"worldwar/help/required_units_{unitAvailability}")
      countryIcon = viewCountryData.icon
      columns = columns
    }
  }
}
register_gui_handler("WwJoinBattleCondition", WwJoinBattleCondition)

return { WwJoinBattleCondition }
