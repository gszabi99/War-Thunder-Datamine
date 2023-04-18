//-file:plus-string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { get_blk_value_by_path } = require("%sqStdLibs/helpers/datablockUtils.nut")
let { GUI, PRICE } = require("%scripts/utils/configs.nut")
let { decimalFormat } = require("%scripts/langUtils/textFormat.nut")

::Warbond <- class {
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

  constructor(wbId, wbListId) {
    this.id = wbId
    this.listId = wbListId
    this.blkListPath = "warbonds/" + this.id + "/" + this.listId

    this.awardsList = []

    let pBlk = ::get_price_blk()
    let listBlk = get_blk_value_by_path(pBlk, this.blkListPath)
    if (!::u.isDataBlock(listBlk))
      return

    this.fontIcon = ::g_warbonds.defaultWbFontIcon

    let guiWarbondsBlock = GUI.get()?.warbonds
    this.medalIcon = getTblValue(this.listId, getTblValue("medalIcons", guiWarbondsBlock), this.medalIcon)
    this.levelIcon = getTblValue(this.listId, getTblValue("levelIcons", guiWarbondsBlock), this.levelIcon)
    this.medalForSpecialTasks = getTblValue("specialTasksByMedal", guiWarbondsBlock, 1)

    //No need to show medal progress if a single medal is required.
    this.needShowSpecialTasksProgress = this.medalForSpecialTasks > 1

    this.expiredTime = listBlk?.expiredTime ?? -1
    this.canEarnTime = listBlk?.endTime ?? -1
    this.levelsArray = listBlk?.levels ? (listBlk.levels % "level") : []
  }

  function getFullId() {
    return this.id + ::g_warbonds.FULL_ID_SEPARATOR + this.listId
  }

  function isCurrent() { //warbond than can be received right now
    return ::get_warbond_curr_stage_name(this.id) == this.listId
  }

  function isVisible() {
    return this.isCurrent() || this.getBalance() > 0
  }

  function validateList() {
    if (this.isListValid)
      return

    this.isListValid = true
    this.awardsList.clear()

    let pBlk = ::get_price_blk()
    let config = get_blk_value_by_path(pBlk, this.blkListPath + "/shop")
    if (!::u.isDataBlock(config))
      return

    let total = config.blockCount()
    for (local i = 0; i < total; i++)
      this.awardsList.append(::WarbondAward(this, config.getBlock(i), i))
  }

  function getAwardsList() {
    this.validateList()
    return this.awardsList
  }

  function getAwardByIdx(awardIdx) {
    let idx = ::to_integer_safe(awardIdx, -1)
    return getTblValue(idx, this.getAwardsList())
  }

  function getAwardById(awardId) {
    return ::u.search(this.getAwardsList(), @(award) award.id == awardId)
  }

  getAwardByType = @(awardType)
    this.getAwardsList().findvalue(@(award) award.awardType == awardType)

  function getPriceText(amount, needShowZero = false, needColorByBalance = true) {
    if (!amount && !needShowZero)
      return ""

    local res = decimalFormat(amount)
    if (needColorByBalance && amount > this.getBalance())
      res = colorize("badTextColor", res)
    return res + loc(this.fontIcon)
  }

  function getBalance() {
    return ::get_warbond_balance(this.id)
  }

  function getBalanceText() {
    let limitText = loc("ui/slash") + this.getPriceText(::g_warbonds.getLimit(), true, false)
    return colorize("activeTextColor", this.getPriceText(this.getBalance(), true, false) + limitText)
  }

  function getExpiredTimeLeft() {
    return this.expiredTime > 0 ? this.expiredTime - ::get_charserver_time_sec() : 0
  }

  function getCanEarnTimeLeft() {
    return this.canEarnTime > 0 ? this.canEarnTime - ::get_charserver_time_sec() : 0
  }

  function getChangeStateTimeLeft() {
    let res = this.isCurrent() ? this.getCanEarnTimeLeft() : this.getExpiredTimeLeft()
    if (res < 0) { //invalid warbond - need price update
      PRICE.update(null, null, false, !this.updateRequested) //forceUpdate request only once
      this.updateRequested = true
    }
    return res
  }

  function getLevelData() {
    return ::warbond_get_shop_levels(this.id, this.listId)
  }

  function haveAnyOrdinaryRequirements() {
    return ::u.search(this.getAwardsList(), @(award) award.haveOrdinaryRequirement()) != null
  }

  function haveAnySpecialRequirements() {
    return ::u.search(this.getAwardsList(), @(award) award.haveSpecialRequirement()) != null
  }

  getLayeredIconStyle = @() ::LayersIcon.getIconData($"reward_battle_task_{this.medalIcon}")
  getMedalIcon = @() $"#ui/gameuiskin#{this.medalIcon}.svg"
  getLevelIcon = @() $"#ui/gameuiskin#{this.levelIcon}.svg"
  getLevelIconOverlay = @() $"#ui/gameuiskin#{this.levelIcon}_overlay"

  function getCurrentShopLevelTasks() {
    return this.getLevelData().Ordinary
  }

  function getCurrentShopLevel() {
    if (!this.haveAnyOrdinaryRequirements())
      return 0

    return this.getShopLevel(this.getCurrentShopLevelTasks())
  }

  function getShopLevel(tasksNum) {
    local shopLevel = 0
    foreach (level, reqTasks in this.levelsArray)
      if (tasksNum >= reqTasks)
        shopLevel = max(shopLevel, level)

    return shopLevel
  }

  function getShopLevelText(level) {
    return ::get_roman_numeral(level + 1)
  }

  function getShopLevelTasks(level) {
    return getTblValue(level, this.levelsArray, this.levelsArray.len() ? this.levelsArray.top() : 0)
  }

  function getNextShopLevelTasks() {
    return this.getShopLevelTasks(this.getCurrentShopLevel() + 1)
  }

  function isMaxLevelReached() {
    return this.levelsArray.top() <= this.getCurrentShopLevelTasks()
  }

  function getCurrentMedalsCount() {
    if (!this.haveAnySpecialRequirements())
      return 0

    return this.getMedalsCount(this.getLevelData().Special)
  }

  function getMedalsCount(tasksCount) {
    return tasksCount / this.medalForSpecialTasks
  }

  function leftForAnotherMedalTasks() {
    return this.getLevelData().Special % this.medalForSpecialTasks
  }

  function needShowNewItemsNotifications() {
    if (!::g_login.isProfileReceived())
      return false

    let curLevel = this.getCurrentShopLevel()
    let lastSeen = ::loadLocalByAccount(this.LAST_SEEN_WARBOND_SHOP_LEVEL_PATH, 0)
    if (curLevel != 0 && lastSeen != curLevel) {
      let balance = this.getBalance()
      if (::u.search(this.getAwardsList(),
          (@(award) this.getShopLevel(award.ordinaryTasks) == curLevel &&
            award.getCost() <= balance).bindenv(this)
        ) != null)
        return true
    }

    let month = ::loadLocalByAccount(this.LAST_SEEN_WARBOND_SHOP_MONTH_PATH, "")
    return month != this.listId
  }

  function markSeenLastResearchShopLevel() {
    if (!this.needShowNewItemsNotifications())
      return

    ::saveLocalByAccount(this.LAST_SEEN_WARBOND_SHOP_MONTH_PATH, this.listId)
    ::saveLocalByAccount(this.LAST_SEEN_WARBOND_SHOP_LEVEL_PATH, this.getCurrentShopLevel())
    ::broadcastEvent("WarbondShopMarkSeenLevel")
  }

  getUnseenAwardIds = @() this.getAwardsList()
    .filter(@(a) !a.isItemLocked())
    .map(@(a) a.getSeenId())

  getSeenId = @() this.listId
}