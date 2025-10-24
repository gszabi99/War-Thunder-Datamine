from "%scripts/dagui_natives.nut" import get_unlock_type
from "%scripts/dagui_library.nut" import *

let { format } = require("string")
let { setTimeout, clearTimer } = require("dagor.workcycle")
let { utf8ToLower } = require("%sqstd/string.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { copyParamsToTable } = require("%sqstd/datablock.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getUnlockById, getAllUnlocksWithBlkOrder } = require("%scripts/unlocks/unlocksCache.nut")
let { toggleUnlockFavButton, initUnlockFavInContainer } = require("%scripts/unlocks/favoriteUnlocks.nut")
let { getUnlockCondsDescByCfg, getUnlockMultDescByCfg, getUnlockMainCondDescByCfg,
  buildConditionsConfig, getUnlockableMedalImage, buildUnlockDesc } = require("%scripts/unlocks/unlocksViewModule.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings } = require("%scripts/clientState/localProfile.nut")
let { isUnlockVisible, isUnlockOpened, getUnlockRewardText } = require("%scripts/unlocks/unlocksModule.nut")
let { isBattleTask } = require("%scripts/unlocks/battleTasks.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")
let { getCountryOverride } = require("%scripts/countries/countriesCustomization.nut")

const SELECTED_MEDAL_SAVE_ID = "wnd/selectedMedal"

function filterMedalsListFunc(medal, nameFilter) {
  if (nameFilter == "")
    return true

  let { searchId, searchName } = medal
  return searchId.indexof(nameFilter) != null || searchName.indexof(nameFilter) != null
}

let MedalsHandler = class (gui_handlers.BaseGuiHandlerWT) {
  wndType          = handlerType.CUSTOM
  sceneBlkName     = "%gui/profile/medalsPage.blk"

  parent = null
  openParams = null
  applyFilterTimer = null
  medalNameFilter = ""
  player = null
  selectedMedal = null
  isOwnStats = false
  isPageFilling = false
  availableMedals = null

  function initScreen() {
    this.availableMedals = {}
    this.loadSelectedMedals()
    this.applyOpenParams()
    this.updateMedalsList()
  }

  function applyOpenParams() {
    if (this.openParams == null)
      return

    let { initCountry } = this.openParams
    if (initCountry == "")
      return

    this.selectedMedal.country = initCountry
    this.selectedMedal.rawdelete(initCountry)
  }

  function updateMedalsList() {
    this.prepareMedalsCache()
    this.fillMedalsList()
  }

  function prepareMedalsCache() {
    this.availableMedals.clear()
    local totalReceived = 0
    let unlocks = getAllUnlocksWithBlkOrder()
    foreach (cb in unlocks) {
      let name = cb.getStr("id", "")
      let unlockType = cb?.type ?? ""
      let unlockTypeId = get_unlock_type(unlockType)
      if (unlockTypeId != UNLOCKABLE_MEDAL || !isUnlockVisible(cb) || isBattleTask(cb))
        continue

      let country = cb.getStr("country", "")
      if (country == "")
        continue
      if (cb?.hideUntilUnlocked && !this.isMedalUnlocked(name))
        continue

      let item = {
        id = name
        tag = "imgSelectable"
        unlocked = this.isMedalUnlocked(name)
        image = getUnlockableMedalImage(name, true)
        imgClass = "profileMedals"
        focusBorder = true
        searchName = utf8ToLower(loc($"{name}/name"))
        searchId = utf8ToLower(name)
        country
      }
      if (item.unlocked)
        totalReceived++

      if (!filterMedalsListFunc(item, this.medalNameFilter))
        continue

      if (country not in this.availableMedals)
        this.availableMedals[country] <- []
      this.availableMedals[country].append(item)
    }

    let totalReceivedObj = this.scene.findObject("total_received")
    totalReceivedObj.setValue(loc("profile/medals/totalReceived", { count = totalReceived }))
  }

  function isMedalUnlocked(name) {
    if (this.isOwnStats)
      return isUnlockOpened(name, UNLOCKABLE_MEDAL)

    if (this.player == null)
      return false

    return this.player?.unlocks.medal[name] != null
  }

  function getMedalCountries() {
    let countries = this.availableMedals
    return shopCountriesList.filter(@(c) countries?[c] != null)
  }

  function fillMedalsList() {
    this.showContent(this.availableMedals.len() > 0)

    if (this.availableMedals.len() == 0)
      return

    let view = { items = [] }
    let countries = this.getMedalCountries()

    local selectedIndex = 0

    foreach (country in countries) {
      let availableCountryMedals = this.availableMedals?[country] ?? []
      if (availableCountryMedals.len() == 0)
        continue
      let unlocked = availableCountryMedals.filter(@(v) v.unlocked).len()
      let total = availableCountryMedals.len()

      view.items.append({
        id = country,
        text = loc(getCountryOverride(country)),
        objects = format("text {text:t='%s'}", $"{unlocked}/{total}")
      })

      if ((this.selectedMedal?.country == null && profileCountrySq.get() == country) || this.selectedMedal?.country == country)
        selectedIndex = view.items.len() - 1
    }

    let data = handyman.renderCached("%gui/commonParts/shopFilter.tpl", view)
    let pageList = this.scene.findObject("medals_list")
    this.guiScene.replaceContentFromText(pageList, data, data.len(), this)
    pageList.setValue(selectedIndex)
  }

  function applyMedalFilter(obj) {
    clearTimer(this.applyFilterTimer)
    this.medalNameFilter = utf8ToLower(obj.getValue())
    if(this.medalNameFilter == "") {
      this.updateMedalsList()
      return
    }

    let applyCallback = Callback(@() this.updateMedalsList(), this)
    this.applyFilterTimer = setTimeout(0.8, @() applyCallback())
  }

  function onFilterCancel(filterObj) {
    if (filterObj.getValue() != "")
      filterObj.setValue("")
    else if (this.parent != null)
      this.guiScene.performDelayed(this.parent, this.parent.goBack)
  }

  function onMedalsCountrySelect(obj) {
    let index = obj.getValue()
    this.isPageFilling = true
    this.guiScene.setUpdatesEnabled(false, false)

    local view = { items = [] }
    let country = obj.getChild(index).id
    this.selectedMedal.country <- country
    if (country not in this.selectedMedal)
      this.selectedMedal[country] <- null

    view.items = this.availableMedals[country]
    local data = handyman.renderCached("%gui/commonParts/imgFrame.tpl", view)

    let medalsObj = this.scene.findObject("medals_zone")
    this.guiScene.replaceContentFromText(medalsObj, data, data.len(), this)
    this.guiScene.setUpdatesEnabled(true, true)

    local selectedIndex = 0
    let selectedMedalName = this.selectedMedal[country]
    if (selectedMedalName != null)
      selectedIndex = view.items.findindex(@(v)v.id == selectedMedalName) ?? 0

    if (medalsObj.getValue() != selectedIndex)
      medalsObj.setValue(selectedIndex)
    else
      this.onMedalSelect(medalsObj)
    this.isPageFilling = false
  }

  function onMedalSelect(obj) {
    let idx = obj.getValue()
    let itemObj = idx >= 0 && idx < obj.childrenCount() ? obj.getChild(idx) : null
    let name = checkObj(itemObj) && itemObj?.id
    let unlock = name && getUnlockById(name)
    if (!unlock)
      return

    let descObj = this.scene.findObject("medals_desc")
    if (!checkObj(descObj))
      return

    if (!this.isPageFilling)
      this.selectedMedal[this.selectedMedal.country] <- name

    let config = buildUnlockDesc(buildConditionsConfig(unlock))
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
    this.updateUnlockFav(name, descObj)
    this.guiScene.setUpdatesEnabled(true, true)

    this.saveSelectedMedals()
  }

  function updateUnlockFav(name, objDesc) {
    initUnlockFavInContainer(name, objDesc)
  }

  function unlockToFavorites(obj) {
    toggleUnlockFavButton(obj)
  }

  function showContent(visible) {
    showObjById("content", visible, this.scene)
    showObjById("empty_text", !visible, this.scene)
  }

  function onEventUnlocksCacheInvalidate(_p) {
    if (!isProfileReceived.get())
      return
    this.updateMedalsList()
  }

  function onEventRegionalUnlocksChanged(_p) {
    this.updateMedalsList()
  }

  function saveSelectedMedals() {
    saveLocalAccountSettings(SELECTED_MEDAL_SAVE_ID, this.selectedMedal)
  }

  function loadSelectedMedals() {
    let blk = loadLocalAccountSettings(SELECTED_MEDAL_SAVE_ID)
    if (blk == null) {
      this.selectedMedal = {}
      return
    }
    this.selectedMedal = copyParamsToTable(blk)
  }
}

gui_handlers.MedalsHandler <- MedalsHandler

return {
  openMedalsPage = @(params = {}) handlersManager.loadHandler(MedalsHandler, params)
}
