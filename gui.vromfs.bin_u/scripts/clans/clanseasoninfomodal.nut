let { format } = require("string")
let { DECORATION } = require("%scripts/utils/genericTooltipTypes.nut")
let { getSelectedChild } = require("%sqDagui/daguiUtil.nut")

::show_clan_season_info <- function show_clan_season_info(difficulty)
{
  ::gui_start_modal_wnd(
    ::gui_handlers.clanSeasonInfoModal,
    {difficulty = difficulty}
  )
}

::gui_handlers.clanSeasonInfoModal <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType      = handlerType.MODAL
  sceneBlkName = "%gui/clans/clanSeasonInfoModal.blk"

  difficulty = null

  rewardsListObj = null
  selectedIndex  = 0

  function initScreen()
  {
    if (!::g_clan_seasons.isEnabled())
      return goBack()
    rewardsListObj = scene.findObject("rewards_list")
    if (!::checkObj(rewardsListObj))
      return goBack()

    scene.findObject("wnd_title").setValue(::loc("clan/battle_season/title") + " - " + ::loc("mainmenu/rewardsList"))

    fillRewardsList()
    selectListItem()
  }

  function fillRewardsList()
  {
    let view = getRewardsView(difficulty)
    let markup = ::handyman.renderCached("%gui/clans/clanSeasonInfoListItem", view)
    guiScene.appendWithBlk(rewardsListObj, markup, this)
  }

  function getRewardsView(diff)
  {
    let view = { rewardsList = [] }
    let rewards = ::g_clan_seasons.getSeasonRewardsList(diff)
    if (::u.isEmpty(rewards))
      return view

    let seasonName = ::g_clan_seasons.getSeasonName()
    foreach(reward in rewards)
    {
      local title = ""
      local medal = ""
      switch(reward.rType)
      {
        case CLAN_SEASON_MEDAL_TYPE.PLACE:
          title = ::loc("clan/season_award/place/place" + reward.place)
          medal = "place" + reward.place
          break
        case CLAN_SEASON_MEDAL_TYPE.TOP:
          title = ::loc("clan/season_award/place/top", { top = reward.place })
          medal = "top" + reward.place
          break
        case CLAN_SEASON_MEDAL_TYPE.RATING:
          title = ::loc("clan/season_award/rating", { ratingValue = reward.rating })
          medal = reward.rating + "rating"
          break
      }
      let medalIconMarkup = ::LayersIcon.getIconData(format("clan_medal_%s_%s", medal, diff.egdLowercaseName),
        null, null, null, { season_title = { text = seasonName } })

      local condition = ""
      if (reward.placeMin)
        condition = ::loc("multiplayer/place") + ::loc("ui/colon") + reward.placeMin + ::loc("ui/mdash") + reward.placeMax
      else if (reward.place)
        condition = ::loc("multiplayer/place") + ::loc("ui/colon") + reward.place
      else if (reward.rating)
        condition = ::loc("userLog/clanDuelRewardClanRating") + " " + reward.rating

      local gold = ""
      if (reward.gold)
      {
        let value = reward.goldMin ?
          (::Cost(0, reward.goldMin).tostring() + ::loc("ui/mdash") + ::Cost(0, reward.goldMax).tostring()) :
          ::Cost(0, reward.gold).tostring()
        gold = ::loc("charServer/chapter/eagles") + ::loc("ui/colon") + value
      }

      let prizesList = {}
      let prizes = ::g_clan_seasons.getRegaliaPrizes(reward.regalia)
      let limits = ::g_clan_seasons.getUniquePrizesCounts(reward.regalia)
      foreach (prize in prizes)
      {
        let prizeType = prize.type
        let collection = []

        if (prizeType == "clanTag")
        {
          let myClanTagUndecorated = ::g_clans.stripClanTagDecorators(::clan_get_my_clan_tag())
          let tagTxt = ::u.isEmpty(myClanTagUndecorated) ? ::loc("clan/clan_tag/short") : myClanTagUndecorated
          let tooltipBase = ::loc("clan/clan_tag_decoration") + ::loc("ui/colon")
          let tagDecorators = ::g_clan_tag_decorator.getDecoratorsForClanDuelRewards(prize.list)
          foreach (decorator in tagDecorators)
            collection.append({
              start = decorator.start
              tag   = tagTxt
              end   = decorator.end
              tooltip = tooltipBase + ::colorize("activeTextColor", decorator.start + tagTxt + decorator.end)
            })
        }
        else if (prizeType == "decal")
        {
          let decorType = ::g_decorator_type.DECALS
          foreach (decalId in prize.list)
          {
            let decal = ::g_decorator.getDecorator(decalId, decorType)
            collection.append({
              id = decalId
              image = decorType.getImage(decal)
              ratio = clamp(decorType.getRatio(decal), 1, 2)
              tooltipId = DECORATION.getTooltipId(decalId, decorType.unlockedItemType)
            })
          }
        }

        let uniqueCount = ::getTblValue(prizeType, limits, 0) || collection.len()
        let splitList = {
          unique = []
          bonus  = []
        }
        foreach (idx, item in collection)
          splitList[(idx < uniqueCount) ? "unique" : "bonus"].append(item)
        prizesList[prizeType] <- splitList
      }

      let uniqueClantags = prizesList?.clanTag.unique ?? []
      let uniqueDecals   = prizesList?.decal.unique ?? []
      let bonusClantags  = prizesList?.clanTag.bonus ?? []
      let bonusDecals    = prizesList?.decal.bonus ?? []

      view.rewardsList.append({
        title      = title
        medalIcon  = medalIconMarkup
        condition  = condition
        gold       = gold
        hasBonuses = bonusClantags.len() > 0 || bonusDecals.len() > 0

        hasUniqueClantags = uniqueClantags.len() > 0
        hasUniqueDecals   = uniqueDecals.len()  > 0
        hasBonusClantags  = bonusClantags.len()  > 0
        hasBonusDecals    = bonusDecals.len()   > 0

        uniqueClantags = uniqueClantags.len() ? uniqueClantags : null
        uniqueDecals   = uniqueDecals.len()   ? uniqueDecals   : null
        bonusClantags  = bonusClantags.len()  ? bonusClantags  : null
        bonusDecals    = bonusDecals.len()    ? bonusDecals    : null
      })
    }

    return view
  }

  function onShowBonuses(obj)
  {
    let bonusesObj = ::checkObj(obj) ? obj.getParent().findObject("bonuses_panel") : null
    if (!::checkObj(bonusesObj))
      return
    let isShow = bonusesObj["toggled"] != "yes"
    bonusesObj["toggled"] = isShow ? "yes" : "no"
    bonusesObj.show(isShow)

    obj.setValue(isShow ? ::loc("mainmenu/btnCollapse") : (::loc("clan/season_award/desc/lower_places_awards_included") + ::loc("ui/ellipsis")))
    obj["tooltip"] = isShow ? "" : ::loc("mainmenu/btnExpand")
  }

  function selectListItem()
  {
    if (rewardsListObj.childrenCount() <= 0)
      return

    if (selectedIndex >= rewardsListObj.childrenCount())
      selectedIndex = rewardsListObj.childrenCount() - 1

    rewardsListObj.setValue(selectedIndex)
    ::move_mouse_on_child(rewardsListObj, selectedIndex)
  }

  function onItemSelect(obj)
  {
    let listChildrenCount = rewardsListObj.childrenCount()
    let index = obj.getValue()
    selectedIndex = (index >= 0 && index < listChildrenCount) ? index : 0
  }

  function showBonusesByActivateItem(obj)
  {
    let btnObj = getSelectedChild(obj)?.findObject("show_bonuses_btn")
    if (btnObj?.isValid())
      onShowBonuses(btnObj)
  }

  function onBtnMoreInfo(obj)
  {
  }
}
