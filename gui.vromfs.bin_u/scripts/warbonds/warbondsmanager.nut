import "%scripts/g_listener_priority.nut" as g_listener_priority
import "%sqStdLibs/helpers/u.nut" as u
from "%scripts/sqDagui/framework/gui_handlers.nut" import get_gui_handler
from "%scripts/clientState/localProfileDeprecated.nut" import loadLocalByAccount, saveLocalByAccount
from "%scripts/warbonds/warbond.nut" import Warbond
from "%scripts/warbonds/warbondShopState.nut" import leftSpecialTasksBoughtCount
from "%scripts/warbonds/warbondsState.nut" import FULL_ID_SEPARATOR, maxAllowedWarbondsBalance
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv
from "%appGlobals/login/loginState.nut" import hasFullLoginState
from "%sqstd/string.nut" import split
from "blkGetters" import get_price_blk
from "%scripts/dagui_natives.nut" import get_warbond_curr_stage_name
from "%scripts/dagui_library.nut" import *
from "%globalScripts/shopItemConsts.nut" import *
from "%scripts/seen/seenIds.nut" import SEEN

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let seenWarbondsShop = require("%scripts/seen/seenList.nut").get(SEEN.WARBONDS_SHOP)
let { PRICE } = require("%scripts/utils/configs.nut")
let warBondAwardType = require("%scripts/warbonds/warbondAwardType.nut")

const OUT_OF_DATE_DAYS_WARBONDS_SHOP = 28
const WARBOND_ID = "WarBond"

local isListValid = false
let warbondsList = []

function validateWarbondsList() {
  PRICE.checkUpdate()
  if (isListValid)
    return
  isListValid = true

  warbondsList.clear()

  let wBlk = get_price_blk()?.warbonds
  if (!wBlk)
    return

  maxAllowedWarbondsBalance.set(wBlk?.maxAllowedWarbondsBalance ?? maxAllowedWarbondsBalance.get())
  for (local i = 0; i < wBlk.blockCount(); i++) {
    let warbondBlk = wBlk.getBlock(i)
    for (local j = 0; j < warbondBlk.blockCount(); j++) {
      let wbListBlk = warbondBlk.getBlock(j)
      let wbClass = Warbond(warbondBlk.getBlockName(), wbListBlk.getBlockName())
      warbondsList.append(wbClass)
      seenWarbondsShop.setSubListGetter(wbClass.getSeenId(), @() wbClass.getUnseenAwardIds())
    }
  }

  warbondsList.sortby(@(a) -a.expiredTime)

  seenWarbondsShop.setDaysToUnseen(OUT_OF_DATE_DAYS_WARBONDS_SHOP)
  seenWarbondsShop.onListChanged()
}

function getWarbondsList(filterFunc = null) {
  validateWarbondsList()
  if (filterFunc)
    return warbondsList.filter(filterFunc)
  return warbondsList
}

let getUnseenAwardIds = @() getWarbondsList().reduce(@(acc, wb) acc.extend(wb.getUnseenAwardIds()), [])


function getVisibleWarbondsList(filterFunc = null) {
  return getWarbondsList( function(wb) {
                   if (!wb.isVisible())
                     return false
                   return filterFunc ? filterFunc(wb) : true
                 })
}

function getWarbondsBalanceText() {
  let wbList = getVisibleWarbondsList()
  return  wbList?[0].getBalanceText() ?? ""
}

function findWarbond(wbId, wbListId = null) {
  if (!wbListId)
    wbListId = get_warbond_curr_stage_name(wbId)

  return u.search(getWarbondsList(), @(wb) wbId == wb.id && wbListId == wb.listId)
}

function getCurrentWarbond() {
  return findWarbond(WARBOND_ID)
}

function getWarbondAwardByFullId(wbAwardFullId) {
  let data = split(wbAwardFullId, FULL_ID_SEPARATOR)
  if (data.len() < 3)
    return null

  let wb = findWarbond(data[0], data[1])
  return wb && wb.getAwardByIdx(data[2])
}

function isWarbondsShopAvailable() {
  return hasFeature("Warbonds") && hasFeature("WarbondsShop") && getWarbondsList().len() > 0
}

function openWarbondsShop(params = {}) {
  if (!isWarbondsShopAvailable())
    return showInfoMsgBox(loc("msgbox/notAvailbleYet"))

  handlersManager.loadHandler(get_gui_handler("WarbondsShop"), params)
}

function isWarbondsShopButtonVisible() {
  return hasFeature("Warbonds")
}

function checkWarbondsOverLimit(wbAmount, onAcceptFn, params, silent = false) {
  let curWb = getCurrentWarbond()
  if (!curWb)
    return true
  let curBalance = curWb.getBalance()
  let limit = max(maxAllowedWarbondsBalance.get(), curBalance) 
  let newBalance = curBalance + wbAmount
  if (newBalance <= limit)
    return true

  if (!silent) {
    scene_msg_box("warbonds_over_limit",
      null,
      loc("warbond/msg/awardMayBeLost", { maxWarbonds = limit, lostWarbonds = newBalance - limit }),
      [
        ["yes", @() onAcceptFn(params)],
        ["#mainmenu/btnWarbondsShop", @() openWarbondsShop()],
        ["no", @() null ]
      ],
      "#mainmenu/btnWarbondsShop",
      { cancel_fn = @() null })
  }
  return false
}

function updateLeftSpecialTasksBoughtCount() {
  if (!hasFullLoginState.get())
    return

  let specialTaskAward = getCurrentWarbond()?.getAwardByType(warBondAwardType[EWBAT_BATTLE_TASK])
  if (specialTaskAward == null) {
    leftSpecialTasksBoughtCount.set(-1)
    return
  }

  leftSpecialTasksBoughtCount.set(specialTaskAward.getLeftBoughtCount())
}
updateLeftSpecialTasksBoughtCount()

addListenersWithoutEnv({
  function PriceUpdated(_p) {
    isListValid = false
    updateLeftSpecialTasksBoughtCount()
  }
  LoginComplete = @(_p) updateLeftSpecialTasksBoughtCount()
  ProfileUpdated = @(_p) updateLeftSpecialTasksBoughtCount()
}, g_listener_priority.CONFIG_VALIDATION)

seenWarbondsShop.setListGetter(@() getUnseenAwardIds())
seenWarbondsShop.setCompatibilityLoadData(function() {
   let res = {}
   const savePath = "seen/warbond_shop_award"
   let blk = loadLocalByAccount(savePath)
   if (!u.isDataBlock(blk))
     return res

   for (local i = 0; i < blk.blockCount(); i++) {
     let warbondBlk = blk.getBlock(i)
     for (local j = 0; j < warbondBlk.paramCount(); j++)
       res["_".concat(warbondBlk.getBlockName(), warbondBlk.getParamName(j))] <- warbondBlk.getParamValue(j)
   }
   saveLocalByAccount(savePath, null)
   return res
  })


return freeze({
  getWarbondsList
  getWarbondsBalanceText
  findWarbond
  getCurrentWarbond
  getWarbondAwardByFullId
  isWarbondsShopAvailable
  openWarbondsShop
  isWarbondsShopButtonVisible
  checkWarbondsOverLimit
})
