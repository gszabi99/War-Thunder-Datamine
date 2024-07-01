from "%scripts/dagui_natives.nut" import clan_get_my_clan_id
from "%scripts/dagui_library.nut" import *
from "%scripts/worldWar/worldWarConst.nut" import *

let u = require("%sqStdLibs/helpers/u.nut")
let { format } = require("string")
let { getCustomViewCountryData } = require("%scripts/worldWar/inOperation/wwOperationCustomAppearance.nut")
let { round } = require("math")
let { userIdInt64 } = require("%scripts/user/profileStates.nut")
let { wwGetPlayerSide } = require("worldwar")
let { WwArmyOwner } = require("%scripts/worldWar/inOperation/model/wwArmyOwner.nut")
let { WwArmyView } = require("%scripts/worldWar/inOperation/model/wwArmy.nut")
let { g_ww_unit_type } = require("%scripts/worldWar/model/wwUnitType.nut")

let WwArmyGroup = class {
  clanId               = ""
  name                 = ""
  supremeCommanderUid   = ""
  supremeCommanderNick = ""

  unitType = g_ww_unit_type.GROUND.code

  owner = null

  managerUids  = null
  observerUids = null
  armyView = null

  armyManagers = null
  isArmyManagersUpdated = false

  constructor(blk) {
    this.clanId               = getTblValue("clanId", blk, "").tostring()
    this.name                 = getTblValue("name", blk, "")
    this.supremeCommanderUid   = getTblValue("supremeCommanderUid", blk, "")
    this.supremeCommanderNick = getTblValue("supremeCommanderNick", blk, "")
    this.owner                = WwArmyOwner(blk.getBlockByName("owner"))
    this.managerUids          = blk.getBlockByName("managerUids") % "item"
    this.observerUids         = blk.getBlockByName("observerUids") % "item" || []
    this.armyManagers         = this.getArmyManagers(blk.getBlockByName("managerStats"))
  }

  function clear() {
    this.clanId               = ""
    this.name                 = ""
    this.supremeCommanderUid   = ""
    this.supremeCommanderNick = ""

    this.owner = null

    this.managerUids  = null
    this.observerUids = null

    this.armyView = null

    this.armyManagers = []
    this.isArmyManagersUpdated = false
  }

  function isValid() {
    return this.name.len() > 0 && this.owner && this.owner.isValid()
  }

  function getView() {
    if (!this.armyView)
      this.armyView = WwArmyView(this)
    return this.armyView
  }

  function isMyArmy(army) {
    return this.getArmyGroupIdx() == army.getArmyGroupIdx() &&
           this.getArmySide()     == army.getArmySide()     &&
           this.getArmyCountry()  == army.getArmyCountry()
  }

  function getGroupUnitType() {
    return this.unitType
  }


  function getFullName() {
    return format("%d %s", this.getArmyGroupIdx(), this.name)
  }

  function getCountryIcon() {
    return getCustomViewCountryData(this.getArmyCountry()).icon
  }

  function showArmyGroupText() {
    return true
  }

  function getClanTag() {
    return this.name
  }

  function getClanId() {
    return this.clanId
  }

  function isMySide(side) {
    return this.getArmySide() == side
  }

  function getArmyGroupIdx() {
    return this.owner.getArmyGroupIdx()
  }

  function getArmyCountry() {
    return this.owner.getCountry()
  }

  function getArmySide() {
    return this.owner.getSide()
  }

  function isBelongsToMyClan() {
    let myClanId = clan_get_my_clan_id()
    if (myClanId && myClanId == this.getClanId())
      return true

    return false
  }

  function getAccessLevel() {
    if (this.supremeCommanderUid == userIdInt64.value || hasFeature("worldWarMaster"))
      return WW_BATTLE_ACCESS.SUPREME

    if (this.owner.side == wwGetPlayerSide()) {
      if (isInArray(userIdInt64.value, this.managerUids))
        return WW_BATTLE_ACCESS.MANAGER
      if (isInArray(userIdInt64.value, this.observerUids))
        return WW_BATTLE_ACCESS.OBSERVER
    }

    return WW_BATTLE_ACCESS.NONE
  }

  function hasManageAccess() {
    let accessLevel = this.getAccessLevel()
    return accessLevel == WW_BATTLE_ACCESS.MANAGER ||
           accessLevel == WW_BATTLE_ACCESS.SUPREME
  }

  function hasObserverAccess() {
    let accessLevel = this.getAccessLevel()
    return accessLevel == WW_BATTLE_ACCESS.OBSERVER ||
           accessLevel == WW_BATTLE_ACCESS.MANAGER ||
           accessLevel == WW_BATTLE_ACCESS.SUPREME
  }

  function getArmyManagers(blk) {
    let managers = []
    if (!blk)
      return managers

    foreach (uid, inst in blk)
      if (u.isDataBlock(inst))
        managers.append({
          uid = uid.tointeger(),
          actionsCount = inst?.actionsCount ?? 0,
          name = "",
          activity = 0
        })

    return managers
  }

  function updateManagerStat(armyManagersNames) {
    let total = this.armyManagers.map(@(m) m.actionsCount).reduce(@(res, value) res + value, 0).tofloat()
    foreach (armyManager in this.armyManagers) {
      armyManager.activity = total > 0
        ? round(100 * armyManager.actionsCount / total).tointeger()
        : 0
      armyManager.name = armyManagersNames?[armyManager.uid].name ?? ""
    }
    this.armyManagers.sort(@(a, b) b.activity <=> a.activity || a.name <=> b.name)
    this.isArmyManagersUpdated = true
  }

  function hasManagersStat() {
    return this.isArmyManagersUpdated && this.armyManagers.len() > 0
  }

  function getUidsForNickRequest(armyManagersNames) {
    return this.armyManagers.filter(@(m) m.name == "" && !(m.uid in armyManagersNames)).map(@(m) m.uid)
  }
}
return {WwArmyGroup}