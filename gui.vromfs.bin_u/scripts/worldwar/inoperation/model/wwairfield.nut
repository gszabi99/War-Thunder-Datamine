from "%scripts/dagui_natives.nut" import ww_side_name_to_val
from "%scripts/dagui_library.nut" import *
from "%scripts/worldWar/worldWarConst.nut" import *

let DataBlock = require("DataBlock")
let { Point2 } = require("dagor.math")
let { wwGetAirfieldInfo } = require("worldwar")
let { search } = require("%sqStdLibs/helpers/u.nut")
let wwUnitClassParams = require("%scripts/worldWar/inOperation/wwUnitClassParams.nut")
let airfieldTypes = require("%scripts/worldWar/inOperation/model/airfieldTypes.nut")
let { WwAirfieldFormation } = require("wwAirfieldFormation.nut")
let { WwCustomFormation } = require("wwCustomFormation.nut")
let { WwAirfieldCooldownFormation } = require("wwAirfieldCooldownFormation.nut")
let { WwArmyOwner } = require("%scripts/worldWar/inOperation/model/wwArmyOwner.nut")
let WwAirfieldView = require("%scripts/worldWar/inOperation/view/wwAirfieldView.nut")
let { getWWConfigurableValue } = require("%scripts/worldWar/worldWarStates.nut")
let { getArmyByName } = require("%scripts/worldWar/inOperation/model/wwArmy.nut")
let { getCurrentOperation } = require("%scripts/worldWar/inOperation/wwOperations.nut")

let WwAirfield = class {
  index  = -1
  size   = 0
  side   = SIDE_NONE
  pos    = null
  airfieldType = null
  armies = null
  formations = null
  cooldownFormations = null
  clanFormation = null
  allyFormation = null
  createArmyMorale = 0
  airfieldView = null

  constructor(airfieldIndex) {
    this.airfieldType = airfieldTypes.AT_RUNWAY
    this.index  = airfieldIndex
    this.pos    = Point2()
    this.armies = []
    this.formations = []
    this.cooldownFormations = []
    this.clanFormation = null
    this.allyFormation = null

    if (airfieldIndex < 0)
      return

    this.update()
  }

  function isValid() {
    return this.index >= 0
  }

  function getIndex() {
    return this.index
  }

  function update() {
    this.createArmyMorale = getWWConfigurableValue("airfieldCreateArmyMorale", 0)

    let blk = DataBlock()
    wwGetAirfieldInfo(this.index, blk)

    if ("specs" in blk) {
      this.side = blk.specs?.side ? ww_side_name_to_val(blk.specs.side) : this.side
      this.size = blk.specs?.size || this.size
      this.pos = blk.specs?.pos || this.pos
      this.airfieldType = airfieldTypes?[blk.specs?.type] ?? this.airfieldType
    }

    if ("groups" in blk)
      for (local i = 0; i < blk.groups.blockCount(); i++) {
        let itemBlk = blk.groups.getBlock(i)
        let formation = WwAirfieldFormation(itemBlk, this)
        this.formations.append(formation)

        if (formation.isBelongsToMyClan()) {
          this.clanFormation = formation
          this.clanFormation.setFormationID(WW_ARMY_RELATION_ID.CLAN)
          this.clanFormation.setName($"formation_{WW_ARMY_RELATION_ID.CLAN}")
          this.clanFormation.setPosition(this.pos)
        }
        else {
          if (!this.allyFormation) {
            this.allyFormation = WwCustomFormation(itemBlk, this)
            this.allyFormation.setFormationID(WW_ARMY_RELATION_ID.ALLY)
            this.allyFormation.setName($"formation_{WW_ARMY_RELATION_ID.ALLY}")
            this.allyFormation.setUnitType(this.airfieldType.unitType.code)
            this.allyFormation.setMapObjectName(this.airfieldType.objName)
            this.allyFormation.setPosition(this.pos)
          }
          this.allyFormation.addUnits(itemBlk)
        }

        let cooldownsBlk = itemBlk.getBlockByName("cooldownUnits")
        for (local j = 0; j < cooldownsBlk.blockCount(); j++) {
          let cdFormation = WwAirfieldCooldownFormation(cooldownsBlk.getBlock(j), this)
          cdFormation.owner = WwArmyOwner(itemBlk.getBlockByName("owner"))
          cdFormation.setFormationID(j)
          cdFormation.setName($"cooldown_{j}")
          this.cooldownFormations.append(cdFormation)
        }
      }

    if ("armies" in blk)
      this.armies = blk.armies % "item"
  }

  function _tostring() {
    local returnText = $"AIRFIELD: index = {this.index}, side = {this.side}, size = {this.size}, pos = {toString(this.pos)}, airfieldType = {this.airfieldType.name}"
    if (this.formations.len())
      returnText = $"{returnText}, groups len = {this.formations.len()}"
    if (this.armies.len())
      returnText = $"{returnText}, armies len = {this.armies.len()}"
    return returnText
  }

  function isArmyBelongsTo(army) {
    return isInArray(army.name, this.armies)
  }

  function getSide() {
    return this.side
  }

  function getSize() {
    return this.size
  }

  function getPos() {
    return this.pos
  }

  function getUnitsNumber(needToAddCooldown = true) {
    local count = 0
    foreach (formation in this.formations)
      count += formation.getUnitsNumber()

    if (needToAddCooldown)
      foreach (formation in this.cooldownFormations)
        count += formation.getUnitsNumber()

    return count
  }

  function getUnitsInFlyNumber() {
    local unitsNumber = 0
    foreach (armyName in this.armies) {
      let army = getArmyByName(armyName)
      if (army.isValid()) {
        army.updateUnits()
        unitsNumber += army.getUnitsNumber()
      }
    }

    return unitsNumber
  }

  function isMySide(checkSide) {
    return this.getSide() == checkSide
  }

  function getCooldownsWithManageAccess() {
    return this.cooldownFormations.filter(@(formation) formation.hasManageAccess())
  }

  function getCooldownArmiesByGroupIdx(groupIdx) {
    return this.cooldownFormations.filter(@(formation) formation.getArmyGroupIdx() == groupIdx)
  }

  function getCooldownArmiesNumberByGroupIdx(groupIdx) {
    return this.getCooldownArmiesByGroupIdx(groupIdx).len()
  }

  function hasEnoughUnitsToFly() {
    foreach (formation in this.formations)
      if (this.hasFormationEnoughUnitsToFly(formation))
        return true

    return false
  }

  function hasFormationEnoughUnitsToFly(formation) {
    if (!formation || !formation.isValid() || !formation.hasManageAccess())
      return false

    let airClassesAmount = {
      [WW_UNIT_CLASS.FIGHTER] = 0,
      [WW_UNIT_CLASS.BOMBER] = 0,
      [WW_UNIT_CLASS.HELICOPTER] = 0
    }
    local customClassAmount = 0
    foreach (unit in formation.units) {
      let flyOutUnitClass = wwUnitClassParams.getUnitClassData(unit).flyOutUnitClass
      if (!(flyOutUnitClass in airClassesAmount))
        continue

      airClassesAmount[flyOutUnitClass] += unit.count

      if (flyOutUnitClass != WW_UNIT_CLASS.FIGHTER)
        continue

      if (wwUnitClassParams.getFighterToAssaultWeapon(unit.unit) != null)
        customClassAmount += unit.count
    }

    let operation = getCurrentOperation()
    let flyoutRange = operation.getUnitsFlyoutRange()
    foreach (mask in [WW_UNIT_CLASS.FIGHTER, WW_UNIT_CLASS.COMBINED, WW_UNIT_CLASS.HELICOPTER]) {
      local additionalAirs = 0
      local hasEnough = false
      foreach (unitClass, amount in airClassesAmount) {
        let unitRange = operation.getQuantityToFlyOut(unitClass, mask, flyoutRange)

        hasEnough = amount + additionalAirs >= unitRange.x
        if (!hasEnough)
          break

        if (unitClass == WW_UNIT_CLASS.FIGHTER && amount > unitRange.x)
          additionalAirs = min(amount - unitRange.x, customClassAmount)
      }

      if (hasEnough)
        return true
    }

    return false
  }

  getAvailableFormations = @() this.isValid()
    ? this.formations.filter(@(formation) formation.hasManageAccess()) : []

  getFormationByGroupIdx = @(groupIdx)
    search(this.formations, @(group) group.owner.armyGroupIdx == groupIdx)

  function getView() {
    if (!this.airfieldView)
      this.airfieldView = WwAirfieldView(this)
    return this.airfieldView
  }
}

return { WwAirfield }