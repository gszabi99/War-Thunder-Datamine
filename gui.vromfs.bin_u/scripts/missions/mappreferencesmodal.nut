let mapPreferencesParams = require("%scripts/missions/mapPreferencesParams.nut")
let mapPreferences    = require("mapPreferences")
let daguiFonts = require("%scripts/viewUtils/daguiFonts.nut")

const POPUP_PREFIX_LOC_ID = "maps/preferences/notice/"

::dagui_propid.add_name_id("hasPremium")
::dagui_propid.add_name_id("hasMaxBanned")
::dagui_propid.add_name_id("hasMaxDisliked")
::dagui_propid.add_name_id("hasMaxLiked")

::gui_handlers.mapPreferencesModal <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType             = handlerType.MODAL
  sceneTplName        = "%gui/missions/mapPreferencesModal"
  curEvent            = null
  curBattleTypeName   = null
  counters            = null
  mapsList            = null
  inactiveMaps        = null
  currentMapId        = -1
  currentPage         = -1

  function getSceneTplView()
  {
    let maxCountX = ::max(::floor(
      ::to_pixels("1@srw - 1@mapPreferencePreviewFullWidth - 1@scrollBarSize")
      * 1.0 / ::to_pixels("1@mapPreferenceIconNestWidth")), 1)
    mapsList = mapPreferencesParams.getMapsList(curEvent)
    inactiveMaps = mapPreferencesParams.getInactiveMaps(curEvent, mapsList)
    updateValidatedCounters()
    let banList = getBanList()
    let mapsCountY = ::ceil(mapsList.len() * 1.0 / maxCountX)
    let mapItemHeight = ::to_pixels("1@mapPreferenceIconSize + 3@blockInterval")
      + daguiFonts.getFontLineHeightPx("fontSmall")
    let mapsRowsHeight = mapsCountY * mapItemHeight
    let title = mapPreferencesParams.getPrefTitle(curEvent)
    let textRowHeight = daguiFonts.getFontLineHeightPx("fontNormal")
    let banListHeight = ::to_pixels("".concat("1@maxWindowHeight-1@frameFooterHeight",
      "-1@frameTopPadding-1@frameHeaderHeight-1@mapPreferencePreviewSize-3@checkboxSize",
      "-2@buttonHeight-3@blockInterval-2@buttonMargin")) - 2*textRowHeight

    return {
      wndTitle = title
      maxCountX = maxCountX
      premium = ::havePremium()
      maps = mapsList
      isListEmpty = mapsList.len() == 0
      listTitle = title
      mapStateBox = banList
      counterTitle = getCounterTitleText()
      hasMaxBanned = hasMaxCount("banned") ? "yes" : "no"
      hasMaxDisliked = hasMaxCount("disliked") ? "yes" : "no"
      hasMaxLiked = hasMaxCount("liked") ? "yes" : "no"
      hasScroll = ::to_pixels("1@mapPreferenceListHeight") < (mapsRowsHeight + ::to_pixels("1@blockInterval"))
      banListHeight = banListHeight > textRowHeight ? banListHeight : 0
    }
  }

  function initScreen()
  {
    curBattleTypeName = mapPreferencesParams.getCurBattleTypeName(curEvent)
    let mlistObj = scene.findObject("maps_list")
    mlistObj.setValue(mapsList.len() ? (::math.rnd() % mapsList.len()) : -1)
    ::move_mouse_on_child_by_value(mlistObj)
    updateBanListPartsVisibility()
  }

  function updateMapPreview()
  {
    let previewObj = scene.findObject("map_preview")
    if (!::check_obj(previewObj))
      return

    let isMapSelected = mapsList?[currentMapId] != null
    ::showBtnTable(previewObj, {
      title             = isMapSelected,
      img_preview       = false,
      ["tactical-map"]  = false,
      ["paginator"]     = false,
      dislike           = isMapSelected,
      ban               = isMapSelected,
      like              = isMapSelected,
      preview_separator = isMapSelected,
    })

    if(!isMapSelected)
      return

    currentPage = 0
    fillMapPreview()
    updatePreviewButtonsState()
  }

  function updatePreviewButtonsState()
  {
    if(currentMapId < 0)
      return
    let isLevelBanMode = curEvent.missionsBanMode == "level"
    let banned = mapsList[currentMapId].banned
    let disliked = mapsList[currentMapId].disliked

    foreach(idx, inst in mapPreferencesParams.getPrefTypes())
    {
      let checkBoxObj = scene.findObject("map_preview").findObject(inst.id)
      checkBoxObj.setValue(idx == "disliked" ? !banned && disliked : mapsList[currentMapId][idx])
      checkBoxObj.findObject("title").setValue(::g_string.implode([
        ::loc("maps/preferences/{0}".subst(mapsList[currentMapId][idx]
          ? inst.tooltip_remove_id
          : inst.id)),
        isLevelBanMode
          ? ::loc("ui/parentheses/space", {text = ::loc("maps/preferences/all_missions")})
          : ""
      ], " "))
      checkBoxObj.inactiveColor = (idx == "disliked" ?  banned : false)
        || (hasMaxCount(idx) && !mapsList[currentMapId][idx]) ? "yes" : "no"
    }
  }

  function hasMaxCount(typeName)
  {
    return counters[typeName].curCounter >= counters[typeName].maxCounter
  }

  function getCounterTextByType(typeName)
  {
    let hasPremium  = ::havePremium()
    let maxCountertextWithPremium = !hasPremium
      && counters[typeName].maxCounter < counters[typeName].maxCounterWithPremium
        ? " {0}".subst(::loc("ui/parentheses", { text = ::loc("maps/preferences/counter/withPremium",
          { count = counters[typeName].maxCounterWithPremium }) }))
        : ""

    return ::loc("ui/parentheses",{text = counters[typeName].curCounter + ::loc("ui/slash")
      + counters[typeName].maxCounter + maxCountertextWithPremium})
  }

  function getCounterTitleText()
  {
    return ::g_string.implode([
      ::loc("maps/preferences/counter/dislike", { counterText = getCounterTextByType("disliked") }),
      ::loc("maps/preferences/counter/ban", { counterText = getCounterTextByType("banned") }),
      ::loc("maps/preferences/counter/like", { counterText = getCounterTextByType("liked") })
    ], " ")
  }

  function updateCounterTitle()
  {
    scene.findObject("counters").setValue(getCounterTitleText())
  }

  function updateMapsListParams()
  {
    let mapListObj = scene.findObject("maps_list")
    let mapsObjParams = {
      hasPremium = ::havePremium() ? "yes" : "no"
      hasMaxBanned = hasMaxCount("banned") ? "yes" : "no"
      hasMaxDisliked = hasMaxCount("disliked") ? "yes" : "no"
      hasMaxLiked = hasMaxCount("liked") ? "yes" : "no"
    }
    foreach (paramName, value in mapsObjParams)
      mapListObj[paramName] = value
  }

  function updateMapsList()
  {
    updateValidatedCounters()
    updateCounterTitle()
    updateMapsListParams()
    refreshMapsCheckBox()
    updateBanList()
  }

  function updateMapState(mapId, paramName, value)
  {
    mapsList[mapId][paramName] = value
    let newState = mapPreferencesParams.getMapState(mapsList[mapId])
    mapsList[mapId].state = newState
    updateCounterTitle()
    updateMapsListParams()
    updateProfile(paramName, value, mapsList[mapId].map)

    let iconObj = scene.findObject("icon_" + mapId)
    if (!::check_obj(iconObj))
      return

    iconObj.state = newState
    let chekboxObj = iconObj.findObject(paramName)
    if (::check_obj(chekboxObj))
      chekboxObj.setValue(value)

    updateBanListPartsVisibility()
  }

  function updateBanListPartsVisibility()
  {
    let isBanListFilled = getBanList().len() > 0
    ::showBtnTable(scene, {
      listTitle = isBanListFilled,
      btnReset  = isBanListFilled,
    })
  }

  function onUpdateIcon(obj)
  {
    let mapId = obj?.mapId.tointeger() ?? currentMapId
    let value = obj.getValue()
    let objType = obj.type
    let curValue = mapsList[mapId][objType]
    if(curValue == value)
      return

    let count = counters[objType]
    let isDislikeBannedMap = objType == "disliked" && mapsList[mapId].banned
    count.curCounter += value ? 1 : -1
    if(value && (count.curCounter > count.maxCounter || isDislikeBannedMap))
    {
      let needPremium  = objType == "banned" && !::havePremium()
      if(needPremium)
        ::scene_msg_box("need_money", null, ::loc("mainmenu/onlyWithPremium"),
          [ ["purchase", (@() onOnlineShopPremium()).bindenv(this)],
            ["cancel", null]
          ], "purchase")
      else
      {
        let msg_id = isDislikeBannedMap ? "mapIsBanned"
          : mapPreferencesParams.getPrefTypes()[objType].msg_id
        ::g_popups.add(null, ::loc(POPUP_PREFIX_LOC_ID + msg_id), null, null, null, msg_id)
      }

      count.curCounter--
      obj.setValue(false)
      return
    }

    let cbNestObj = scene.findObject("cb_nest_" + mapId)
    switch (objType)
    {
      case "banned":
        if (mapsList[mapId]["liked"])
          cbNestObj.findObject("liked").setValue(false)
        else
          cbNestObj.findObject("disliked").setValue(false)
      break
      case "disliked":
        if (mapsList[mapId]["liked"])
          cbNestObj.findObject("liked").setValue(false)
      break
      case "liked":
        if (mapsList[mapId]["banned"])
          cbNestObj.findObject("banned").setValue(false)
        else
          cbNestObj.findObject("disliked").setValue(false)
      break
    }

    updateMapState(mapId, objType, value)
    updatePreviewButtonsState()
    updateBanList()
  }

  function refreshMapsCheckBox()
  {
    for(local i=0; i < mapsList.len(); i++)
    {
      let iconObj = scene.findObject("icon_" + i)
      if (!::check_obj(iconObj))
        continue

      iconObj.state = mapPreferencesParams.getMapState(mapsList[i])
      iconObj.findObject("disliked")?.setValue(mapsList[i].disliked)
      iconObj.findObject("banned")?.setValue(mapsList[i].banned)
      iconObj.findObject("liked")?.setValue(mapsList[i].liked)
    }
  }

  function updateProfile(aType, value, missionName)
  {
    let actionType = mapPreferencesParams.getPrefTypes()?[aType].sType
    if (actionType == null)
      return

    if(value)
      mapPreferences.add(curBattleTypeName, actionType, missionName)
    else
      mapPreferences.remove(curBattleTypeName, actionType, missionName)
  }

  function goBack()
  {
    base.goBack()
    foreach(name, list in inactiveMaps)
      if(counters[name].curCounter + list.len() > counters[name].maxCounter)
        foreach(inst in list)
          updateProfile(name, false, inst)
    ::save_online_single_job(SAVE_ONLINE_JOB_DIGIT)
  }

  function onSelect(obj)
  {
    let childrenCount = obj.childrenCount()
    let idx = obj.getValue()
    if (idx < 0 || idx >= childrenCount)
      return

    currentMapId = idx
    updateMapPreview()
  }

  function updateScreen()
  {
    mapsList = mapPreferencesParams.getMapsList(curEvent)
    updateMapsList()
    updateMapPreview()
    updateBanListPartsVisibility()
  }

  function onEventProfileUpdated(params)
  {
    updateScreen()
  }

  function resetCounters(params)
  {
    foreach(pref in params)
    {
      mapPreferencesParams.resetProfilePreferences(curEvent, pref)
      counters[pref].curCounter = 0
    }
    ::save_online_single_job(SAVE_ONLINE_JOB_DIGIT)
  }

  function updateValidatedCounters()
  {
    counters = mapPreferencesParams.getCounters(curEvent)
    foreach(name, list in inactiveMaps)
      counters[name].curCounter = ::max(counters[name].curCounter - list.len(), 0)
    let params = counters.filter(@(c) c.curCounter > c.maxCounter).keys()
    if(params.len() > 0)
    {
      resetCounters(params)
      ::scene_msg_box("reset_preferences", null, ::loc(POPUP_PREFIX_LOC_ID + "resetPreferences"),
        [["ok", updateScreen.bindenv(this)]], "ok")
    }
  }

  function getBanList()
  {
    let list = mapsList.filter(@(inst) inst.disliked || inst.banned || inst.liked).map(@(inst)
      {
        id = "cb_" + inst.mapId
        text = inst.title
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

  function updateBanList()
  {
    let listObj = scene.findObject("ban_list")
    if (!::check_obj(listObj))
      return

    let data = ::handyman.renderCached("%gui/missions/mapStateBox", {mapStateBox = getBanList()})
    guiScene.replaceContentFromText(listObj, data, data.len(), this)
  }

  function onResetPreferencess(obj)
  {
    ::scene_msg_box("reset_preferences", null, ::loc("maps/preferences/notice/request_reset"),
      [["ok", function() {
            resetCounters(counters.keys())
            updateScreen()
          }.bindenv(this)],
        ["cancel", null]
      ], "ok")
  }

  function onFilterEditBoxActivate()
  {
    selectMapById(currentMapId)
  }

  function onFilterEditBoxCancel()
  {
    let editBoxObj = scene.findObject("filter_edit_box")
    if (editBoxObj.getValue() != "")
    {
      editBoxObj.setValue("")
      selectMapById(currentMapId)
    }
    else
      goBack()
  }

  function onFilterEditBoxChangeValue(obj)
  {
    let value = obj.getValue()
    scene.findObject("filter_edit_cancel_btn")?.show(value.len() != 0)

    let searchStr = ::g_string.utf8ToLower(::g_string.trim(value))
    let visibleMapsList = searchStr != "" ? mapsList.filter(@(inst)
      ::g_string.utf8ToLower(inst.title).indexof(searchStr) != null) : mapsList

    let mlistObj = scene.findObject("maps_list")
    foreach (inst in mapsList)
      mlistObj.findObject("nest_" + inst.mapId)?.show(visibleMapsList.indexof(inst) != null)

    let isFound = visibleMapsList.len() != 0
    currentMapId = isFound ? visibleMapsList[0].mapId : -1
    showSceneBtn("empty_list_label", !isFound)
    mlistObj.findObject("nest_" + currentMapId)?.scrollToView()
    updateMapPreview()
  }

  function selectMapById(mapId)
  {
    let mlistObj = scene.findObject("maps_list")
    mlistObj?.setValue(mapId)
    ::move_mouse_on_child_by_value(mlistObj)
    guiScene.performDelayed(this, @() guiScene.performDelayed(this,
      @() mlistObj?.findObject("nest_" + mapId).scrollToView() ))
  }

  function updatePaginator()
  {
    let paginatorObj = scene.findObject("paginator_place")
    ::generatePaginator(paginatorObj, this,
      currentPage, mapsList[currentMapId].missions.len() - 1, null)
  }

  function fillMapPreview()
  {
    let previewObj = scene.findObject("map_preview")
    if (!::check_obj(previewObj))
      return

    let missionsList = mapsList[currentMapId].missions
    previewObj.findObject("title").setValue(missionsList[currentPage].title)
    let curMission = ::get_mission_meta_info(missionsList[currentPage].id)
    if (curMission)
    {
      let config = ::g_map_preview.getMissionBriefingConfig({blk = curMission})
      ::g_map_preview.setMapPreview(scene.findObject("tactical-map"), config)
    }
    else
      previewObj.findObject("img_preview")["background-image"] = mapsList[currentMapId].image

    ::showBtnTable(previewObj, {
      img_preview       = !curMission,
      ["tactical-map"]  = curMission,
      ["paginator"]     = missionsList.len() > 1
    })
    updatePaginator()
  }

  function goToPage(obj)
  {
    currentPage = obj.to_page.tointeger()
    fillMapPreview()
  }
}

return {
  open = function(params)
  {
    if(!mapPreferencesParams.hasPreferences(params.curEvent))
      return

    ::handlersManager.loadHandler(::gui_handlers.mapPreferencesModal, params)
  }
}