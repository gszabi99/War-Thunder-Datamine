from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { loadFirearm } = require("%scripts/hangarModelLoadManager.nut")
let { getBranchDataByPath } = require("%scripts/utils/listTreeUtils.nut")
let { apply_human_skin } = require("unitCustomization")
let { hangar_is_model_loaded, hangar_focus_model, hangar_weapon_loaded} = require("hangar")
let { createSlotInfoPanel } = require("%scripts/slotInfoPanel.nut")
let { showedUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { getInfantrySkinsTree, saveInfantrySkinByPath, DEFAULT_SKINS, getRandomSkin, getApplyToAllState,
  sortSkinsFn, getTiersRangeOnLocation, getSavedSkinByPatchArr, saveInfantrySkin, parseSkinPathArr,
  getSeenListSubset, getSkinsSeenList, isSkinCanBeNew, getInfantrySkinOnLocation, getBranchName
} = require("%scripts/customization/infantryCamouflageStorage.nut")
let { convertFromTemplateName, getCamoNameById
} = require("%scripts/customization/infantryCamouflageUtils.nut")
let { lastIndexOf } = require("%sqstd/string.nut")
let bhvUnseen = require("%scripts/seen/bhvUnseen.nut")
let { calcBattleRatingFromRank } = require("%appGlobals/ranks_common_shared.nut")
let { findChildIndex } = require("%sqDagui/daguiUtil.nut")

const TEAMS_COUNT = 2


let getLocationLocId = @(locationName) $"location/hvg_{locationName}"

let selectedState = {
  locationBlkName = "", tierIndex = 0, userSelectedTier = 0, team = 1
}

let tierButtonsTemplate =
@"infantryBlockBtn {
  id:t='{id}'
  width:t='pw/{btnsCount}'
  on_click:t='onTierBtnClick'
  tier:t='{tier}'
  isSelected:t='{isSelected}'
  label {
    id:t='label'
    text:t='{label}'
  }
  infantryUnseenIcon {
    id:t='unseen_tier_{tier}'
    pos:t='pw - w - 3@sf/@pf, (ph-h)/2'
    value:t='{unseenValue}'
  }
}"

gui_handlers.InfantryCamouflageHandler <- class (gui_handlers.BaseGuiHandlerWT) {
  sceneBlkName = "%gui/customization/customizationInfantry.blk"
  unit = null
  unitInfoPanelWeak = null
  needForceShowUnitInfoPanel = false
  skinListTree = null
  isLoadingRot = null
  lastSelectedSkin = ""
  tiersRange = null

  function initScreen() {
    this.unit = showedUnit.get()
    if (!this.unit)
      return this.goBack()

    this.scene.findObject("timer_update").setUserData(this)
    hangar_focus_model(true)

    let unitInfoPanel = createSlotInfoPanel(this.scene,
      {showTabs = false, configSaveId = "infantry_camouflage", showButtons = ["btnChangeFirearm"]})
    this.registerSubHandler(unitInfoPanel)
    this.unitInfoPanelWeak = unitInfoPanel.weakref()
    if (this.needForceShowUnitInfoPanel)
      this.unitInfoPanelWeak.uncollapse()

    loadFirearm(this.unit.name)
    this.guiScene.setCursor("normal", true)
    this.updateSkinList()
  }

  function updateSkinList() {
    this.skinListTree = getInfantrySkinsTree()

    let view = {
      optionTag = "option"
      options = []
    }
    local selIdx = 0
    local locationIndex = 0
    let seenList = getSkinsSeenList()
    let locationsList = []
    foreach (locationBlkName, _branch in this.skinListTree.branches) {
      let locationName = convertFromTemplateName.location(locationBlkName)
      locationsList.append(locationName)
      if (selectedState.locationBlkName == "")
        selectedState.locationBlkName = locationBlkName
      if (selectedState.locationBlkName == locationBlkName)
        selIdx = locationIndex
      view.options.append({
        text = loc(getLocationLocId(locationName))
        optName = locationBlkName
        enabled = true
        unseenValue = bhvUnseen.makeConfigStr("infantry_camouflage", locationName)
      })
      locationIndex++
      seenList.setSubListGetter(locationName, @() getSeenListSubset(seenList, locationName))
    }

    let locationsBox = this.scene.findObject("locations_box")
    local data = handyman.renderCached(("%gui/customization/infantryLocationListItem.tpl"), view)
    this.guiScene.replaceContentFromText(locationsBox, data, data.len(), this)

    locationsBox.setValue(selIdx)
    this.updateTierButtons()
  }

  function showLoadingRot(flag) {
    if (this.isLoadingRot == flag)
      return

    this.isLoadingRot = flag
    this.scene.findObject("loading_rot").show(flag)
  }

  function onUpdate(_obj, _dt) {
    this.showLoadingRot(!hangar_is_model_loaded() && !hangar_weapon_loaded())
  }

  function sortSkins(branches) {
    if ((branches?.len() ?? 0) == 0)
      return branches

    return branches
      .values()
      .sort(sortSkinsFn)
  }

  function onSkinRadioBtnClick(radioBtnObj) {
    let branchObj = radioBtnObj.getParent()
    this.checkSkinByPath(branchObj.id)
  }

  function checkSkinByPath(path) {
    let parentPath = path.slice(0, lastIndexOf(path, "/"))
    let skinList = this.scene.findObject("teams_skins")

    let branchData = getBranchDataByPath(this.skinListTree, parentPath)
    local skinObj = null
    local radioBtn = null
    foreach (skinData in branchData.branches) {
      let isSkinChecked = getSavedSkinByPatchArr(skinData.path.split("/"), this.unit.name)
      if (!isSkinChecked)
        continue
      skinObj = skinList.findObject(skinData.path)
      radioBtn = skinObj?.findObject("radio_button")
      if (skinObj == null || radioBtn == null)
        continue
      radioBtn.isChecked = "no"
    }
    skinObj = skinList.findObject(path)
    radioBtn = skinObj.findObject("radio_button")
    radioBtn.isChecked = "yes"
    saveInfantrySkinByPath(path, this.unit.name)

    let {location, team, tier} = parseSkinPathArr(path.split("/"))
    let applyToAllState = getApplyToAllState(location, team, tier)
    if (!applyToAllState)
      this.updateApplyToAllButtons()
  }

  function fillSkins(skinsData, teamIndex) {
    let skins = this.sortSkins(skinsData)
    let unitName = this.unit.name
    let view = { items = skins.map(@(s) {
      skinId = s.id,
      id = s.path,
      label = getCamoNameById(s.id),
      isChecked = getSavedSkinByPatchArr(s.path.split("/"), unitName) == s.id ? "yes" : "no"
      unseenValue = isSkinCanBeNew(s.id)
        ? bhvUnseen.makeConfigStr("infantry_camouflage", s.path)
        : null
    })}
    let data = handyman.renderCached("%gui/customization/infantrySkinListItem.tpl", view)
    let teamObj = this.scene.findObject($"team_{teamIndex}_skins")
    this.guiScene.replaceContentFromText(teamObj, data, data.len(), this)
  }

  function updateSelectedSkin() {
    let location = convertFromTemplateName.location(selectedState.locationBlkName)
    let tier = this.getTierByTierIndex(selectedState.tierIndex)
    let team = selectedState.team
    let skin = getInfantrySkinOnLocation(location, team, tier, this.unit.name)

    local branchName = getBranchName(location, team, tier)
    branchName = $"{branchName}/{skin}"
    let skinObj = this.scene.findObject(branchName)
    if (!skinObj)
      return
    let listObj = skinObj.getParent()
    let idx = findChildIndex(listObj, @(child) child.id == skinObj.id)
    listObj.setValue(idx)
  }

  function updateSkinsList() {
    let locationData =  this.skinListTree.branches[selectedState.locationBlkName]
    let selectedTier = this.getTierByTierIndex(selectedState.tierIndex)
    foreach (teamId, teamData in locationData.branches)
      foreach (tierId, tierData in teamData.branches) {
        let tier = convertFromTemplateName.tier(tierId)
        if (selectedTier == tier) {
          this.fillSkins(tierData.branches, convertFromTemplateName.team(teamId))
          break
        }
      }

    this.updateApplyToAllButtons()
  }

  function selectLocation(locationBlkName) {
    if (this.skinListTree.branches?[locationBlkName] == null)
      return
    selectedState.locationBlkName = locationBlkName
    this.fillTiersButtons()
    this.updateSkinsList()
    this.updateSelectedSkin()
  }

  function onLocationBox(locationBox) {
    let index = locationBox.getValue()
    if (index == null)
      return
    let item = locationBox.getChild(index)
    this.selectLocation(item.optName)
  }

  function getTierByTierIndex(tierIndex) {
    return this.tiersRange?[tierIndex] ?? -1
  }

  function onSkinListSelect(skinList) {
    let index = skinList.getValue()
    if (index == null)
      return
    let team = to_integer_safe(skinList.team, 1)
    selectedState.team = team
    let skinItem = skinList.getChild(index)
    this.selectSkinByPath(skinItem.id)
  }

  function selectSkinByPath(skinPath) {
    if (this.lastSelectedSkin != "" && skinPath != this.lastSelectedSkin) {
      let lastSelectedObj = this.scene.findObject(this.lastSelectedSkin)
      if (lastSelectedObj?.selected == "yes")
        lastSelectedObj.selected = "no"
    }
    this.lastSelectedSkin = skinPath
    let pathArr = skinPath.split("/")
    let {location, tier, team, skin} = parseSkinPathArr(pathArr)

    let isRandomNotDefault = skin == DEFAULT_SKINS.randomNotDefault
    let skinName = skin == DEFAULT_SKINS.random || isRandomNotDefault
      ? getRandomSkin(location, team, tier, isRandomNotDefault)
      : skin

    let seenList = getSkinsSeenList()
    seenList.setSeen(skinPath, true)
    apply_human_skin(skinName, pathArr[0], tier, team)
  }

  function updateTierButtons() {
    let tiersCount = this.tiersRange.len()
    for (local i = 0; i < tiersCount; i++) {
      let btn = this.scene.findObject($"btn_tier_{i}")
      btn.isSelected = selectedState.tierIndex == i ? "yes" : "no"
    }
  }

  function getBrByTierIndex(tierIndex) {
    let tier = this.tiersRange[tierIndex]
    let nextTier = (this.tiersRange?[tierIndex+1] ?? 0)
    let minBr = calcBattleRatingFromRank(tier)
    let maxBr = calcBattleRatingFromRank(nextTier)
    return "".concat(minBr, nextTier > 0 ? $"-{maxBr}" : "+")
  }

  function fillTiersButtons() {
    this.tiersRange = getTiersRangeOnLocation(selectedState.locationBlkName)

    let btnsCount = this.tiersRange.len()
    local curTierIndex = btnsCount - 1
    foreach (idx, tier in this.tiersRange)
      if (tier >= selectedState.userSelectedTier)
        curTierIndex = idx - 1

    selectedState.tierIndex = curTierIndex > 0 ? curTierIndex : 0
    let seenList = getSkinsSeenList()
    let locationName = convertFromTemplateName.location(selectedState.locationBlkName)

    let tiersButtons = []
    for (local i = 0; i < btnsCount; i++) {
      let id = $"btn_tier_{i}"
      let label = this.getBrByTierIndex(i)
      let tier = this.tiersRange[i]
      let isSelected = i == selectedState.tierIndex ? "yes" : "no"
      let subsetName = $"{locationName}/tier_{tier}"
      seenList.setSubListGetter(subsetName, @() getSeenListSubset(seenList, locationName, tier))
      tiersButtons.append(tierButtonsTemplate.subst({id, btnsCount, tier = i, isSelected, label,
        unseenValue = bhvUnseen.makeConfigStr("infantry_camouflage", subsetName)
      }))
    }
    let markup = "".join(tiersButtons)
    let tiers_container = this.scene.findObject("tiers_container")
    this.guiScene.replaceContentFromText(tiers_container, markup, markup.len(), this)
  }

  function onTierBtnClick(btn) {
    let tierIndex = btn.tier
    selectedState.tierIndex = to_integer_safe(tierIndex)
    let minTier = this.tiersRange?[selectedState.tierIndex] ?? 0
    let maxTier = this.tiersRange?[selectedState.tierIndex + 1] ?? (minTier + 1)
    selectedState.userSelectedTier = maxTier
    this.updateTierButtons()
    this.updateSkinsList()
    this.updateSelectedSkin()
  }

  function onApplyToAllClick(btn) {
    if (btn.isSelected == "yes")
      return

    let location = convertFromTemplateName.location(selectedState.locationBlkName)
    let team = loc(btn.team == "1" ? "events/teamA" : "events/teamB")
    let tier = this.getTierByTierIndex(selectedState.tierIndex)
    let skin = getInfantrySkinOnLocation(location, btn.team, tier, this.unit.name)
    let teamIndex = btn.team

    let handler = this
    let br = this.getBrByTierIndex(selectedState.tierIndex)
    scene_msg_box("chest_exchange", null,
      loc("msgbox/applyToAllInfantrySkins",
      {skin = getCamoNameById(skin), team, br, location = loc(getLocationLocId(location))}),
      [
        [ "yes", @() handler.applyToAll(teamIndex) ],
        [ "no" ]
      ], "yes"
    )
  }

  function applyToAll(team) {
    let location = convertFromTemplateName.location(selectedState.locationBlkName)
    let tier = this.getTierByTierIndex(selectedState.tierIndex)
    let skin = getInfantrySkinOnLocation(location, team, tier, this.unit.name)
    saveInfantrySkin(skin, location, team, tier)
    this.updateApplyToAllButtons()
  }

  function updateApplyToAllButtons() {
    let location = convertFromTemplateName.location(selectedState.locationBlkName)
    let tier = this.getTierByTierIndex(selectedState.tierIndex)
    for (local i = 0; i < TEAMS_COUNT; i++) {
      let btn = this.scene.findObject($"apply_to_all_{i+1}")
      btn.isSelected = getApplyToAllState(location, i+1, tier) ? "yes" : "no"
    }
  }

  function onPresentationAnim(_btn) {}
  function onScreenClick(_btn) {}

  function onBtnBack() {
    return this.goBack()
  }

}
