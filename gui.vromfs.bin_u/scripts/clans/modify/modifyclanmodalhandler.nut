local { clearBorderSymbols } = require("std/string.nut")
local dirtyWordsFilter = require("scripts/dirtyWords/dirtyWords.nut")
local { placePriceTextToButton } = require("scripts/viewUtils/objectTextUpdate.nut")

class ::gui_handlers.ModifyClanModalHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/clans/clanModifyWindow.blk"

  clanData = null

  newClanName = ""
  newClanTag = ""
  newClanTagDecoration = 0
  newClanSlogan = ""
  newClanDescription = ""
  newClanType = ::g_clan_type.NORMAL
  newClanRegion = ""
  newClanAnnouncement = ""
  lastShownReq = null
  focusArray = [
    function() { return getCurrentTopGCPanel() }     //gamercard top
    function() { return getCurGCDropdownMenu() }     //gamercard menu
    "newclan_type"
    "newclan_name"
    "newclan_tag"
    "newclan_slogan"
    "newclan_region"
    "newclan_description"
    "newclan_announcement"
    function() { return getCurrentBottomGCPanel() }    //gamercard bottom
  ]

  // Abstract method.
  function createView()
  {
    return {}
  }

  function initScreen()
  {
    local view = createView()
    local data = ::handyman.renderCached("gui/clans/clanModifyWindowContent", view)
    local contentObj = scene.findObject("content")
    guiScene.replaceContentFromText(contentObj, data, data.len(), this)

    local newClanTypeObj = scene.findObject("newclan_type")
    if (::checkObj(newClanTypeObj))
      newClanTypeObj.setValue(0)

    lastShownReq = scene.findObject("req_newclan_name")

    local regionObj = scene.findObject("region_nest")
    if (!::has_feature("ClanRegions") && ::checkObj(regionObj))
      regionObj.show(false)

    local announcementNest = scene.findObject("announcement_nest")
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
    local newClanTypeObj = scene.findObject("newclan_type")
    if (!::checkObj(newClanTypeObj))
      return ::g_clan_type.UNKNOWN
    local selectedIndex = newClanTypeObj.getValue()
    if (selectedIndex == -1)
      return ::g_clan_type.UNKNOWN
    local typeName = newClanTypeObj.getChild(selectedIndex)["clanTypeName"]
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
    local tagDecorationObj = scene.findObject("newclan_tag_decoration")
    if (!::checkObj(tagDecorationObj))
      return
    local view = {
      decoratorItems = []
    }

    local decorators = getDecoratorsList()
    foreach(index, decorator in decorators)
    {
      view.decoratorItems.append({
        decoratorId = ::format("option_%s", index.tostring())
        decoratorText = ::format("%s   %s", decorator.start, decorator.end)
        isDecoratorSelected = selectedTag != null && decorator.checkTagText(selectedTag)
      })
    }
    local blk = ::handyman.renderCached("gui/clans/clanTagDecoratorItem", view)
    guiScene.replaceContentFromText(tagDecorationObj, blk, blk.len(), this)
    updateDecoration(scene.findObject("newclan_tag"))
  }

  // Called from within scene as well.
  function updateDecoration(obj)
  {
    local decorators = getDecoratorsList()
    local decorObj = scene.findObject("newclan_tag_decoration")
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
    local descObj = scene.findObject("newclan_description")
    if (::checkObj(descObj))
      descObj.show(newClanType.isDescriptionChangeAllowed())
    local captionObj = scene.findObject("not_allowed_description_caption")
    if (::checkObj(captionObj))
      captionObj.show(!newClanType.isDescriptionChangeAllowed())
  }

  function updateAnnouncement()
  {
    local descObj = scene.findObject("newclan_announcement")
    if (::checkObj(descObj))
      descObj.show(newClanType.isAnnouncementAllowed())
    local captionObj = scene.findObject("not_allowed_announcement_caption")
    if (::checkObj(captionObj))
      captionObj.show(!newClanType.isAnnouncementAllowed())
  }

  function prepareClanDataTextValue(valueName, objId)
  {
    local obj = scene.findObject(objId)
    if (::checkObj(obj))
      this[valueName] = obj.getValue()
  }

  function prepareClanData(edit = false, silent = false)
  {
    local clanType       = getSelectedClanType()
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

    local tagLengthLimit = newClanType.getTagLengthLimit()
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

    local tagDecorations = getDecoratorsList()
    if(tagDecorations.len() >= newClanTagDecoration + 1 && newClanTag.len() > 0)
      newClanTag = tagDecorations[newClanTagDecoration].start + newClanTag + tagDecorations[newClanTagDecoration].end
    return true
  }

  function onFocus(obj)
  {
    local req = obj?.id && scene.findObject("req_" + obj.id)
    if(lastShownReq && !lastShownReq.isEqual(req))
      lastShownReq.show(false)
    if(!req)
      return
    req.show(true)
    lastShownReq = req
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
    local reqTextObj = scene.findObject("req_newclan_tag_text")
    if (::checkObj(reqTextObj))
    {
      local locId = ::format("clan/newclan_tag_req/%s", newClanType.getTypeName())
      local locParams = {
        tagLengthLimit = newClanType.getTagLengthLimit()
      }
      local text = ::loc(locId, locParams)
      reqTextObj.setValue(text)
    }
  }

  function updateTagMaxLength()
  {
    local newClanTagObj = scene.findObject("newclan_tag")
    if (::checkObj(newClanTagObj))
    {
      local tagLengthLimit = newClanType.getTagLengthLimit()
      newClanTagObj["max-len"] = tagLengthLimit.tostring()
      local curText = newClanTagObj.getValue()
      if (curText.len() > tagLengthLimit)
      {
        local newText = ::g_string.slice(curText, 0, tagLengthLimit)
        newClanTagObj.setValue(newText)
        newClanTag = newText
      }
    }
  }
}
