import "%sqstd/math.nut" as stdMath
from "%sqStdLibs/helpers/handyman.nut" import handyman
from "hangarEventCommand" import set_protection_checker_params
from "%scripts/dagui_library.nut" import *
from "%globalScripts/unitTypeConsts.nut" import *
from "%scripts/measureType.nut" import measureType
from "%scripts/sqDagui/daguiUtil.nut" import enableObjsByTable
from "%scripts/weaponry/shellSelectOptions/shellSelectOptions.nut" import mkShellSelectOptions


let unitTypes = require("%scripts/unit/unitTypesList.nut")

let targetTypeToThreatTypes = {
  [ES_UNIT_TYPE_AIRCRAFT]   = [ ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_TANK, ES_UNIT_TYPE_HELICOPTER ],
  [ES_UNIT_TYPE_HELICOPTER] = [ ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_TANK, ES_UNIT_TYPE_HELICOPTER ],
  [ES_UNIT_TYPE_TANK] = [ ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_TANK, ES_UNIT_TYPE_HELICOPTER ],
  [ES_UNIT_TYPE_SHIP] = [ ES_UNIT_TYPE_SHIP, ES_UNIT_TYPE_BOAT, ES_UNIT_TYPE_AIRCRAFT ],
  [ES_UNIT_TYPE_BOAT] = [ ES_UNIT_TYPE_SHIP, ES_UNIT_TYPE_BOAT, ES_UNIT_TYPE_AIRCRAFT ],
}

function getThreatEsUnitTypes(targetUnit) {
  let targetUnitType = targetUnit.esUnitType
  let res = targetTypeToThreatTypes?[targetUnitType] ?? [ targetUnitType ]
  return res.filter(@(e) unitTypes.getByEsUnitType(e).isAvailable())
}

function getSecondaryShellTypes() {
  let res = [
    { shellType = "rocket", hasBulletParams = true }
    { shellType = "bullet", hasBulletParams = true }
  ]
  if (hasFeature("ProtectionAnalysisShowTorpedoes"))
    res.append({ shellType = "torpedo", hasBulletParams = true })
  if (hasFeature("ProtectionAnalysisShowBombs"))
    res.append({ shellType = "bomb", hasBulletParams = true })
  return res
}

function updateDistanceNativeUnitsText(options) {
  let descObj = options.nestObj.findObject("distanceNativeUnitsText")
  if (!descObj?.isValid())
    return
  let distance = options.DISTANCE.value
  let desc = measureType.DISTANCE.getMeasureUnitsText(distance)
  descObj.setValue(desc)
}

function updateArmorPiercingText(options) {
  let descObj = options.nestObj.findObject("armorPiercingText")
  if (!descObj?.isValid())
    return
  local desc = loc("ui/mdash")

  let bullet   = options.BULLET.value
  let distance = options.DISTANCE.value

  if (bullet?.bulletParams.armorPiercing) {
    local pMin
    local pMax

    for (local i = 0; i < bullet.bulletParams.armorPiercing.len(); i++) {
      let v = {
        armor = bullet.bulletParams.armorPiercing[i]?[0] ?? 0,
        dist  = bullet.bulletParams.armorPiercingDist[i],
      }
      if (!pMin)
        pMin = { armor = v.armor, dist = 0 }
      if (!pMax)
        pMax = pMin
      if (v.dist <= distance)
        pMin = v
      pMax = v
      if (v.dist >= distance)
        break
    }
    if (pMax && pMax.dist < distance)
      pMax.dist = distance

    if (pMin && pMax) {
      let armor = stdMath.lerp(pMin.dist, pMax.dist, pMin.armor, pMax.armor, distance)
      desc =  " ".concat(stdMath.round(armor).tointeger(), loc("measureUnits/mm"))
    }
  }

  descObj.setValue(desc)
}

function setAnalysisParams(options) {
  let bullet   = options.BULLET.value
  let distance = options.DISTANCE.value
  let unit = options.UNIT.value
  let offset = options?.OFFSET.value ?? 0
  let depth = options?.DEPTH.value ?? 0
  set_protection_checker_params(bullet?.weaponBlkName ?? "", bullet?.bulletName ?? "", unit?.name ?? "", distance, offset, depth, "")
}

let options = mkShellSelectOptions({
  getThreatEsUnitTypes
  getSecondaryShellTypes
  isReinitNeeded = @(opts) !opts.isSaved
    || !targetTypeToThreatTypes[opts.targetUnit.esUnitType].contains(opts.UNITTYPE.value)
    || opts.UNIT.value == null
  onValuesChanged = setAnalysisParams
  isSaved = false
})

let isBulletAvailable = @() options?.BULLET.value != null

function mkSliderMarkup(option) {
  return handyman.renderCached("%gui/dmViewer/distanceSlider.tpl", {
    containerId =$"container_{option.id}"
    id = option.id
    sliderWidth = "1@sliderWidth"
    min = 0
    max = 0
    value = 0
    step = 0
    width = "fw"
    btnOnDec = "onButtonDec"
    btnOnInc = "onButtonInc"
    onChangeSliderValue = "onChangeOption"
  })
}

local sortIdCount = options.types.len()
options.addTypes({
  DISTANCE = {
    sortId = sortIdCount++
    labelLocId = "distance"
    value = -1
    defValue = -1
    minValue = -1
    maxValue = -1
    step = 0
    valueWidth = "fw"

    getControlMarkup = @() mkSliderMarkup(this)

    function getInfoRows() {
      let res = [{
        valueId = "armorPiercingText"
        valueWidth = this.valueWidth
        label = $"{loc("bullet_properties/armorPiercing")}{loc("ui/colon")}"
      }]

      if (measureType.DISTANCE.isMetricSystem() == false)
        res.insert(0, {
        valueId = "distanceNativeUnitsText"
        valueWidth = "fw"
        label = ""
      })

      return res
    }

    getValFromObj = @(obj) obj?.isValid() ? obj.getValue() : 0

    function afterChangeFunc(obj) {
      let parentObj = obj.getParent().getParent()
      parentObj.findObject($"value_{this.id}").setValue($"{this.value}{loc("measureUnits/meters_alt")}")
      enableObjsByTable(parentObj, {
        buttonInc = this.value < this.maxValue
        buttonDec = this.value > this.minValue
      })
      updateDistanceNativeUnitsText(options)
      updateArmorPiercingText(options)
    }

    function updateParams() {
      let minValue = options.BULLET.value?.bulletParams.armorPiercingDist[0].tointeger() ?? 0
      this.minValue = minValue > 10 ? minValue : 0
      this.maxValue = options.UNIT.value?.isShipOrBoat() ? 15000 : 2000
      this.step     = options.targetDistance != null ? 1 : 100
      let preferredDistance = this.value >= 0 ? this.value
        : options.targetDistance ?? (options.UNIT.value?.isShipOrBoat() ? 2000 : 500)
      this.value = clamp(preferredDistance, this.minValue, this.maxValue)
    }

    function updateView(_handler, scene) {
      let obj = scene.findObject(this.id)
      if (!obj?.isValid())
        return
      let parentObj = obj.getParent().getParent()
      if (isBulletAvailable()) {
        obj.min = this.minValue
        obj.max = this.maxValue
        obj.optionAlign = this.step
        obj.setValue(this.value)
      }
      parentObj.display = isBulletAvailable() ? "show" : "hide"
    }
  }
  

























































































})

return options
