from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let wwActionsWithUnitsList = require("%scripts/worldWar/inOperation/wwActionsWithUnitsList.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

let { getCustomViewCountryData } = require("%scripts/worldWar/inOperation/wwOperationCustomAppearance.nut")

::gui_handlers.WwJoinBattleCondition <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneTplName = "%gui/worldWar/battleJoinCondition"

  battle = null
  side = SIDE_NONE

  static maxUnitsInColumn = 8

  function getSceneTplView()
  {
    let unitAvailability = ::g_world_war.getSetting("checkUnitAvailability",
      WW_BATTLE_UNITS_REQUIREMENTS.BATTLE_UNITS)

    let team = battle.getTeamBySide(side)
    local wwUnitsList = []
    if (unitAvailability == WW_BATTLE_UNITS_REQUIREMENTS.OPERATION_UNITS ||
        unitAvailability == WW_BATTLE_UNITS_REQUIREMENTS.BATTLE_UNITS)
    {
      let requiredUnits = battle.getUnitsRequiredForJoin(team, side)
      wwUnitsList = ::u.filter(wwActionsWithUnitsList.loadUnitsFromNameCountTbl(requiredUnits),
        @(unit) !unit.isControlledByAI())
      wwUnitsList = wwActionsWithUnitsList.getUnitsListViewParams({
        wwUnits = wwUnitsList,
        params = { addPreset = false, needShopInfo = true }
        needSort = false
      })
    }

    let columns = []
    if (wwUnitsList.len() <= maxUnitsInColumn)
      columns.append({ unitString = wwUnitsList })
    else
    {
      let unitsInColumn = wwUnitsList.len() > 2 * maxUnitsInColumn
        ? wwUnitsList.len() - wwUnitsList.len() / 2
        : maxUnitsInColumn
      columns.append({ unitString = wwUnitsList.slice(0, unitsInColumn), first = true })
      columns.append({ unitString = wwUnitsList.slice(unitsInColumn) })
    }

    let viewCountryData = getCustomViewCountryData(team.country)
    return {
      countryInfoText = loc("worldwar/help/country_info",
        {country = colorize("@newTextColor", loc(viewCountryData.locId))})
      battleConditionText = loc("worldwar/help/required_units_" + unitAvailability)
      countryIcon = viewCountryData.icon
      columns = columns
    }
  }
}
