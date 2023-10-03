//checked for plus_string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

let { split_by_chars } = require("string")
let enums = require("%sqStdLibs/helpers/enums.nut")
let { startsWith, cutPrefix } = require("%sqstd/string.nut")
let { get_num_attempts_left } = require("guiMission")

enum hintTagCheckOrder {
  EXACT_WORD //single word tags
  REGULAR
  ALL_OTHER //all other tags are work as shortcuts
}

::g_hint_tag <- {
  types = []
}

::g_hint_tag.template <- {
  typeName = ""
  checkOrder = hintTagCheckOrder.EXACT_WORD

  checkTag = function(tagName) { return this.typeName == tagName }
  getViewSlices = function(_tagName, _params) { return [] }
  makeTag = function(_params = null) { return this.typeName }
  makeFullTag = @(params = null) ::g_hints.hintTags[0] + this.makeTag(params) + ::g_hints.hintTags[1]
  getSeparator = @() ""
}

enums.addTypesByGlobalName("g_hint_tag", {
  TIMER = {
    typeName = "@"
    getViewSlices = function(_tagName, params) {
      let total = (getTblValue("time", params, 0) + 0.5).tointeger()
      let offset = getTblValue("timeoffset", params, 0)
      return [{
               timer = {
                 incFactor = total ? 360.0 / total : 0
                 angle = (offset && total) ? (360 * offset / total).tointeger() : 0
                 hideWhenStopped = getTblValue("hideWhenStopped", params, false)
                 timerOffsetX = getTblValue("timerOffsetX", params)
               }
             }]
    }
  }

  SHORTCUT = {
    typeName = ""
    checkOrder = hintTagCheckOrder.ALL_OTHER
    checkTag = function(_tagName) { return true }
    getSeparator = @() loc("hints/shortcut_separator")

    getViewSlices = function(tagName, params) { //tagName == shortcutId
      let slices = []
      let needConfig = params?.needConfig ?? false
      let expanded = ::g_shortcut_type.expandShortcuts([tagName], params?.showKeyBoardShortcutsForMouseAim ?? false)
      let showShortcutsNameIfNotAssign = params?.showShortcutsNameIfNotAssign ?? false
      let shortcutsCount = expanded.len()
      foreach (i, expandedShortcut in expanded) {
        let shortcutType = ::g_shortcut_type.getShortcutTypeByShortcutId(expandedShortcut)
        let shortcutId = expandedShortcut
        slices.append({
          shortcut = needConfig
            ? shortcutType.getFirstInput(shortcutId, ::g_controls_manager.getPreviewPreset()).getConfig()
            : function() {
              let input = shortcutType.getFirstInput(shortcutId, ::g_controls_manager.getPreviewPreset(), showShortcutsNameIfNotAssign)
              return input.getMarkup()
            }
        })
        if (i < (shortcutsCount - 1))
          slices.append({ text = { textValue = this.getSeparator() } })
      }
      return slices
    }
  }

  IMAGE = {
    typeName = "img="
    checkOrder = hintTagCheckOrder.REGULAR
    checkTag = function(tagName) { return startsWith(tagName, this.typeName) }
    colorParam = "color="
    sizeParam = "sizeStyle="
    delimiter = " "
    getViewSlices = function(tagName, _params) {
      let paramsList = split_by_chars(tagName, this.delimiter)
      let res = {
        image = cutPrefix(paramsList[0], this.typeName,  "")
        color = null
        sizeStyle = null
      }
      for (local i = 1; i < paramsList.len(); i++) {
        res.color = res.color || cutPrefix(paramsList[i], this.colorParam)
        res.sizeStyle = res.sizeStyle || cutPrefix(paramsList[i], this.sizeParam)
      }
      return [res]
    }
    makeTag = function(params = null) {
      return this.typeName + (params?.image || "")
        + (params?.color      ? this.delimiter + this.colorParam + params.color : "")
        + (params?.sizeStyle  ? this.delimiter + this.sizeParam + params.sizeStyle : "")
    }
  }

  MISSION_ATTEMPTS_LEFT = {
    typeName = "attempts_left" //{{attempts_left}} or {{attempts_left=locId}}
    checkOrder = hintTagCheckOrder.REGULAR
    checkTag = function(tagName) { return startsWith(tagName, this.typeName) }
    getViewSlices = function(tagName, _params) {
      let attempts = get_num_attempts_left()
      local attemptsText = attempts < 0 ? loc("options/attemptsUnlimited") : attempts

      if (tagName.len() > this.typeName.len() + 1) { //{{attempts_left=locId}}
        let locId = tagName.slice(this.typeName.len() + 1)
        attemptsText = loc(locId, { attemptsText, attempts })
      }
      return [{
        text = attemptsText
      }]
    }
  }

  INPUT_BUTTON = {
    typeName = "INPUT_BUTTON"
    delimiter = " "
    checkOrder = hintTagCheckOrder.REGULAR
    checkTag = function(tagName) { return startsWith(tagName, this.typeName) }

    getViewSlices = function(tagName, params) { //tagName == shortcutId
      let paramsList = split_by_chars(tagName, this.delimiter)
      let shortcut = ::SHORTCUT?[paramsList?[1]]
      if (!u.isTable(shortcut))
        return []

      let input = ::Input.Button(shortcut.dev[0], shortcut.btn[0])
      return [{
        shortcut = (params?.needConfig ?? false)
          ? input.getConfig()
          : input.getMarkup()
      }]
    }
  }
})

::g_hint_tag.types.sort(function(a, b) {
  if (a.checkOrder != b.checkOrder)
    return a.checkOrder < b.checkOrder ? -1 : 1
  return 0
})

::g_hint_tag.getHintTagType <- function getHintTagType(tagName) {
  foreach (tagType in this.types)
    if (tagType.checkTag(tagName))
      return tagType

  return this.SHORTCUT
}
