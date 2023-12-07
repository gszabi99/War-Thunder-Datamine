//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { getObjValidIndex } = require("%sqDagui/daguiUtil.nut")
let regexp2 = require("regexp2")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { move_mouse_on_obj, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getCustomWeaponryPresetView, editSlotInPreset, getPresetWeightRestrictionText, getTierIcon
} = require("%scripts/weaponry/weaponryPresetsParams.nut")
let { addWeaponsFromBlk } = require("%scripts/weaponry/weaponryInfo.nut")
let { getWeaponItemViewParams } = require("%scripts/weaponry/weaponryVisual.nut")
let { openPopupList } = require("%scripts/popups/popupList.nut")
let { getStringWidthPx } = require("%scripts/viewUtils/daguiFonts.nut")
let { addCustomPreset, isPresetChanged } = require("%scripts/unit/unitWeaponryCustomPresets.nut")
let { clearBorderSymbols } = require("%sqstd/string.nut")
let { round_by_value } = require("%sqstd/math.nut")
let validatePresetNameRegexp = regexp2(@"^|[;|\\<>]")
let validatePresetName = @(v) validatePresetNameRegexp.replace("", v)
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")

const MASS_KG_PRESIZE = 0.1

let function openEditPresetName(name, okFunc) {
  ::gui_modal_editbox_wnd({
    title = loc("mainmenu/newPresetName")
    maxLen = 40
    value = name
    checkButtonFunc = @(value) value != null && clearBorderSymbols(value).len() > 0
    validateFunc = @(value) validatePresetName(value)
    okFunc
  })
}

let class EditWeaponryPresetsModal (gui_handlers.BaseGuiHandlerWT) {
  wndType              = handlerType.MODAL
  sceneTplName         = "%gui/weaponry/editWeaponryPresetModal.tpl"
  unit                 = null
  preset               = null
  originalPreset       = null
  presetNest           = null
  availableWeapons     = null
  favoriteArr          = null
  unitBlk              = null

  getSceneTplView = @() { presets = this.getPresetMarkup() }
  getKgUnitsText = @(val, addMeasureUnits = true) ::g_measure_type.getTypeByName("kg", addMeasureUnits).getMeasureUnitsText(round_by_value(val, MASS_KG_PRESIZE))

  function initScreen() {
    this.scene.findObject("edit_wnd").width = "{0}@tierIconSize + 1@modPresetTextMaxWidth + 2@blockInterval".subst(this.originalPreset.weaponsSlotCount)
    this.unitBlk = ::get_full_unit_blk(this.unit.name)
    this.checkWeightRestrictions()
    this.updateWeightCapacityText()
    this.presetNest = this.scene.findObject("presetNest")
    move_mouse_on_obj(this.presetNest.findObject("presetHeader_"))
  }

  function getPresetMarkup() {
    let weaponryItem = getWeaponItemViewParams("preset", this.unit, this.preset.weaponPreset).__update({
      presetTextWidth = "1@modPresetTextMaxWidth"
      tiersView = this.preset.tiersView.map(@(t) {
        tierId        = t.tierId
        img           = t?.img ?? ""
        tierTooltipId = !showConsoleButtons.value ? t?.tierTooltipId : null
        isActive      = t?.isActive || "img" in t
      })
    })
    return [{
      presetId = ""
      weaponryItem
    }]
  }

  function getPopupWeaponsList(weaponsBlk) {
    let res = []
    let weapons = {}
    foreach (wBlk in weaponsBlk)
      foreach (key, val in (addWeaponsFromBlk({}, [wBlk], this.unit)?.weaponsByTypes ?? {}))
        weapons[key] <- (weapons?[key] ?? []).extend(val)
    foreach (triggerType, triggers in weapons)
      foreach (weapon in triggers)
        foreach (id, inst in weapon.weaponBlocks)
          res.append(inst.__merge({ id = id, tType = triggerType }))
    return res
  }

  function getPopupItemName(weapon) {
    let { massKg, additionalMassKg, ammo } = weapon
    let nameText = loc($"weapons/{weapon.id}")

    let countStr = $"{loc("shop/ammo")}{loc("ui/colon")}{ammo}"
    let weightStr = $"{loc("shop/tank_mass")} {this.getKgUnitsText(additionalMassKg + massKg * (ammo || 1))}" // for containers ammo == 0 but we should count the mass
    let detailsStr = !ammo
      ? weightStr
      : $"{countStr}{loc("ui/comma")}{weightStr}"

    return "".concat(
      nameText,
      loc("ui/parentheses/space", { text = detailsStr })
    )
  }

  function getWeaponsPopupParams(weapons, tierId) {
    let res = []
    foreach (weapon in weapons) {
      let tierWeaponConfig = weapon.__merge({
        iconType = weapon.tiers?[tierId].iconType ?? weapon.iconType
      })
      let dubIdx = res.findindex(@(v) v.presetId == weapon.presetId)
      if (dubIdx != null) {
        res[dubIdx].name = "".concat(res[dubIdx].name, loc("ui/comma"),
          this.getPopupItemName(weapon))
        continue
      }

      res.append({
        id = weapon.tiers?[tierId].presetId ?? weapon.id
        presetId = weapon.presetId // To find duplicates
        name = this.getPopupItemName(weapon)
        img = getTierIcon(tierWeaponConfig, weapon.ammo)
      })
    }
    return res
  }

  function getWeaponsPopupView(parentObj, tierId, weaponsBlk) {
    let buttons = []
    let tierIdInt = tierId.tointeger()
    let weapons = this.getPopupWeaponsList(weaponsBlk)
    let params = this.getWeaponsPopupParams(weapons, tierIdInt)
    let curTier = this.preset.tiers?[tierIdInt]
    let curPresetId = curTier?.presetId ?? ""
    local maxWidth = 0
    foreach (p in params)
      maxWidth = max(maxWidth, getStringWidthPx(p.name, "fontMedium"))
    foreach (p in params)
      if (p.id != curPresetId)
        buttons.append({
          id = p.id
          holderId = tierId
          image = p.img
          funcName = "onItemClick"
          buttonClass = "image"
          visualStyle = "noFrame"
          text = p.name
          btnWidth = maxWidth
        })
    if (curTier != null)
      buttons.append({
        id = ""
        holderId = tierId
        image = "#ui/gameuiskin#btn_close.svg"
        funcName = "onItemClick"
        buttonClass = "image"
        visualStyle = "noFrame"
        text = "#ui/empty"
        btnWidth = maxWidth
      })

    return {
      buttonsList = buttons
      parentObj = parentObj
      onClickCb  = Callback(@(obj) this.onWeaponChoose(obj), this)
      clickPropagation = true
    }
  }

  function getCurrenTierObj() {
    let presetObj = this.presetNest.findObject("tiersNest_")
    let value = getObjValidIndex(presetObj)
    if (value < 0)
      return null

    let tierObj = presetObj.getChild(value)
    if (!tierObj?.isValid())
      return null

    return tierObj
  }

  function editPreset() {
    let tierObj = this.getCurrenTierObj()
    if (!this.isTierObj(tierObj))
      return
    // Preset tier
    let weaponsBlk = this.availableWeapons.filter(@(w) w?.tier == tierObj.tierId.tointeger())
    if (weaponsBlk.len() == 0)
      return

    let view = this.getWeaponsPopupView(tierObj, tierObj.tierId, weaponsBlk)
    if (view)
      openPopupList(view)
  }

  function onPresetRename() {
    let headerObj = this.presetNest.findObject("header_name_txt")
    let curPreset = this.preset
    let okFunc = function(newName) {
      curPreset.customNameText = newName
      if (headerObj?.isValid() ?? false)
        headerObj.setValue(newName)
    }
    openEditPresetName(this.preset.customNameText, okFunc)
  }

  function chooseWeapon(tierId, presetId, isForced = false) {
    let cb = Callback(function() {
      if (!this.isValid())
        return
      this.preset = getCustomWeaponryPresetView(this.unit, this.preset, this.favoriteArr, this.availableWeapons)
      this.updatePreset()
      this.checkWeightRestrictions()
      this.updateWeightCapacityText()
      move_mouse_on_obj(this.presetNest.findObject($"tier_{tierId}"))
    }, this)
    editSlotInPreset(this.preset, tierId, presetId, this.availableWeapons, this.unit, this.favoriteArr, cb, isForced)
  }

  onWeaponChoose = @(obj) this.chooseWeapon(obj.holderId.tointeger(), obj.id)

  function updateButtons() {
    if (!showConsoleButtons.value)
      return

    let tierObj = this.getCurrenTierObj()
    let isWeaponsAvailable = this.isTierObj(tierObj)
      && this.availableWeapons.filter(@(w) w?.tier == tierObj.tierId.tointeger()).len() > 0
    this.showSceneBtn("editTier", this.presetNest.findObject("tiersNest_").isHovered()
      && isWeaponsAvailable)
  }

  isTierObj = @(obj) obj != null && ("tierId" in obj)

  onTierClick = @() this.editPreset()
  onModItemDblClick = @() this.editPreset()
  onEditCurrentTier = @() this.editPreset()
  onPresetMenuOpen = @() this.editPreset()

  onPresetUnhover = @() this.updateButtons()
  onCellSelect = @() this.updateButtons()
  onModActionBtn = @() null
  onAltModAction = @() null
  onPresetSelect = @() null

  function savePreset() {
    let restrictionsText = getPresetWeightRestrictionText(this.preset, this.unitBlk)
    if (restrictionsText != "") {
      showInfoMsgBox($"{loc("msg/can_not_save_preset")}\n{restrictionsText}", "can_not_save_disbalanced_preset")
      return
    }

    addCustomPreset(this.unit, this.preset)
  }

  function onPresetSave() {
    this.savePreset()
    base.goBack()
  }

  function updatePreset() {
    let data = handyman.renderCached("%gui/weaponry/weaponryPreset.tpl", { presets = this.getPresetMarkup() })
    this.guiScene.replaceContentFromText(this.presetNest, data, data.len(), this)
  }

  function goBack() {
    if (!isPresetChanged(this.originalPreset, this.preset))
      return base.goBack()

    this.msgBox("question_save_preset", loc("msgbox/genericRequestDisard", { item = this.preset.customNameText }),
      [
        ["yes", base.goBack],
        ["cancel", function () {}]
      ], "cancel")
  }

  function checkWeightRestrictions() {
    let restrictionsText = getPresetWeightRestrictionText(this.preset, this.unitBlk)
    this.scene.findObject("weightDisbalance").setValue(restrictionsText)
    this.scene.findObject("savePreset").inactiveColor = restrictionsText != "" ? "yes" : "no"
  }

  function updateWeightCapacityText() {
    this.scene.findObject("weightCapacity").setValue(this.getWeightCapacityText())
  }

  function getWeightCapacityText() {
    let maxWeight = this.unitBlk?.WeaponSlots?.maxloadMass
    if (maxWeight == null)
      return ""
    let totalWeightStr = this.getKgUnitsText(this.getTotalWeight(), false)
    let maxWeightStr = this.getKgUnitsText(maxWeight)

    return $"{loc("shop/tank_mass")} {totalWeightStr}{loc("ui/slash")}{maxWeightStr}"
  }

  function getTotalWeight() {
    return this.preset.tiersView.reduce(function(tatoalWeight, tier, idx) {
      let { additionalMassKg = 0.0 } = tier?.weaponry.tiers[idx]
      let { amountPerTier = 1.0 } = tier?.weaponry.tiers[idx]
      let { massKg = 0.0 } = tier?.weaponry
      return tatoalWeight + additionalMassKg + amountPerTier * massKg
    }, 0)
  }
}

gui_handlers.EditWeaponryPresetsModal <- EditWeaponryPresetsModal

let openEditWeaponryPreset = @(params) handlersManager.loadHandler(EditWeaponryPresetsModal, params)

return {
  openEditWeaponryPreset
  openEditPresetName
  EditWeaponryPresetsModal
}
