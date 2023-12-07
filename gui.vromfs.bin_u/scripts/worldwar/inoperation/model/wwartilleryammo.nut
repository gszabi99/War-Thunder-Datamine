//checked for plus_string
from "%scripts/dagui_library.nut" import *


let time = require("%scripts/time.nut")
let { ceil } = require("math")
let DataBlock  = require("DataBlock")
let { wwGetOperationTimeMillisec } = require("worldwar")

let WwArtilleryAmmo = class {
  hasArtilleryStrike = false
  strikesDone = null
  ammoCount = 0
  maxAmmoCount = 0
  maxStrikesPerAttack = 0
  nextAmmoRefillMillisec = 0
  nextStrikeTimeMillis = 0
  cooldownAfterMoveSec = 0
  strikeIntervalSec = 0

  function update(armyName, blk = null) {
    if (!blk)
      return

    this.ammoCount = blk.ammo
    this.nextAmmoRefillMillisec = blk.nextAmmoRefillMillisec
    this.updateStrike(armyName)
  }

  function updateStrike(armyName) {
    this.hasArtilleryStrike = false
    this.nextStrikeTimeMillis = 0
    this.strikesDone = null

    let strikesBlk = DataBlock()
    ::ww_get_artillery_strikes(strikesBlk)

    let strikeBlk = strikesBlk?.artilleryStrikes?[armyName]
    if (!strikeBlk)
      return

    this.hasArtilleryStrike = true
    this.nextStrikeTimeMillis = getTblValue("nextStrikeTimeMillis", strikeBlk, 0)
    this.strikesDone = getTblValue("strikesDone", strikeBlk, 0)
  }

  function getAmmoCount() {
    return this.ammoCount
  }

  function getMaxAmmoCount() {
    return this.maxAmmoCount
  }

  function getNextAmmoRefillTime() {
    let millisec = this.nextAmmoRefillMillisec - wwGetOperationTimeMillisec()
    return time.millisecondsToSeconds(millisec).tointeger()
  }

  function getMaxStrikesPerAttack() {
    return min(this.maxStrikesPerAttack, this.maxAmmoCount)
  }

  function getCooldownAfterMoveMillisec() {
    return (this.cooldownAfterMoveSec * 1000 / ::ww_get_speedup_factor()).tointeger()
  }

  function getStrikeIntervalMillisec() {
    return (this.strikeIntervalSec * 1000 / ::ww_get_speedup_factor()).tointeger()
  }

  function getTimeToNextStrike() {
    if (!this.hasStrike())
      return 0

    let millisec = this.nextStrikeTimeMillis - wwGetOperationTimeMillisec()
    return max(ceil(time.millisecondsToSeconds(millisec)).tointeger(), 1)
  }

  function getTimeToCompleteStrikes() {
    if (!this.hasStrike())
      return 0

    local millisec = this.nextStrikeTimeMillis
    millisec += this.getUnusedStrikesNumber() * this.getStrikeIntervalMillisec()
    millisec -= wwGetOperationTimeMillisec()

    return max(ceil(time.millisecondsToSeconds(millisec)).tointeger(), 1)
  }

  function getUnusedStrikesNumber() {
    return this.hasStrike() ? this.getMaxStrikesPerAttack() - this.strikesDone - 1 : 0
  }

  function hasStrike() {
    return this.hasArtilleryStrike
  }

  function isStrikePreparing() {
    return this.hasStrike() ? this.strikesDone == 0 : false
  }

  function setArtilleryParams(params) {
    if (!params)
      return

    this.maxAmmoCount = getTblValue("maxAmmo", params, 0)
    this.maxStrikesPerAttack = getTblValue("maxStrikesPerAttack", params, 0)
    this.cooldownAfterMoveSec = getTblValue("cooldownAfterMoveSec", params, 0)
    this.strikeIntervalSec = getTblValue("strikeIntervalSec", params, 0)
  }
}
return { WwArtilleryAmmo }