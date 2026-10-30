import "%sqStdLibs/helpers/u.nut" as u
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%scripts/viewUtils/layeredIcon.nut" import LayersIcon
from "%scripts/sqDagui/daguiUtil.nut" import getSelectedChild, move_mouse_on_child
from "%scripts/baseGuiHandlerManagerWT.nut" import loadHandler
from "%scripts/money.nut" import Cost
from "%sqStdLibs/helpers/handyman.nut" import handyman
from "%scripts/utils/genericTooltipTypes.nut" import getTooltipType
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/customization/decoratorGetters.nut" import getDecorator
from "%scripts/customization/decoratorViewType.nut" import getViewTypeByUnlockedItemType
from "%scripts/clans/clanTextInfo.nut" import stripClanTagDecorators
from "%scripts/clans/clanSeasons.nut" import isClanSeasonsEnabled, getClanCurrentSeasonName, getClanSeasonRegaliaPrizes, getClanSeasonUniquePrizesCounts, getClanSeasonRewardsList
from "%scripts/user/clanName.nut" import getMyClanTag
from "string" import format
from "%scripts/dagui_library.nut" import *
from "%scripts/clans/clanConsts.nut" import CLAN_SEASON_MEDAL_TYPE

let { decoratorTypes } = require("%scripts/customization/decoratorBaseType.nut")
let { clanTagDecoratorFuncs } = require("%scripts/clans/clanTagDecorator.nut")

let clanSeasonInfoModal = class (BaseGuiHandlerWT) {
  wndType      = handlerType.MODAL
  sceneBlkName = "%gui/clans/clanSeasonInfoModal.blk"

  difficulty = null

  rewardsListObj = null
  selectedIndex  = 0

  function initScreen() {
    if (!isClanSeasonsEnabled())
      return this.goBack()
    this.rewardsListObj = this.scene.findObject("rewards_list")
    if (!checkObj(this.rewardsListObj))
      return this.goBack()

    this.scene.findObject("wnd_title").setValue("".concat(loc("clan/battle_season/title"), " - ", loc("mainmenu/rewardsList")))

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
    let rewards = getClanSeasonRewardsList(diff)
    if (u.isEmpty(rewards))
      return view

    let seasonName = getClanCurrentSeasonName()
    foreach (reward in rewards) {
      local title = ""
      local medal = ""
      if (reward.rType == CLAN_SEASON_MEDAL_TYPE.PLACE) {
        title = loc($"clan/season_award/place/place{reward.place}")
        medal =$"place{reward.place}"
      }
      if (reward.rType == CLAN_SEASON_MEDAL_TYPE.TOP) {
        title = loc("clan/season_award/place/top", { top = reward.place })
        medal =$"top{reward.place}"
      }
      if (reward.rType == CLAN_SEASON_MEDAL_TYPE.RATING) {
        title = loc("clan/season_award/rating", { ratingValue = reward.rating })
        medal =$"{reward.rating}rating"
      }
      let medalIconMarkup = LayersIcon.getIconData(format("clan_medal_%s_%s", medal, diff.egdLowercaseName),
        null, null, null, { season_title = { text = seasonName } })

      local condition = ""
      if (reward.placeMin)
        condition = "".concat(loc("multiplayer/place"), loc("ui/colon"), reward.placeMin,
          loc("ui/mdash"), reward.placeMax)
      else if (reward.place)
        condition = "".concat(loc("multiplayer/place"), loc("ui/colon"), reward.place)
      else if (reward.rating)
        condition =  " ".concat(loc("userLog/clanDuelRewardClanRating"), reward.rating)

      local gold = ""
      if (reward.gold) {
        let value = reward.goldMin
          ? "".concat(Cost(0, reward.goldMin).tostring(), loc("ui/mdash"), Cost(0, reward.goldMax).tostring())
          : Cost(0, reward.gold).tostring()
        gold = "".concat(loc("charServer/chapter/eagles"), loc("ui/colon"), value)
      }

      let prizesList = {}
      let prizes = getClanSeasonRegaliaPrizes(reward.regalia)
      let limits = getClanSeasonUniquePrizesCounts(reward.regalia)
      foreach (prize in prizes) {
        let prizeType = prize.type
        let collection = []

        if (prizeType == "clanTag") {
          let myClanTagUndecorated = stripClanTagDecorators(getMyClanTag())
          let tagTxt = u.isEmpty(myClanTagUndecorated) ? loc("clan/clan_tag/short") : myClanTagUndecorated
          let tooltipBase = $"{loc("clan/clan_tag_decoration")}{loc("ui/colon")}"
          let tagDecorators = clanTagDecoratorFuncs.getDecoratorsForClanDuelRewards(prize.list)
          foreach (decorator in tagDecorators)
            collection.append({
              start = decorator.start
              tag   = tagTxt
              end   = decorator.end
              tooltip = "".concat(tooltipBase, colorize("activeTextColor", $"{decorator.start}{tagTxt}{decorator.end}"))
            })
        }
        else if (prizeType == "decal") {
          let decorType = decoratorTypes.DECALS
          let viewDecoratorType = getViewTypeByUnlockedItemType(decorType.unlockedItemType)

          foreach (decalId in prize.list) {
            let decal = getDecorator(decalId, decorType)
            collection.append({
              id = decalId
              image = viewDecoratorType.getImage(decal)
              ratio = clamp(viewDecoratorType.getRatio(decal), 1, 2)
              tooltipId = getTooltipType("DECORATION").getTooltipId(decalId, decorType.unlockedItemType)
            })
          }
        }

        let uniqueCount = (limits?[prizeType] ?? 0) || collection.len()
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

    obj.setValue(isShow ? loc("mainmenu/btnCollapse")
      : "".concat(loc("clan/season_award/desc/lower_places_awards_included"), loc("ui/ellipsis")))
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
register_gui_handler("clanSeasonInfoModal", clanSeasonInfoModal)

let openClanSeasonInfoWnd = @(difficulty) loadHandler(
  clanSeasonInfoModal, { difficulty })

return freeze({
  openClanSeasonInfoWnd
})
