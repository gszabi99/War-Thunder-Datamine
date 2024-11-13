from "%scripts/dagui_natives.nut" import get_unlock_type, get_nicks_find_result_blk, myself_can_devoice, myself_can_ban, req_player_public_statinfo, find_nicks_by_prefix, set_char_cb, get_player_public_stats, req_player_public_statinfo_by_player_id
from "%scripts/dagui_library.nut" import *
from "%scripts/leaderboard/leaderboardConsts.nut" import LEADERBOARD_VALUE_TOTAL, LEADERBOARD_VALUE_INHISTORY
from "%scripts/mainConsts.nut" import SEEN

let { g_difficulty } = require("%scripts/difficulty.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let { format } = require("string")
let DataBlock = require("DataBlock")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { getUnlockById, getAllUnlocksWithBlkOrder, getUnlocksByTypeInBlkOrder } = require("%scripts/unlocks/unlocksCache.nut")
let { isXBoxPlayerName, canInteractCrossConsole, isPlatformSony, isPlatformXboxOne,
  isPlayerFromPS4
} = require("%scripts/clientState/platform.nut")
let { hasAllFeatures } = require("%scripts/user/features.nut")
let externalIDsService = require("%scripts/user/externalIdsService.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let psnSocial = require("sony.social")
let { RESET_ID, openPopupFilter } = require("%scripts/popups/popupFilterWidget.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { getMedalRibbonImg } = require("%scripts/unlocks/unlockInfo.nut")
let { fillProfileSummary, getPlayerStatsFromBlk,
  airStatsListConfig } = require("%scripts/user/userInfoStats.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { APP_ID } = require("app")
let { getUnlockNameText, getUnlockableMedalImage, buildUnlockDesc, getUnlockMainCondDescByCfg,
      getUnlockMultDescByCfg, getUnlockCondsDescByCfg
} = require("%scripts/unlocks/unlocksViewModule.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { floor } = require("math")
let { utf8ToLower } = require("%sqstd/string.nut")
let { addContact, removeContact } = require("%scripts/contacts/contactsState.nut")
let { encode_uri_component } = require("url")
let { get_local_mplayer } = require("mission")
let { show_profile_card } = require("%xboxLib/impl/user.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { getEsUnitType, getUnitName } = require("%scripts/unit/unitInfo.nut")
let { userIdStr } = require("%scripts/user/profileStates.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { setTimeout, clearTimer, defer } = require("dagor.workcycle")
let { openNickEditBox, getCustomNick } = require("%scripts/contacts/customNicknames.nut")
let { getCurCircuitOverride } = require("%appGlobals/curCircuitOverride.nut")
let { setDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { MAX_COUNTRY_RANK } = require("%scripts/ranks.nut")
let { isUnlockVisible, getUnlockRewardText } = require("%scripts/unlocks/unlocksModule.nut")
let { isBattleTask } = require("%scripts/unlocks/battleTasks.nut")
let { setBreadcrumbGoBackParams } = require("%scripts/breadcrumb.nut")
let { isInBattleState } = require("%scripts/clientState/clientStates.nut")
let { getLbItemCell } = require("%scripts/leaderboard/leaderboardHelpers.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { requestUserInfoData, getUserInfo, userInfoEventName } = require("%scripts/user/usersInfoManager.nut")
let { getShowcaseTitleViewData, getShowcaseViewData, trySetBestShowcaseMode } = require("%scripts/user/profileShowcase.nut")
let { add_event_listener, removeEventListenersByEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { fill_gamer_card, addGamercardScene } = require("%scripts/gamercard.nut")
let { getCurrentShopDifficulty } = require("%scripts/gameModes/gameModeManagerState.nut")

::gui_modal_userCard <- function gui_modal_userCard(playerInfo) {  // uid, id (in session), name
  if (!hasFeature("UserCards"))
    return
  let guiScene = get_gui_scene()
  if (guiScene?.isInAct()) {
    defer(@() loadHandler(gui_handlers.UserCardHandler, { info = playerInfo }))
    return
  }
  loadHandler(gui_handlers.UserCardHandler, { info = playerInfo })
}

function getUnlockFiltersList(uType, getCategoryFunc) {
  let categories = []
  let unlocks = getUnlocksByTypeInBlkOrder(uType)
  foreach (unlock in unlocks)
    if (isUnlockVisible(unlock))
      u.appendOnce(getCategoryFunc(unlock), categories, true)

  return categories
}

function getCurrentWndDifficulty() {
  let diffCode = loadLocalByAccount("wnd/diffMode", getCurrentShopDifficulty().diffCode)
  local diff = g_difficulty.getDifficultyByDiffCode(diffCode)
  if (!diff.isAvailable())
    diff = g_difficulty.ARCADE
  return diff.diffCode
}

function setCurrentWndDifficulty(mode = 0) {
  saveLocalByAccount("wnd/diffMode", mode)
}

gui_handlers.UserCardHandler <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/profile/userCard.blk"

  isOwnStats = false

  info = null
  sheetsList = ["UserCard", "Records", "Statistics", "Medal"]

  tabImageNameTemplate = "#ui/gameuiskin#sh_%s.svg"
  tabLocalePrefix = "#mainmenu/btn"

  statsPerPage = 0
  showLbPlaces = 0

  airStatsInited = false
  profileInited = false

  airStatsList = null
  statsType = ETTI_VALUE_INHISORY
  statsMode = ""
  countryStats = null
  unitStats = null
  rankStats = null
  allRanksStats = null
  availableUTypes = null
  availableCountries = null
  availableRanks = null
  statsSortBy = ""
  statsSortReverse = false
  curStatsPage = 0
  filterCountryName = null
  player = null
  searchPlayerByNick = false
  infoReady = false

  curMode = DIFFICULTY_ARCADE
  lbMode  = ""
  lbModesList = null

  curPlayerExternalIds = null
  isFilterVisible = false

  ribbonsRowLength = 3
  filterTypes = {}
  applyFilterTimer = null
  medalsByCountry = null
  isProfileInited = false

  nameStats = ""
  isMyPage = false
  isPageFilling = false
  medalsFilters = []
  curFilter = null
  selMedalIdx = null
  terseInfo = null

  function initScreen() {
    if (isInBattleState.get())
      this.scene.findObject("back_scene_name").setValue(loc("mainmenu/btnBack"))
    else
      setBreadcrumbGoBackParams(this)

    this.selMedalIdx = {}
    if (!this.scene || !this.info || !(("uid" in this.info) || ("id" in this.info) || ("name" in this.info)))
      return this.goBack()

    addGamercardScene(this.scene) //for show popups
    let needShortSeparators = to_pixels("sw") > to_pixels("1@maxProfileFrameWidth + 2@framePadding")
    let frame = this.scene.findObject("wnd_frame")
    frame.needShortSeparators = needShortSeparators ? "yes" : "no"

    this.player = {}
    foreach (pName in ["name", "uid", "id"])
      if (pName in this.info && this.info[pName] != "")
        this.player[pName] <- this.info[pName]
    if (!("name" in this.player))
      this.player.name <- ""

    let customNick = getCustomNick(this.player)
    let profileName = customNick == null
      ? getPlayerName(this.player.name)
      : $"{getPlayerName(this.player.name)}{loc("ui/parentheses/space", { text = customNick })}"
    this.scene.findObject("profile-name").setValue(profileName)
    this.scene.findObject("usercard-container").show(false)
    let breadCrumbTitle = this.scene.findObject("breadcrumb_title")
    breadCrumbTitle.setValue(" ".concat(loc("mainmenu/btnProfile"), profileName))

    this.scene.findObject("profile_header").show(false)
    this.initTabs()
    this.initStatsParams()

    this.taskId = -1
    if ("uid" in this.player) {
      this.taskId = req_player_public_statinfo(this.player.uid)
      if (userIdStr.value == this.player.uid)
        this.isMyPage = true
      else
        externalIDsService.reqPlayerExternalIDsByUserId(this.player.uid)
    }
    else if ("id" in this.player) {
      this.taskId = req_player_public_statinfo_by_player_id(this.player.id)
      let selfPlayerId = getTblValue("uid", get_local_mplayer())
      if (selfPlayerId != null && selfPlayerId == this.player.id)
        this.isMyPage = true
      else
        externalIDsService.reqPlayerExternalIDsByPlayerId(this.player.id)
    }
    else {
      this.searchPlayerByNick = true
      this.taskId = find_nicks_by_prefix(this.player.name, 1, false)
    }

    if (this.isMyPage)
      this.updateExternalIdsData(externalIDsService.getSelfExternalIds(), this.isMyPage)

    if (this.taskId < 0)
      return this.notFoundPlayerMsg()

    set_char_cb(this, this.slotOpCb)
    this.afterSlotOp = this.tryFillUserStats
    this.afterSlotOpError = function(_result) { /* notFoundPlayerMsg() */ this.goBack() }

    this.fillGamercard()
    this.updateButtons()

    let medalCountries = getUnlockFiltersList("medal", @(unlock) unlock?.country)
    this.medalsFilters = shopCountriesList.filter(@(c) medalCountries.contains(c))
  }

  function initTabs() {
    let view = { tabs = [] }
    foreach (idx, sheet in this.sheetsList) {
      view.tabs.append({
        id = sheet
        tabName = this.tabLocalePrefix + sheet
        navImagesText = ::get_navigation_images_text(idx, this.sheetsList.len())
      })
    }

    let data = handyman.renderCached("%gui/frameHeaderTabs.tpl", view)
    let sheetsListObj = this.scene.findObject("profile_sheet_list")
    this.guiScene.replaceContentFromText(sheetsListObj, data, data.len(), this)
    sheetsListObj.setValue(0)
    sheetsListObj.show(false)
  }

  function initStatsParams() {
    this.curMode = getCurrentWndDifficulty()
    this.statsType = loadLocalByAccount("leaderboards_type", ETTI_VALUE_INHISORY)
  }

  function goBack() {
    base.goBack()
  }

  function notFoundPlayerMsg() {
    this.msgBox("incorrect_user", loc("chat/error/item-not-found", { nick = ("name" in this.player) ? this.player.name : "" }),
        [
          ["ok", function() { this.goBack() } ]
        ], "ok")
  }

  function onSearchResult() {
    this.searchPlayerByNick = false

    local searchRes = DataBlock()
    searchRes = get_nicks_find_result_blk()
    foreach (uid, nick in searchRes)
      if (nick == this.player.name) {
        this.player.uid <- uid
        this.taskId = req_player_public_statinfo(this.player.uid)
        if (this.taskId < 0)
          return this.notFoundPlayerMsg()
        set_char_cb(this, this.slotOpCb)
        return
      }
    return this.notFoundPlayerMsg()
  }

  function tryFillUserStats() {
    if (this.searchPlayerByNick)
      return this.onSearchResult()

    if (!checkObj(this.scene))
      return;

    let blk = DataBlock()
    get_player_public_stats(blk)

    if (!blk?.nick || blk.nick == "") { //!!FIX ME: Check incorrect user by no uid in answer.
      this.msgBox("user_not_played", loc("msg/player_not_played_our_game"),
        [
          ["ok", function() { this.goBack() } ]
        ], "ok")
      return
    }

    this.player = getPlayerStatsFromBlk(blk)
    if ("uid" in this.player)
      externalIDsService.reqPlayerExternalIDsByUserId(this.player.uid)

    this.infoReady = true
    this.scene.findObject("usercard-container").show(true)
    this.scene.findObject("profile_sheet_list").show(true)
    this.scene.findObject("profile_header").show(true)
    this.onSheetChange(null)
    this.updateShowcase()
  }

  function showSheetDiv(name) {
    foreach (div in ["usercard", "records", "stats", "medals"]) {
      let show = div == name
      let divObj = this.scene.findObject($"{div}-container")
      if (checkObj(divObj)) {
        divObj.show(show)
        if (show)
          this.updateDifficultySwitch(divObj)
      }
    }
  }

  function isPageHasProfileHandler(sheet) {
    return (sheet == "UserCard") || (sheet == "Records")
  }

  function onSheetChange(_obj) {
    if (!this.infoReady)
      return

    let curSheet = this.getCurSheet()
    let pageHasProfileHeader = this.isPageHasProfileHandler(curSheet)
    showObjById("profile_header", pageHasProfileHeader, this.scene)

    let accountImage = this.scene.findObject("profile_header_picture")
    accountImage.height = pageHasProfileHeader ? "@maxAccountHeaderHeight" : "@minAccountHeaderHeight"

    if (pageHasProfileHeader && !this.isProfileInited)
      this.fillProfile()

    if (curSheet == "UserCard")
      this.showSheetDiv("usercard")
    else if (curSheet == "Records") {
      this.showSheetDiv("stats")
      this.fillModeListBox(this.scene.findObject("stats-container"), this.curMode)
    } else if (curSheet == "Statistics") {
      this.showSheetDiv("records")
      this.fillStatistics()
    } else if (curSheet == "Medal")
      this.showMedalsSheet()

    this.updateButtons()
  }

  function fillProfile() {
    if (!checkObj(this.scene))
      return

    this.fillTitleName(this.player.title, false)
    this.fillClanInfo(this.player)
    this.fillModeListBox(this.scene.findObject("profile-container"), this.curMode)
    fill_gamer_card(this.player, "profile-", this.scene)
    this.scene.findObject("profile_loading").show(false)
    this.isProfileInited = true
  }

  function onEventContactsUpdated(_p) {
    if (this.isMyPage)
      return
    fill_gamer_card(this.player, "profile-", this.scene)
  }

  function fillTitleName(name, setEmpty = true) {
    if (name == "") {
      if (!setEmpty)
        return

      name = "empty_title"
    }
    this.fillAdditionalName(getUnlockNameText(UNLOCKABLE_TITLE, name), "title")
    this.scene.findObject("profile-currentUser-title")["inactive"] = this.isOwnStats ? "no" : "yes"
  }

  function onProfileStatsModeChange(obj) {
    if (!checkObj(this.scene))
      return
    let value = obj.getValue()

    this.curMode = value
    this.setCurrentWndDifficulty(this.curMode)
    this.updateCurrentStatsMode(this.curMode)
    fillProfileSummary(this.scene.findObject("stats_table"), this.player.summary, this.curMode)
  }

  setCurrentWndDifficulty = @(value) setCurrentWndDifficulty(value)

  function onEventContactsGroupUpdate(_p) {
    this.updateButtons()
  }

  function onEventUpdateExternalsIDs(params) {
    if (!(params?.externalIds))
      return

    if (this.player?.uid != params?.request?.uid && this.player?.id != params?.request?.playerId)
      return

    let isMe = userIdStr.value == this.player?.uid
    this.updateExternalIdsData(params.externalIds, isMe)
  }

  function updateExternalIdsData(externalIdsData, isMe) {
    this.curPlayerExternalIds = externalIdsData

    this.fillAdditionalName(this.curPlayerExternalIds?.steamName ?? "", "steamName")

    showObjById("btn_xbox_profile", isPlatformXboxOne && !isMe && (this.curPlayerExternalIds?.xboxId ?? "") != "", this.scene)
    showObjById("btn_psn_profile", isPlatformSony && !isMe && psnSocial?.open_player_profile != null && (this.curPlayerExternalIds?.psnId ?? "") != "", this.scene)
  }

  function fillAdditionalName(name, link) {
    if (!checkObj(this.scene))
      return

    let nameObj = this.scene.findObject($"profile-currentUser-{link}")
    if (!checkObj(nameObj))
      return

    nameObj.setValue(name == "" ? "" : $"{link == "title" ? "" : loc($"profile/{link}")}{name}")
  }

  function fillClanInfo(playerData) {
    if (!hasFeature("Clans"))
      return

    let clanTagObj = this.scene.findObject("profile-clanTag")
    if (clanTagObj) {
      let text = ::checkClanTagForDirtyWords(playerData.clanTag)
      clanTagObj.setValue(text)
      clanTagObj.tooltip = ::ps4CheckAndReplaceContentDisabledText(playerData.clanName)
    }
  }


  function updateCurrentStatsMode(value) {
    this.statsMode = g_difficulty.getDifficultyByDiffCode(value).egdLowercaseName
  }

  function updateDifficultySwitch(parentObj) {
    if (!checkObj(parentObj))
      return

    let switchObj = parentObj.findObject("modes_list")
    if (!checkObj(switchObj))
      return

    let childrenCount = switchObj.childrenCount()
    if (childrenCount <= 0)
      return

    switchObj.setValue(clamp(this.curMode, 0, childrenCount - 1))
  }

  function onStatsModeChange(obj) {
    if (!checkObj(obj))
      return

    let value = obj.getValue()
    if (this.curMode == value)
      return

    this.curMode = value
    this.setCurrentWndDifficulty(this.curMode)
    this.updateCurrentStatsMode(value)
    this.fillAirStats()
  }

  function getRibbonsView(medalsList) {
    return medalsList.len() > 0 ? {
      flowAlign = medalsList.len() > this.ribbonsRowLength ? "center" : "left"
      items = medalsList.map((@(id) {
        tag = "imgUsercardRibbon"
        image = getMedalRibbonImg(id)
      }.__merge(this.getBaseConfigMedal(id))).bindenv(this))
    } : null
  }

  function getMedalsView(medalsList) {
    return medalsList.len() > 0 ? {
      items = medalsList.map((@(id) {
        tag = "imgUsercardMedal"
        image = getUnlockableMedalImage(id)
      }.__merge(this.getBaseConfigMedal(id))).bindenv(this))
    } : null
  }

  function getBaseConfigMedal(id) {
    return {
      id = id
      unlocked = true
      tooltipId = getTooltipType("UNLOCK").getTooltipId(id, { showLocalState = this.isOwnStats, needTitle = false })
    }
  }


  function getPlayerStats() {
    return this.player
  }

  function onStatsTypeChange(obj) {
    if (!obj)
      return
    this.statsType = obj.getValue() ? ETTI_VALUE_INHISORY : ETTI_VALUE_TOTAL
    saveLocalByAccount("leaderboards_type", this.statsType)
  }


  function fillStatistics() {
    if (!checkObj(this.scene))
      return
    this.fillAirStats()
  }

  function fillAirStats() {
    if (!checkObj(this.scene))
      return

    if (!this.airStatsInited)
      return this.initAirStats()

    this.fillAirStatsScene(this.player.userstat)
  }

  function initAirStats() {
    this.countryStats = []
    foreach (country in shopCountriesList)
      this.countryStats.append(country)
    this.initAirStatsPage()
  }

  function initAirStatsPage() {
    let sObj = this.scene.findObject("records-container")
    sObj.findObject("stats_loading").show(false)

    let modesObj = sObj.findObject("modes_list")
    local selDiff = null
    local selIdx = -1
    let view = { items = [] }
    foreach (diff in g_difficulty.types) {
      if (!diff.isAvailable())
        continue
      view.items.append({ text = diff.getLocName() })
      if (!selDiff || this.statsMode == diff.egdLowercaseName) {
        selDiff = diff
        selIdx = view.items.len() - 1
      }
    }
    this.statsMode = selDiff.egdLowercaseName

    let data = handyman.renderCached("%gui/commonParts/shopFilter.tpl", view)
    this.guiScene.replaceContentFromText(modesObj, data, data.len(), this)
    modesObj.setValue(selIdx)

    this.fillUnitListCheckBoxes()
    this.fillCountriesCheckBoxes()
    this.fillRanksCheckBoxes()
    this.nameStats = ""

    let nestObj = this.scene.findObject("filter_nest")
    openPopupFilter({
      scene = nestObj
      onChangeFn = this.onFilterCbChange.bindenv(this)
      filterTypesFn = this.getFiltersView.bindenv(this)
      popupAlign = "bottom-right"
    })

    this.airStatsInited = true
    this.fillAirStats()
  }

  function fillUnitListCheckBoxes() {
    this.availableUTypes = {}
    if (!this.isOwnStats)
      this.unitStats = []

    foreach (unitType in unitTypes.types) {
      if (!unitType.isAvailable())
        continue

      let typeIdx = unitType.esUnitType
      this.availableUTypes[unitType.armyId] <- {
        id    = $"unit_{typeIdx}"
        idx   = typeIdx
        image = unitType.testFlightIcon
        text  = unitType.getArmyLocName()
      }
    }
    this.filterTypes["unit"] <- { referenceArr = this.availableUTypes selectedArr = this.unitStats }
  }

  function fillCountriesCheckBoxes() {
    this.availableCountries = {}
    foreach (idx, inst in shopCountriesList)
      this.availableCountries[inst] <- {
        id    = inst
        idx   = idx
        image = getCountryIcon(inst)
        text  = loc(inst)
      }

    if (!this.countryStats && !this.isOwnStats)
      this.countryStats = []

    this.filterTypes["country"] <- { referenceArr = this.availableCountries selectedArr = this.countryStats }
  }

  function fillRanksCheckBoxes() {
    this.availableRanks = {}
    if (!this.isOwnStats)
      this.rankStats = []
    this.allRanksStats = []
    for (local i = 1; i <= MAX_COUNTRY_RANK; i++) {
      this.availableRanks[i] <- {
        id    = $"rank_{i}"
        idx   = i
        text  = $"{loc("shop/age")} {get_roman_numeral(i)}"
      }
      this.allRanksStats.append(i)
    }

    this.filterTypes["rank"] <- { referenceArr = this.availableRanks selectedArr = this.rankStats }
  }

  function getFiltersView() {
    let res = []
    foreach (tName in ["country", "unit", "rank"]) {
      let selectedArr = this.filterTypes[tName].selectedArr
      let referenceArr = this.filterTypes[tName].referenceArr
      let view = { checkbox = [] }
      foreach (idx, inst in referenceArr)
        view.checkbox.append({
          id = inst.id
          idx = inst.idx
          image = inst?.image
          text = inst.text
          value = isInArray(idx, selectedArr)
        })

      view.checkbox.sort(@(a, b) a.idx <=> b.idx)
      res.append(view)
    }

    return res
  }

  function onFilterCbChange(objId, tName, value) {
    let selectedArr = this.filterTypes[tName].selectedArr
    let referenceArr = this.filterTypes[tName].referenceArr
    let isReset = objId == RESET_ID

    foreach (idx, inst in referenceArr) {
      if (!isReset && inst.id != objId)
        continue

      if (value)
        u.appendOnce(idx, selectedArr)
      else
        this.removeItemFromList(idx, selectedArr)
    }

    this.fillAirStats()
  }

  function fillAirStatsScene(airStats) {
    if (!checkObj(this.scene))
      return

    this.airStatsList = []
    // Show all items if filters list is empty
    let filterUnits = this.unitStats.len() > 0 ? this.unitStats
      : unitTypes.types.map(@(t) t.isAvailable() ? t.armyId : null).filter(@(t) t)
    let filterCountry = this.countryStats.len() > 0 ? this.countryStats : shopCountriesList
    let filterRank = this.rankStats.len() > 0 ? this.rankStats : this.allRanksStats
    let filterName = this.nameStats

    local checkList = []
    let typeName = "total"
    let modeName = this.statsMode
    if ((modeName in airStats) && (typeName in airStats[modeName]))
      checkList = airStats[modeName][typeName]
    foreach (item in checkList) {
      let air = getAircraftByName(item.name)
      let airLocName = air ? getUnitName(air, true) : ""
      let unitTypeShopId = unitTypes.getByEsUnitType(getEsUnitType(air)).armyId
      if (!isInArray(unitTypeShopId, filterUnits))
        continue

      if (!isInArray(air.rank, filterRank))
        continue

      if(filterName != "" && ([airLocName, air.name].findindex(@(v) utf8ToLower(v).indexof(filterName) != null) == null))
        continue

      if (!("country" in item)) {
        item.country <- air ? air.shopCountry : ""
        item.rank <- air ? air.rank : 0
      }
      if (! ("locName" in item))
        item.locName <- airLocName
      if (isInArray(item.country, filterCountry))
        this.airStatsList.append(item)
    }

    if (this.statsSortBy == "")
      this.statsSortBy = "victories"

    let sortBy = this.statsSortBy
    let sortReverse = this.statsSortReverse == (sortBy != "locName")
    this.airStatsList.sort(function(a, b) {
      let res = b[sortBy] <=> a[sortBy]
      if (res != 0)
        return sortReverse ? -res : res
      return a.locName <=> b.locName || a.name <=> b.name
    })

    this.curStatsPage = 0
    this.updateStatPage()
  }

  function initStatsPerPage() {
    if (this.statsPerPage > 0)
      return

    let listObj = this.scene.findObject("airs_stats_table")
    let size = listObj.getSize()
    let rowsHeigt = size[1] - this.guiScene.calcString("@leaderboardHeaderHeight", null)
    this.statsPerPage =   max(1, (rowsHeigt / this.guiScene.calcString("@leaderboardTrHeight",  null)).tointeger())
  }

  function updateStatPage() {
    if (!this.airStatsList)
      return

    this.initStatsPerPage()

    let data = []
    let posWidth = "0.05@scrn_tgt"
    let rcWidth = "0.04@scrn_tgt"
    let nameWidth = "0.2@scrn_tgt"
    let countryWidth = "0.08@scrn_tgt"
    let rankWidth = "70@sf/@pf"
    let headerRow = [
      { width = posWidth, text = "#", tdalign = "center"}
      { id = "country", width = countryWidth, text="#options/country", cellType = "splitLeft",
        tdalign = "center", callback = "onStatsCategory", active = this.statsSortBy == "country" }
      { id = "rank", width = rankWidth, text = "#sm_rank", tdalign = "center", callback = "onStatsCategory", active = this.statsSortBy == "rank" }
      { id = "locName", width = "0.05@scrn_tgt", cellType = "splitRight", callback = "onStatsCategory" }
      { id = "locName", width = nameWidth, text = "#options/unit", tdalign = "center", cellType = "splitLeft", callback = "onStatsCategory", active = this.statsSortBy == "locName" }
    ]
    foreach (item in airStatsListConfig) {
      if ("reqFeature" in item && !hasAllFeatures(item.reqFeature))
        continue
      if (this.isOwnStats || !("ownProfileOnly" in item) || !item.ownProfileOnly)
        headerRow.append({
          id = item.id
          image = "".concat("#ui/gameuiskin#", item?.icon ?? $"lb_{item.id}", ".svg")
          tooltip = loc(item?.text ?? $"multiplayer/{item.id}")
          callback = "onStatsCategory"
          active = this.statsSortBy == item.id
          needText = false
        })
    }
    data.append(::buildTableRow("row_header", headerRow, null, "isLeaderBoardHeader:t='yes'"))

    let tooltips = {}
    let fromIdx = this.curStatsPage * this.statsPerPage
    local toIdx = min(this.airStatsList.len(), (this.curStatsPage + 1) * this.statsPerPage)

    for (local idx = fromIdx; idx < toIdx; idx++) {
      let rowName = $"row_{idx}"
      local rowData = null
      let airData = this.airStatsList[idx]
      let unitTooltipId = getTooltipType("UNIT").getTooltipId(airData.name)

      rowData = [
        { text = (idx + 1).tostring(), width = posWidth, tdalign = "center"}
        { id = "country", width = countryWidth, image = getCountryIcon(airData.country), imageRawParams = "left:t='0.5*(pw-w)'",
          tdalign = "center", cellType = "splitLeft", needText = false }
        { id = "rank", width = rankWidth, text = airData.rank.tostring(), tdalign = "center", cellType = "splitRight", active = this.statsSortBy == "rank" }
        {
          id = "unit",
          width = rcWidth,
          image = ::getUnitClassIco(airData.name),
          tooltipId = unitTooltipId,
          cellType = "splitRight",
          imageRawParams = "left:t='pw-w-2@sf/@pf';",
          needText = false,
          tdalign = "right"
        }
        { id = "name", text = getUnitName(airData.name, true), tdalign = "left", active = this.statsSortBy == "name", cellType = "splitLeft", tooltipId = unitTooltipId }
      ]
      foreach (item in airStatsListConfig) {
        if ("reqFeature" in item && !hasAllFeatures(item.reqFeature))
          continue

        if (this.isOwnStats || !("ownProfileOnly" in item) || !item.ownProfileOnly) {
          let cell = getLbItemCell(item.id, airData[item.id], item.type)
          cell.active <- this.statsSortBy == item.id
          cell.tdalign <- "center"
          if ("tooltip" in cell) {
            if (!(rowName in tooltips))
              tooltips[rowName] <- {}
            tooltips[rowName][item.id] <- cell.$rawdelete("tooltip")
          }
          rowData.append(cell)
        }
      }
      data.append(::buildTableRow(rowName, rowData ?? [], idx % 2 == 0))
    }

    let dataTxt = "".join(data)
    let tblObj = this.scene.findObject("airs_stats_table")
    this.guiScene.replaceContentFromText(tblObj, dataTxt, dataTxt.len(), this)
    foreach (rowName, row in tooltips) {
      let rowObj = tblObj.findObject(rowName)
      if (rowObj)
        foreach (name, value in row)
          rowObj.findObject(name).tooltip = value
    }
    let nestObj = this.scene.findObject("paginator_place")
    ::generatePaginator(nestObj, this, this.curStatsPage, floor((this.airStatsList.len() - 1) / this.statsPerPage))
    this.updateButtons()
  }

  function goToPage(obj) {
    this.curStatsPage = obj.to_page.tointeger()
    this.updateStatPage()
  }

  function onChangePilotIcon(_obj) {}
  function openChooseTitleWnd() {}

  function getCurSheet() {
    let obj = this.scene.findObject("profile_sheet_list")
    let sheetIdx = obj.getValue()
    if ((sheetIdx < 0) || (sheetIdx >= obj.childrenCount()))
      return ""

    return obj.getChild(sheetIdx).id
  }


  function updateButtons() {
    if (!checkObj(this.scene))
      return

    let hasFeatureFriends = hasFeature("Friends")

    let contact = ::getContact(this.player?.uid, this.player.name)
    let isMe = contact?.isMe() ?? false
    let canBan = isMe ? false : (::myself_can_devoice() || myself_can_ban())
    let isFriend = contact?.isInFriendGroup() ?? false
    let isBlock = contact?.isInBlockGroup() ?? false

    let isPS4Player = isPlayerFromPS4(this.player.name)
    let isXBoxOnePlayer = isXBoxPlayerName(this.player.name)
    let canBlock = !isPlatformXboxOne || !isXBoxOnePlayer
    let canInteractCC = canInteractCrossConsole(this.player.name)

    let sheet = this.getCurSheet()
    let showStatBar = this.infoReady && sheet == "Statistics"
    let showProfBar = this.infoReady && sheet == "UserCard"
    let isVisibleAchievementsUrlBtn = !isMe && showProfBar && hasFeature("AchievementsUrl") && hasFeature("AllowExternalLink")

    showObjectsByTable(this.scene, {
      paginator_place = showStatBar && (this.airStatsList != null) && (this.airStatsList.len() > this.statsPerPage)
      btn_friendAdd = showProfBar && hasFeatureFriends && canInteractCC && !isMe && !isFriend && !isBlock
      btn_friendRemove = showProfBar && hasFeatureFriends && isFriend && (contact?.isInFriendlist() ?? false)
      btn_blacklistAdd = showProfBar && hasFeatureFriends && !isMe && !isFriend && !isBlock && canBlock && !isPS4Player
      btn_blacklistRemove = showProfBar && hasFeatureFriends && isBlock && canBlock && !isPS4Player
      btn_moderatorBan = showProfBar && ::is_myself_anyof_moderators() && canBan
      btn_complain = showProfBar && !isMe
      btn_friendChangeNick = hasFeature("CustomNicks") && showProfBar && !isMe
      btn_achievements_url = isVisibleAchievementsUrlBtn
      btn_leaderboard = sheet == "Records" && hasFeature("Leaderboards")
    })

    if (isVisibleAchievementsUrlBtn)
      setDoubleTextToButton(this.scene, "btn_achievements_url",
        loc("mainmenu/compareAchievements", {
          name = getCurCircuitOverride("operatorName", "Gaijin.Net") }))
  }

  function onBlacklistBan() {
    let clanTag = getTblValue("clanTag", this.player, "")
    let playerName = getTblValue("name", this.player, "")
    let userId = getTblValue("uid", this.player, "")

    ::gui_modal_ban({ name = playerName, uid = userId, clanTag = clanTag })
  }

  function onFriendChangeNick() {
    openNickEditBox(this.player)
  }

  function onFriendAdd() {
    addContact(this.player, EPL_FRIENDLIST)
  }

  function onFriendRemove() {
    removeContact(this.player, EPL_FRIENDLIST)
  }

  function onBlacklistAdd() {
    addContact(this.player, EPL_BLOCKLIST)
  }

  function onBlacklistRemove() {
    removeContact(this.player, EPL_BLOCKLIST)
  }

  function onComplain() {
    if (this.infoReady && ("uid" in this.player))
      ::gui_modal_complain(this.player)
  }

  function onOpenXboxProfile() {
    if (this.curPlayerExternalIds?.xboxId)
      show_profile_card(this.curPlayerExternalIds?.xboxId.tointeger(), null)
  }

  function onOpenPSNProfile() {
    let psnId = this.curPlayerExternalIds?.psnId ?? ""
    if (psnId == "")
      return

    psnSocial?.open_player_profile(
      psnId.tointeger(),
      psnSocial.PlayerAction.DISPLAY,
      "",
      {}
    )
  }

  function removeItemFromList(value, list) {
    let idx = list.findindex(@(v) v == value)
    if (idx != null)
      list.remove(idx)
  }

  function onStatsCategory(obj) {
    if (!obj)
      return
    let value = obj.id
    if (this.statsSortBy == value)
      this.statsSortReverse = !this.statsSortReverse
    else {
      this.statsSortBy = value
      this.statsSortReverse = false
    }
    this.guiScene.performDelayed(this, function() { this.fillAirStats() })
  }

  function onOpenAchievementsUrl() {
    openUrl(getCurCircuitOverride("achievementsURL", loc("url/achievements")).subst(
        { appId = APP_ID, name = encode_uri_component(this.player.name) }),
      false, false, "profile_page")
  }

  function onFilterCancel(filterObj) {
    if (filterObj.getValue() != "")
      filterObj.setValue("")
    else
      this.guiScene.performDelayed(this, this.goBack)
  }

  function applyFilter(obj) {
    clearTimer(this.applyFilterTimer)
    this.nameStats = utf8ToLower(obj.getValue())
    if(this.nameStats == "") {
      this.fillAirStats()
      return
    }

    let applyCallback = Callback(@() this.fillAirStats(), this)
    this.applyFilterTimer = setTimeout(0.8, @() applyCallback())
  }

  function showMedalsSheet() {
    this.showSheetDiv("medals")
    if (this.medalsByCountry == null)
      this.fillMedalsByCountry()

    let selCategory = this.filterCountryName ?? profileCountrySq.value
    local selIdx = 0
    let view = { items = [] }

    foreach (idx, filter in this.medalsFilters) {
      if (filter == selCategory)
        selIdx = idx
      let medalsData = this.medalsByCountry?[filter]
      view.items.append({
        text = $"#{filter}",
        objects = format("text {text:t='%s'}", $"{medalsData?.unlocked ?? 0}/{medalsData?.total ?? 1}")
      })
    }

    let data = handyman.renderCached("%gui/commonParts/shopFilter.tpl", view)
    let pageList = this.scene.findObject("medals_list")
    this.guiScene.replaceContentFromText(pageList, data, data.len(), this)

    let isEqualIdx = selIdx == pageList.getValue()
    pageList.setValue(selIdx)
    if (isEqualIdx) // func on_select don't call if same value is se already
      this.onMedalsCountrySelect(pageList)
  }


  function onMedalsCountrySelect(_obj) {
    this.fillMedalsZone()
  }

  function updateUnlockFav(_name, containerObj) {
    showObjById("checkbox_favorites", false, containerObj)
  }

  function unlockToFavorites(_obj = null) {}

  function onMedalSelect(obj) {
    if (!checkObj(obj))
      return

    let idx = obj.getValue()
    let itemObj = idx >= 0 && idx < obj.childrenCount() ? obj.getChild(idx) : null
    let name = checkObj(itemObj) && itemObj?.id
    let unlock = name && getUnlockById(name)
    if (!unlock)
      return

    let containerObj = this.scene.findObject("medals_info")
    let descObj = checkObj(containerObj) && containerObj.findObject("medals_desc")
    if (!checkObj(descObj))
      return

    if (!this.isPageFilling)
      this.selMedalIdx[this.curFilter] <- idx

    let config = buildUnlockDesc(::build_conditions_config(unlock))
    let rewardText = getUnlockRewardText(name)
    let progressData = this.isOwnStats ? config.getProgressBarData() : null

    let view = {
      title = loc($"{name}/name")
      image = getUnlockableMedalImage(name, true)
      unlockProgress = progressData?.value ?? 0
      hasProgress = progressData?.show ?? false
      mainCond = getUnlockMainCondDescByCfg(config, { showSingleStreakCondText = true })
      multDesc = getUnlockMultDescByCfg(config)
      conds = getUnlockCondsDescByCfg(config)
      rewardText = rewardText != "" ? rewardText : null
    }

    let markup = handyman.renderCached("%gui/profile/profileMedal.tpl", view)
    this.guiScene.setUpdatesEnabled(false, false)
    this.guiScene.replaceContentFromText(descObj, markup, markup.len(), this)
    this.updateUnlockFav(name, containerObj)
    this.guiScene.setUpdatesEnabled(true, true)
  }

  function fillMedalsZone() {
    let pageIdx = this.scene.findObject("medals_list").getValue()
    if (pageIdx < 0 || pageIdx >= this.medalsFilters.len())
      return

    this.isPageFilling = true
    this.guiScene.setUpdatesEnabled(false, false)

    local view = { items = [] }
    let country = this.medalsFilters[pageIdx]
    this.curFilter = country
    view.items = this.medalsByCountry?[country].items ?? []
    local data = handyman.renderCached("%gui/commonParts/imgFrame.tpl", view)

    let medalsObj = this.scene.findObject("medals_zone")
    this.guiScene.replaceContentFromText(medalsObj, data, data.len(), this)
    this.guiScene.setUpdatesEnabled(true, true)

    local curIndex = this.selMedalIdx?[country] ?? 0
    let total = medalsObj.childrenCount()
    curIndex = total ? clamp(curIndex, 0, total - 1) : -1
    medalsObj.setValue(curIndex)

    this.onMedalSelect(medalsObj)
    this.isPageFilling = false
  }

  function fillMedalsByCountry() {
    this.medalsByCountry = {}
    let unlocks = getAllUnlocksWithBlkOrder()
    foreach (cb in unlocks) {
      let name = cb.getStr("id", "")
      let unlockType = cb?.type ?? ""
      let unlockTypeId = get_unlock_type(unlockType)
      if (unlockTypeId != UNLOCKABLE_MEDAL || !isUnlockVisible(cb) || isBattleTask(cb))
        continue

      let medalCountry = cb.getStr("country", "")
      if (medalCountry == "")
        return

      if (this.medalsByCountry?[medalCountry] == null)
        this.medalsByCountry[medalCountry] <- {unlocked = 0, total = 0, items = [] }

      let item = {
        id = name
        tag = "imgSelectable"
        unlocked = this.isMedalUnlocked(name)
        image = getUnlockableMedalImage(name)
        imgClass = "profileMedals"
        focusBorder = true
      }
      this.medalsByCountry[medalCountry].total += 1
      if (item.unlocked)
        this.medalsByCountry[medalCountry].unlocked += 1

      this.medalsByCountry[medalCountry].items.append(item)
    }
  }

  function isMedalUnlocked(name) {
    return this.player?.unlocks.medal[name] != null
  }

  function onLeaderboard() {
    let userId = (this.player?.uid ?? "-1").tointeger()
    if (userId >= 0)
      loadHandler(gui_handlers.LeaderboardWindow, { userId })
  }

  function fillShowcaseMid(terseInfo, userStats) {
    let data = getShowcaseViewData(userStats, terseInfo)
    let midNest = this.scene.findObject("showcase_mid_nest")
    this.guiScene.replaceContentFromText(midNest, data, data.len(), this)
  }

  function fillShowcaseTitle(terseInfo) {
    let nest = this.scene.findObject("showcase_title_nest")
    let data = getShowcaseTitleViewData(terseInfo)
    this.guiScene.replaceContentFromText(nest, data, data.len(), this)
  }

  function fillShowcase(terseInfo, userStats) {
    this.fillShowcaseTitle(terseInfo)
    this.fillShowcaseMid(terseInfo, userStats)
  }

  function onUserInfoRequestComplete(responce, stats = null) {
    if (this.terseInfo != null) {
      removeEventListenersByEnv(userInfoEventName.UPDATED, this)
      return
    }
    stats = stats ?? this.getPageProfileStats()
    let infos = responce?.usersInfo[stats.uid]
    if (infos == null)
      return

    this.terseInfo = {}
    this.terseInfo.schType <- infos.shcType
    this.terseInfo.showcase <- infos?.showcase
      ? clone infos.showcase
      : {}
    trySetBestShowcaseMode(stats, this.terseInfo)
    this.updateShowcase()
    removeEventListenersByEnv(userInfoEventName.UPDATED, this)
  }

  function updateShowcase() {
    let userStats = this.getPageProfileStats()
    if (userStats == null)
      return

    if (this.terseInfo == null) {
      let userInfo = getUserInfo(userStats.uid)
      if (userInfo != null) {
        let data = {}
        data[userStats.uid] <- userInfo
        this.onUserInfoRequestComplete({usersInfo = data}, userStats)
      }
    }

    if (this.terseInfo) {
      this.fillShowcase(this.terseInfo, userStats)
      return
    }
    add_event_listener(userInfoEventName.UPDATED, this.onUserInfoRequestComplete, this)
    requestUserInfoData(userStats.uid)
  }

  function getPageProfileStats() {
    return this.player
  }

}