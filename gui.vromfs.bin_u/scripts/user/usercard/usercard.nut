from "%scripts/dagui_natives.nut" import clan_get_my_clan_name, get_nicks_find_result_blk, myself_can_devoice, myself_can_ban, req_player_public_statinfo, find_nicks_by_prefix, set_char_cb, get_player_public_stats, req_player_public_statinfo_by_player_id
from "%scripts/dagui_library.nut" import *
from "%scripts/leaderboard/leaderboardConsts.nut" import LEADERBOARD_VALUE_TOTAL, LEADERBOARD_VALUE_INHISTORY
from "%scripts/mainConsts.nut" import SEEN
from "%scripts/utils_sa.nut" import is_myself_anyof_moderators, buildTableRow

let { g_difficulty } = require("%scripts/difficulty.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let DataBlock = require("DataBlock")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { isXBoxPlayerName, canInteractCrossConsole, isPlatformSony, isPlatformXbox,
  isPlayerFromPS4 } = require("%scripts/clientState/platform.nut")
let externalIDsService = require("%scripts/user/externalIdsService.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let psnSocial = require("sony.social")
let { fillProfileSummary, getExternalPlayerStatsFromBlk } = require("%scripts/user/userInfoStats.nut")
let { APP_ID } = require("app")
let { getUnlockNameText } = require("%scripts/unlocks/unlocksViewModule.nut")
let { addContact, removeContact } = require("%scripts/contacts/contactsState.nut")
let { encode_uri_component } = require("url")
let { get_local_mplayer } = require("mission")
let { show_profile_card } = require("%gdkLib/impl/user.nut")
let { userIdStr } = require("%scripts/user/profileStates.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { setTimeout } = require("dagor.workcycle")
let { openNickEditBox, getCustomNick } = require("%scripts/contacts/customNicknames.nut")
let { getCurCircuitOverride } = require("%appGlobals/curCircuitOverride.nut")
let { setDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { setBreadcrumbGoBackParams } = require("%scripts/breadcrumb.nut")
let { isInBattleState } = require("%scripts/clientState/clientStates.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { forceRequestUserInfoData, getUserInfo } = require("%scripts/user/usersInfoManager.nut")
let { getShowcaseTitleViewData, getShowcaseViewData, trySetBestShowcaseMode } = require("%scripts/user/profileShowcase.nut")
let { fillGamercard } = require("%scripts/gamercard/fillGamercard.nut")
let { addGamercardScene } = require("%scripts/gamercard/gamercardHelpers.nut")
let { getCurrentShopDifficulty } = require("%scripts/gameModes/gameModeManagerState.nut")
let { checkCanComplainAndProceed } = require("%scripts/user/complaints.nut")
let { checkClanTagForDirtyWords, amendUGCText, checkUGCAllowed } = require("%scripts/clans/clanTextInfo.nut")
let { getContact } = require("%scripts/contacts/contacts.nut")
let { gui_modal_ban, gui_modal_complain } = require("%scripts/penitentiary/banhammer.nut")
let getNavigationImagesText = require("%scripts/utils/getNavigationImagesText.nut")
let g_font = require("%scripts/options/fonts.nut")
let { openMedalsPage } = require("%scripts/user/medals/medalsHandler.nut")
let { getAvatarIconIdByUserInfo } = require("%scripts/user/avatars.nut")
let { openServiceRecordsPage } = require("%scripts/user/serviceRecords/serviceRecordsHandler.nut")
let { getMyClanTag, getMyClanName } = require("%scripts/user/clanName.nut")

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
  sceneTplName = "%gui/profile/userCard.tpl"
  isOwnStats = false

  info = null
  sheetsList = ["UserCard", "Records", "Statistics", "Medal"]

  tabImageNameTemplate = "#ui/gameuiskin#sh_%s.svg"
  tabLocalePrefix = "#mainmenu/btn"

  showLbPlaces = 0

  profileInited = false

  statsType = ETTI_VALUE_INHISORY
  statsMode = ""

  player = null
  searchPlayerByNick = false
  infoReady = false

  curMode = DIFFICULTY_ARCADE
  lbMode  = ""
  lbModesList = null

  curPlayerExternalIds = null
  isProfileInited = false

  isMyPage = false
  terseInfo = null
  showcaseScale = 1
  isSmallSize = false
  currentHeaderBackgroundId = null
  currentAvatarFrameId = null
  currentAvatarId = null
  medalsPageHandlerWeak = null
  serviceRecordsPageHandlerWeak = null
  filterCountryName = ""
  ugcAllowed = false

  function getSceneTplView() {
    let maxHeight  = to_pixels("sh - 1@maxAccountHeaderHeight - 1@frameFooterHeight - 1@bh - 10@sf/@pf").tofloat()
    let defShowcaseHeight = to_pixels("1@favoriteUnitShowcaseHeight")
    local headerAndPadHeight = to_pixels("1@profileHeaderH + 30@sf/@pf")

    if (maxHeight < defShowcaseHeight + headerAndPadHeight) {
      this.isSmallSize = g_font.getCurrent() == g_font.LARGE
      if (this.isSmallSize)
        headerAndPadHeight = to_pixels("1@smallProfileHeaderH + 15@sf/@pf")

      if (!this.isSmallSize || (maxHeight < defShowcaseHeight + headerAndPadHeight))
        this.showcaseScale = maxHeight / (defShowcaseHeight + headerAndPadHeight)
    }
    return this.getScaleParams()
  }

  function getScaleParams() {
    return {scale = this.showcaseScale, isSmallSize = this.isSmallSize}
  }

  function initScreen() {
    let callback = Callback(function(isUgcAllowed) {
      this.ugcAllowed = isUgcAllowed
      this.actualInitScreen()
    }, this)
    checkUGCAllowed(callback)
  }

  function actualInitScreen() {
    if (isInBattleState.get())
      this.scene.findObject("back_scene_name").setValue(loc("mainmenu/btnBack"))
    else
      setBreadcrumbGoBackParams(this)

    if (!this.scene || !this.info || !(("uid" in this.info) || ("id" in this.info) || ("name" in this.info)))
      return this.goBack()

    addGamercardScene(this.scene) 
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
    this.updateCurrentStatsMode(this.curMode)

    this.taskId = -1
    if ("uid" in this.player) {
      this.taskId = req_player_public_statinfo(this.player.uid)
      if (userIdStr.get() == this.player.uid)
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
    this.afterSlotOpError = function(_result) {  this.goBack() }

    this.fillGamercard()
    this.updateButtons()
  }

  function initTabs() {
    let view = { tabs = [] }
    foreach (idx, sheet in this.sheetsList) {
      view.tabs.append({
        id = sheet
        tabName = this.tabLocalePrefix + sheet
        navImagesText = getNavigationImagesText(idx, this.sheetsList.len())
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

    if (!blk?.nick || blk.nick == "") { 
      this.msgBox("user_not_played", loc("msg/player_not_played_our_game"),
        [
          ["ok", function() { this.goBack() } ]
        ], "ok")
      return
    }

    this.player = getExternalPlayerStatsFromBlk(blk)
    if ("uid" in this.player) {
      externalIDsService.reqPlayerExternalIDsByUserId(this.player.uid)
      forceRequestUserInfoData(this.player.uid)
    }

    this.infoReady = true
    this.scene.findObject("usercard-container").show(true)
    this.scene.findObject("profile_sheet_list").show(true)
    this.scene.findObject("profile_header").show(true)
    this.onSheetChange(null)
    this.updateShowcase()
  }

  function showSheetDiv(name) {
    local divObj = null
    local showed_div = null
    foreach (div in ["usercard", "records", "stats", "medals"]) {
      let show = div == name
      divObj = this.scene.findObject($"{div}-container")
      if (checkObj(divObj)) {
        divObj.show(show)
        if (show) {
          this.updateDifficultySwitch(divObj)
          showed_div = divObj
        }
      }
    }
    return showed_div
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
    }
    else if (curSheet == "Statistics")
      this.showServiceRecordsSheet()
    else if (curSheet == "Medal")
      this.showMedalsSheet()

    this.updateButtons()
  }

  function fillProfile() {
    if (!checkObj(this.scene))
      return

    this.fillTitleName(this.player.title, false)
    this.fillClanInfo(this.player)
    this.fillModeListBox(this.scene.findObject("profile-container"), this.curMode)
    fillGamercard(this.player, "profile-", this.scene)
    this.scene.findObject("profile_loading").show(false)
    this.isProfileInited = true
  }

  function onEventContactsUpdated(_p) {
    if (this.isMyPage)
      return
    fillGamercard(this.player, "profile-", this.scene)
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

    if (this.player?.uid != params?.request.uid && this.player?.id != params?.request.playerId)
      return

    let isMe = userIdStr.get() == this.player?.uid
    this.updateExternalIdsData(params.externalIds, isMe)
  }

  function updateExternalIdsData(externalIdsData, isMe) {
    this.curPlayerExternalIds = externalIdsData

    this.fillAdditionalName(this.curPlayerExternalIds?.steamName ?? "", "steamName")

    showObjById("btn_xbox_profile", isPlatformXbox && !isMe && (this.curPlayerExternalIds?.xboxId ?? "") != "", this.scene)
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

    let clanTagObj = this.scene.findObject("clanTag")
    if (clanTagObj) {
      let text = this.isMyPage ? getMyClanTag() : checkClanTagForDirtyWords(playerData.clanTag)
      clanTagObj.setValue(text)
      clanTagObj.tooltip = amendUGCText(this.isMyPage ? getMyClanName() : playerData.clanName, !this.ugcAllowed)
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

  function getPlayerStats() {
    return this.player
  }

  function onStatsTypeChange(obj) {
    if (!obj)
      return
    this.statsType = obj.getValue() ? ETTI_VALUE_INHISORY : ETTI_VALUE_TOTAL
    saveLocalByAccount("leaderboards_type", this.statsType)
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

    let contact = getContact(this.player?.uid, this.player.name)
    let isMe = contact?.isMe() ?? false
    let canBan = isMe ? false : (myself_can_devoice() || myself_can_ban())
    let isFriend = contact?.isInFriendGroup() ?? false
    let isBlock = contact?.isInBlockGroup() ?? false

    let isPS4Player = isPlayerFromPS4(this.player.name)
    let isXBoxOnePlayer = isXBoxPlayerName(this.player.name)
    let canBlock = !isPlatformXbox || !isXBoxOnePlayer
    let canInteractCC = canInteractCrossConsole(this.player.name)

    let sheet = this.getCurSheet()
    let showStatBar = this.infoReady && sheet == "Statistics"
    let showProfBar = this.infoReady && sheet == "UserCard"
    let isVisibleAchievementsUrlBtn = !isMe && showProfBar && hasFeature("AchievementsUrl") && hasFeature("AllowExternalLink")

    showObjectsByTable(this.scene, {
      paginator_place = showStatBar
      btn_friendAdd = showProfBar && hasFeatureFriends && canInteractCC && !isMe && !isFriend && !isBlock
      btn_friendRemove = showProfBar && hasFeatureFriends && isFriend && (contact?.isInFriendlist() ?? false)
      btn_blacklistAdd = showProfBar && hasFeatureFriends && !isMe && !isFriend && !isBlock && canBlock && !isPS4Player
      btn_blacklistRemove = showProfBar && hasFeatureFriends && isBlock && canBlock && !isPS4Player
      btn_moderatorBan = showProfBar && is_myself_anyof_moderators() && canBan
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

    gui_modal_ban({ name = playerName, uid = userId, clanTag = clanTag })
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
    if (this.infoReady && ("uid" in this.player)) {
      checkCanComplainAndProceed(this.player.uid, @() gui_modal_complain(this.player))
    }
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

  function onOpenAchievementsUrl() {
    openUrl(getCurCircuitOverride("achievementsURL", loc("url/achievements")).subst(
        { appId = APP_ID, name = encode_uri_component(this.player.name) }),
      false, false, "profile_page")
  }

  function showMedalsSheet() {
    let holder = this.showSheetDiv("medals")
    if (this.medalsPageHandlerWeak != null)
      return

    let medalsPageHandler = openMedalsPage({
      scene = holder
      parent = this
      player = this.player
      isOwnStats = this.isOwnStats
      openParams = {
        initCountry = this.filterCountryName
      }
    })
    this.registerSubHandler(medalsPageHandler)
    this.medalsPageHandlerWeak = medalsPageHandler.weakref()
  }

  function showServiceRecordsSheet() {
    let holder = this.showSheetDiv("records")
    if (this.serviceRecordsPageHandlerWeak != null)
      return

    let serviceRecordsPageHandler = openServiceRecordsPage({
      scene = holder
      parent = this
      player = this.player
      isOwnStats = this.isOwnStats
      paginatorHolder = this.scene.findObject("paginator_place")
    })
    this.registerSubHandler(serviceRecordsPageHandler)
    this.serviceRecordsPageHandlerWeak = serviceRecordsPageHandler.weakref()
  }

  function updateUnlockFav(_name, containerObj) {
    showObjById("checkbox_favorites", false, containerObj)
  }

  function unlockToFavorites(_obj = null) {}

  function onLeaderboard() {
    let userId = (this.player?.uid ?? "-1").tointeger()
    if (userId >= 0)
      loadHandler(gui_handlers.LeaderboardWindow, { userId })
  }

  function fillShowcaseMid(terseInfo, userStats) {
    let data = getShowcaseViewData(userStats, terseInfo, this.getScaleParams())
    let midNest = this.scene.findObject("showcase_mid_nest")
    this.guiScene.replaceContentFromText(midNest, data, data.len(), this)
  }

  function fillShowcaseTitle(terseInfo) {
    let nest = this.scene.findObject("showcase_title_nest")
    let data = getShowcaseTitleViewData(terseInfo, this.getScaleParams())
    this.guiScene.replaceContentFromText(nest, data, data.len(), this)
  }

  function fillShowcase(terseInfo, userStats) {
    this.fillShowcaseTitle(terseInfo)
    this.fillShowcaseMid(terseInfo, userStats)
  }

  function updateUserCardTerseInfo(responce, stats = null) {
    stats = stats ?? this.getPageProfileStats()
    let infos = responce?.usersInfo[stats?.uid ?? ""]
    if (infos == null)
      return

    let pilotIcon = getAvatarIconIdByUserInfo(infos)
    this.terseInfo = {}
    this.terseInfo.schType <- infos.shcType
    this.terseInfo.background <- infos.background
    this.terseInfo.frame <- infos.frame
    this.terseInfo.pilotIcon <- pilotIcon
    this.terseInfo.showcase <- infos?.showcase
      ? clone infos.showcase
      : {}
    trySetBestShowcaseMode(stats, this.terseInfo)
    this.fillShowcase(this.terseInfo, stats)

    this.currentHeaderBackgroundId = this.terseInfo.background != "" ? this.terseInfo.background : "profile_header_default"
    this.currentAvatarFrameId = this.terseInfo.frame != "" ? this.terseInfo.frame : ""
    this.currentAvatarId = this.terseInfo.pilotIcon != "" ? this.terseInfo.pilotIcon : "cardicon_default"
    this.setCurrentHeaderBackground()
    this.setCurrentAvatarFrame()
    this.setCurrentAvatar()
  }

  function updateShowcase() {
    let userStats = this.getPageProfileStats()
    if (userStats == null)
      return

    if (this.terseInfo != null) {
      this.fillShowcase(this.terseInfo, userStats)
      return
    }

    let userInfo = getUserInfo(userStats.uid)
    if (userInfo == null)
      return

    this.updateUserCardTerseInfo({usersInfo = { [userStats.uid] = userInfo }}, userStats)
  }

  onEventUserInfoManagerDataUpdated = @(param) this.updateUserCardTerseInfo(param)

  function getPageProfileStats() {
    return this.player
  }

  function changeHeaderBackgroundImage(image) {
    let newImage = $"!ui/images/profile_headers/{image}"
    let profileHeaderBackground = this.scene.findObject("profileHeaderBackground")
    if (profileHeaderBackground["background-image"] == newImage)
      return

    if (profileHeaderBackground["background-image"] == "") {
      profileHeaderBackground["background-image"] = newImage
      return
    }

    profileHeaderBackground["headerAnim"] = "hide"

    let cb = Callback(function() {
      profileHeaderBackground["background-image"] = newImage
      profileHeaderBackground["headerAnim"] = "show"
    }, this)

    setTimeout(0.25, @() cb())
  }

  function changeFrameImage(image) {
    let avatarFrame = showObjById("avatarFrame", image != "", this.scene)
    if (avatarFrame == null || image == "")
      return

    avatarFrame["background-image"] = $"!ui/images/avatar_frames/{image}.avif"
    avatarFrame.show(true)
  }

  changeAvatarImage = @(image) this.scene.findObject("profile-icon").setValue(image)

  setCurrentHeaderBackground = @() this.changeHeaderBackgroundImage(this.currentHeaderBackgroundId)

  setCurrentAvatarFrame = @() this.changeFrameImage(this.currentAvatarFrameId)

  setCurrentAvatar = @() this.changeAvatarImage(this.currentAvatarId)

  function onUnitImageClick(_obj) {}

  function onDeleteUnitClick(_obj) {}

  function onSelectFavUnitDiff(_obj) {}

  function onShowcaseCustomFunc(_obj) {}

}