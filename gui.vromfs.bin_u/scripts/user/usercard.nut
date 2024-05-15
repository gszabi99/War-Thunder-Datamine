//-file:plus-string
from "%scripts/dagui_natives.nut" import get_nicks_find_result_blk, myself_can_devoice, myself_can_ban, req_player_public_statinfo, find_nicks_by_prefix, set_char_cb, get_player_public_stats, req_player_public_statinfo_by_player_id
from "%scripts/dagui_library.nut" import *
from "%scripts/leaderboard/leaderboardConsts.nut" import LEADERBOARD_VALUE_TOTAL, LEADERBOARD_VALUE_INHISTORY

let { g_clan_type } = require("%scripts/clans/clanType.nut")
let { g_difficulty } = require("%scripts/difficulty.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let { format } = require("string")
let DataBlock = require("DataBlock")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { isXBoxPlayerName, canInteractCrossConsole, isPlatformSony, isPlatformXboxOne,
  isPlayerFromPS4
} = require("%scripts/clientState/platform.nut")
let { hasAllFeatures } = require("%scripts/user/features.nut")
let externalIDsService = require("%scripts/user/externalIdsService.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let psnSocial = require("sony.social")
let { RESET_ID, openPopupFilter } = require("%scripts/popups/popupFilter.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { getMedalRibbonImg, hasMedalRibbonImg } = require("%scripts/unlocks/unlockInfo.nut")
let { fillProfileSummary, getCountryMedals, getPlayerStatsFromBlk,
  airStatsListConfig } = require("%scripts/user/userInfoStats.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { APP_ID } = require("app")
let { getUnlockNameText, getUnlockableMedalImage
} = require("%scripts/unlocks/unlocksViewModule.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { ceil, floor } = require("math")
let lbDataType = require("%scripts/leaderboard/leaderboardDataType.nut")
let { utf8ToLower } = require("%sqstd/string.nut")
let { addContact, removeContact } = require("%scripts/contacts/contactsState.nut")
let { encode_uri_component } = require("url")
let { get_local_mplayer } = require("mission")
let { show_profile_card } = require("%xboxLib/impl/user.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { getEsUnitType, getUnitName } = require("%scripts/unit/unitInfo.nut")
let { userIdStr } = require("%scripts/user/profileStates.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { setTimeout, clearTimer } = require("dagor.workcycle")
let { openNickEditBox, getCustomNick } = require("%scripts/contacts/customNicknames.nut")
let { getCurCircuitOverride, isPixelStorm } = require("%appGlobals/curCircuitOverride.nut")
let { setDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")

::gui_modal_userCard <- function gui_modal_userCard(playerInfo) {  // uid, id (in session), name
  if (!hasFeature("UserCards"))
    return
  loadHandler(gui_handlers.UserCardHandler, { info = playerInfo })
}

gui_handlers.UserCardHandler <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/profile/userCard.blk"

  isOwnStats = false

  info = null
  sheetsList = ["Profile", "Statistics"]

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

  nameStats = ""
  isMyPage = false

  function initScreen() {
    if (!this.scene || !this.info || !(("uid" in this.info) || ("id" in this.info) || ("name" in this.info)))
      return this.goBack()

    this.player = {}
    foreach (pName in ["name", "uid", "id"])
      if (pName in this.info && this.info[pName] != "")
        this.player[pName] <- this.info[pName]
    if (!("name" in this.player))
      this.player.name <- ""

    let customNick = getCustomNick(this.player)
    this.scene.findObject("profile-name").setValue(customNick == null
      ? this.player.name
      : $"{this.player.name}{loc("ui/parentheses/space", { text = customNick })}")
    this.scene.findObject("profile-container").show(false)

    this.initStatsParams()
    this.initTabs()

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
    this.initLeaderboardModes()
    this.updateButtons()
  }

  function initTabs() {
    let view = { tabs = [] }
    foreach (idx, sheet in this.sheetsList) {
      view.tabs.append({
        id = sheet
        tabImage = format(this.tabImageNameTemplate, sheet.tolower())
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
    this.curMode = ::get_current_wnd_difficulty()
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
    this.scene.findObject("profile-container").show(true)
    this.scene.findObject("profile_sheet_list").show(true)
    this.onSheetChange(null)
    this.fillLeaderboard()
  }

  function showSheetDiv(name) {
    foreach (div in ["profile", "stats"]) {
      let show = div == name
      let divObj = this.scene.findObject(div + "-container")
      if (checkObj(divObj)) {
        divObj.show(show)
        if (show)
          this.updateDifficultySwitch(divObj)
      }
    }
  }

  function onSheetChange(_obj) {
    if (!this.infoReady)
      return

    if (this.getCurSheet() == "Statistics") {
      this.showSheetDiv("stats")
      this.fillStatistics()
    }
    else {
      this.showSheetDiv("profile")
      this.fillProfile()
    }
    this.updateButtons()
  }

  function fillProfile() {
    if (!checkObj(this.scene))
      return

    this.fillTitleName(this.player.title, false)

    this.fillClanInfo(this.player)
    this.fillModeListBox(this.scene.findObject("profile-container"), this.curMode)
    ::fill_gamer_card(this.player, "profile-", this.scene)
    this.fillAwardsBlock(this.player)
    this.fillShortCountryStats(this.player)
    this.scene.findObject("profile_loading").show(false)
  }

  function onEventContactsUpdated(_p) {
    if (this.isMyPage)
      return
    ::fill_gamer_card(this.player, "profile-", this.scene)
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
    ::set_current_wnd_difficulty(this.curMode)
    this.updateCurrentStatsMode(this.curMode)
    fillProfileSummary(this.scene.findObject("stats_table"), this.player.summary, this.curMode)
  }

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

    let nameObj = this.scene.findObject("profile-currentUser-" + link)
    if (!checkObj(nameObj))
      return

    nameObj.setValue(name == "" ? "" : $"{link == "title" ? "" : loc("profile/" + link)}{name}")
  }

  function fillClanInfo(playerData) {
    if (!hasFeature("Clans"))
      return

    let clanTagObj = this.scene.findObject("profile-clanTag");
    if (clanTagObj) {
      let clanType = g_clan_type.getTypeByCode(playerData.clanType)
      let text = ::checkClanTagForDirtyWords(playerData.clanTag);
      clanTagObj.setValue(colorize(clanType.color, text));
      clanTagObj.tooltip = ::ps4CheckAndReplaceContentDisabledText(playerData.clanName);
    }
  }

  function fillShortCountryStats(profile) {
    let countryStatsNest = this.scene.findObject("country_stats_nest")
    if (!checkObj(countryStatsNest))
      return

    let columns = shopCountriesList.map(@(c) {
      icon            = getCountryIcon(c)
      unitsCount      = profile.countryStats[c].unitsCount
      eliteUnitsCount = profile.countryStats[c].eliteUnitsCount
    })

    let blk = handyman.renderCached(("%gui/profile/country_stats_table.tpl"), {
      columns = columns,
      tableName = loc("lobby/vehicles")
    })
    this.guiScene.replaceContentFromText(countryStatsNest, blk, blk.len(), this)
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
    ::set_current_wnd_difficulty(this.curMode)
    this.updateCurrentStatsMode(value)
    this.fillAirStats()
  }

  function fillAwardsBlock(pl) {
    if (hasFeature("ProfileMedals"))
      this.fillMedalsBlock(pl)
    else
      this.fillTitlesBlock(pl)
  }

  function fillMedalsBlock(pl) {
    local curCountryId = profileCountrySq.value
    local maxMedals = 0
    if (!this.isOwnStats) {
      maxMedals = pl.countryStats[curCountryId].medalsCount
      foreach (_idx, countryId in shopCountriesList) {
        let medalsCount = pl.countryStats[countryId].medalsCount
        if (maxMedals < medalsCount) {
          curCountryId = countryId
          maxMedals = medalsCount
        }
      }
    }

    // Filling country tabs
    local curValue = 0
    let view = { items = [] }
    let countFmt = "text { pos:t='pw/2-w/2, ph+@blockInterval'; position:t='absolute'; text:t='%d' }"
    foreach (idx, countryId in shopCountriesList) {
      view.items.append({
        id = countryId
        image = getCountryIcon(countryId)
        tooltip = "#" + countryId
        objects = format(countFmt, pl.countryStats[countryId].medalsCount)
      })

      if (countryId == curCountryId)
        curValue = idx
    }

    let data = handyman.renderCached("%gui/commonParts/shopFilter.tpl", view)
    let countriesObj = this.scene.findObject("medals_country_tabs")
    this.guiScene.replaceContentFromText(countriesObj, data, data.len(), this)
    countriesObj.setValue(curValue)
  }

  function onMedalsCountrySelect(obj) {
    let nestObj = this.scene.findObject("medals_nest")
    if (!checkObj(obj) || !checkObj(nestObj))
      return

    let countryId = shopCountriesList?[obj.getValue()]
    if (!countryId)
      return

    let medalsList = getCountryMedals(countryId, this.player)
    showObjById("medals_empty", !medalsList.len(), this.scene)

    let view = {
      ribbons = this.getRibbonsView(medalsList.filter(@(id) hasMedalRibbonImg(id)))
      medals = this.getMedalsView(medalsList.filter(@(id) !hasMedalRibbonImg(id)))
    }

    let markup = handyman.renderCached("%gui/profile/profileRibbons.tpl", view)
    this.guiScene.replaceContentFromText(nestObj, markup, markup.len(), this)
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

  function fillTitlesBlock(pl) {
    showObjById("medals_block", false, this.scene)
    showObjById("titles_block", true, this.scene)

    let titles = []
    foreach (id in pl.titles) {
      let titleUnlock = getUnlockById(id)
      if (!titleUnlock || titleUnlock?.hidden)
        continue

      let locText = loc($"title/{id}")
      titles.append({
        name = id
        text = locText
        lowerText = utf8ToLower(locText)
        tooltipId = getTooltipType("UNLOCK").getTooltipId(id, { showLocalState = this.isOwnStats, needTitle = false })
      })
    }
    titles.sort(@(a, b) a.lowerText <=> b.lowerText)

    let titlesTotal = titles.len()
    showObjById("titles_empty", !titlesTotal, this.scene)
    if (!titlesTotal)
      return

    local markup = ""
    let cols = 2
    let rows = ceil(titlesTotal * 1.0 / cols)
    for (local r = 0; r < rows; r++) {
      let rowData = []
      for (local c = 0; c < cols; c++)
        rowData.append(titles?[rows * c + r] ?? {})
      markup += ::buildTableRow("", rowData)
    }

    this.guiScene.replaceContentFromText(this.scene.findObject("titles_table"), markup, markup.len(), this)
  }

  function getPlayerStats() {
    return this.player
  }

  function onStatsTypeChange(obj) {
    if (!obj)
      return
    this.statsType = obj.getValue() ? ETTI_VALUE_INHISORY : ETTI_VALUE_TOTAL
    saveLocalByAccount("leaderboards_type", this.statsType)
    this.fillLeaderboard()
  }

  function onLbModeSelect(obj) {
    if (!checkObj(obj) || this.lbModesList == null)
      return

    let newLbMode = this.lbModesList?[obj.getValue()]
    if (newLbMode == null || this.lbMode == newLbMode)
      return

    this.lbMode = newLbMode
    this.guiScene.performDelayed(this, function() {
      if (this.isValid())
        this.fillLeaderboard()
    })
  }

  function fillStatistics() {
    if (!checkObj(this.scene))
      return

    this.showSheetDiv("stats")
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
    this.initAirStatsScene(this.player.userstat)
  }

  function initAirStatsScene(_airStats) {
    let sObj = this.scene.findObject("stats-container")

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
      filterTypes = this.getFiltersView()
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
    for (local i = 1; i <= ::max_country_rank; i++) {
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
      let unitTypeShopId = ::get_army_id_by_es_unit_type(getEsUnitType(air))
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

    local data = ""
    let posWidth = "0.05@scrn_tgt"
    let rcWidth = "0.04@scrn_tgt"
    let nameWidth = "0.2@scrn_tgt"
    let headerRow = [
      { width = posWidth }
      { id = "rank", width = rcWidth, text = "#sm_rank", tdalign = "split", cellType = "splitRight", callback = "onStatsCategory", active = this.statsSortBy == "rank" }
      { id = "rank", width = rcWidth, cellType = "splitLeft", callback = "onStatsCategory" }
      { id = "locName", width = rcWidth, cellType = "splitRight", callback = "onStatsCategory" }
      { id = "locName", width = nameWidth, text = "#options/unit", tdalign = "left", cellType = "splitLeft", callback = "onStatsCategory", active = this.statsSortBy == "locName" }
    ]
    foreach (item in airStatsListConfig) {
      if ("reqFeature" in item && !hasAllFeatures(item.reqFeature))
        continue

      if (this.isOwnStats || !("ownProfileOnly" in item) || !item.ownProfileOnly)
        headerRow.append({
          id = item.id
          image = "#ui/gameuiskin#" + (("icon" in item) ? item.icon : "lb_" + item.id) + ".svg"
          tooltip = ("text" in item) ? "#" + item.text : "#multiplayer/" + item.id
          callback = "onStatsCategory"
          active = this.statsSortBy == item.id
          needText = false
        })
    }
    data += ::buildTableRow("row_header", headerRow, null, "isLeaderBoardHeader:t='yes'")

    let tooltips = {}
    let fromIdx = this.curStatsPage * this.statsPerPage
    local toIdx = (this.curStatsPage + 1) * this.statsPerPage - 1
    if (toIdx >= this.airStatsList.len())
      toIdx = this.airStatsList.len() - 1

    for (local idx = fromIdx; idx <= toIdx; idx++) {
      let airData = this.airStatsList[idx]
      let unitTooltipId = getTooltipType("UNIT").getTooltipId(airData.name)

      let rowName = "row_" + idx
      let rowData = [
        { text = (idx + 1).tostring(), width = posWidth }
        { id = "rank", width = rcWidth, text = airData.rank.tostring(), tdalign = "right", cellType = "splitRight", active = this.statsSortBy == "rank" }
        { id = "country", width = rcWidth, image = getCountryIcon(airData.country), cellType = "splitLeft", needText = false }
        {
          id = "unit",
          width = rcWidth,
          image = ::getUnitClassIco(airData.name),
          tooltipId = unitTooltipId,
          cellType = "splitRight",
          needText = false
        }
        { id = "name", text = getUnitName(airData.name, true), tdalign = "left", active = this.statsSortBy == "name", cellType = "splitLeft", tooltipId = unitTooltipId }
      ]
      foreach (item in airStatsListConfig) {
        if ("reqFeature" in item && !hasAllFeatures(item.reqFeature))
          continue

        if (this.isOwnStats || !("ownProfileOnly" in item) || !item.ownProfileOnly) {
          let cell = ::getLbItemCell(item.id, airData[item.id], item.type)
          cell.active <- this.statsSortBy == item.id
          if ("tooltip" in cell) {
            if (!(rowName in tooltips))
              tooltips[rowName] <- {}
            tooltips[rowName][item.id] <- cell.$rawdelete("tooltip")
          }
          rowData.append(cell)
        }
      }
      data += ::buildTableRow(rowName, rowData, idx % 2 == 0)
    }

    let tblObj = this.scene.findObject("airs_stats_table")
    this.guiScene.replaceContentFromText(tblObj, data, data.len(), this)
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

  function checkLbRowVisibility(row) {
    return ::leaderboardModel.checkLbRowVisibility(row, this)
  }

  function fillLeaderboard() {
    let stats = this.getPlayerStats()
    if (!stats || !("leaderboard" in stats) || !stats.leaderboard.len())
      return

    let typeProfileObj = this.scene.findObject("stats_type_profile")
    if (checkObj(typeProfileObj)) {
      typeProfileObj.show(true)
      typeProfileObj.setValue(this.statsType == ETTI_VALUE_INHISORY)
    }

    let tblObj = this.scene.findObject("profile_leaderboard")
    local rowIdx = 0
    local data = ""
    let tooltips = {}

    //add header row
    let headerRow = [""]
    foreach (lbCategory in ::leaderboards_list)
      if (this.checkLbRowVisibility(lbCategory))
        headerRow.append({
          id = lbCategory.id
          image = lbCategory.headerImage
          tooltip = lbCategory.headerTooltip
          active = true
          needText = false
        })

    data = ::buildTableRow("row_header", headerRow, null, "isLeaderBoardHeader:t='yes'")

    let rows = [
      {
        text = "#mainmenu/btnLeaderboards"
        showLbPlaces = false
      }
      {
        text = "#multiplayer/place"
        showLbPlaces = true
      }
    ]

    let valueFieldName = (this.statsType == ETTI_VALUE_TOTAL)
                           ? LEADERBOARD_VALUE_TOTAL
                           : LEADERBOARD_VALUE_INHISTORY
    let lb = getTblValue(valueFieldName, getTblValue(this.lbMode, stats.leaderboard), {})
    let standartRow = {}

    foreach (idx, fieldTbl in lb) {
      standartRow[idx] <- getTblValue(valueFieldName, fieldTbl, -1)
    }

    foreach (row in rows) {
      let rowName = "row_" + rowIdx
      let rowData = [{ text = row.text, tdalign = "left" }]
      local res = {}

      foreach (lbCategory in ::leaderboards_list)
        if (this.checkLbRowVisibility(lbCategory)) {
          if (lbCategory.field in lb) {
            if (!row.showLbPlaces)
              res = lbCategory.getItemCell(standartRow[lbCategory.field], standartRow)
            else {
              let value = (lb[lbCategory.field].idx < 0) ? -1 : lb[lbCategory.field].idx + 1
              res = lbCategory.getItemCell(value, null, false, lbDataType.PLACE)
            }
          }
          else {
            if (!row.showLbPlaces)
              res = lbCategory.getItemCell(lbCategory.lbDataType == lbDataType.PERCENT ? -1 : 0)
            else
              res = lbCategory.getItemCell(-1, null, false, lbDataType.PLACE)
          }

          if ("tooltip" in res) {
            if (!(rowName in tooltips))
              tooltips[rowName] <- {}
            tooltips[rowName][lbCategory.id] <- res.$rawdelete("tooltip")
          }

          rowData.append(res)
        }

      rowIdx++
      data += ::buildTableRow(rowName, rowData, rowIdx % 2 == 0, "")
    }
    this.guiScene.replaceContentFromText(tblObj, data, data.len(), this)

    foreach (rowName, row in tooltips)
      foreach (name, value in row)
        tblObj.findObject(rowName).findObject(name).tooltip = value
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

  function initLeaderboardModes() {
    this.lbMode      = ""
    this.lbModesList = []

    local data  = ""

    foreach (_idx, mode in ::leaderboard_modes) {
      let diffCode = getTblValue("diffCode", mode)
      if (!g_difficulty.isDiffCodeAvailable(diffCode, GM_DOMINATION))
        continue
      let reqFeature = getTblValue("reqFeature", mode)
      if (!hasAllFeatures(reqFeature))
        continue

      this.lbModesList.append(mode.mode)
      data += format("option {text:t='%s'}", mode.text)
    }

    let modesObj = showObjById("leaderboard_modes_list", true, this.scene)
    this.guiScene.replaceContentFromText(modesObj, data, data.len(), this)
    modesObj.setValue(0)
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
    let showProfBar = this.infoReady && !showStatBar
    let isVisibleAchievementsUrlBtn = showProfBar && hasFeature("AchievementsUrl") && hasFeature("AllowExternalLink")

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
    })

    if (isPixelStorm() && isVisibleAchievementsUrlBtn)
      setDoubleTextToButton(this.scene, "btn_achievements_url", loc("mainmenu/comparePixelAchievements"))
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
}