from "%scripts/dagui_library.nut" import *
from "%scripts/dagui_natives.nut" import shop_get_spawn_score
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let guiStartWeaponryPresets = require("%scripts/weaponry/guiStartWeaponryPresets.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { setPopupMenuPosAndAlign, move_mouse_on_child_by_value, move_mouse_on_obj
} = require("%sqDagui/daguiUtil.nut")
let { ceil, sqrt } = require("math")
let { updateModItem, createModItemLayout } = require("%scripts/weaponry/weaponryVisual.nut")
let { getLastWeapon, setLastWeapon, isWeaponVisible, isWeaponEnabled, isDefaultTorpedoes,
  needSecondaryWeaponsWnd } = require("%scripts/weaponry/weaponryInfo.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { isInFlight } = require("gameplayBinding")
let { getCurMissionRules } = require("%scripts/misCustomRules/missionCustomState.nut")
let guiStartWeaponrySelectModal = require("%scripts/weaponry/guiStartWeaponrySelectModal.nut")
let { getUnitLastBullets, getBulletGroupIndex, getWeaponBlkNameByGroupIdx } = require("%scripts/weaponry/bulletsInfo.nut")

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
  let lastBullets = getUnitLastBullets(unit)
  let uniqueSpawnScores = {}
  foreach (weapon in unit.getWeapons()) {
    let needShowDefTorpedoes = forceShowDefaultTorpedoes && isDefaultTorpedoes(weapon)
    if (!isForcedAvailable && !needShowDefTorpedoes
        && (!isWeaponVisible(unit, weapon, hasOnlySelectable)
          || (hasOnlySelectable && !isWeaponEnabled(unit, weapon))))
      continue

    let spawnScore = shop_get_spawn_score(unit.name, weapon.name, lastBullets, true, true)
    uniqueSpawnScores[spawnScore] <- true
    list.append({
      weaponryItem = weapon
      selected = curWeaponName == weapon.name
      enabled = isForcedAvailable || needShowDefTorpedoes || isWeaponEnabled(unit, weapon)
    })
  }

  let isSamePriceForAll = uniqueSpawnScores.len() == 1
  let itemParams = params.itemParams ?? {}
  itemParams.hideSpawnScoreCost <- isSamePriceForAll

  if (needSecondaryWeaponsWnd(unit))
    guiStartWeaponryPresets({ 
        unit = unit
        chooseMenuList   = list
        initLastWeapon   = curWeaponName
        weaponItemParams = itemParams
        onChangeValueCb  = onChangeValueCb
      })
  else
    guiStartWeaponrySelectModal({
      unit = unit
      list = list
      weaponItemParams = itemParams
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
    let params = { posX = 0, posY = 0, canModifyCustomPrests = false }
    let weaponryListMarkup = []
    let uniqueSpawnScores = {}
    foreach (idx, config in this.list) {
      let weaponryItem = getTblValue("weaponryItem", config)
      if (!weaponryItem) {
        script_net_assert_once("cant load weaponry",
          $"Error: empty weaponryItem for WeaponrySelectModal. unit = {this.unit?.name}")
        this.list = null 
        return null
      }

      if (getTblValue("selected", config))
        this.wasSelIdx = idx

      params.posX = rows ? (idx / rows) : 0
      params.posY = rows ? (idx % rows) : 0
      weaponryListMarkup.append(createModItemLayout(idx, this.unit, weaponryItem, weaponryItem.type, params))

      let groupIndex = getBulletGroupIndex(this.unit.name, config.weaponryItem.name)
      let weaponName = getWeaponBlkNameByGroupIdx(this.unit, groupIndex)
      let spawnScore = shop_get_spawn_score(this.unit.name, getLastWeapon(this.unit.name),
        [{name = config.weaponryItem.name, weapon = weaponName}], true, true)
      uniqueSpawnScores[spawnScore] <- true
    }
    let isSamePriceForAll = uniqueSpawnScores.len() == 1
    this.weaponItemParams.hideSpawnScoreCost <- isSamePriceForAll

    this.selIdx = max(this.wasSelIdx, 0)
    let res = {
      weaponryList = "".join(weaponryListMarkup)
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
    animObj[$"{scaleId}-base"] = "1"
    animObj[$"{scaleId}-end"] = size[scaleAxis].tostring()
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
}