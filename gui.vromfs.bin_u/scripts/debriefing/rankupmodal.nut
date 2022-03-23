let { updatePlayerRankByCountry } = require("%scripts/ranks.nut")

let delayedRankUpWnd = []

::gui_handlers.RankUpModal <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/rankUpWindow.blk";

  country = "country_0";
  ranks = [];
  unlockData = null

  function initScreen()
  {
    let aircraftTableObj = scene.findObject("rankup_aircraft_table");
    let showAsUnlock = ::isInArray(0, ranks)
    local topRank = 0;
    local airRow = "";
    let unitItems = []
    ::show_facebook_screenshot_button(scene)

    guiScene.playSound("new_rank")

    if (country.len() > 0 && (country.slice(0, 8) == "country_"))
    {
      let bgImage = scene.findObject("background_country");
      if(bgImage) bgImage["background-image"] = "#ui/images/new_rank_" + country.slice(8) + ".jpg?P1"
      scene.findObject("country_icon")["background-image"] = ::get_country_icon(country)
    }

    let blk = ::get_shop_blk();

    for(local shopCountry=0; shopCountry<blk.blockCount(); shopCountry++)  //country
    {
      let cblk = blk.getBlock(shopCountry);
      if (cblk.getBlockName() != country)
        continue;

      for(local page=0; page<cblk.blockCount(); page++) //pages
      {
        let pblk = cblk.getBlock(page)
        for(local range=0; range<pblk.blockCount(); range++)  //ranges
        {
          let rblk = pblk.getBlock(range)
          for(local aircraft=0; aircraft<rblk.blockCount(); aircraft++) //aircrafts
          {
            let airBlk = rblk.getBlock(aircraft);
            local air = getAircraftByName(airBlk.getBlockName());
            if (air)
            {
              if (isShowUnit(air, showAsUnlock))
              {
                airRow += build_aircraft_item(air.name, air);
                unitItems.append({ id = air.name, unit = air })
              }
            }
            else
              for(local group=0; group<airBlk.blockCount(); group++) //airgroup
              {
                let gAirBlk = airBlk.getBlock(group);
                air = getAircraftByName(gAirBlk.getBlockName());
                if (isShowUnit(air, showAsUnlock))
                {
                  airRow += build_aircraft_item(air.name, air);
                  unitItems.append({ id = air.name, unit = air })
                }
              }
          }
        }
      }
    }

    foreach (r in ranks)
      if (topRank < r)
        topRank = r;

    let topRankStr = ::get_roman_numeral(topRank)
    local headerText = format(::loc("userlog/new_rank/country"), topRankStr)
    local rankText = ::loc("shop/age") + ::colorize("userlogColoredText", topRankStr)
    if (showAsUnlock)
    {
      let cText = ::loc(country)
      headerText = ::loc("unlocks/country") + ::loc("ui/colon") + "<color=@userlogColoredText>" + cText + "</color>"
      rankText = cText + ((topRank>0)? ", " + rankText : "")
    }
    scene.findObject("player_rank").setValue(rankText)
    scene.findObject("rankup_country_title").setValue(headerText)

    if(airRow.len() != 0) {
      scene.findObject("availableNewAirText").setValue(::loc("debriefing/new_aircrafts_available"))
      guiScene.replaceContentFromText(aircraftTableObj, airRow, airRow.len(), this);
      foreach (unitItem in unitItems)
        ::fill_unit_item_timers(aircraftTableObj.findObject(unitItem.id), unitItem.unit, unitItem.params)
    }

    updateNextAwardInfo()
  }

  function isShowUnit(unit, showAsUnlock)
  {
    if (!unit || !unit.unitType.isAvailable())
      return false

    local showUnit = isInArray(unit.rank, ranks)
    if (showAsUnlock)
      showUnit = showUnit && !::isUnitLocked(unit) && (!::isUnitGift(unit) || ::isUnitUsable(unit))
    else
      showUnit = showUnit && !::isUnitGift(unit) && !::isUnitUsable(unit)
    return showUnit
  }

  function updateNextAwardInfo()
  {
    let checkUnlockId = ::getTblValue("miscParam", unlockData)
    if (!checkUnlockId)
      return

    let text = ::get_next_award_text(checkUnlockId)
    if (text == "")
      return

    let airsObj = scene.findObject("rankup_aircraft_holder")
    let newMaxheight = airsObj?["decreased-height"]
    if (newMaxheight)
      airsObj["max-height"] = newMaxheight

    scene.findObject("next_award").setValue(text)
  }

  function afterModalDestroy()
  {
    if (delayedRankUpWnd.len() > 0)
    {
      ::gui_start_modal_wnd(::gui_handlers.RankUpModal, delayedRankUpWnd[0])
      delayedRankUpWnd.remove(0)
    } else
      ::check_delayed_unlock_wnd(unlockData)
  }
}

let function checkRankUpWindow(country, old_rank, new_rank, unlockData = null) {
  if (country == "country_0" || country == "")
    return false
  if (new_rank <= old_rank)
    return false

  let gained_ranks = [];
  for (local i = old_rank+1; i<=new_rank; i++)
    gained_ranks.append(i);
  let config = { country = country, ranks = gained_ranks, unlockData = unlockData }
  if (::isHandlerInScene(::gui_handlers.RankUpModal))
    delayedRankUpWnd.append(config) //better to refactor this to wrok by showUnlockWnd completely
  else
    ::gui_start_modal_wnd(::gui_handlers.RankUpModal, config)
  updatePlayerRankByCountry(country, new_rank)
  return true
}

return {
  checkRankUpWindow
}
