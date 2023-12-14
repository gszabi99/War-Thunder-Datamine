//-file:plus-string
from "%scripts/dagui_natives.nut" import clan_get_my_clan_tag
from "%scripts/dagui_library.nut" import *
from "%scripts/clans/clansConsts.nut" import CLAN_SEASON_MEDAL_TYPE

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let { move_mouse_on_child, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { Cost } = require("%scripts/money.nut")
let u = require("%sqStdLibs/helpers/u.nut")

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

let { format } = require("string")
let { DECORATION } = require("%scripts/utils/genericTooltipTypes.nut")
let { getSelectedChild } = require("%sqDagui/daguiUtil.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { getDecorator } = require("%scripts/customization/decorCache.nut")
let { decoratorTypes } = require("%scripts/customization/types.nut")

gui_handlers.clanSeasonInfoModal <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType      = handlerType.MODAL
  sceneBlkName = "%gui/clans/clanSeasonInfoModal.blk"

  difficulty = null

  rewardsListObj = null
  selectedIndex  = 0

  function initScreen() {
    if (!::g_clan_seasons.isEnabled())
      return this.goBack()
    this.rewardsListObj = this.scene.findObject("rewards_list")
    if (!checkObj(this.rewardsListObj))
      return this.goBack()

    this.scene.findObject("wnd_title").setValue(loc("clan/battle_season/title") + " - " + loc("mainmenu/rewardsList"))

    this.fillRewardsList()
    this.selectListItem()
  }

  function fillRewardsList() {
    let view = this.getRewardsView(this.difficulty)
    let markup = handyman.renderCached("%gui/clans/clanSeasonInfoListItem.tpl", view)
    this.guiScene.appendWithBlk(this.rewardsListObj, markup, this)
  }

  function getRewardsView(diff) {
    let view = { rewardsList = [] }
    let rewards = ::g_clan_seasons.getSeasonRewardsList(diff)
    if (u.isEmpty(rewards))
      return view

    let seasonName = ::g_clan_seasons.getSeasonName()
    foreach (reward in rewards) {
      local title = ""
      local medal = ""
      if (reward.rType == CLAN_SEASON_MEDAL_TYPE.PLACE) {
        title = loc("clan/season_award/place/place" + reward.place)
        medal = "place" + reward.place
      }
      if (reward.rType == CLAN_SEASON_MEDAL_TYPE.TOP) {
        title = loc("clan/season_award/place/top", { top = reward.place })
        medal = "top" + reward.place
      }
      if (reward.rType == CLAN_SEASON_MEDAL_TYPE.RATING) {
        title = loc("clan/season_award/rating", { ratingValue = reward.rating })
        medal = reward.rating + "rating"
      }
      let medalIconMarkup = LayersIcon.getIconData(format("clan_medal_%s_%s", medal, diff.egdLowercaseName),
        null, null, null, { season_title = { text = seasonName } })

      local condition = ""
      if (reward.placeMin)
        condition = loc("multiplayer/place") + loc("ui/colon") + reward.placeMin + loc("ui/mdash") + reward.placeMax
      else if (reward.place)
        condition = loc("multiplayer/place") + loc("ui/colon") + reward.place
      else if (reward.rating)
        condition = loc("userLog/clanDuelRewardClanRating") + " " + reward.rating

      local gold = ""
      if (reward.gold) {
        let value = reward.goldMin ?
          (Cost(0, reward.goldMin).tostring() + loc("ui/mdash") + Cost(0, reward.goldMax).tostring()) :
          Cost(0, reward.gold).tostring()
        gold = loc("charServer/chapter/eagles") + loc("ui/colon") + value
      }

      let prizesList = {}
      let prizes = ::g_clan_seasons.getRegaliaPrizes(reward.regalia)
      let limits = ::g_clan_seasons.getUniquePrizesCounts(reward.regalia)
      foreach (prize in prizes) {
        let prizeType = prize.type
        let collection = []

        if (prizeType == "clanTag") {
          let myClanTagUndecorated = ::g_clans.stripClanTagDecorators(clan_get_my_clan_tag())
          let tagTxt = u.isEmpty(myClanTagUndecorated) ? loc("clan/clan_tag/short") : myClanTagUndecorated
          let tooltipBase = loc("clan/clan_tag_decoration") + loc("ui/colon")
          let tagDecorators = ::g_clan_tag_decorator.getDecoratorsForClanDuelRewards(prize.list)
          foreach (decorator in tagDecorators)
            collection.append({
              start = decorator.start
              tag   = tagTxt
              end   = decorator.end
              tooltip = tooltipBase + colorize("activeTextColor", decorator.start + tagTxt + decorator.end)
            })
        }
        else if (prizeType == "decal") {
          let decorType = decoratorTypes.DECALS
          foreach (decalId in prize.list) {
            let decal = getDecorator(decalId, decorType)
            collection.append({
              id = decalId
              image = decorType.getImage(decal)
              ratio = clamp(decorType.getRatio(decal), 1, 2)
              tooltipId = DECORATION.getTooltipId(decalId, decorType.unlockedItemType)
            })
          }
        }

        let uniqueCount = getTblValue(prizeType, limits, 0) || collection.len()
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

  function onShowBonuses(obj) {
    let bonusesObj = checkObj(obj) ? obj.getParent().findObject("bonuses_panel") : null
    if (!checkObj(bonusesObj))
      return
    let isShow = bonusesObj["toggled"] != "yes"
    bonusesObj["toggled"] = isShow ? "yes" : "no"
    bonusesObj.show(isShow)

    obj.setValue(isShow ? loc("mainmenu/btnCollapse") : (loc("clan/season_award/desc/lower_places_awards_included") + loc("ui/ellipsis")))
    obj["tooltip"] = isShow ? "" : loc("mainmenu/btnExpand")
  }

  function selectListItem() {
    if (this.rewardsListObj.childrenCount() <= 0)
      return

    if (this.selectedIndex >= this.rewardsListObj.childrenCount())
      this.selectedIndex = this.rewardsListObj.childrenCount() - 1

    this.rewardsListObj.setValue(this.selectedIndex)
    move_mouse_on_child(this.rewardsListObj, this.selectedIndex)
  }

  function onItemSelect(obj) {
    let listChildrenCount = this.rewardsListObj.childrenCount()
    let index = obj.getValue()
    this.selectedIndex = (index >= 0 && index < listChildrenCount) ? index : 0
  }

  function showBonusesByActivateItem(obj) {
    let btnObj = getSelectedChild(obj)?.findObject("show_bonuses_btn")
    if (btnObj?.isValid())
      this.onShowBonuses(btnObj)
  }

  function onBtnMoreInfo(_obj) {
  }
}

let openClanSeasonInfoWnd = @(difficulty) loadHandler(
  gui_handlers.clanSeasonInfoModal, { difficulty })

return {
  openClanSeasonInfoWnd
}
