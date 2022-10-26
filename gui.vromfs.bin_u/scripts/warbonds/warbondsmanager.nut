from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let seenWarbondsShop = require("%scripts/seen/seenList.nut").get(SEEN.WARBONDS_SHOP)
let { PRICE } = require("%scripts/utils/configs.nut")

const MAX_ALLOWED_WARBONDS_BALANCE = 0x7fffffff
let OUT_OF_DATE_DAYS_WARBONDS_SHOP = 28

::g_warbonds <- {
  FULL_ID_SEPARATOR = "."

  list = []
  isListValid = false

  fontIcons = {}
  isFontIconsValid = false
  defaultWbFontIcon = "currency/warbond/green"

  maxAllowedWarbondsBalance = MAX_ALLOWED_WARBONDS_BALANCE //default value as on server side, MAX_ALLOWED_WARBONDS_BALANCE

  WARBOND_ID = "WarBond"

  function getList(filterFunc = null)
  {
    this.validateList()
    if (filterFunc)
      return ::u.filter(this.list, filterFunc)
    return this.list
  }

  getUnseenAwardIds = @() this.getList().reduce(@(acc, wb) acc.extend(wb.getUnseenAwardIds()), [])
}

::g_warbonds.getVisibleList <- function getVisibleList(filterFunc = null)
{
  return this.getList((@(filterFunc) function(wb) {
                   if (!wb.isVisible())
                     return false
                   return filterFunc ? filterFunc(wb) : true
                 })(filterFunc))
}

::g_warbonds.validateList <- function validateList()
{
  PRICE.checkUpdate()
  if (this.isListValid)
    return
  this.isListValid = true

  this.list.clear()

  let wBlk = ::get_price_blk()?.warbonds
  if (!wBlk)
    return

  this.maxAllowedWarbondsBalance = wBlk?.maxAllowedWarbondsBalance ?? this.maxAllowedWarbondsBalance
  for(local i = 0; i < wBlk.blockCount(); i++)
  {
    let warbondBlk = wBlk.getBlock(i)
    for(local j = 0; j < warbondBlk.blockCount(); j++)
    {
      let wbListBlk = warbondBlk.getBlock(j)
      let wbClass = ::Warbond(warbondBlk.getBlockName(), wbListBlk.getBlockName())
      this.list.append(wbClass)
      seenWarbondsShop.setSubListGetter(wbClass.getSeenId(), @() wbClass.getUnseenAwardIds())
    }
  }

  this.list.sort(function(a, b)
  {
    if (a.expiredTime != b.expiredTime)
      return a.expiredTime > b.expiredTime ? -1 : 1
    return 0
  })

  seenWarbondsShop.setDaysToUnseen(OUT_OF_DATE_DAYS_WARBONDS_SHOP)
  seenWarbondsShop.onListChanged()
}

::g_warbonds.getBalanceText <- function getBalanceText()
{
  let wbList = this.getVisibleList()
  return wbList.len()? wbList[0].getBalanceText() : ""
}

::g_warbonds.isWarbondsRecounted <- function isWarbondsRecounted()
{
  local hasCurrent = false
  local timersValid = true
  foreach(wb in this.getList())
  {
    hasCurrent = hasCurrent || wb.isCurrent()
    timersValid = timersValid && wb.getChangeStateTimeLeft() >= 0
  }
  return hasCurrent && timersValid
}

::g_warbonds.getInfoText <- function getInfoText()
{
  if (!::g_warbonds.isWarbondsRecounted())
    return loc("warbonds/recalculating")
  return this.getBalanceText()
}

::g_warbonds.findWarbond <- function findWarbond(wbId, wbListId = null)
{
  if (!wbListId)
    wbListId = ::get_warbond_curr_stage_name(wbId)

  return ::u.search(this.getList(), @(wb) wbId == wb.id && wbListId == wb.listId)
}

::g_warbonds.getCurrentWarbond <- function getCurrentWarbond()
{
  return this.findWarbond(this.WARBOND_ID)
}

::g_warbonds.getWarbondByFullId <- function getWarbondByFullId(wbFullId)
{
  let data = ::g_string.split(wbFullId, this.FULL_ID_SEPARATOR)
  if (data.len() >= 2)
    return this.findWarbond(data[0], data[1])
  return null
}

::g_warbonds.getWarbondAwardByFullId <- function getWarbondAwardByFullId(wbAwardFullId)
{
  let data = ::g_string.split(wbAwardFullId, this.FULL_ID_SEPARATOR)
  if (data.len() < 3)
    return null

  let wb = this.findWarbond(data[0], data[1])
  return wb && wb.getAwardByIdx(data[2])
}

::g_warbonds.getWarbondPriceText <- function getWarbondPriceText(amount)
{
  if (!amount)
    return ""
  return amount + loc(this.defaultWbFontIcon)
}

::g_warbonds.openShop <- function openShop(params = {})
{
  if (!this.isShopAvailable())
    return ::showInfoMsgBox(loc("msgbox/notAvailbleYet"))

  ::g_warbonds_view.resetShowProgressBarFlag()
  ::handlersManager.loadHandler(::gui_handlers.WarbondsShop, params)
}

::g_warbonds.isShopAvailable <- function isShopAvailable()
{
  return hasFeature("Warbonds") && hasFeature("WarbondsShop") && this.getList().len() > 0
}

::g_warbonds.isShopButtonVisible <- function isShopButtonVisible()
{
  return hasFeature("Warbonds")
}

::g_warbonds.getLimit <- function getLimit()
{
  return this.maxAllowedWarbondsBalance
}

::g_warbonds.checkOverLimit <- function checkOverLimit(wbAmount, onAcceptFn, params, silent = false)
{
  let curWb = ::g_warbonds.getCurrentWarbond()
  if (!curWb)
    return true
  let limit = this.getLimit()
  let newBalance = curWb.getBalance() + wbAmount
  if (newBalance <= limit)
    return true

  if (!silent)
  {
    ::scene_msg_box("warbonds_over_limit",
      null,
      loc("warbond/msg/awardMayBeLost", {maxWarbonds = limit, lostWarbonds = newBalance - limit}),
      [
        ["yes", @() onAcceptFn(params)],
        ["#mainmenu/btnWarbondsShop", @() ::g_warbonds.openShop()],
        ["no", @() null ]
      ],
      "#mainmenu/btnWarbondsShop",
      {cancel_fn = @() null})
  }
  return false
}

::g_warbonds.onEventPriceUpdated <- function onEventPriceUpdated(_p)
{
  this.isListValid = false
}

::g_warbonds.onEventInitConfigs <- function onEventInitConfigs(_p)
{
  this.isFontIconsValid = false
}

::subscribe_handler(::g_warbonds ::g_listener_priority.CONFIG_VALIDATION)

seenWarbondsShop.setListGetter(@() ::g_warbonds.getUnseenAwardIds())
seenWarbondsShop.setCompatibilityLoadData(function()
 {
   let res = {}
   let savePath = "seen/warbond_shop_award"
   let blk = ::loadLocalByAccount(savePath)
   if (!::u.isDataBlock(blk))
     return res

   for (local i = 0; i < blk.blockCount(); i++)
   {
     let warbondBlk = blk.getBlock(i)
     for (local j = 0; j < warbondBlk.paramCount(); j++)
       res[warbondBlk.getBlockName() + "_" + warbondBlk.getParamName(j)] <- warbondBlk.getParamValue(j)
   }
   ::saveLocalByAccount(savePath, null)
   return res
  })
