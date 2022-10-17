from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { get_blk_value_by_path } = require("%sqStdLibs/helpers/datablockUtils.nut")
let { GUI, PRICE } = require("%scripts/utils/configs.nut")

::Warbond <- class
{
  id = ""
  listId = ""
  fontIcon = "currency/warbond"
  medalIcon = "hard_task_medal1"
  levelIcon = "level_icon"

  blkListPath = ""
  isListValid = false
  awardsList = null
  levelsArray = null

  expiredTime = -1 //time to which you can spend warbonds
  canEarnTime = -1 //time to which you can earn warbonds. (time to which isCurrent will be true)

  updateRequested = false //warbond will be full reloaded after request complete

  medalForSpecialTasks = 1
  needShowSpecialTasksProgress = true

  static LAST_SEEN_WARBOND_SHOP_LEVEL_PATH = "warbonds/lastReachedShopLevel"
  static LAST_SEEN_WARBOND_SHOP_MONTH_PATH = "warbonds/lastReachedShopMonth"

  constructor(wbId, wbListId)
  {
    id = wbId
    listId = wbListId
    blkListPath = "warbonds/" + id + "/" + listId

    awardsList = []

    let pBlk = ::get_price_blk()
    let listBlk = get_blk_value_by_path(pBlk, blkListPath)
    if (!::u.isDataBlock(listBlk))
      return

    fontIcon = ::g_warbonds.defaultWbFontIcon

    let guiWarbondsBlock = GUI.get()?.warbonds
    medalIcon = getTblValue(listId, getTblValue("medalIcons", guiWarbondsBlock), medalIcon)
    levelIcon = getTblValue(listId, getTblValue("levelIcons", guiWarbondsBlock), levelIcon)
    medalForSpecialTasks = getTblValue("specialTasksByMedal", guiWarbondsBlock, 1)

    //No need to show medal progress if a single medal is required.
    needShowSpecialTasksProgress = medalForSpecialTasks > 1

    expiredTime = listBlk?.expiredTime ?? -1
    canEarnTime = listBlk?.endTime ?? -1
    levelsArray = listBlk?.levels ? (listBlk.levels % "level") : []
  }

  function getFullId()
  {
    return id + ::g_warbonds.FULL_ID_SEPARATOR + listId
  }

  function isCurrent() //warbond than can be received right now
  {
    return ::get_warbond_curr_stage_name(id) == listId
  }

  function isVisible()
  {
    return isCurrent() || getBalance() > 0
  }

  function validateList()
  {
    if (isListValid)
      return

    isListValid = true
    awardsList.clear()

    let pBlk = ::get_price_blk()
    let config = get_blk_value_by_path(pBlk, blkListPath + "/shop")
    if (!::u.isDataBlock(config))
      return

    let total = config.blockCount()
    for(local i = 0; i < total; i++)
      awardsList.append(::WarbondAward(this, config.getBlock(i), i))
  }

  function getAwardsList()
  {
    validateList()
    return awardsList
  }

  function getAwardByIdx(awardIdx)
  {
    let idx = ::to_integer_safe(awardIdx, -1)
    return getTblValue(idx, getAwardsList())
  }

  function getAwardById(awardId)
  {
    return ::u.search(getAwardsList(), @(award) award.id == awardId )
  }

  getAwardByType = @(awardType)
    getAwardsList().findvalue(@(award) award.awardType == awardType)

  function getPriceText(amount, needShowZero = false, needColorByBalance = true)
  {
    if (!amount && !needShowZero)
      return ""

    local res = ::g_language.decimalFormat(amount)
    if (needColorByBalance && amount > getBalance())
      res = colorize("badTextColor", res)
    return res + loc(fontIcon)
  }

  function getBalance()
  {
    return ::get_warbond_balance(id)
  }

  function getBalanceText()
  {
    let limitText = loc("ui/slash") + getPriceText(::g_warbonds.getLimit(), true, false)
    return colorize("activeTextColor", getPriceText(getBalance(), true, false) + limitText)
  }

  function getExpiredTimeLeft()
  {
    return expiredTime > 0 ? expiredTime - ::get_charserver_time_sec() : 0
  }

  function getCanEarnTimeLeft()
  {
    return canEarnTime > 0 ? canEarnTime - ::get_charserver_time_sec() : 0
  }

  function getChangeStateTimeLeft()
  {
    let res = isCurrent() ? getCanEarnTimeLeft() : getExpiredTimeLeft()
    if (res < 0) //invalid warbond - need price update
    {
      PRICE.update(null, null, false, !updateRequested) //forceUpdate request only once
      updateRequested = true
    }
    return res
  }

  function getLevelData()
  {
    return ::warbond_get_shop_levels(id, listId)
  }

  function haveAnyOrdinaryRequirements()
  {
    return ::u.search(getAwardsList(), @(award) award.haveOrdinaryRequirement()) != null
  }

  function haveAnySpecialRequirements()
  {
    return ::u.search(getAwardsList(), @(award) award.haveSpecialRequirement()) != null
  }

  getLayeredIconStyle = @() ::LayersIcon.getIconData($"reward_battle_task_{medalIcon}")
  getMedalIcon = @() $"#ui/gameuiskin#{medalIcon}.svg"
  getLevelIcon = @() $"#ui/gameuiskin#{levelIcon}.svg"
  getLevelIconOverlay = @() $"#ui/gameuiskin#{levelIcon}_overlay.png"

  function getCurrentShopLevelTasks()
  {
    return getLevelData().Ordinary
  }

  function getCurrentShopLevel()
  {
    if (!haveAnyOrdinaryRequirements())
      return 0

    return getShopLevel(getCurrentShopLevelTasks())
  }

  function getShopLevel(tasksNum)
  {
    local shopLevel = 0
    foreach (level, reqTasks in levelsArray)
      if (tasksNum >= reqTasks)
        shopLevel = max(shopLevel, level)

    return shopLevel
  }

  function getShopLevelText(level)
  {
    return ::get_roman_numeral(level + 1)
  }

  function getShopLevelTasks(level)
  {
    return getTblValue(level, levelsArray, levelsArray.len()? levelsArray.top() : 0)
  }

  function getNextShopLevelTasks()
  {
    return getShopLevelTasks(getCurrentShopLevel() + 1)
  }

  function isMaxLevelReached()
  {
    return levelsArray.top() <= getCurrentShopLevelTasks()
  }

  function getCurrentMedalsCount()
  {
    if (!haveAnySpecialRequirements())
      return 0

    return getMedalsCount(getLevelData().Special)
  }

  function getMedalsCount(tasksCount)
  {
    return tasksCount / medalForSpecialTasks
  }

  function leftForAnotherMedalTasks()
  {
    return getLevelData().Special % medalForSpecialTasks
  }

  function needShowNewItemsNotifications()
  {
    if (!::g_login.isProfileReceived())
      return false

    let curLevel = getCurrentShopLevel()
    let lastSeen = ::loadLocalByAccount(LAST_SEEN_WARBOND_SHOP_LEVEL_PATH, 0)
    if (curLevel != 0 && lastSeen != curLevel)
    {
      let balance = getBalance()
      if (::u.search(getAwardsList(),
          (@(award) getShopLevel(award.ordinaryTasks) == curLevel &&
            award.getCost() <= balance).bindenv(this)
        ) != null)
        return true
    }

    let month = ::loadLocalByAccount(LAST_SEEN_WARBOND_SHOP_MONTH_PATH, "")
    return month != listId
  }

  function markSeenLastResearchShopLevel()
  {
    if (!needShowNewItemsNotifications())
      return

    ::saveLocalByAccount(LAST_SEEN_WARBOND_SHOP_MONTH_PATH, listId)
    ::saveLocalByAccount(LAST_SEEN_WARBOND_SHOP_LEVEL_PATH, getCurrentShopLevel())
    ::broadcastEvent("WarbondShopMarkSeenLevel")
  }

  getUnseenAwardIds = @() getAwardsList()
    .filter(@(a) !a.isItemLocked())
    .map(@(a) a.getSeenId())

  getSeenId = @() listId
}