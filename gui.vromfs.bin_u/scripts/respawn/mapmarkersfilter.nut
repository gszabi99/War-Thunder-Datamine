from "%scripts/dagui_library.nut" import *
from "guiTacticalMap" import TacticalMapIconType
let { appendOnce } = require("%sqStdLibs/helpers/u.nut")
let { RESET_ID, SELECT_ALL_ID } = require("%scripts/popups/popupFilterWidget.nut")

let { IT_Fighter, IT_Bomber, IT_Assault, IT_LightTank, IT_MediumTank, IT_HeavyTank, IT_TankDestroyer,
  IT_Tracked, IT_SPAA, IT_Airdefence, IT_BattleCruiser, IT_BattleShip, IT_Frigate, IT_HeavyBoat,
  IT_HeavyCruiser, IT_LightCruiser, IT_Ship, IT_Submarine, IT_TorpedoBoat, IT_Boat, IT_Structure,
  IT_Wheeled, IT_Airport, IT_MLRS, IT_Radar, IT_SAM } = TacticalMapIconType

let unitTypesData = [
  { name = "mainmenu/aviation", types = [IT_Fighter, IT_Bomber, IT_Assault] }
  { name = "mainmenu/armored_vehicles", types = [IT_LightTank, IT_MediumTank, IT_HeavyTank, IT_TankDestroyer, IT_Tracked] }
  { name = "mainmenu/air_defense", types = [IT_SPAA, IT_Airdefence] }
  { name = "multiplayer/artillery", types = [IT_MLRS] }
  { name = "xray/radar", types = [IT_Radar] }
  { name = "tankSight/sam", types = [IT_SAM] }
  { name = "mainmenu/fleet", types = [IT_BattleCruiser, IT_BattleShip, IT_Frigate, IT_HeavyBoat, IT_HeavyCruiser, IT_LightCruiser,
    IT_Ship, IT_Submarine, IT_TorpedoBoat, IT_Boat] }
  { name = "mainmenu/ground_facilities", types = [IT_Structure] }
  { name = "mainmenu/supply", types = [IT_Wheeled] }
  { name = "worldWar/airfieldsList", types = [IT_Airport] }
]

let unitTypes = unitTypesData.reduce(function(res, value, idx) {
  res[idx] <- {
    idx
    text = value.name
    types = value.types
    value = idx
  }
  return res
}, {} )

let getUpdatedUnitTypes = @(side) unitTypes.map(@(v, idx) v.__merge({ id = $"{side}_{idx}" }))

let filterNames = [
  {
    name = "allies"
    title = "sensorsFilters/allyes"
    fillFunction = @() getUpdatedUnitTypes("allies")
    selectedArr = persist("markerFilterAllies", @() [])
  }
  {
    name = "enemies"
    title = "sensorsFilters/enemyes"
    fillFunction = @() getUpdatedUnitTypes("enemies")
    selectedArr = persist("markerFilterEnemies", @() [])
  }
]

let filterTypes = filterNames.reduce(function(res, value) {
  let { name, fillFunction, selectedArr } = value
  res[name] <- { referenceArr = fillFunction(), selectedArr }
  return res
}, {})

function getTacticalMapMarksFiltersView() {
  return filterNames.map(function(filterName) {
      let { title = "", fillFunction, selectedArr } = filterName
      let referenceArr = fillFunction()
      let view = { checkbox = [], title }
      foreach (key, inst in referenceArr)
        view.checkbox.append({
          id = inst.id
          idx = inst.idx
          image = inst?.image
          text = loc(inst.text)
          value = selectedArr.contains(key)
        })
      return view
    })
}

function getTacticalMapMarksSelectedFilters() {
  return filterTypes.map(@(value) value.selectedArr.reduce(function(res, v) {
    res.extend(value.referenceArr[v].types)
    return res
  }, []))
}

function removeItemFromList(value, list) {
  let idx = list.findindex(@(v) v == value)
  if (idx != null)
    list.remove(idx)
}

function applyTacticalMapMarksFilterChange(objId, tName, value) {
  let { selectedArr, referenceArr } = filterTypes[tName]

  if (objId == RESET_ID) {
    selectedArr.clear()
    return
  }

  if (objId == SELECT_ALL_ID) {
    referenceArr.each(@(_v, idx) appendOnce(idx, selectedArr))
    return
  }

  foreach (idx, inst in referenceArr) {
    if (inst.id != objId)
      continue

    if (value)
      appendOnce(idx, selectedArr)
    else
      removeItemFromList(idx, selectedArr)
    break
  }
}

return {
  getTacticalMapMarksFiltersView
  applyTacticalMapMarksFilterChange
  getTacticalMapMarksSelectedFilters
}
