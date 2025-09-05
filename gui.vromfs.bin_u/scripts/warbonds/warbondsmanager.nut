from "%scripts/dagui_natives.nut" import get_warbond_curr_stage_name
from "%scripts/dagui_library.nut" import *
from "%scripts/mainConsts.nut" import SEEN

let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let seenWarbondsShop = require("%scripts/seen/seenList.nut").get(SEEN.WARBONDS_SHOP)
let { PRICE } = require("%scripts/utils/configs.nut")
let { Warbond } = require("%scripts/warbonds/warbond.nut")
let { split } = require("%sqstd/string.nut")
let { get_price_blk } = require("blkGetters")
let { leftSpecialTasksBoughtCount } = require("%scripts/warbonds/warbondShopState.nut")
let { FULL_ID_SEPARATOR, maxAllowedWarbondsBalance } = require("%scripts/warbonds/warbondsState.nut")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")
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

  warbondsList.sort(function(a, b) {
    if (a.expiredTime != b.expiredTime)
      return a.expiredTime > b.expiredTime ? -1 : 1
    return 0
  })

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

  handlersManager.loadHandler(gui_handlers.WarbondsShop, params)
}

function isWarbondsShopButtonVisible() {
  return hasFeature("Warbonds")
}

function checkWarbondsOverLimit(wbAmount, onAcceptFn, params, silent = false) {
  let curWb = getCurrentWarbond()
  if (!curWb)
    return true
  let limit = maxAllowedWarbondsBalance.get()
  let newBalance = curWb.getBalance() + wbAmount
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
  if (!isLoggedIn.get())
    return

  let specialTaskAward = getCurrentWarbond()?.getAwardByType(warBondAwardType[EWBAT_BATTLE_TASK])
  if (specialTaskAward == null) {
    leftSpecialTasksBoughtCount.set(-1)
    return
  }

  leftSpecialTasksBoughtCount.set(specialTaskAward.getLeftBoughtCount())
}

addListenersWithoutEnv({
  function PriceUpdated(_p) {
    isListValid = false
    updateLeftSpecialTasksBoughtCount()
  }
  LoginComplete = @(_p) updateLeftSpecialTasksBoughtCount()
  ScriptsReloaded = @(_p) updateLeftSpecialTasksBoughtCount()
  ProfileUpdated = @(_p) updateLeftSpecialTasksBoughtCount()
}, g_listener_priority.CONFIG_VALIDATION)

seenWarbondsShop.setListGetter(@() getUnseenAwardIds())
seenWarbondsShop.setCompatibilityLoadData(function() {
   let res = {}
   let savePath = "seen/warbond_shop_award"
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

::g_warbonds <- {
  checkWarbondsOverLimit
  findWarbond
  getCurrentWarbond
}

return {
  getWarbondsList
  getWarbondsBalanceText
  findWarbond
  getCurrentWarbond
  getWarbondAwardByFullId
  isWarbondsShopAvailable
  openWarbondsShop
  isWarbondsShopButtonVisible
}