let { clearBorderSymbols } = require("%sqstd/string.nut")
let dirtyWordsFilter = require("%scripts/dirtyWordsFilter.nut")
let { placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { setFocusToNextObj } = require("%sqDagui/daguiUtil.nut")

::gui_handlers.ModifyClanModalHandler <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/clans/clanModifyWindow.blk"

  clanData = null

  newClanName = ""
  newClanTag = ""
  newClanTagDecoration = 0
  newClanSlogan = ""
  newClanDescription = ""
  newClanType = ::g_clan_type.NORMAL
  newClanRegion = ""
  newClanAnnouncement = ""
  lastShownHintObj = null

  tabFocusArray = [
    "newclan_type",
    "newclan_name",
    "newclan_tag",
    "newclan_slogan",
    "newclan_region",
    "newclan_description",
    "newclan_announcement",
  ]

  // Abstract method.
  function createView()
  {
    return {}
  }

  function initScreen()
  {
    let view = createView()
    let data = ::handyman.renderCached("%gui/clans/clanModifyWindowContent", view)
    let contentObj = scene.findObject("content")
    guiScene.replaceContentFromText(contentObj, data, data.len(), this)

    let newClanTypeObj = scene.findObject("newclan_type")
    if (::checkObj(newClanTypeObj))
      newClanTypeObj.setValue(0)

    lastShownHintObj = scene.findObject("req_newclan_name")

    let regionObj = scene.findObject("region_nest")
    if (!::has_feature("ClanRegions") && ::checkObj(regionObj))
      regionObj.show(false)

    let announcementNest = scene.findObject("announcement_nest")
    if (!::has_feature("ClanAnnouncements") && ::checkObj(announcementNest))
      announcementNest.show(false)

    updateReqs()
    updateTagMaxLength()
  }

  function setSubmitButtonText(buttonText, cost = 0)
  {
    placePriceTextToButton(scene, "btn_submit", buttonText, cost)
  }

  function getSelectedClanType()
  {
    let newClanTypeObj = scene.findObject("newclan_type")
    if (!::checkObj(newClanTypeObj))
      return ::g_clan_type.UNKNOWN
    let selectedIndex = newClanTypeObj.getValue()
    if (selectedIndex == -1)
      return ::g_clan_type.UNKNOWN
    let typeName = newClanTypeObj.getChild(selectedIndex)["clanTypeName"]
    return ::g_clan_type.getTypeByName(typeName)
  }

  function isObsceneWord()
  {
    local errorMsg = ""

    if ((clanData == null || newClanName != clanData.name) &&
      !dirtyWordsFilter.isPhrasePassing(newClanName))
    {
      errorMsg = "charServer/updateError/16"
    }
    else if ((clanData == null || newClanTag != clanData.tag) &&
      !dirtyWordsFilter.isPhrasePassing(::g_clans.stripClanTagDecorators(newClanTag)))
    {
      errorMsg = "charServer/updateError/17"
    }

    if (errorMsg == "")
      return false

    msgBox("clan_creating_error", ::loc(errorMsg), [["ok", function(){}]], "ok")
    return true
  }

  // Abstract method.
  function onFieldChange(obj)
  {
  }

  // Abstract method.
  function onClanTypeSelect(obj)
  {
  }

  // Abstract method.
  function onSubmit()
  {
  }

  // Abstract method.
  function updateSubmitButtonText()
  {
  }

  // Abstract method.
  function onUpgradeMembers()
  {
  }

  // Abstract method.
  function onDisbandClan()
  {
  }

  // Abstract method.
  function getDecoratorsList()
  {
    return []
  }

  // Override.
  function onEventOnlineShopPurchaseSuccessful(params)
  {
    updateSubmitButtonText()
  }

  function resetTagDecorationObj(selectedTag = null)
  {
    let tagDecorationObj = scene.findObject("newclan_tag_decoration")
    if (!::checkObj(tagDecorationObj))
      return
    let view = {
      decoratorItems = []
    }

    let decorators = getDecoratorsList()
    foreach(index, decorator in decorators)
    {
      view.decoratorItems.append({
        decoratorId = ::format("option_%s", index.tostring())
        decoratorText = ::format("%s   %s", decorator.start, decorator.end)
        isDecoratorSelected = selectedTag != null && decorator.checkTagText(selectedTag)
      })
    }
    let blk = ::handyman.renderCached("%gui/clans/clanTagDecoratorItem", view)
    guiScene.replaceContentFromText(tagDecorationObj, blk, blk.len(), this)
    updateDecoration(scene.findObject("newclan_tag"))
  }

  // Called from within scene as well.
  function updateDecoration(obj)
  {
    let decorators = getDecoratorsList()
    let decorObj = scene.findObject("newclan_tag_decoration")
    if (decorObj.childrenCount() != decorators.len())
      return

    local tag = obj.getValue() || ""
    if(!tag.len())
      tag = "   "
    foreach(idx, decorItem in decorators)
      decorObj.getChild(idx).setValue(decorItem.start + tag + decorItem.end)
    decorObj.setValue(decorObj.getValue())
    onFieldChange(obj)
  }

  function updateDescription()
  {
    let descObj = scene.findObject("newclan_description")
    if (::checkObj(descObj))
      descObj.show(newClanType.isDescriptionChangeAllowed())
    let captionObj = scene.findObject("not_allowed_description_caption")
    if (::checkObj(captionObj))
      captionObj.show(!newClanType.isDescriptionChangeAllowed())
  }

  function updateAnnouncement()
  {
    let descObj = scene.findObject("newclan_announcement")
    if (::checkObj(descObj))
      descObj.show(newClanType.isAnnouncementAllowed())
    let captionObj = scene.findObject("not_allowed_announcement_caption")
    if (::checkObj(captionObj))
      captionObj.show(!newClanType.isAnnouncementAllowed())
  }

  function prepareClanDataTextValue(valueName, objId)
  {
    let obj = scene.findObject(objId)
    if (::checkObj(obj))
      this[valueName] = obj.getValue()
  }

  function prepareClanData(edit = false, silent = false)
  {
    let clanType       = getSelectedClanType()
    newClanType          = clanType != ::g_clan_type.UNKNOWN ? clanType : ::g_clan_type.NORMAL

    prepareClanDataTextValue("newClanName",           "newclan_name")
    prepareClanDataTextValue("newClanTag",            "newclan_tag")
    prepareClanDataTextValue("newClanTagDecoration",  "newclan_tag_decoration")
    prepareClanDataTextValue("newClanSlogan",         "newclan_slogan")
    prepareClanDataTextValue("newClanDescription",    "newclan_description")
    prepareClanDataTextValue("newClanRegion",         "newclan_region")
    prepareClanDataTextValue("newClanAnnouncement",   "newclan_announcement")

    local err            = ""

    newClanName          = newClanName.len() > 0 ? clearBorderSymbols(newClanName, [" "]) : ""
    newClanTag           = newClanTag.len() > 0 ? clearBorderSymbols(newClanTag, [" "]) : ""
    newClanTagDecoration = !newClanTagDecoration ? 0 : newClanTagDecoration
    newClanSlogan        = newClanSlogan.len() > 0 ? clearBorderSymbols(newClanSlogan, [" "]) : ""
    newClanDescription   = newClanDescription.len() > 0 ? clearBorderSymbols(newClanDescription, [" "]) : ""
    newClanRegion        = newClanRegion.len() > 0 ? clearBorderSymbols(newClanRegion, [" "]) : ""
    newClanAnnouncement  = newClanAnnouncement.len() > 0 ? clearBorderSymbols(newClanAnnouncement, [" "]) : ""

    if(!::checkClanTagForDirtyWords(newClanTag, false))
      err += ::loc("clan/error/bad_words_in_clanTag")

    if(newClanTag.len() <= 0)
      err += ::loc("clan/error/empty_tag") + "\n"

    let tagLengthLimit = newClanType.getTagLengthLimit()
    if (!edit && tagLengthLimit > 0 && ::utf8_strlen(newClanTag) > tagLengthLimit)
      err += ::loc("clan/error/tag_length", { maxLength = tagLengthLimit }) + "\n"

    if((!edit && newClanName.len() <= 0) || newClanName.len() < 3)
      err += ::loc("clan/error/empty_name") + "\n"

    if(err.len() > 0)
    {
      if (!silent)
        msgBox("clan_create_error", err, [["ok"]], "ok")
      return false
    }

    let tagDecorations = getDecoratorsList()
    if(tagDecorations.len() >= newClanTagDecoration + 1 && newClanTag.len() > 0)
      newClanTag = tagDecorations[newClanTagDecoration].start + newClanTag + tagDecorations[newClanTagDecoration].end
    return true
  }

  function onFocus(obj)
  {
    if (!::show_console_buttons)
      updateHint(obj, true)
  }

  function onHover(obj)
  {
    if (::show_console_buttons)
      updateHint(obj, obj.isHovered())
  }

  function updateHint(obj, isShow)
  {
    let hintObj = obj?.id != null ? scene.findObject($"req_{obj.id}") : null
    if (::check_obj(lastShownHintObj) && (hintObj == null || !lastShownHintObj.isEqual(hintObj)))
    {
      lastShownHintObj.show(false)
      lastShownHintObj = null
    }
    if (::check_obj(hintObj))
    {
      hintObj.show(isShow)
      lastShownHintObj = hintObj
    }
  }

  function clanCanselEdit(obj)
  {
    if (obj.getValue().len() > 0)
      obj.setValue("")
    else
      goBack()
  }

  function updateReqs()
  {
    let reqTextObj = scene.findObject("req_newclan_tag_text")
    if (::checkObj(reqTextObj))
    {
      let locId = ::format("clan/newclan_tag_req/%s", newClanType.getTypeName())
      let locParams = {
        tagLengthLimit = newClanType.getTagLengthLimit()
      }
      let text = ::loc(locId, locParams)
      reqTextObj.setValue(text)
    }
  }

  function updateTagMaxLength()
  {
    let newClanTagObj = scene.findObject("newclan_tag")
    if (::checkObj(newClanTagObj))
    {
      let tagLengthLimit = newClanType.getTagLengthLimit()
      newClanTagObj["max-len"] = tagLengthLimit.tostring()
      let curText = newClanTagObj.getValue()
      if (curText.len() > tagLengthLimit)
      {
        let newText = ::g_string.slice(curText, 0, tagLengthLimit)
        newClanTagObj.setValue(newText)
        newClanTag = newText
      }
    }
  }

  onKbdWrapUp   = @() setFocusToNextObj(scene, tabFocusArray, -1)
  onKbdWrapDown = @() setFocusToNextObj(scene, tabFocusArray, 1)
}
