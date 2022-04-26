let { getTierWeaponsParams, getCustomWeaponryPresetView, editSlotInPreset
} = require("%scripts/weaponry/weaponryPresetsParams.nut")
let { addWeaponsFromBlk } = require("%scripts/weaponry/weaponryInfo.nut")
let { getWeaponItemViewParams } = require("%scripts/weaponry/weaponryVisual.nut")
let { openPopupList } = require("%scripts/popups/popupList.nut")
let { getStringWidthPx } = require("%scripts/viewUtils/daguiFonts.nut")
let { addCustomPreset } = require("%scripts/unit/unitWeaponryCustomPresets.nut")
let { clearBorderSymbols } = require("%sqstd/string.nut")

let validatePresetNameRegexp = regexp2(@"^|[;|\\<>]")
let validatePresetName = @(v) validatePresetNameRegexp.replace("", v)

let function openEditPresetName(name, okFunc) {
  ::gui_modal_editbox_wnd({
    title = ::loc("mainmenu/newPresetName")
    maxLen = 40
    value = name
    checkButtonFunc = @(value) value != null && clearBorderSymbols(value).len() > 0
    validateFunc = @(value) validatePresetName(value)
    okFunc
  })
}

::gui_handlers.EditWeaponryPresetsModal <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType              = handlerType.MODAL
  sceneTplName         = "%gui/weaponry/editWeaponryPresetModal"
  unit                 = null
  preset               = null
  presetNest           = null
  availableWeapons     = null
  favoriteArr          = null

  getSceneTplView = @() { presets = getPresetMarkup() }

  function initScreen() {
    presetNest = scene.findObject("presetNest")
    ::move_mouse_on_obj(presetNest.findObject("presetHeader_"))
  }

  function getPresetMarkup() {
    let weaponryItem = getWeaponItemViewParams("preset", unit, preset.weaponPreset).__update({
      presetTextWidth = "1@modPresetTextMaxWidth"
      tiersView = preset.tiersView.map(@(t) {
        tierId        = t.tierId
        img           = t?.img ?? ""
        tierTooltipId = !::show_console_buttons ? t?.tierTooltipId : null
        isActive      = t?.isActive || "img" in t
      })
    })
    return [{
      presetId = ""
      weaponryItem
    }]
  }

  function getWeaponsPopupView(parentObj, tierId, weaponsBlk) {
    let buttons = []
    let tierIdInt = tierId.tointeger()
    local weapons = {}
    foreach(wBlk in weaponsBlk)
      foreach(key, val in addWeaponsFromBlk({}, [wBlk], unit))
        weapons[key] <- (weapons?[key] ?? []).extend(val)

    let params = getTierWeaponsParams(weapons, tierIdInt)
    let curTier = preset.tiers?[tierIdInt]
    let curPresetId = curTier?.presetId ?? ""
    local maxWidth = 0
    foreach (p in params)
      maxWidth = ::max(maxWidth, getStringWidthPx(p.name, "fontMedium"))
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
      onClickCb  = ::Callback(@(obj) onWeaponChoose(obj), this)
    }
  }

  function getCurrenTierObj() {
    let presetObj = presetNest.findObject("tiersNest_")
    let value = ::get_obj_valid_index(presetObj)
    if (value < 0)
      return null

    let tierObj = presetObj.getChild(value)
    if (!tierObj?.isValid())
      return null

    return tierObj
  }

  function editPreset() {
    let tierObj = getCurrenTierObj()
    if (!isTierObj(tierObj))
      return
    // Preset tier
    let weaponsBlk = availableWeapons.filter(@(_) _?.tier == tierObj.tierId.tointeger())
    if (weaponsBlk.len() == 0)
      return

    let view = getWeaponsPopupView(tierObj, tierObj.tierId, weaponsBlk)
    if (view)
      openPopupList(view)
  }

  function onPresetRename() {
    let headerObj = presetNest.findObject("header_name_txt")
    let curPreset = preset
    let okFunc = function(newName) {
      curPreset.customNameText = newName
      if (headerObj?.isValid() ?? false)
        headerObj.setValue(newName)
    }
    openEditPresetName(preset.customNameText, okFunc)
  }

  function onWeaponChoose(obj) {
    let presetId = obj.id
    let tierId = obj.holderId.tointeger()
    let cb = ::Callback(function() {
      preset = getCustomWeaponryPresetView(unit, preset, favoriteArr, availableWeapons)
      updatePreset()
      ::move_mouse_on_obj(presetNest.findObject($"tier_{tierId}"))
    }, this)
    editSlotInPreset(preset, tierId, presetId, availableWeapons, cb)
  }

  function updateButtons() {
    if (!::show_console_buttons)
      return

    let tierObj = getCurrenTierObj()
    let isWeaponsAvailable = isTierObj(tierObj)
      && availableWeapons.filter(@(_) _?.tier == tierObj.tierId.tointeger()).len() > 0
    showSceneBtn("editTier", presetNest.findObject("tiersNest_").isHovered()
      && isWeaponsAvailable)
  }

  isTierObj = @(obj) obj != null && ("tierId" in obj)

  onTierClick = @() editPreset()
  onModItemDblClick = @() editPreset()
  onEditCurrentTier = @() editPreset()
  onPresetMenuOpen = @() editPreset()

  onPresetUnhover = @() updateButtons()
  onCellSelect = @() updateButtons()
  onModActionBtn = @() null
  onAltModAction = @() null
  onPresetSelect = @() null

  function onPresetSave() {
    addCustomPreset(unit, preset)
    base.goBack()
  }

  function updatePreset() {
    if (!presetNest?.isValid())
      return

    let data = ::handyman.renderCached("%gui/weaponry/weaponryPreset", {presets = getPresetMarkup()})
    guiScene.replaceContentFromText(presetNest, data, data.len(), this)
  }

  function goBack() {
    msgBox("question_save_preset", ::loc("msgbox/genericRequestDisard", { item = preset.customNameText }),
      [
        ["yes", base.goBack],
        ["cancel", function () {}]
      ], "cancel")
  }
}

let openEditWeaponryPreset = @(params) ::handlersManager.loadHandler(::gui_handlers.EditWeaponryPresetsModal, params)

return {
  openEditWeaponryPreset
  openEditPresetName
}
