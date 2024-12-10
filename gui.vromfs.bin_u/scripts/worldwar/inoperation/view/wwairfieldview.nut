from "%scripts/dagui_natives.nut" import ww_get_zone_idx_world
from "%scripts/dagui_library.nut" import *
from "%scripts/worldWar/worldWarConst.nut" import *

let { wwGetZoneName, wwGetPlayerSide } = require("worldwar")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { ceil } = require("math")
let wwActionsWithUnitsList = require("%scripts/worldWar/inOperation/wwActionsWithUnitsList.nut")

let WwAirfieldView = class {
  redrawData = null
  airfield = null

  static unitsInArmyRowsMax = 5

  constructor(airfield) {
    this.airfield = airfield
    this.setRedrawArmyStatusData()
  }

  function getCountryIcon() {
    let groups = ::g_world_war.getArmyGroupsBySide(this.airfield.side)
    return groups.len() > 0 ? groups[0].getCountryIcon() : ""
  }

  getTeamColor = @() this.airfield.isMySide(wwGetPlayerSide()) ? "blue" : "red"

  getUnitTypeIcon = @() this.airfield.airfieldType.unitType.getUnitTypeIcon()

  isBelongsToMyClan = @() this.airfield.clanFormation?.armyGroup.isBelongsToMyClan() ?? false

  getMapObjectName = @() this.airfield.airfieldType.objName

  getZoneName = @() loc("ui/parentheses", { text = wwGetZoneName(ww_get_zone_idx_world(this.airfield.pos)) })

  clanTag = @() this.airfield.clanFormation?.armyGroup.name ?? ""

  unitsCount = @() this.airfield.getUnitsNumber()

  getUnitTypeText = @() this.airfield.airfieldType.unitType.fontIcon

  getUnitsCountText = @() this.unitsCount()

  getUnitsCountTextIcon = @() " ".concat(this.getUnitsCountText(), this.getUnitTypeText())

  isFormation = @() true

  function getSectionsView(sections, isMultipleColumns) {
    let view = { infoSections = [] }
    foreach (sect in sections) {
      let sectView = {
        title = sect?.title,
        columns = [],
        multipleColumns = isMultipleColumns,
        hasSpaceBetweenUnits = true
      }
      let units = sect.units
      if (!isMultipleColumns)
        sectView.columns.append({ unitString = units })
      else {
        let unitsInRow = ceil(units.len() / 2.0).tointeger()
        sectView.columns.append({ unitString = units.slice(0, unitsInRow), first = true })
        sectView.columns.append({ unitString = units.slice(unitsInRow) })
      }
      view.infoSections.append(sectView)
    }
    return view
  }

  function unitsList() {
    let wwUnits = this.airfield.clanFormation?.units ?? this.airfield.allyFormation?.units ?? []
    let rowsCount = wwUnits.len()
    let isMultipleColumns = rowsCount > this.unitsInArmyRowsMax
    let sections = [{ units = wwActionsWithUnitsList.getUnitsListViewParams({ wwUnits = wwUnits }) }]
    let view = this.getSectionsView(sections, isMultipleColumns)
    return handyman.renderCached("%gui/worldWar/worldWarMapArmyInfoUnitsList.tpl", view)
  }

  function setRedrawArmyStatusData() {
    this.redrawData = {
      army_count = this.getUnitsCountTextIcon
    }
  }

  getRedrawArmyStatusData = @() this.redrawData

  needSmallSize = @() false
}

return WwAirfieldView