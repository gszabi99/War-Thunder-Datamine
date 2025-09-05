from "%scripts/dagui_library.nut" import *
from "%scripts/controls/rawShortcuts.nut" import SHORTCUT

let { g_shortcut_type } = require("%scripts/controls/shortcutType.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { split_by_chars } = require("string")
let u = require("%sqStdLibs/helpers/u.nut")
let { enumsAddTypes } = require("%sqStdLibs/helpers/enums.nut")
let { startsWith, cutPrefix } = require("%sqstd/string.nut")
let { get_num_attempts_left } = require("guiMission")
let { Button } = require("%scripts/controls/input/button.nut")
let { getPreviewControlsPreset } = require("%scripts/controls/controlsState.nut")

enum hintTagCheckOrder {
  EXACT_WORD 
  REGULAR
  ALL_OTHER 
}

local g_hints

let g_hint_tag = {
  types = []

  template = {
    typeName = ""
    checkOrder = hintTagCheckOrder.EXACT_WORD

    checkTag = function(tagName) { return this.typeName == tagName }
    getViewSlices = function(_tagName, _params) { return [] }
    makeTag = function(_params = null) { return this.typeName }
    makeFullTag = @(params = null) g_hints.hintTags[0] + this.makeTag(params) + g_hints.hintTags[1]
    getSeparator = @() ""
  }
  function getHintTagType(tagName) {
    foreach (tagType in this.types)
      if (tagType.checkTag(tagName))
        return tagType

    return this.SHORTCUT
  }
}


enumsAddTypes(g_hint_tag, {
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

    getViewSlices = function(tagName, params) { 
      let slices = []
      let { needConfig = false, skipDeviceIds = {} } = params
      let expanded = g_shortcut_type.expandShortcuts([tagName], params?.showKeyBoardShortcutsForMouseAim ?? false)
      let showShortcutsNameIfNotAssign = params?.showShortcutsNameIfNotAssign ?? false
      let shortcutsCount = expanded.len()
      foreach (i, expandedShortcut in expanded) {
        let shortcutType = g_shortcut_type.getShortcutTypeByShortcutId(expandedShortcut)
        let shortcutId = expandedShortcut
        slices.append({
          shortcut = needConfig
            ? shortcutType.getFirstInput(shortcutId, getPreviewControlsPreset()
                { skipDeviceIds }).getConfig()
            : function() {
              let input = shortcutType.getFirstInput(shortcutId, getPreviewControlsPreset(),
                { showShortcutsNameIfNotAssign, skipDeviceIds })
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
      return "".concat( this.typeName, (params?.image ?? ""),
        (params?.color      ? "".concat(this.delimiter, this.colorParam, params.color) : ""),
        (params?.sizeStyle  ? "".concat(this.delimiter, this.sizeParam, params.sizeStyle) : "")
      )
    }
  }

  MISSION_ATTEMPTS_LEFT = {
    typeName = "attempts_left" 
    checkOrder = hintTagCheckOrder.REGULAR
    checkTag = function(tagName) { return startsWith(tagName, this.typeName) }
    getViewSlices = function(tagName, _params) {
      let attempts = get_num_attempts_left()
      local attemptsText = attempts < 0 ? loc("options/attemptsUnlimited") : attempts

      if (tagName.len() > this.typeName.len() + 1) { 
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

    getViewSlices = function(tagName, params) { 
      let paramsList = split_by_chars(tagName, this.delimiter)
      let shortcut = SHORTCUT?[paramsList?[1]]
      if (!u.isTable(shortcut))
        return []

      let input = Button(shortcut.dev[0], shortcut.btn[0])
      return [{
        shortcut = (params?.needConfig ?? false)
          ? input.getConfig()
          : input.getMarkup()
      }]
    }
  }
})

g_hint_tag.types.sort(function(a, b) {
  if (a.checkOrder != b.checkOrder)
    return a.checkOrder < b.checkOrder ? -1 : 1
  return 0
})


enum HINT_PIECE_TYPE {
  TEXT,
  TAG,
  LINK
}

function getTextSlice(textsArray) {
  return { text = textsArray.map(
    @(text, idx) { textValue = textsArray?[idx + 1] != null ? $"{text} " : text }) }
}


g_hints = {
  hintTags = ["{{", "}}"]
  timerMark = g_hint_tag.TIMER.typeName
  colorTags = ["<color=", "</color>"]
  linkTags = ["<Link=", "</Link>"]
}








g_hints.buildHintMarkup <- function buildHintMarkup(text, params = {}) {
  return handyman.renderCached("%gui/hint.tpl", this.getHintSlices(text, params))
}

g_hints.getHintSlices <- function getHintSlices(text, params = {}) {
  let rows = split_by_chars(text, "\n")
  let isWrapInRowAllowed = params?.isWrapInRowAllowed ?? false
  let view = {
    id = getTblValue("id", params)
    style = getTblValue("style", params, "")
    isOrderPopup = getTblValue("isOrderPopup", params, false)
    isWrapInRowAllowed = isWrapInRowAllowed
    flowAlign = getTblValue("flowAlign", params, "center")
    animation = getTblValue("animation", params)
    isVerticalAlignText = params?.isVerticalAlignText ?? false
    rows = []
  }

  let colors = [] 

  foreach (row in rows) {
    let slices = []
    let needProtectSplitLinks = (isWrapInRowAllowed && row.indexof(this.linkTags[0]) != null)
    let rawRowPieces = this.splitRowToPieces(row, needProtectSplitLinks)
    let needSplitByWords = isWrapInRowAllowed && rawRowPieces.len() > 1

    foreach (rawRowPiece in rawRowPieces) {
      if (rawRowPiece.type == HINT_PIECE_TYPE.TEXT || rawRowPiece.type == HINT_PIECE_TYPE.LINK ) {
        local piece = rawRowPiece.piece
        local carriage = 0
        local unclosedTags = 0
        local textsArray = []
        local lastIdxOfSlicedPiece = 0

        while (true) {
          let openingColorTagStartIndex = piece.indexof(this.colorTags[0], carriage)
          let closingColorTagStartIndex = piece.indexof(this.colorTags[1], carriage)

          
          if (openingColorTagStartIndex != null && closingColorTagStartIndex != null)
            carriage = min(
              openingColorTagStartIndex + this.colorTags[0].len(),
              closingColorTagStartIndex + this.colorTags[1].len()
            )
          else if (closingColorTagStartIndex != null)
            carriage = closingColorTagStartIndex + this.colorTags[1].len()
          else if (openingColorTagStartIndex != null)
            carriage = openingColorTagStartIndex + this.colorTags[0].len()
          else
            break

          
          if (openingColorTagStartIndex == null ||
            (openingColorTagStartIndex ?? -1) > (closingColorTagStartIndex ?? -1)) {
            if (unclosedTags > 0)
              unclosedTags--
            else if (colors.len() > 0) {
              let lenBefore = piece.len()
              piece = "".concat("<color=", colors.top(), ">", piece)
              carriage += piece.len() - lenBefore
            }

            if (colors.len() > 0)
              colors.pop()
            if (needSplitByWords && colors.len() == 0 && rawRowPiece.type == HINT_PIECE_TYPE.TEXT) {
              textsArray.append(piece.slice(lastIdxOfSlicedPiece, carriage))
              lastIdxOfSlicedPiece = carriage
            }
          }
          
          else if (openingColorTagStartIndex != null && openingColorTagStartIndex < (closingColorTagStartIndex ?? -1)) {
            let colorEnd = piece.indexof(">", openingColorTagStartIndex)
            let colorStart = openingColorTagStartIndex + this.colorTags[0].len()
            colors.append(piece.slice(colorStart, colorEnd))
            unclosedTags++
          }
        }

        
        for (local i = 0; i < unclosedTags; ++i)
          piece += this.colorTags[1]

        if (colors.len() > 0)
          piece = colorize(colors.top(), piece)

        if (piece.len()) {
          if (rawRowPiece.type == HINT_PIECE_TYPE.LINK || colors.len() > 0 || !needSplitByWords)
            textsArray = [piece]
          else {
            let lastPiece = piece.slice(lastIdxOfSlicedPiece, piece.len())
            if (lastPiece != "")
              textsArray.extend(lastPiece.split(" "))
          }

          slices.append(getTextSlice(textsArray))
        }
      }
      else if (rawRowPiece.type == HINT_PIECE_TYPE.TAG) {
        let tagType = g_hint_tag.getHintTagType(rawRowPiece.piece)
        slices.extend(tagType.getViewSlices(rawRowPiece.piece, params))
      }
    }

    view.rows.append({ slices = slices })
  }

  if (colors.len())
    log("unclosed <color> tag! in text:", text)

  return view
}


function findLinks(oldSlices) {
  let oldlen = oldSlices.len()
  let slices = []
  for ( local i = 0; i < oldlen; i++) {
    local oldSlice = oldSlices[i]
    if (oldSlice.type == HINT_PIECE_TYPE.TAG) {
      slices.append(oldSlice)
      continue
    }
    let linkIndex = oldSlice.piece.indexof(this.linkTags[0])
    if (linkIndex == null) {
      slices.append(oldSlice)
      continue
    }
    let linkEndIndex = oldSlice.piece.indexof(this.linkTags[1], linkIndex)
    if (linkEndIndex == null) {
      slices.append(oldSlice)
      continue
    }
    slices.append({
      type = HINT_PIECE_TYPE.TEXT,
      piece = oldSlice.piece.slice(0, linkIndex)
    })
    slices.append({
      type = HINT_PIECE_TYPE.LINK
      piece = oldSlice.piece.slice(linkIndex, linkEndIndex + this.linkTags[1].len())
    })
    slices.append({
      type = HINT_PIECE_TYPE.TEXT,
      piece = oldSlice.piece.slice(linkEndIndex + this.linkTags[1].len(), oldSlice.piece.len())
    })
  }
  return slices
}






g_hints.splitRowToPieces <- function splitRowToPieces(row, needProtectSplitLinks = false) {
  let slices = []
  while (row.len() > 0) {
    let tagStartIndex = row.indexof(this.hintTags[0])

    
    
    if (tagStartIndex == null) {
      slices.append({
        type = HINT_PIECE_TYPE.TEXT,
        piece = row
      })
      break
    }

    let tagEndIndex = row.indexof(this.hintTags[1], tagStartIndex)
    
    
    if (tagEndIndex == null) {
      slices.append({
        type = HINT_PIECE_TYPE.TEXT,
        piece = row
      })
      break
    }

    
    slices.append({
      type = HINT_PIECE_TYPE.TEXT,
      piece = row.slice(0, tagStartIndex)
    })

    
    slices.append({
      type = HINT_PIECE_TYPE.TAG
      piece = row.slice(tagStartIndex + this.hintTags[0].len(), tagEndIndex)
    })

    row = row.slice(tagEndIndex + this.hintTags[1].len())
  }

  return (needProtectSplitLinks && slices.len() > 1) ? findLinks(slices) : slices
}


::cross_call_api.getHintConfig <- @(text, params)
  g_hints.getHintSlices(text, { needConfig = true }.__update(params))

return freeze({
  g_hints
  g_hint_tag
})