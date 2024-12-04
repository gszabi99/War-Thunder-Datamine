from "%scripts/dagui_library.nut" import *

let { isHandlerInScene } = require("%sqDagui/framework/baseGuiHandlerManager.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { updatePlayerRankByCountry } = require("%scripts/user/userInfoStats.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { get_shop_blk } = require("blkGetters")
let { isUnitGift } = require("%scripts/unit/unitShopInfo.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { buildUnitSlot, fillUnitSlotTimers } = require("%scripts/slotbar/slotbarView.nut")
let { getNextAwardText } = require("%scripts/unlocks/unlocksModule.nut")
let { isUnitLocked, isUnitUsable } = require("%scripts/unit/unitStatus.nut")

let delayedRankUpWnd = []

gui_handlers.RankUpModal <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/rankUpWindow.blk"

  country = "country_0"
  ranks = []
  unlockData = null

  function initScreen() {
    let aircraftTableObj = this.scene.findObject("rankup_aircraft_table")
    let showAsUnlock = isInArray(0, this.ranks)
    local topRank = 0;
    local airRow = ""
    let unitItems = []

    this.guiScene.playSound("new_rank")

    if (this.country.len() > 0 && (this.country.slice(0, 8) == "country_")) {
      let bgImage = this.scene.findObject("background_country");
      if (bgImage)
        bgImage["background-image"] = "".concat("#ui/images/new_rank_", this.country.slice(8), "?P1")
      this.scene.findObject("country_icon")["background-image"] = getCountryIcon(this.country)
    }

    let blk = get_shop_blk();

    for (local shopCountry = 0; shopCountry < blk.blockCount(); shopCountry++) {  //country
      let cblk = blk.getBlock(shopCountry);
      if (cblk.getBlockName() != this.country)
        continue;

      for (local page = 0; page < cblk.blockCount(); page++) { //pages
        let pblk = cblk.getBlock(page)
        for (local range = 0; range < pblk.blockCount(); range++) {  //ranges
          let rblk = pblk.getBlock(range)
          for (local aircraft = 0; aircraft < rblk.blockCount(); aircraft++) { //aircrafts
            let airBlk = rblk.getBlock(aircraft);
            local air = getAircraftByName(airBlk.getBlockName())
            if (air) {
              if (this.isShowUnit(air, showAsUnlock)) {
                airRow = "".concat(airRow, buildUnitSlot(air.name, air))
                unitItems.append({ id = air.name, unit = air })
              }
            }
            else
              for (local group = 0; group < airBlk.blockCount(); group++) { //airgroup
                let gAirBlk = airBlk.getBlock(group);
                air = getAircraftByName(gAirBlk.getBlockName());
                if (this.isShowUnit(air, showAsUnlock)) {
                  airRow = "".concat(airRow, buildUnitSlot(air.name, air))
                  unitItems.append({ id = air.name, unit = air })
                }
              }
          }
        }
      }
    }

    foreach (r in this.ranks)
      if (topRank < r)
        topRank = r;

    let topRankStr = get_roman_numeral(topRank)
    local headerText = format(loc("userlog/new_rank/country"), topRankStr)
    local rankText = "".concat(loc("shop/age"), colorize("userlogColoredText", topRankStr))
    if (showAsUnlock) {
      let cText = loc(this.country)
      headerText = "".concat(loc("unlocks/country"), loc("ui/colon"), $"<color=@userlogColoredText>{cText}</color>")
      rankText = "".concat(cText, ((topRank > 0) ? $", {rankText}" : ""))
    }
    this.scene.findObject("player_rank").setValue(rankText)
    this.scene.findObject("rankup_country_title").setValue(headerText)

    if (airRow.len() != 0) {
      this.scene.findObject("availableNewAirText").setValue(loc("debriefing/new_aircrafts_available"))
      this.guiScene.replaceContentFromText(aircraftTableObj, airRow, airRow.len(), this);
      foreach (unitItem in unitItems)
        fillUnitSlotTimers(aircraftTableObj.findObject(unitItem.id), unitItem.unit)
    }

    this.updateNextAwardInfo()
  }

  function isShowUnit(unit, showAsUnlock) {
    if (!unit || !unit.unitType.isAvailable())
      return false

    local showUnit = isInArray(unit.rank, this.ranks)
    if (showAsUnlock)
      showUnit = showUnit && !isUnitLocked(unit) && (!isUnitGift(unit) || isUnitUsable(unit))
    else
      showUnit = showUnit && !isUnitGift(unit) && !isUnitUsable(unit)
    return showUnit
  }

  function updateNextAwardInfo() {
    let checkUnlockId = getTblValue("miscParam", this.unlockData)
    if (!checkUnlockId)
      return

    let text = getNextAwardText(checkUnlockId)
    if (text == "")
      return

    let airsObj = this.scene.findObject("rankup_aircraft_holder")
    let newMaxheight = airsObj?["decreased-height"]
    if (newMaxheight)
      airsObj["max-height"] = newMaxheight

    this.scene.findObject("next_award").setValue(text)
  }

  function afterModalDestroy() {
    if (delayedRankUpWnd.len() > 0) {
      loadHandler(gui_handlers.RankUpModal, delayedRankUpWnd[0])
      delayedRankUpWnd.remove(0)
    }
    else
      ::check_delayed_unlock_wnd(this.unlockData)
  }
}

function checkRankUpWindow(country, old_rank, new_rank, unlockData = null) {
  if (country == "country_0" || country == "")
    return false
  if (new_rank <= old_rank)
    return false

  let gained_ranks = [];
  for (local i = old_rank + 1; i <= new_rank; i++)
    gained_ranks.append(i);
  let config = { country = country, ranks = gained_ranks, unlockData = unlockData }
  if (isHandlerInScene(gui_handlers.RankUpModal))
    delayedRankUpWnd.append(config) //better to refactor this to wrok by showUnlockWnd completely
  else
    loadHandler(gui_handlers.RankUpModal, config)
  updatePlayerRankByCountry(country, new_rank)
  return true
}

return {
  checkRankUpWindow
}
