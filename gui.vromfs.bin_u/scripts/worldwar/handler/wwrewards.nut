//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { getObjValidIndex } = require("%sqDagui/daguiUtil.nut")
let userstat = require("userstat")
let time = require("%scripts/time.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { get_charserver_time_sec } = require("chard")
let { openTrophyRewardsList } = require("%scripts/items/trophyRewardList.nut")

const USERSTAT_REQUEST_TIMEOUT = 600

local lastRequestTime = null
local rewardsTimeData = null
let fetchRewardsTimeData = function(cb) {
  let now = get_charserver_time_sec()
  if (lastRequestTime && now < lastRequestTime + USERSTAT_REQUEST_TIMEOUT)
    return cb()

  lastRequestTime = now
  userstat.request({
      add_token = true
      headers = { appid = "1134" }
      action = "GetTablesInfo"
    },
    function(userstatTbl) {
      rewardsTimeData = {}
      foreach (key, val in userstatTbl.response.tables) {
        let rewardTimeStr = val?.interval?.index == 0 && val?.prevInterval?.index != 0 ?
          val?.prevInterval?.end : val?.interval?.end
        rewardsTimeData[key] <- rewardTimeStr ? time.getTimestampFromIso8601(rewardTimeStr) : 0
      }
      cb()
    })
}

gui_handlers.WwRewards <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType      = handlerType.MODAL
  sceneBlkName = "%gui/clans/clanSeasonInfoModal.blk"

  isClanRewards = false
  rewardsBlk = null
  day       = ""
  lbMode    = null
  lbDay     = null
  lbMap     = null
  lbCountry = null

  rewardsListObj = null
  rewards = null

  function initScreen() {
    this.rewardsListObj = this.scene.findObject("rewards_list")
    if (!checkObj(this.rewardsListObj))
      return this.goBack()

    let wndTitle = loc("ui/comma").join([
      (this.lbMode ? loc("worldwar/leaderboard/" + this.lbMode) : ""),
      (this.lbDay ? loc("enumerated_day", { number = this.lbDay }) : !this.isClanRewards ? loc("worldwar/allSeason") : ""),
      (this.lbMap ? this.lbMap.getNameText() : loc("worldwar/allMaps")),
      (this.lbCountry ? loc(this.lbCountry) : loc("worldwar/allCountries")),
    ], true) + " " + loc("ui/mdash") + " " + loc("worldwar/btn_rewards")
    this.scene.findObject("wnd_title").setValue(wndTitle)

    this.showSceneBtn("nav-help", true)

    this.rewards = []
    foreach (rewardBlk in this.rewardsBlk) {
      let reward = this.getRewardData(rewardBlk)
      if (!reward)
        continue

      let blockCount = rewardBlk.blockCount()
      if (blockCount) {
        reward.internalRewards <- []
        for (local i = 0; i < rewardBlk.blockCount(); i++) {
          let internalReward = this.getRewardData(rewardBlk.getBlock(i), false)
          if (internalReward)
            reward.internalRewards.append(internalReward)
        }
      }

      this.rewards.append(reward)
    }

    this.updateRewardsList()
    fetchRewardsTimeData(Callback(@() this.updateRerwardsStartTime(), this))
  }

  function getRewardData(rewardBlk, needPlace = true) {
    let reward = {}
    for (local i = 0; i < rewardBlk.paramCount(); i++)
      reward[rewardBlk.getParamName(i)] <- rewardBlk.getParamValue(i)

    return (!needPlace || (reward?.tillPlace ?? 0)) ? reward : null
  }

  function getItemsMarkup(items) {
    local view = { items = [] }
    foreach (item in items)
      view.items.append(item.getViewData({
        ticketBuyWindow = false
        hasButton = false
        contentIcon = false
        hasTimer = false
        addItemName = false
        interactive = true
      }))

    return handyman.renderCached("%gui/items/item.tpl", view)
  }

  function getPlaceText(tillPlace, prevPlace, isClan = false) {
    if (!tillPlace)
      tillPlace = ::g_clan_type.NORMAL.maxMembers
    return loc(isClan ? "multiplayer/clan_place" : "multiplayer/place") + loc("ui/colon")
      + ((tillPlace - prevPlace == 1) ? tillPlace : (prevPlace + 1) + loc("ui/mdash") + tillPlace)
  }

  function getRewardTitle(tillPlace, prevPlace) {
    if (!tillPlace)
      return loc("multiplayer/place/to_other")

    if (tillPlace - prevPlace == 1)
      return tillPlace <= 3
        ? loc("clan/season_award/place/place" + tillPlace)
        : loc("clan/season_award/place/placeN", { placeNum = tillPlace })

    return loc("clan/season_award/place/top", { top = tillPlace })
  }

  function getRewardsView() {
    local prevPlace = 0
    return {
      rewardsList = this.rewards.map(function(reward) {
        let rewardRowView = {
          title = this.getRewardTitle(reward.tillPlace, prevPlace)
          condition = this.getPlaceText(reward.tillPlace, prevPlace, this.isClanRewards)
        }
        prevPlace = reward.tillPlace

        let trophyId = reward?.itemdefid
        if (trophyId) {
          let trophyItem = ::ItemsManager.findItemById(trophyId)
          if (trophyItem) {
              rewardRowView.trophyMarkup <- this.getItemsMarkup([trophyItem])
              rewardRowView.trophyName <- trophyItem.getName()
          }
        }

        let internalRewards = reward?.internalRewards
        if (internalRewards) {
          rewardRowView.internalRewardsList <- []

          let internalRewardsList = []
          local internalPrevPlace = 0
          foreach (internalReward in internalRewards) {
            let internalTrophyId = internalReward?.itemdefid
            if (internalTrophyId) {
              let internalTrophyItem = ::ItemsManager.findItemById(internalTrophyId)
              if (internalTrophyItem)
                internalRewardsList.append({
                  internalTrophyMarkup = this.getItemsMarkup([internalTrophyItem])
                  internalCondition = this.getPlaceText(internalReward?.tillPlace, internalPrevPlace)
                })
            }
            internalPrevPlace = internalReward?.tillPlace ?? 0
          }
          if (internalRewardsList.len()) {
            rewardRowView.internalRewardsList <- internalRewardsList
            rewardRowView.hasInternalRewards <- true
          }
        }

        return rewardRowView
      }.bindenv(this))
    }
  }

  function updateRerwardsStartTime() {
    local text = ""
    let rewardsTime = rewardsTimeData?[this.day] ?? 0
    if (rewardsTime > 0)
      text = loc("worldwar/rewards_start_time") + loc("ui/colon") +
        time.buildDateTimeStr(rewardsTime, false, false)
    this.scene.findObject("statusbar_text").setValue(text)
  }

  function onBtnMoreInfo(_obj) {
    let rewardsArray = []
    let addItem = @(item) u.appendOnce(item?.itemdefid, rewardsArray, true)
    this.rewards.each(@(reward) reward?.internalRewards.each(addItem) ?? addItem(reward))
    openTrophyRewardsList({
      rewardsArray = rewardsArray.map(@(reward) { item = reward })
    })
  }

  function onItemSelect(_obj) {}

  function updateRewardsList() {
    local val = getObjValidIndex(this.rewardsListObj)
    let markup = handyman.renderCached("%gui/worldWar/wwRewardItem.tpl", this.getRewardsView())
    this.guiScene.replaceContentFromText(this.rewardsListObj, markup, markup.len(), this)

    if (val < 0 || val >= this.rewardsListObj.childrenCount())
      val = 0

    this.rewardsListObj.setValue(val)
  }

  function onEventItemsShopUpdate(_obj) {
    this.updateRewardsList()
  }

  function showBonusesByActivateItem(_obj) {}
}

return {
  open = function(params) {
    if (!params?.rewardsBlk)
      return

    handlersManager.loadHandler(gui_handlers.WwRewards, params)
  }
}
