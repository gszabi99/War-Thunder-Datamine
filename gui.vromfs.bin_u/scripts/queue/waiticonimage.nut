//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

let { rnd } = require("dagor.random")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { getCurEsUnitTypesList } = require("%scripts/queue/curEsUnitTypesMask.nut")
let FULL_CIRCLE_GRAD = 360

let function getQueueWaitIconImageMarkup() {
  let esUnitTypes = getCurEsUnitTypesList(false)
  let esUnitTypesOrder = [
    ES_UNIT_TYPE_SHIP
    ES_UNIT_TYPE_TANK
    ES_UNIT_TYPE_HELICOPTER
    ES_UNIT_TYPE_AIRCRAFT
  ]

  let view = { icons = [] }
  let rotationStart = rnd() % FULL_CIRCLE_GRAD
  foreach (esUnitType in esUnitTypesOrder)
    if (isInArray(esUnitType, esUnitTypes))
      view.icons.append({
        unittag = unitTypes.getByEsUnitType(esUnitType).tag
        rotation = rotationStart
      })

  let circlesCount = view.icons.len()
  if (circlesCount)
    foreach (idx, icon in view.icons)
      icon.rotation = (rotationStart + idx * FULL_CIRCLE_GRAD / circlesCount) % FULL_CIRCLE_GRAD
  return handyman.renderCached("%gui/queue/queueWaitingIcon.tpl", view)
}

return {
  getQueueWaitIconImageMarkup
}