from "%scripts/dagui_natives.nut" import save_online_single_job, hangar_customization_preset_create, save_profile, hangar_customization_preset_set_name, hangar_customization_preset_get_name, hangar_customization_preset_calc_usage, hangar_customization_preset_unassign_from_skin, hangar_customization_preset_assign_to_skin
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let regexp2 = require("regexp2")
let { apply_skin } = require("unitCustomization")
let { clearBorderSymbols } = require("%sqstd/string.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { setLastSkin, getSkinsOption } = require("%scripts/customization/skins.nut")

const PRESET_MIN_USAGE = 2

gui_handlers.DecorLayoutPresets <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = null
  sceneTplName = "%gui/customization/decorLayoutPresetsWnd.tpl"

  unit = null
  masterSkinId = ""
  skinList = null

  masterPresetId = ""
  isPreset = false
  presetBySkinIdx = null

  linkedSkinsInitial = 0
  linkedSkinsCurrent = 0

  function getSceneTplView() {
    let view = { list = [] }
    for (local i = 0; i < this.skinList.items.len(); i++)
      view.list.append({
        id   = this.skinList.values[i]
        text = this.skinList.items[i].text
        icon = this.skinList.items[i].image
      })
    return view
  }

  function initScreen() {
    let objCombobox = this.scene.findObject("master_skin")
    let selIdx = this.getIndexBySkinId(this.masterSkinId)
    let markup = ::create_option_combobox(null, this.skinList.items, selIdx, null, false)
    this.guiScene.replaceContentFromText(objCombobox, markup, markup.len(), this)
    this.updateMasterPreset()
  }

  function updateMasterPreset(needResetLinkedSkins = true) {
    this.masterPresetId = hangar_customization_preset_get_name(this.masterSkinId)
    this.isPreset = this.masterPresetId != ""
    this.presetBySkinIdx = this.skinList.values.map(@(id) hangar_customization_preset_get_name(id))

    if (needResetLinkedSkins) {
      this.linkedSkinsInitial = 0
      foreach (idx, val in this.skinList.values)
        if (val == this.masterSkinId || (this.isPreset && this.presetBySkinIdx[idx] == this.masterPresetId))
          this.linkedSkinsInitial = this.linkedSkinsInitial | (1 << idx)
      this.linkedSkinsCurrent = this.linkedSkinsInitial
    }

    this.updateSkinsPresets()
    this.updateLinkedSkins()
    this.updateButtons()
  }

  function updateSkinsPresets() {
    foreach (idx, skinId in this.skinList.values)
      this.scene.findObject($"preset_of_{skinId}").setValue(this.presetBySkinIdx[idx])
  }

  function updateLinkedSkins() {
    let listObj = this.scene.findObject("destination_skins")
    listObj.setValue(this.linkedSkinsCurrent)
    foreach (_idx, skinId in this.skinList.values)
      listObj.findObject(skinId).enable(skinId != this.masterSkinId)
  }

  function getIndexBySkinId(skinId) {
    let selSkinId = skinId
    return this.skinList.values.findindex(@(id) id == selSkinId) ?? -1
  }

  function updateButtons() {
    showObjectsByTable(this.scene, {
        btn_rename = this.isPreset
        btn_apply  = this.linkedSkinsCurrent != this.linkedSkinsInitial
    })
  }

  function onMasterSkinSelect(obj) {
    if (!checkObj(obj))
      return
    this.masterSkinId = this.skinList.values?[obj.getValue()] ?? ""

    setLastSkin(this.unit.name, this.masterSkinId, false)
    apply_skin(this.masterSkinId)
    save_online_single_job(3210)
    save_profile(false)

    this.updateMasterPreset()
  }

  function onDestinationSkinSelect(obj) {
    if (!checkObj(obj))
      return
    this.linkedSkinsCurrent = obj.getValue()
    this.updateButtons()
  }

  function onBtnRename(_obj) {
    if (!this.isPreset)
      return
    let validatePresetNameRegexp = regexp2(@"^#|[;|\\<>]")
    let oldName = this.masterPresetId
    ::gui_modal_editbox_wnd({
      title = loc("customization/decorLayout/layoutName")
      maxLen = 16
      value = oldName
      owner = this
      checkButtonFunc = @(val) val != null && clearBorderSymbols(val).len() > 0
      validateFunc = @(val) validatePresetNameRegexp.replace("", val)
      okFunc = @(val) this.doRenamePreset(oldName, val)
    })
  }

  function doRenamePreset(oldName, newName) {
    if (newName == oldName)
      return
    if (isInArray(newName, this.presetBySkinIdx))
      return showInfoMsgBox(loc("rename/cant/nameAlreadyTaken"))

    hangar_customization_preset_set_name(oldName, newName)
    save_profile(false)
    this.updateMasterPreset(false)
  }

  function onStart(_obj) {
    if (this.linkedSkinsCurrent == this.linkedSkinsInitial)
      return

    let listAttach = []
    let listDetach = []
    for (local i = 0; i < this.skinList.values.len(); i++) {
      let id = this.skinList.values[i]
      let val = (this.linkedSkinsCurrent & (1 << i)) != 0
      if ((this.isPreset && this.masterPresetId == this.presetBySkinIdx[i]) != val) // warning disable: -compared-with-bool
        if (val)
          listAttach.append(id)
        else
          listDetach.append(id)
    }

    local presetId = this.masterPresetId
    if (!this.isPreset && listAttach.len())
      for (local i = 0; i < this.skinList.values.len(); i++) {
        presetId = loc("customization/decorLayout/defaultName", { number = i + 1 })
        if (hangar_customization_preset_calc_usage(presetId) == 0) {
          hangar_customization_preset_create(presetId)
          u.removeFrom(listAttach, this.masterSkinId)
          break
        }
      }

    foreach (id in listAttach)
      hangar_customization_preset_assign_to_skin(presetId, id)
    foreach (id in listDetach)
      hangar_customization_preset_unassign_from_skin(id)

    let usedPresetsList = {}
    foreach (id in this.skinList.values)
      usedPresetsList[hangar_customization_preset_get_name(id)] <- id
    foreach (pId, id in usedPresetsList)
      if (hangar_customization_preset_calc_usage(pId) < PRESET_MIN_USAGE)
        hangar_customization_preset_unassign_from_skin(id)

    save_profile(false)

    this.updateMasterPreset()
  }
}

return {
  open = function (unit, skinId) {
    if (!hasFeature("CustomizationLayoutPresets"))
      return
    let skinList = getSkinsOption(unit?.name, false, false)
    if (!isInArray(skinId, skinList.values))
      return
    handlersManager.loadHandler(gui_handlers.DecorLayoutPresets, {
      unit = unit
      masterSkinId = skinId
      skinList = skinList
    })
  }
}
