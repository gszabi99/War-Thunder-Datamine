//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let weaponryPresetsModal = require("%scripts/weaponry/weaponryPresetsModal.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { move_mouse_on_child_by_value, move_mouse_on_obj, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { ceil, sqrt } = require("math")
let { setPopupMenuPosAndAlign } = require("%sqDagui/daguiUtil.nut")
let { updateModItem, createModItemLayout } = require("%scripts/weaponry/weaponryVisual.nut")
let { getLastWeapon, setLastWeapon, isWeaponVisible, isWeaponEnabled, isDefaultTorpedoes,
  needSecondaryWeaponsWnd } = require("%scripts/weaponry/weaponryInfo.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { isInFlight } = require("gameplayBinding")
let { getCurMissionRules } = require("%scripts/misCustomRules/missionCustomState.nut")

/*
  config = {
    unit  //unit for weapons
    onChangeValueCb = function(chosenWeaponryItem)   //callback on value select (only if value was changed)
    weaponItemParams = null //list of special items render params (for weaponVisual::updateItem)

    align = "top"/"bottom"/"left"/"right"
    alignObj = DaguiObj  //object to align menu

    list = [
      {
        //must have parameter:
        weaponryItem //weapon or modification from unit

        //optional parameters:
        selected = false
        enabled = true
        visualDisabled = false
      }
      ...
    ]
  }
*/
function guiStartWeaponrySelectModal(config) {
  handlersManager.loadHandler(gui_handlers.WeaponrySelectModal, config)
}

local CHOOSE_WEAPON_PARAMS = {
  itemParams = null
  alignObj = null
  align = "bottom"
  isForcedAvailable = false
  setLastWeapon = @(unitName, weaponName) setLastWeapon(unitName, weaponName)
  getLastWeapon = @(unitName) getLastWeapon(unitName)
}
function guiStartChooseUnitWeapon(unit, cb, params = CHOOSE_WEAPON_PARAMS) {
  params = CHOOSE_WEAPON_PARAMS.__merge(params)

  let curWeaponName = params.getLastWeapon(unit.name)
  let hasOnlySelectable = !isInFlight() || !getCurMissionRules().isWorldWar
  let isForcedAvailable = params.isForcedAvailable
  let forceShowDefaultTorpedoes = params?.forceShowDefaultTorpedoes ?? false
  let onChangeValueCb = function(weapon) {
    params.setLastWeapon(unit.name, weapon.name)
    cb?(unit.name, weapon.name)
  }

  let list = []
  foreach (weapon in unit.getWeapons()) {
    let needShowDefTorpedoes = forceShowDefaultTorpedoes && isDefaultTorpedoes(weapon)
    if (!isForcedAvailable && !needShowDefTorpedoes
        && (!isWeaponVisible(unit, weapon, hasOnlySelectable)
          || (hasOnlySelectable && !isWeaponEnabled(unit, weapon))))
      continue

    list.append({
      weaponryItem = weapon
      selected = curWeaponName == weapon.name
      enabled = isForcedAvailable || needShowDefTorpedoes || isWeaponEnabled(unit, weapon)
    })
  }

  if (needSecondaryWeaponsWnd(unit))
    weaponryPresetsModal.open({ //open modal menu for air and helicopter only
        unit = unit
        chooseMenuList   = list
        initLastWeapon   = curWeaponName
        weaponItemParams = params.itemParams
        onChangeValueCb  = onChangeValueCb
      })
  else
    guiStartWeaponrySelectModal({
      unit = unit
      list = list
      weaponItemParams = params.itemParams
      alignObj = params.alignObj
      align = params.align
      onChangeValueCb = onChangeValueCb
    })
}

gui_handlers.WeaponrySelectModal <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType      = handlerType.MODAL
  sceneTplName = "%gui/weaponry/weaponrySelectModal.tpl"
  needVoiceChat = false

  unit = null
  list = null
  currentValue = null
  weaponItemParams = null
  onChangeValueCb = null

  align = "bottom"
  alignObj = null

  rowsToClumnsProportion = 3

  wasSelIdx = 0
  selIdx = 0

  function getSceneTplView() {
    if (!this.unit || !this.list)
      return null

    let cols = ceil(sqrt(this.list.len().tofloat() / this.rowsToClumnsProportion)).tointeger()
    let rows = cols ? ceil(this.list.len().tofloat() / cols).tointeger() : 0

    this.wasSelIdx = -1
    let params = { posX = 0, posY = 0 }
    local weaponryListMarkup = ""
    foreach (idx, config in this.list) {
      let weaponryItem = getTblValue("weaponryItem", config)
      if (!weaponryItem) {
        script_net_assert_once("cant load weaponry",
                                "Error: empty weaponryItem for WeaponrySelectModal. unit = " + (this.unit && this.unit.name))
        this.list = null //goback
        return null
      }

      if (getTblValue("selected", config))
        this.wasSelIdx = idx

      params.posX = rows ? (idx / rows) : 0
      params.posY = rows ? (idx % rows) : 0
      weaponryListMarkup += createModItemLayout(idx, this.unit, weaponryItem, weaponryItem.type, params)
    }

    this.selIdx = max(this.wasSelIdx, 0)
    let res = {
      weaponryList = weaponryListMarkup
      columns = cols
      rows = rows
      value = this.selIdx
    }
    return res
  }

  function initScreen() {
    if (!this.list || !this.unit)
      return this.goBack()

    this.align = setPopupMenuPosAndAlign(this.alignObj, this.align, this.scene.findObject("main_frame"))
    this.updateItems()
    this.updateOpenAnimParams()
    move_mouse_on_child_by_value(this.scene.findObject("weapons_list"))
  }

  function updateItems() {
    let listObj = this.scene.findObject("weapons_list")
    let total = min(this.list.len(), listObj.childrenCount())
    for (local i = 0; i < total; i++) {
      let config = this.list[i]
      let itemObj = listObj.getChild(i)
      let enabled = getTblValue("enabled", config, true)
      itemObj.enable(enabled)

      this.weaponItemParams.visualDisabled <- !enabled || getTblValue("visualDisabled", config, false)
      updateModItem(this.unit, config.weaponryItem, itemObj, false, this, this.weaponItemParams)
    }
    this.weaponItemParams.visualDisabled <- false
  }

  function updateOpenAnimParams() {
    let animObj = this.scene.findObject("anim_block")
    if (!animObj)
      return
    let size = animObj.getSize()
    if (!size[0] || !size[1])
      return

    local scaleId = "height"
    local scaleAxis = 1
    if (this.align == "left" || this.align == "right") {
      scaleId = "width"
      scaleAxis = 0
    }

    animObj[scaleId] = "1"
    animObj[scaleId + "-base"] = "1"
    animObj[scaleId + "-end"] = size[scaleAxis].tostring()
  }

  function onChangeValue(obj) {
    this.selIdx = obj.getValue()
    this.goBack()
  }

  function onModItemClick(obj) {
    let idx = to_integer_safe(obj?.holderId, -1)
    if (idx < 0)
      return
    this.selIdx = idx
    this.goBack()
  }

  function afterModalDestroy() {
    if (this.alignObj?.isValid())
      move_mouse_on_obj(this.alignObj)

    if (this.selIdx == this.wasSelIdx
        || !(this.selIdx in this.list)
        || !this.onChangeValueCb)
      return
    this.onChangeValueCb(getTblValue("weaponryItem", this.list[this.selIdx]))
  }
}

return {
  guiStartChooseUnitWeapon
  guiStartWeaponrySelectModal
}