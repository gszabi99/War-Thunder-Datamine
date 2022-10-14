from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { format } = require("string")
let { getCustomViewCountryData } = require("%scripts/worldWar/inOperation/wwOperationCustomAppearance.nut")

::WwArmyGroup <- class
{
  clanId               = ""
  name                 = ""
  supremeCommanderUid   = ""
  supremeCommanderNick = ""

  unitType = ::g_ww_unit_type.GROUND.code

  owner = null

  managerUids  = null
  observerUids = null
  armyView = null

  armyManagers = null
  isArmyManagersUpdated = false

  constructor(blk)
  {
    clanId               = getTblValue("clanId", blk, "").tostring()
    name                 = getTblValue("name", blk, "")
    supremeCommanderUid   = getTblValue("supremeCommanderUid", blk, "")
    supremeCommanderNick = getTblValue("supremeCommanderNick", blk, "")
    owner                = ::WwArmyOwner(blk.getBlockByName("owner"))
    managerUids          = blk.getBlockByName("managerUids") % "item"
    observerUids         = blk.getBlockByName("observerUids") % "item" || []
    armyManagers         = getArmyManagers(blk.getBlockByName("managerStats"))
  }

  function clear()
  {
    clanId               = ""
    name                 = ""
    supremeCommanderUid   = ""
    supremeCommanderNick = ""

    owner = null

    managerUids  = null
    observerUids = null

    armyView = null

    armyManagers = []
    isArmyManagersUpdated = false
  }

  function isValid()
  {
    return name.len() > 0 && owner && owner.isValid()
  }

  function getView()
  {
    if (!armyView)
      armyView = ::WwArmyView(this)
    return armyView
  }

  function isMyArmy(army)
  {
    return getArmyGroupIdx() == army.getArmyGroupIdx() &&
           getArmySide()     == army.getArmySide()     &&
           getArmyCountry()  == army.getArmyCountry()
  }

  function getGroupUnitType()
  {
    return unitType
  }


  function getFullName()
  {
    return format("%d %s", getArmyGroupIdx(), name)
  }

  function getCountryIcon()
  {
    return getCustomViewCountryData(getArmyCountry()).icon
  }

  function showArmyGroupText()
  {
    return true
  }

  function getClanTag()
  {
    return name
  }

  function getClanId()
  {
    return clanId
  }

  function isMySide(side)
  {
    return getArmySide() == side
  }

  function getArmyGroupIdx()
  {
    return owner.getArmyGroupIdx()
  }

  function getArmyCountry()
  {
    return owner.getCountry()
  }

  function getArmySide()
  {
    return owner.getSide()
  }

  function isBelongsToMyClan()
  {
    let myClanId = ::clan_get_my_clan_id()
    if (myClanId && myClanId == getClanId())
      return true

    return false
  }

  function getAccessLevel()
  {
    if (supremeCommanderUid == ::my_user_id_int64 || hasFeature("worldWarMaster"))
      return WW_BATTLE_ACCESS.SUPREME

    if (owner.side == ::ww_get_player_side())
    {
      if (isInArray(::my_user_id_int64, managerUids))
        return WW_BATTLE_ACCESS.MANAGER
      if (isInArray(::my_user_id_int64, observerUids))
        return WW_BATTLE_ACCESS.OBSERVER
    }

    return WW_BATTLE_ACCESS.NONE
  }

  function hasManageAccess()
  {
    let accessLevel = getAccessLevel()
    return accessLevel == WW_BATTLE_ACCESS.MANAGER ||
           accessLevel == WW_BATTLE_ACCESS.SUPREME
  }

  function hasObserverAccess()
  {
    let accessLevel = getAccessLevel()
    return accessLevel == WW_BATTLE_ACCESS.OBSERVER ||
           accessLevel == WW_BATTLE_ACCESS.MANAGER ||
           accessLevel == WW_BATTLE_ACCESS.SUPREME
  }

  function getArmyManagers(blk)
  {
    let managers = []
    if (!blk)
      return managers

    foreach(uid, inst in blk)
      if (::u.isDataBlock(inst))
        managers.append({
          uid = uid.tointeger(),
          actionsCount = inst?.actionsCount ?? 0,
          name = "",
          activity = 0
        })

    return managers
  }

  function updateManagerStat(armyManagersNames)
  {
    let total = armyManagers.map(@(m) m.actionsCount).reduce(@(res, value) res + value, 0).tofloat()
    foreach(armyManager in armyManagers) {
      armyManager.activity = total > 0
        ? ::round(100 * armyManager.actionsCount / total).tointeger()
        : 0
      armyManager.name = armyManagersNames?[armyManager.uid].name ?? ""
    }
    armyManagers.sort(@(a,b) b.activity <=> a.activity || a.name<=> b.name)
    isArmyManagersUpdated = true
  }

  function hasManagersStat()
  {
    return isArmyManagersUpdated && armyManagers.len() > 0
  }

  function getUidsForNickRequest(armyManagersNames)
  {
    return armyManagers.filter(@(m) m.name == "" && !(m.uid in armyManagersNames)).map(@(m) m.uid)
  }
}
