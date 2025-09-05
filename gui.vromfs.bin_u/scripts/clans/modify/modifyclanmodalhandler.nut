from "%scripts/dagui_natives.nut" import utf8_strlen
from "%scripts/dagui_library.nut" import *

let { g_clan_type } = require("%scripts/clans/clanType.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { clearBorderSymbols, slice } = require("%sqstd/string.nut")
let { isNamePassing } = require("%scripts/dirtyWordsFilter.nut")
let { placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { setFocusToNextObj } = require("%sqDagui/daguiUtil.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { checkClanTagForDirtyWords, stripClanTagDecorators } = require("%scripts/clans/clanTextInfo.nut")
let { debug } = require("dagor.debug")

gui_handlers.ModifyClanModalHandler <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/clans/clanModifyWindow.blk"

  clanData = null

  newClanName = ""
  newClanTag = ""
  newClanTagDecoration = 0
  newClanSlogan = ""
  newClanDescription = ""
  newClanType = g_clan_type.NORMAL
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

  
  function createView() {
    return {}
  }

  function initScreen() {
    let view = this.createView()
    let data = handyman.renderCached("%gui/clans/clanModifyWindowContent.tpl", view)
    let contentObj = this.scene.findObject("content")
    this.guiScene.replaceContentFromText(contentObj, data, data.len(), this)

    let newClanTypeObj = this.scene.findObject("newclan_type")
    if (checkObj(newClanTypeObj))
      newClanTypeObj.setValue(0)

    this.lastShownHintObj = this.scene.findObject("req_newclan_name")

    let regionObj = this.scene.findObject("region_nest")
    if (!hasFeature("ClanRegions") && checkObj(regionObj))
      regionObj.show(false)

    let announcementNest = this.scene.findObject("announcement_nest")
    if (!hasFeature("ClanAnnouncements") && checkObj(announcementNest))
      announcementNest.show(false)

    this.updateReqs()
    this.updateTagMaxLength()
  }

  function setSubmitButtonText(buttonText, cost = 0) {
    placePriceTextToButton(this.scene, "btn_submit", buttonText, cost)
  }

  function getSelectedClanType() {
    let newClanTypeObj = this.scene.findObject("newclan_type")
    if (!checkObj(newClanTypeObj))
      return g_clan_type.UNKNOWN
    let selectedIndex = newClanTypeObj.getValue()
    if (selectedIndex == -1)
      return g_clan_type.UNKNOWN
    let typeName = newClanTypeObj.getChild(selectedIndex)["clanTypeName"]
    return g_clan_type.getTypeByName(typeName)
  }

  function isObsceneWord() {
    local errorMsg = ""

    if ((this.clanData == null || this.newClanName != this.clanData.name) &&
      !isNamePassing(this.newClanName)) {
      debug($"Clan name is not passing: {this.newClanName}")
      errorMsg = "charServer/updateError/16"
    }
    else if ((this.clanData == null || this.newClanTag != this.clanData.tag) &&
      !isNamePassing(stripClanTagDecorators(this.newClanTag))) {
      debug($"Clan tag is not passing: {stripClanTagDecorators(this.newClanTag)}")
      errorMsg = "charServer/updateError/17"
    }

    if (errorMsg == "")
      return false

    this.msgBox("clan_creating_error", loc(errorMsg), [["ok", function() {}]], "ok")
    return true
  }

  
  function onFieldChange(_obj) {
  }

  
  function onClanTypeSelect(_obj) {
  }

  
  function onSubmit() {
  }

  
  function updateSubmitButtonText() {
  }

  
  function onUpgradeMembers() {
  }

  
  function onDisbandClan() {
  }

  
  function getDecoratorsList() {
    return []
  }

  
  function onEventOnlineShopPurchaseSuccessful(_params) {
    this.updateSubmitButtonText()
  }

  function resetTagDecorationObj(selectedTag = null) {
    let tagDecorationObj = this.scene.findObject("newclan_tag_decoration")
    if (!checkObj(tagDecorationObj))
      return
    let view = {
      decoratorItems = []
    }

    let decorators = this.getDecoratorsList()
    foreach (index, decorator in decorators) {
      view.decoratorItems.append({
        decoratorId = format("option_%s", index.tostring())
        decoratorText = format("%s   %s", decorator.start, decorator.end)
        isDecoratorSelected = selectedTag != null && decorator.checkTagText(selectedTag)
      })
    }
    let blk = handyman.renderCached("%gui/clans/clanTagDecoratorItem.tpl", view)
    this.guiScene.replaceContentFromText(tagDecorationObj, blk, blk.len(), this)
    this.updateDecoration(this.scene.findObject("newclan_tag"))
  }

  
  function updateDecoration(obj) {
    let decorators = this.getDecoratorsList()
    let decorObj = this.scene.findObject("newclan_tag_decoration")
    if (decorObj.childrenCount() != decorators.len())
      return

    local tag = obj.getValue() ?? ""
    if (!tag.len())
      tag = "   "
    foreach (idx, decorItem in decorators)
      decorObj.getChild(idx).setValue("".concat(decorItem.start, tag, decorItem.end))
    decorObj.setValue(decorObj.getValue())
    this.onFieldChange(obj)
  }

  function updateDescription() {
    let descObj = this.scene.findObject("newclan_description")
    if (checkObj(descObj))
      descObj.show(this.newClanType.isDescriptionChangeAllowed())
    let captionObj = this.scene.findObject("not_allowed_description_caption")
    if (checkObj(captionObj))
      captionObj.show(!this.newClanType.isDescriptionChangeAllowed())
  }

  function updateAnnouncement() {
    let descObj = this.scene.findObject("newclan_announcement")
    if (checkObj(descObj))
      descObj.show(this.newClanType.isAnnouncementAllowed())
    let captionObj = this.scene.findObject("not_allowed_announcement_caption")
    if (checkObj(captionObj))
      captionObj.show(!this.newClanType.isAnnouncementAllowed())
  }

  function prepareClanDataTextValue(valueName, objId) {
    let obj = this.scene.findObject(objId)
    if (checkObj(obj))
      this[valueName] = obj.getValue()
  }

  function prepareClanData(edit = false, silent = false) {
    let clanType       = this.getSelectedClanType()
    this.newClanType          = clanType != g_clan_type.UNKNOWN ? clanType : g_clan_type.NORMAL

    this.prepareClanDataTextValue("newClanName",           "newclan_name")
    this.prepareClanDataTextValue("newClanTag",            "newclan_tag")
    this.prepareClanDataTextValue("newClanTagDecoration",  "newclan_tag_decoration")
    this.prepareClanDataTextValue("newClanSlogan",         "newclan_slogan")
    this.prepareClanDataTextValue("newClanDescription",    "newclan_description")
    this.prepareClanDataTextValue("newClanRegion",         "newclan_region")
    this.prepareClanDataTextValue("newClanAnnouncement",   "newclan_announcement")

    local err            = ""

    this.newClanName          = this.newClanName.len() > 0 ? clearBorderSymbols(this.newClanName, [" "]) : ""
    this.newClanTag           = this.newClanTag.len() > 0 ? clearBorderSymbols(this.newClanTag, [" "]) : ""
    this.newClanTagDecoration = !this.newClanTagDecoration ? 0 : this.newClanTagDecoration
    this.newClanSlogan        = this.newClanSlogan.len() > 0 ? clearBorderSymbols(this.newClanSlogan, [" "]) : ""
    this.newClanDescription   = this.newClanDescription.len() > 0 ? clearBorderSymbols(this.newClanDescription, [" "]) : ""
    this.newClanRegion        = this.newClanRegion.len() > 0 ? clearBorderSymbols(this.newClanRegion, [" "]) : ""
    this.newClanAnnouncement  = this.newClanAnnouncement.len() > 0 ? clearBorderSymbols(this.newClanAnnouncement, [" "]) : ""

    if (!checkClanTagForDirtyWords(this.newClanTag, false))
      err = "".concat(err, loc("clan/error/bad_words_in_clanTag"))

    if (this.newClanTag.len() <= 0)
      err = "".concat(err, loc("clan/error/empty_tag"), "\n")

    let tagLengthLimit = this.newClanType.getTagLengthLimit()
    if (!edit && tagLengthLimit > 0 && utf8_strlen(this.newClanTag) > tagLengthLimit)
      err = "".concat(err, loc("clan/error/tag_length", { maxLength = tagLengthLimit }), "\n")

    if ((!edit && this.newClanName.len() <= 0) || this.newClanName.len() < 3)
      err = "".concat(err, loc("clan/error/empty_name"), "\n")

    if (err.len() > 0) {
      if (!silent)
        this.msgBox("clan_create_error", err, [["ok"]], "ok")
      return false
    }

    let tagDecorations = this.getDecoratorsList()
    if (tagDecorations.len() >= this.newClanTagDecoration + 1 && this.newClanTag.len() > 0)
      this.newClanTag = "".concat(tagDecorations[this.newClanTagDecoration].start, this.newClanTag, tagDecorations[this.newClanTagDecoration].end)
    return true
  }

  function onFocus(obj) {
    if (!showConsoleButtons.get())
      this.updateHint(obj, true)
  }

  function onHover(obj) {
    if (showConsoleButtons.get())
      this.updateHint(obj, obj.isHovered())
  }

  function updateHint(obj, isShow) {
    let hintObj = obj?.id != null ? this.scene.findObject($"req_{obj.id}") : null
    if (checkObj(this.lastShownHintObj) && (hintObj == null || !this.lastShownHintObj.isEqual(hintObj))) {
      this.lastShownHintObj.show(false)
      this.lastShownHintObj = null
    }
    if (checkObj(hintObj)) {
      hintObj.show(isShow)
      this.lastShownHintObj = hintObj
    }
  }

  function clanCanselEdit(obj) {
    if (obj.getValue().len() > 0)
      obj.setValue("")
    else
      this.goBack()
  }

  function updateReqs() {
    let reqTextObj = this.scene.findObject("req_newclan_tag_text")
    if (checkObj(reqTextObj)) {
      let locId = format("clan/newclan_tag_req/%s", this.newClanType.getTypeName())
      let locParams = {
        tagLengthLimit = this.newClanType.getTagLengthLimit()
      }
      let text = loc(locId, locParams)
      reqTextObj.setValue(text)
    }
  }

  function updateTagMaxLength() {
    let newClanTagObj = this.scene.findObject("newclan_tag")
    if (checkObj(newClanTagObj)) {
      let tagLengthLimit = this.newClanType.getTagLengthLimit()
      newClanTagObj["max-len"] = tagLengthLimit.tostring()
      let curText = newClanTagObj.getValue()
      if (curText.len() > tagLengthLimit) {
        let newText = slice(curText, 0, tagLengthLimit)
        newClanTagObj.setValue(newText)
        this.newClanTag = newText
      }
    }
  }

  onKbdWrapUp   = @() setFocusToNextObj(this.scene, this.tabFocusArray, -1)
  onKbdWrapDown = @() setFocusToNextObj(this.scene, this.tabFocusArray, 1)
}