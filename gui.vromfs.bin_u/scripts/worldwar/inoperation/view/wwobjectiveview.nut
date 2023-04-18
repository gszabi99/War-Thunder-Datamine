//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

::WwObjectiveView <- class {
  id = ""
  oType = null
  staticBlk = null
  dynamicBlk = null
  side = null
  status = ""
  statusImg = ""
  zonesList = null

  isLastObjective = false

  constructor(v_staticBlk, v_dynamicBlk, v_side, v_isLastObjective = false) {
    this.staticBlk = v_staticBlk
    this.dynamicBlk = v_dynamicBlk
    this.side = ::ww_side_val_to_name(v_side)
    this.oType = ::g_ww_objective_type.getTypeByTypeName(this.staticBlk.type)
    this.id = this.staticBlk.getBlockName()
    this.isLastObjective = v_isLastObjective

    let statusType = this.oType.getObjectiveStatus(this.dynamicBlk?.winner, this.side)
    this.status = statusType.name
    this.statusImg = statusType.wwMissionObjImg
    this.zonesList = this.oType.getUpdatableZonesParams(this.staticBlk, this.dynamicBlk, this.side)
  }

  function getNameId() {
    return this.oType.getNameId(this.staticBlk, this.side)
  }

  function getName() {
    return this.oType.getName(this.staticBlk, this.dynamicBlk, this.side)
  }

  function getDesc() {
    return this.oType.getDesc(this.staticBlk, this.dynamicBlk, this.side)
  }

  function getParamsArray() {
    return this.oType.getParamsArray(this.staticBlk, this.side)
  }

  function getUpdatableData() {
    return this.oType.getUpdatableParamsArray(this.staticBlk, this.dynamicBlk, this.side)
  }

  function getUpdatableDataDescriptionText() {
    return this.oType.getUpdatableParamsDescriptionText(this.staticBlk, this.dynamicBlk, this.side)
  }

  function getUpdatableDataDescriptionTooltip() {
    return this.oType.getUpdatableParamsDescriptionTooltip(this.staticBlk, this.dynamicBlk, this.side)
  }

  function getUpdatableZonesData() {
    return this.zonesList
  }

  function hasObjectiveZones() {
    return this.zonesList.len()
  }
}
