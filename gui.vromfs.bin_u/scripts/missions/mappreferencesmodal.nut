//-file:plus-string
from "%scripts/dagui_natives.nut" import save_online_single_job
from "%scripts/dagui_library.nut" import *
from "%scripts/options/optionsConsts.nut" import SAVE_ONLINE_JOB_DIGIT

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { ceil, floor } = require("math")
let { rnd } = require("dagor.random")
let mapPreferencesParams = require("%scripts/missions/mapPreferencesParams.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { move_mouse_on_child_by_value, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let mapPreferences    = require("mapPreferences")
let daguiFonts = require("%scripts/viewUtils/daguiFonts.nut")
let { havePremium } = require("%scripts/user/premium.nut")
let { setMapPreview, getMissionBriefingConfig } = require("%scripts/missions/mapPreview.nut")
let { trim, utf8ToLower } = require("%sqstd/string.nut")
let { get_meta_mission_info_by_name } = require("guiMission")
let { addPopup } = require("%scripts/popups/popups.nut")

const POPUP_PREFIX_LOC_ID = "maps/preferences/notice/"

dagui_propid_add_name_id("hasPremium")
dagui_propid_add_name_id("hasMaxBanned")
dagui_propid_add_name_id("hasMaxDisliked")
dagui_propid_add_name_id("hasMaxLiked")

gui_handlers.mapPreferencesModal <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType             = handlerType.MODAL
  sceneTplName        = "%gui/missions/mapPreferencesModal.tpl"
  curEvent            = null
  curBattleTypeName   = null
  counters            = null
  mapsList            = null
  inactiveMaps        = null
  currentMapId        = -1
  currentPage         = -1

  function getSceneTplView() {
    let maxCountX = max(floor(
      to_pixels("1@srw - 1@mapPreferencePreviewFullWidth - 1@scrollBarSize")
      * 1.0 / to_pixels("1@mapPreferenceIconNestWidth")), 1)
    this.mapsList = mapPreferencesParams.getMapsList(this.curEvent)
    this.inactiveMaps = mapPreferencesParams.getInactiveMaps(this.curEvent, this.mapsList)
    this.updateValidatedCounters()
    let banList = this.getBanList()
    let mapsCountY = ceil(this.mapsList.len() * 1.0 / maxCountX)
    let mapItemHeight = to_pixels("1@mapPreferenceIconSize + 3@blockInterval")
      + daguiFonts.getFontLineHeightPx("fontSmall")
    let mapsRowsHeight = mapsCountY * mapItemHeight
    let title = mapPreferencesParams.getPrefTitle(this.curEvent)
    let textRowHeight = daguiFonts.getFontLineHeightPx("fontNormal")
    let banListHeight = to_pixels("".concat("1@maxWindowHeight-1@frameFooterHeight",
      "-1@frameTopPadding-1@frameHeaderHeight-1@mapPreferencePreviewSize-3@checkboxSize",
      "-2@buttonHeight-3@blockInterval-2@buttonMargin")) - 2 * textRowHeight

    return {
      wndTitle = title
      maxCountX = maxCountX
      premium = havePremium.value
      maps = this.mapsList
      isListEmpty = this.mapsList.len() == 0
      listTitle = title
      mapStateBox = banList
      counterTitle = this.getCounterTitleText()
      hasMaxBanned = this.hasMaxCount("banned") ? "yes" : "no"
      hasMaxDisliked = this.hasMaxCount("disliked") ? "yes" : "no"
      hasMaxLiked = this.hasMaxCount("liked") ? "yes" : "no"
      hasScroll = to_pixels("1@mapPreferenceListHeight") < (mapsRowsHeight + to_pixels("1@blockInterval"))
      banListHeight = banListHeight > textRowHeight ? banListHeight : 0
      showLevelBrRange = this.curEvent.missionsBanMode == "level"
    }
  }

  function initScreen() {
    this.curBattleTypeName = mapPreferencesParams.getCurBattleTypeName(this.curEvent)
    let mlistObj = this.scene.findObject("maps_list")
    mlistObj.setValue(this.mapsList.len() ? (rnd() % this.mapsList.len()) : -1)
    move_mouse_on_child_by_value(mlistObj)
    this.updateBanListPartsVisibility()
  }

  function updateMapPreview() {
    let previewObj = this.scene.findObject("map_preview")
    if (!checkObj(previewObj))
      return

    let isMapSelected = this.mapsList?[this.currentMapId] != null
    showObjectsByTable(previewObj, {
      title             = isMapSelected,
      img_preview       = false,
      ["tactical-map"]  = false,
      ["paginator"]     = false,
      dislike           = isMapSelected,
      ban               = isMapSelected,
      like              = isMapSelected,
      preview_separator = isMapSelected,
    })

    if (!isMapSelected)
      return

    this.currentPage = 0
    this.fillMapPreview()
    this.updatePreviewButtonsState()
  }

  function updateLevelBrRangeText() {
    let { minMRank, maxMRank } = this.mapsList[this.currentMapId].missions[this.currentPage].ranksRange
    let brRangeText = mapPreferencesParams.getBattleRatingsDescriptionText(minMRank, maxMRank)
    this.scene.findObject("level_br_range").setValue(brRangeText)
  }

  function updatePreviewButtonsState() {
    if (this.currentMapId < 0)
      return
    let isLevelBanMode = this.curEvent.missionsBanMode == "level"
    let banned = this.mapsList[this.currentMapId].banned
    let disliked = this.mapsList[this.currentMapId].disliked

    foreach (idx, inst in mapPreferencesParams.getPrefTypes()) {
      let checkBoxObj = this.scene.findObject("map_preview").findObject(inst.id)
      checkBoxObj.setValue(idx == "disliked" ? !banned && disliked : this.mapsList[this.currentMapId][idx])
      checkBoxObj.findObject("title").setValue(" ".join([
        loc("maps/preferences/{0}".subst(this.mapsList[this.currentMapId][idx]
          ? inst.tooltip_remove_id
          : inst.id)),
        isLevelBanMode
          ? loc("ui/parentheses/space", { text = loc("maps/preferences/all_missions") })
          : ""
      ], true))
      checkBoxObj.inactiveColor = (idx == "disliked" ?  banned : false)
        || (this.hasMaxCount(idx) && !this.mapsList[this.currentMapId][idx]) ? "yes" : "no"
    }
  }

  function hasMaxCount(typeName) {
    return this.counters[typeName].curCounter >= this.counters[typeName].maxCounter
  }

  function getCounterTextByType(typeName) {
    let maxCountertextWithPremium = !havePremium.value
      && this.counters[typeName].maxCounter < this.counters[typeName].maxCounterWithPremium
        ? " {0}".subst(loc("ui/parentheses", { text = loc("maps/preferences/counter/withPremium",
          { count = this.counters[typeName].maxCounterWithPremium }) }))
        : ""

    return loc("ui/parentheses", { text = this.counters[typeName].curCounter + loc("ui/slash")
      + this.counters[typeName].maxCounter + maxCountertextWithPremium })
  }

  function getCounterTitleText() {
    return " ".join([
      loc("maps/preferences/counter/dislike", { counterText = this.getCounterTextByType("disliked") }),
      loc("maps/preferences/counter/ban", { counterText = this.getCounterTextByType("banned") }),
      loc("maps/preferences/counter/like", { counterText = this.getCounterTextByType("liked") })
    ], true)
  }

  function updateCounterTitle() {
    this.scene.findObject("counters").setValue(this.getCounterTitleText())
  }

  function updateMapsListParams() {
    let mapListObj = this.scene.findObject("maps_list")
    let mapsObjParams = {
      hasPremium = havePremium.value ? "yes" : "no"
      hasMaxBanned = this.hasMaxCount("banned") ? "yes" : "no"
      hasMaxDisliked = this.hasMaxCount("disliked") ? "yes" : "no"
      hasMaxLiked = this.hasMaxCount("liked") ? "yes" : "no"
    }
    foreach (paramName, value in mapsObjParams)
      mapListObj[paramName] = value
  }

  function updateMapsList() {
    this.updateValidatedCounters()
    this.updateCounterTitle()
    this.updateMapsListParams()
    this.refreshMapsCheckBox()
    this.updateBanList()
  }

  function updateMapState(mapId, paramName, value) {
    this.mapsList[mapId][paramName] = value
    let newState = mapPreferencesParams.getMapState(this.mapsList[mapId])
    this.mapsList[mapId].state = newState
    this.updateCounterTitle()
    this.updateMapsListParams()
    this.updateProfile(paramName, value, this.mapsList[mapId].map)

    let iconObj = this.scene.findObject("icon_" + mapId)
    if (!checkObj(iconObj))
      return

    iconObj.state = newState
    let chekboxObj = iconObj.findObject(paramName)
    if (checkObj(chekboxObj))
      chekboxObj.setValue(value)

    this.updateBanListPartsVisibility()
  }

  function updateBanListPartsVisibility() {
    let isBanListFilled = this.counters.len() != 0
      && this.counters.reduce(@(res, v) res + v.curCounter, 0) > 0
    showObjectsByTable(this.scene, {
      listTitle = isBanListFilled,
      btnReset  = isBanListFilled,
    })
  }

  function onUpdateIcon(obj) {
    let mapId = obj?.mapId.tointeger() ?? this.currentMapId
    let value = obj.getValue()
    let objType = obj.type
    let curValue = this.mapsList[mapId][objType]
    if (curValue == value)
      return

    let count = this.counters[objType]
    let isDislikeBannedMap = objType == "disliked" && this.mapsList[mapId].banned
    count.curCounter += value ? 1 : -1
    if (value && (count.curCounter > count.maxCounter || isDislikeBannedMap)) {
      let needPremium  = objType == "banned" && !havePremium.value
      if (needPremium)
        scene_msg_box("need_money", null, loc("mainmenu/onlyWithPremium"),
          [ ["purchase", Callback(@() this.onOnlineShopPremium(), this)],
            ["cancel", null]
          ], "purchase")
      else {
        let msg_id = isDislikeBannedMap ? "mapIsBanned"
          : mapPreferencesParams.getPrefTypes()[objType].msg_id
        addPopup(null, loc(POPUP_PREFIX_LOC_ID + msg_id), null, null, null, msg_id)
      }

      count.curCounter--
      obj.setValue(false)
      return
    }

    let cbNestObj = this.scene.findObject("cb_nest_" + mapId)
    if (objType == "banned") {
      if (this.mapsList[mapId]["liked"])
        cbNestObj.findObject("liked").setValue(false)
      else
        cbNestObj.findObject("disliked").setValue(false)
    }
    else if (objType ==  "disliked") {
      if (this.mapsList[mapId]["liked"])
        cbNestObj.findObject("liked").setValue(false)
    }
    else if (objType == "liked") {
      if (this.mapsList[mapId]["banned"])
        cbNestObj.findObject("banned").setValue(false)
      else
        cbNestObj.findObject("disliked").setValue(false)
    }

    this.updateMapState(mapId, objType, value)
    this.updatePreviewButtonsState()
    this.updateBanList()
  }

  function refreshMapsCheckBox() {
    for (local i = 0; i < this.mapsList.len(); i++) {
      let iconObj = this.scene.findObject("icon_" + i)
      if (!checkObj(iconObj))
        continue

      iconObj.state = mapPreferencesParams.getMapState(this.mapsList[i])
      iconObj.findObject("disliked")?.setValue(this.mapsList[i].disliked)
      iconObj.findObject("banned")?.setValue(this.mapsList[i].banned)
      iconObj.findObject("liked")?.setValue(this.mapsList[i].liked)
    }
  }

  function updateProfile(aType, value, missionName) {
    let actionType = mapPreferencesParams.getPrefTypes()?[aType].sType
    if (actionType == null)
      return

    if (value)
      mapPreferences.add(this.curBattleTypeName, actionType, missionName)
    else
      mapPreferences.remove(this.curBattleTypeName, actionType, missionName)
  }

  function goBack() {
    base.goBack()
    foreach (name, list in this.inactiveMaps)
      if (this.counters[name].curCounter + list.len() > this.counters[name].maxCounter)
        foreach (inst in list)
          this.updateProfile(name, false, inst)
    save_online_single_job(SAVE_ONLINE_JOB_DIGIT)
  }

  function onSelect(obj) {
    let childrenCount = obj.childrenCount()
    let idx = obj.getValue()
    if (idx < 0 || idx >= childrenCount)
      return

    this.currentMapId = idx
    this.updateMapPreview()
  }

  function updateScreen() {
    this.mapsList = mapPreferencesParams.getMapsList(this.curEvent)
    this.updateMapsList()
    this.updateMapPreview()
    this.updateBanListPartsVisibility()
  }

  function onEventProfileUpdated(_params) {
    this.updateScreen()
  }

  function resetCounters(params) {
    foreach (pref in params) {
      mapPreferencesParams.resetProfilePreferences(this.curEvent, pref)
      this.counters[pref].curCounter = 0
    }
    save_online_single_job(SAVE_ONLINE_JOB_DIGIT)
  }

  function updateValidatedCounters() {
    this.counters = mapPreferencesParams.getCounters(this.curEvent)
    foreach (name, list in this.inactiveMaps)
      this.counters[name].curCounter = max(this.counters[name].curCounter - list.len(), 0)
    let params = this.counters.filter(@(c) c.curCounter > c.maxCounter).keys()
    if (params.len() > 0) {
      this.resetCounters(params)
      scene_msg_box("reset_preferences", null, loc(POPUP_PREFIX_LOC_ID + "resetPreferences"),
        [["ok", this.updateScreen.bindenv(this)]], "ok")
    }
  }

  function getBanList() {
    let list = this.mapsList.filter(@(inst) inst.disliked || inst.banned || inst.liked).map(@(inst)
      {
        id = "cb_" + inst.mapId
        text = $"[{inst.brRangeText}] {inst.title}"
        value = true
        funcName = "onUpdateIcon"
        sortParam = inst.banned ? 0 : 1
        specialParams = "smallFont:t='yes'; mapId:t='{mapId}'; type:t='{type}';".subst({
          mapId = inst.mapId
          type = mapPreferencesParams.getMapState(inst)
        })
      }
    )

    list.sort(@(a, b) a.sortParam <=> b.sortParam || a.text <=> b.text)
    return list
  }

  function updateBanList() {
    let listObj = this.scene.findObject("ban_list")
    if (!checkObj(listObj))
      return

    let data = handyman.renderCached("%gui/missions/mapStateBox.tpl", { mapStateBox = this.getBanList() })
    this.guiScene.replaceContentFromText(listObj, data, data.len(), this)
  }

  function onResetPreferencess(_obj) {
    scene_msg_box("reset_preferences", null, loc("maps/preferences/notice/request_reset"),
      [["ok", function() {
            this.resetCounters(this.counters.keys())
            this.updateScreen()
          }.bindenv(this)],
        ["cancel", null]
      ], "ok")
  }

  function onFilterEditBoxActivate() {
    this.selectMapById(this.currentMapId)
  }

  function onFilterEditBoxCancel() {
    let editBoxObj = this.scene.findObject("filter_edit_box")
    if (editBoxObj.getValue() != "") {
      editBoxObj.setValue("")
      this.selectMapById(this.currentMapId)
    }
    else
      this.goBack()
  }

  function onFilterEditBoxChangeValue(obj) {
    let value = obj.getValue()
    this.scene.findObject("filter_edit_cancel_btn")?.show(value.len() != 0)

    let searchStr = utf8ToLower(trim(value))
    let visibleMapsList = searchStr != "" ? this.mapsList.filter(@(inst)
      utf8ToLower(inst.title).indexof(searchStr) != null) : this.mapsList

    let mlistObj = this.scene.findObject("maps_list")
    foreach (inst in this.mapsList)
      mlistObj.findObject("nest_" + inst.mapId)?.show(visibleMapsList.indexof(inst) != null)

    let isFound = visibleMapsList.len() != 0
    this.currentMapId = isFound ? visibleMapsList[0].mapId : -1
    showObjById("empty_list_label", !isFound, this.scene)
    mlistObj.findObject("nest_" + this.currentMapId)?.scrollToView()
    this.updateMapPreview()
  }

  function selectMapById(mapId) {
    let mlistObj = this.scene.findObject("maps_list")
    mlistObj?.setValue(mapId)
    move_mouse_on_child_by_value(mlistObj)
    this.guiScene.performDelayed(this, @() this.guiScene.performDelayed(this,
      @() mlistObj?.findObject("nest_" + mapId).scrollToView()))
  }

  function updatePaginator() {
    let paginatorObj = this.scene.findObject("paginator_place")
    ::generatePaginator(paginatorObj, this,
      this.currentPage, this.mapsList[this.currentMapId].missions.len() - 1, null)
  }

  function fillMapPreview() {
    let previewObj = this.scene.findObject("map_preview")
    if (!checkObj(previewObj))
      return

    let missionsList = this.mapsList[this.currentMapId].missions
    previewObj.findObject("title").setValue(missionsList[this.currentPage].title)
    let curMission = get_meta_mission_info_by_name(missionsList[this.currentPage].id)
    if (curMission) {
      let config = getMissionBriefingConfig({ blk = curMission })
      setMapPreview(this.scene.findObject("tactical-map"), config)
    }
    else
      previewObj.findObject("img_preview")["background-image"] = this.mapsList[this.currentMapId].image

    showObjectsByTable(previewObj, {
      img_preview       = !curMission,
      ["tactical-map"]  = curMission,
      ["paginator"]     = missionsList.len() > 1
    })
    this.updatePaginator()
    this.updateLevelBrRangeText()
  }

  function goToPage(obj) {
    this.currentPage = obj.to_page.tointeger()
    this.fillMapPreview()
  }
}

return {
  open = function(params) {
    if (!mapPreferencesParams.hasPreferences(params.curEvent))
      return

    handlersManager.loadHandler(gui_handlers.mapPreferencesModal, params)
  }
}