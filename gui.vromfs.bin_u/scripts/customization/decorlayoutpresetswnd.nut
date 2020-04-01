local { clearBorderSymbols } = require("std/string.nut")

const PRESET_MIN_USAGE = 2

class ::gui_handlers.DecorLayoutPresets extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = null
  sceneTplName = "gui/customization/decorLayoutPresetsWnd"

  unit = null
  masterSkinId = ""
  skinList = null

  masterPresetId = ""
  isPreset = false
  presetBySkinIdx = null

  linkedSkinsInitial = 0
  linkedSkinsCurrent = 0

  function getSceneTplView()
  {
    local view = { list = [] }
    for (local i = 0; i < skinList.items.len(); i++)
      view.list.append({
        id   = skinList.values[i]
        text = skinList.items[i].text
        icon = skinList.items[i].image
      })
    return view
  }

  function initScreen()
  {
    ::enableHangarControls(true)

    local objCombobox = scene.findObject("master_skin")
    local selIdx = getIndexBySkinId(masterSkinId)
    local markup = ::create_option_combobox(null, skinList.items, selIdx, null, false)
    guiScene.replaceContentFromText(objCombobox, markup, markup.len(), this)
    updateMasterPreset()

    initFocusArray()
  }

  getMainFocusObj  = @() scene.findObject("master_skin")
  getMainFocusObj2 = @() scene.findObject("destination_skins")

  function updateMasterPreset(needResetLinkedSkins = true)
  {
    masterPresetId = ::hangar_customization_preset_get_name(masterSkinId)
    isPreset = masterPresetId != ""
    presetBySkinIdx = ::u.map(skinList.values, @(id) ::hangar_customization_preset_get_name(id))

    if (needResetLinkedSkins)
    {
      linkedSkinsInitial = 0
      foreach (idx, val in skinList.values)
        if (val == masterSkinId || (isPreset && presetBySkinIdx[idx] == masterPresetId))
          linkedSkinsInitial = linkedSkinsInitial | (1 << idx)
      linkedSkinsCurrent = linkedSkinsInitial
    }

    updateSkinsPresets()
    updateLinkedSkins()
    updateButtons()
  }

  function updateSkinsPresets()
  {
    foreach (idx, skinId in skinList.values)
      scene.findObject("preset_of_" + skinId).setValue(presetBySkinIdx[idx])
  }

  function updateLinkedSkins()
  {
    local listObj = scene.findObject("destination_skins")
    listObj.setValue(linkedSkinsCurrent)
    foreach (idx, skinId in skinList.values)
      listObj.findObject(skinId).enable(skinId != masterSkinId)
  }

  function getIndexBySkinId(skinId)
  {
    local selSkinId = skinId
    return skinList.values.findindex(@(id) id == selSkinId) ?? -1
  }

  function updateButtons()
  {
    ::showBtnTable(scene, {
        btn_rename = isPreset
        btn_apply  = linkedSkinsCurrent != linkedSkinsInitial
    })
  }

  function onMasterSkinSelect(obj)
  {
    if (!::check_obj(obj))
      return
    masterSkinId = skinList.values?[obj.getValue()] ?? ""

    ::g_decorator.setLastSkin(unit.name, masterSkinId, false)
    ::hangar_apply_skin(masterSkinId)
    ::save_online_single_job(3210)
    ::save_profile(false)

    updateMasterPreset()
  }

  function onDestinationSkinSelect(obj)
  {
    if (!::check_obj(obj))
      return
    linkedSkinsCurrent = obj.getValue()
    updateButtons()
  }

  function onBtnRename(obj)
  {
    if (!isPreset)
      return
    local validatePresetNameRegexp = regexp2(@"^#|[;|\\<>]")
    local oldName = masterPresetId
    ::gui_modal_editbox_wnd({
      title = ::loc("customization/decorLayout/layoutName")
      maxLen = 16
      value = oldName
      owner = this
      checkButtonFunc = @(val) val != null && clearBorderSymbols(val).len() > 0
      validateFunc = @(val) validatePresetNameRegexp.replace("", val)
      okFunc = @(val) doRenamePreset(oldName, val)
    })
  }

  function doRenamePreset(oldName, newName)
  {
    if (newName == oldName)
      return
    if (::isInArray(newName, presetBySkinIdx))
      return ::showInfoMsgBox(::loc("rename/cant/nameAlreadyTaken"))

    ::hangar_customization_preset_set_name(oldName, newName)
    ::save_profile(false)
    updateMasterPreset(false)
  }

  function onStart(obj)
  {
    if (linkedSkinsCurrent == linkedSkinsInitial)
      return

    local listAttach = []
    local listDetach = []
    for (local i = 0; i < skinList.values.len(); i++)
    {
      local id = skinList.values[i]
      local val = (linkedSkinsCurrent & (1 << i)) != 0
      if ((isPreset && masterPresetId == presetBySkinIdx[i]) != val) // warning disable: -compared-with-bool
        if (val)
          listAttach.append(id)
        else
          listDetach.append(id)
    }

    local presetId = masterPresetId
    if (!isPreset && listAttach.len())
      for (local i = 0; i < skinList.values.len(); i++)
      {
        presetId = ::loc("customization/decorLayout/defaultName", { number = i + 1 })
        if (::hangar_customization_preset_calc_usage(presetId) == 0)
        {
          ::hangar_customization_preset_create(presetId)
          ::u.removeFrom(listAttach, masterSkinId)
          break
        }
      }

    foreach (id in listAttach)
      ::hangar_customization_preset_assign_to_skin(presetId, id)
    foreach (id in listDetach)
      ::hangar_customization_preset_unassign_from_skin(id)

    local usedPresetsList = {}
    foreach (id in skinList.values)
      usedPresetsList[::hangar_customization_preset_get_name(id)] <- id
    foreach (pId, id in usedPresetsList)
      if (::hangar_customization_preset_calc_usage(pId) < PRESET_MIN_USAGE)
        ::hangar_customization_preset_unassign_from_skin(id)

    ::save_profile(false)

    updateMasterPreset()
  }
}

return {
  open = function (unit, skinId)
  {
    if (!::has_feature("CustomizationLayoutPresets"))
      return
    local skinList = ::g_decorator.getSkinsOption(unit?.name, false, false)
    if (!::isInArray(skinId, skinList.values))
      return
    ::handlersManager.loadHandler(::gui_handlers.DecorLayoutPresets, {
      unit = unit
      masterSkinId = skinId
      skinList = skinList
    })
  }
}
