from "%scripts/dagui_library.nut" import *

let WwArmyOwner = class {
  side         = null
  country      = null
  armyGroupIdx = null

  constructor(blk = null) {
    this.clear()
    this.update(blk)
  }

  function update(blk) {
    if (!blk)
      return

    this.side         = ::ww_side_name_to_val(getTblValue("side", blk, ""))
    this.country      = getTblValue("country",      blk, "")
    this.armyGroupIdx = getTblValue("armyGroupIdx", blk, -1)
  }

  function clear() {
    this.side         = SIDE_NONE
    this.country      = ""
    this.armyGroupIdx = -1
  }

  function isValid() {
    return this.side != SIDE_NONE && this.country != "" && this.armyGroupIdx >= 0
  }

  function getCountry() { return this.country }

  function getArmyGroupIdx() { return this.armyGroupIdx }

  function getSide() { return this.side }
}

return { WwArmyOwner }