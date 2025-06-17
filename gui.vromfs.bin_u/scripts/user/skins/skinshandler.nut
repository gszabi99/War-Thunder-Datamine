from "%scripts/dagui_library.nut" import *
let DataBlock = require("DataBlock")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { getPlaneBySkinId } = require("%scripts/customization/skinUtils.nut")
let { getUnitName, getUnitCountry } = require("%scripts/unit/unitInfo.nut")
let { getDecoratorById } = require("%scripts/customization/decorCache.nut")
let { decoratorTypes } = require("%scripts/customization/types.nut")
let { toggleUnlockFavButton, initUnlockFavInContainer } = require("%scripts/unlocks/favoriteUnlocks.nut")
let { getUnlockCondsDescByCfg, getLocForBitValues, getUnlockMultDescByCfg, getUnlockMainCondDescByCfg,
  buildConditionsConfig } = require("%scripts/unlocks/unlocksViewModule.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { is_bit_set } = require("%sqstd/math.nut")
let { canStartPreviewScene } = require("%scripts/customization/contentPreview.nut")
let { openPopupFilter } = require("%scripts/popups/popupFilterWidget.nut")
let { getFiltersView, applyFilterChange, getSelectedFilters } = require("%scripts/user/skins/skinsFilter.nut")
let { setTimeout, clearTimer } = require("dagor.workcycle")
let { utf8ToLower } = require("%sqstd/string.nut")
let { initTree } = require("%scripts/user/skins/decoratorGroupsTree.nut")
let { getSkinsCache } = require("%scripts/user/skins/skinsCache.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings } = require("%scripts/clientState/localProfile.nut")

local skinsLocalization = null
const SELECTED_SKIN_SAVE_ID = "wnd/selectedSkin"

function filterSkinsListFunc(skin, nameFilter) {
  if (nameFilter != "") {
    let hasSubstring = (skin.searchSkinId.indexof(nameFilter) != null) ||
      skin.searchSkinName.indexof(nameFilter) != null
    if (!hasSubstring)
      return false
  }

  let selectedFilters = getSelectedFilters()

  let bought = selectedFilters.bought
  if (bought.len() > 0 && bought[0] != skin.isUnitBought)
    return false

  let ranks = selectedFilters.rank
  if (ranks.len() > 0 && !ranks.contains(skin.rank))
    return false
  return true
}

function getSkinName(skinId) {
  if (skinsLocalization == null) {
    skinsLocalization = DataBlock()
    skinsLocalization.load("config/skins_localization.blk")
  }
  return loc(skinsLocalization?[skinId] ?? skinId)
}

function getUnitParamsFromSkinId(skinId) {
  let res = { unitCountry = "", unitType = "" }
  let unit = getAircraftByName(getPlaneBySkinId(skinId))
  if (unit == null)
    return res

  res.unitCountry = getUnitCountry(unit)
  res.unitType = unit.unitType.armyId
  return res
}

local SkinsHandler = class (gui_handlers.BaseGuiHandlerWT) {
  wndType          = handlerType.CUSTOM
  sceneBlkName     = "%gui/profile/skinsPage.blk"

  parent = null
  openParams = null
  treeHandlerWeak = null
  skinsListObj = null
  skinsCache = null
  totalReceived = 0
  applyFilterTimer = null
  skinNameFilter = ""
  selectedCategory = ""
  selectedSkin = ""

  function initScreen() {
    this.skinsListObj = this.scene.findObject("skins_list")
    this.prepareSkins()
    let countReceived = this.totalReceived
    openPopupFilter({
      scene = this.scene.findObject("filter_nest")
      onChangeFn = this.onFilterChange.bindenv(this)
      filterTypesFn = @() getFiltersView(countReceived > 0)
      popupAlign = "bottom-center"
    })

    this.updateTotalReceived()
    this.loadSelectedSkin()
    this.applyOpenParams()
    this.createSkinsTree()
    this.updateSkinsTree()
  }

  function applyOpenParams() {
    if (this.openParams == null)
      return

    local initCountry = this.openParams.initCountry
    local initUnitType = this.openParams.initUnitType
    let initSkinId = this.openParams.initSkinId

    if (initCountry == "" && initUnitType == "" && initSkinId != "") {
      let { unitCountry, unitType } = getUnitParamsFromSkinId(initSkinId)
      initCountry = unitCountry
      initUnitType = unitType
    }

    if (initCountry == "")
      return

    this.selectedCategory = initUnitType == "" ? initCountry : $"{initCountry}/{initUnitType}"
    this.selectedSkin = initSkinId
  }

  function applySkinFilter(obj) {
    clearTimer(this.applyFilterTimer)
    this.skinNameFilter = obj.getValue()
    if(this.skinNameFilter == "") {
      this.updateSkinsTree()
      return
    }

    let applyCallback = Callback(@() this.updateSkinsTree(), this)
    this.applyFilterTimer = setTimeout(0.8, @() applyCallback())
  }

  function onFilterChange(objId, tName, value) {
    applyFilterChange(objId, tName, value)
    this.updateSkinsTree()
  }

  function updateTotalReceived() {
    let totalReceivedObj = this.scene.findObject("total_received")
    totalReceivedObj.setValue(loc("profile/skins/totalReceived", { count = this.totalReceived }))
  }

  function onFilterCancel(filterObj) {
    if (filterObj.getValue() != "")
      filterObj.setValue("")
    else if (this.parent != null)
      this.guiScene.performDelayed(this.parent, this.parent.goBack)
  }

  function prepareSkins() {
    if (this.skinsCache != null)
      return
    this.totalReceived = 0
    this.skinsCache = []
    let cachedSkins = getSkinsCache()
    foreach (skinId, skinData in cachedSkins) {
      let unitId = getPlaneBySkinId(skinId)
      let unitName = getUnitName(unitId)
      let skinName = getSkinName(skinId)
      if (!skinData.isVisible())
        continue

      this.skinsCache.append(skinData.__merge({
        unitName
        skinName
        searchSkinId = utf8ToLower(skinId)
        searchSkinName = utf8ToLower($"{unitName}{loc("ui/comma")}{skinName}")
      }))

      if (skinData.isUnlocked)
        this.totalReceived++
    }
  }

  function prepareSkinsTreeData(skins) {
    let tree = {}

    foreach (skin in skins) {
      let country = skin.country
      let unitType = skin.unitType

      if (country not in tree)
        tree[country] <- {}
      if (unitType not in tree[country])
        tree[country][unitType] <- { unitType, sortOrder = skin.sortOrder }
    }

    let treeData = []
    foreach (country in shopCountriesList) {
      if (country not in tree)
        continue

      treeData.append({
        id = country
        itemTag = "campaign_item"
        itemText = $"#{country}"
        isCollapsable = true
        hidden = false
      })

      let unitTypes = tree[country].values().sort(@(v1, v2) v1.sortOrder <=> v2.sortOrder)
      treeData.extend(unitTypes.map(@(unitType) {
        id = $"{country}/{unitType.unitType}"
        itemText = $"#mainmenu/{unitType.unitType}"
        hidden = false
      }))
    }

    return treeData
  }

  function createSkinsTree() {
    this.treeHandlerWeak = initTree({
      scene = this.scene.findObject("treeSkinsNest")
      treeData = this.prepareSkinsTreeData(this.skinsCache)
      selectCallback = Callback(@(id) this.onSkinsCategorySelect(id), this)
      prevSelected = this.selectedCategory
    })
  }

  function updateSkinsTree() {
    let nameFilter = utf8ToLower(this.skinNameFilter)
    let filteredSkins = this.skinsCache.filter(@(skin) filterSkinsListFunc(skin, nameFilter))
    this.showContent(filteredSkins.len() > 0)
    if (filteredSkins.len() == 0)
      return

    let treeData = []

    foreach (skin in filteredSkins) {
      let { country, unitType } = skin
      if (!treeData.contains(country))
        treeData.append(country)

      let category = $"{country}/{unitType}"
      if (!treeData.contains(category))
        treeData.append(category)
    }
    this.treeHandlerWeak?.update(treeData)
  }

  function onSkinsCategorySelect(id) {
    this.selectedCategory = id
    let nameFilter = utf8ToLower(this.skinNameFilter)

    let skins = this.skinsCache
      .filter(@(skin) (id == $"{skin.country}/{skin.unitType}") && filterSkinsListFunc(skin, nameFilter))
      .sort(@(v1, v2) v1.searchSkinName <=> v2.searchSkinName)

    let skinsView = []
    let selectedItem = { idx = 0, id = ""}
    foreach (idx, skin in skins) {
      skinsView.append(this.getSkinShortDesc(skin))
      if (skin.skinId == this.selectedSkin) {
        selectedItem.idx = idx
        selectedItem.id = skin.skinId
      }
    }

    this.guiScene.setUpdatesEnabled(false, false)
    let listItemsCount = this.skinsListObj.childrenCount()
    let needListItemsCount = skinsView.len()
    if (needListItemsCount > listItemsCount)
      this.guiScene.createMultiElementsByObject(this.skinsListObj, "%gui/skins/skinItem.blk", "skinsListItem", needListItemsCount - listItemsCount, this)

    for (local i = 0; i < this.skinsListObj.childrenCount(); i++) {
      let item = this.skinsListObj.getChild(i)
      if (i >= needListItemsCount) {
        item.show(false)
        continue
      }
      item["selected"] = "no"
      item.show(true)
      item.id = skinsView[i].id
      item.findObject("skinName").setValue(skinsView[i].skinName)
      item.findObject("imgLocked").show(!skinsView[i].isUnlocked)
    }
    this.guiScene.setUpdatesEnabled(true, true)

    if (selectedItem.idx == this.skinsListObj.getValue())
      this.onSkinSelect(this.skinsListObj)

    this.skinsListObj.setValue(selectedItem.idx)
    if (selectedItem.id != "")
      this.selectedSkin = selectedItem.id

    this.saveSelectedSkin()
  }

  function getSkinShortDesc(skin) {
    return {
      id = skin.skinId
      skinName = $"{skin.unitName}{loc("ui/comma")}{skin.isRare ? colorize(skin.rarityColor, skin.skinName) : skin.skinName}"
      isUnlocked = skin.isUnlocked
    }
  }

  function onSkinSelect(obj) {
    let index = obj.getValue()
    if ((index < 0) || (index >= obj.childrenCount()))
      return
    let skinId = obj.getChild(index).id
    this.selectedSkin = skinId
    let skin = this.getSkinById(skinId)
    if (skin == null)
      return

    this.fillSkinDescr(skin)
    this.saveSelectedSkin()
  }

  getSkinById = @(id) this.skinsCache.findvalue(@(v) v.skinId == id)

  function onSkinPreview(_obj) {
    let index = this.skinsListObj.getValue()
    let skinId = this.skinsListObj.getChild(index).id
    let decorator = getDecoratorById(skinId)
    if (decorator && canStartPreviewScene(true, true))
      this.guiScene.performDelayed(this, @() decorator.doPreview())
  }

  function fillSkinDescr(skin) {
    let name = skin.skinId
    let unlockBlk = getUnlockById(name)
    let config = unlockBlk ? buildConditionsConfig(unlockBlk) : null
    let progressData = config?.getProgressBarData()
    let canAddFav = !!unlockBlk
    let decorator = getDecoratorById(name)

    let skinView = {
      skinName = decorator.getName()
      image = config?.image ?? decoratorTypes.SKINS.getImage(decorator)
      unlocked = skin.isUnlocked
      skinDesc = this.getSkinDesc(decorator)
      unlockProgress = progressData?.value
      hasProgress = progressData?.show
      skinPrice = decorator.getCostText()
      mainCond = getUnlockMainCondDescByCfg(config, { showSingleStreakCondText = true })
      multDesc = getUnlockMultDescByCfg(config)
      conds = getUnlockCondsDescByCfg(config)
      conditions = this.getSubUnlocksView(config)
      canAddFav
    }

    this.guiScene.setUpdatesEnabled(false, false)
    let markUpData = handyman.renderCached("%gui/profile/profileSkins.tpl", skinView)
    let objDesc = showObjById("skin_desc", true, this.scene)
    this.guiScene.replaceContentFromText(objDesc, markUpData, markUpData.len(), this)

    if (canAddFav)
      initUnlockFavInContainer(name, objDesc)
    this.guiScene.setUpdatesEnabled(true, true)
  }

  function getSkinDesc(decor) {
    return "\n".join([
      decor.getDesc(),
      decor.getTypeDesc(),
      decor.getLocParamsDesc(),
      decor.getRestrictionsDesc(),
      decor.getLocationDesc(),
      decor.getTagsDesc()
    ], true)
  }

  function getSubUnlocksView(config) {
    if (!config)
      return null

    return getLocForBitValues(config.type, config.names)
      .map(function(name, i) {
        let isUnlocked = is_bit_set(config.curVal, i)
        let text = config?.compareOR && i > 0
          ? $"{loc("hints/shortcut_separator")}\n{name}"
          : name
        return {
          unlocked = isUnlocked ? "yes" : "no"
          text
        }
      })
  }

  function unlockToFavorites(obj) {
    toggleUnlockFavButton(obj)
  }

  function saveSelectedSkin() {
    saveLocalAccountSettings(SELECTED_SKIN_SAVE_ID, {
      category = this.selectedCategory
      skin = this.selectedSkin
    })
  }

  function loadSelectedSkin() {
    let blk = loadLocalAccountSettings(SELECTED_SKIN_SAVE_ID)
    if (blk == null)
      return

    this.selectedCategory = blk?.category
    this.selectedSkin = blk?.skin
  }

  function onEventItemsShopUpdate(_) {
    this.onSkinsCategorySelect(this.selectedCategory)
  }

  function showContent(visible) {
    showObjById("content", visible, this.scene)
    showObjById("empty_text", !visible, this.scene)
  }
}

gui_handlers.SkinsHandler <- SkinsHandler

return {
  openSkinsPage = @(params = {}) handlersManager.loadHandler(SkinsHandler, params)
}
