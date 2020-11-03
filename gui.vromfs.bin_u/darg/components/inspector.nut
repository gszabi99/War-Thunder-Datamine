local string = require("string")
local utf8 = require_optional("utf8")
local clipboard = require("darg.clipboard")


local shown          = persist("shown", @() ::Watched(false))
local wndHalign      = persist("wndHalign", @() ::Watched(ALIGN_RIGHT))
local pickerActive   = persist("pickerActive", @() ::Watched(false))
local highlight      = persist("highlight", @() ::Watched(null))
local pickedList     = persist("pickedList", @() ::Watched([]))
local viewIdx        = persist("viewIdx", @() ::Watched(0))

local curData        = ::Computed(@() pickedList.value?[viewIdx.value])

shown.subscribe(function(v) {
  pickerActive(false)
  pickedList([])
  highlight(null)
})

pickedList.subscribe(@(v) viewIdx(0))

local cursors = {
  normal = null
  pick = null
}

local function textButton(text, action, isEnabled = true) {
  local stateFlags = ::Watched(0)

  local override = isEnabled
    ? {
        watch = stateFlags
        onElemState = isEnabled ? @(val) stateFlags.update(val) : null
        onClick = isEnabled ? action : null
      }
    : {}

  return function() {
    local sf = stateFlags.value
    local color = !isEnabled ? Color(0, 0, 0, 50)
      : (sf & S_ACTIVE)   ? Color(100, 120, 200, 120)
      : (sf & S_HOVER)    ? Color(110, 110, 150, 50)
      : (sf & S_KB_FOCUS) ? Color(130, 130, 150, 120)
                          : Color(100, 120, 160, 80)
    return {
      rendObj = ROBJ_SOLID
      size = SIZE_TO_CONTENT
      behavior = Behaviors.Button
      focusOnClick = true
      color = color
      padding = 5
      children = {
        rendObj = ROBJ_DTEXT
        text = text
        color = isEnabled ? 0xFFFFFFFF : 0x40404040
      }
    }.__update(override)
  }
}

local function mkDirBtn(text, dir) {
  local isVisible = ::Computed(@() pickedList.value.len() > 1)
  local isEnabled = ::Computed(@() (viewIdx.value + dir) in pickedList.value)
  return @() {
    watch = [isVisible, isEnabled]
    children = !isVisible.value ? null
      : textButton(text, @() isEnabled.value ? viewIdx(viewIdx.value + dir) : null, isEnabled.value)
  }
}

local invAlign = @(align) align == ALIGN_LEFT ? ALIGN_RIGHT : ALIGN_LEFT
local function panelToolbar() {
  local pickBtn = textButton("Pick", @() pickerActive(true))
  local alignBtn = textButton(wndHalign.value == ALIGN_RIGHT ? "<-" : "->", @() wndHalign(invAlign(wndHalign.value)))
  local prev = mkDirBtn("Prev", -1)
  local next = mkDirBtn("Next", 1)
  return {
    watch = wndHalign
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    padding = sh(1)
    gap = sh(0.5)
    halign = invAlign(wndHalign.value)
    children = wndHalign.value == ALIGN_RIGHT
      ? [alignBtn, pickBtn, prev, next]
      : [prev, next, pickBtn, alignBtn]
  }
}

local cutText = utf8 ? @(text, num) utf8(text).slice(0, num)
  : @(text, num) text.slice(0, num)

local function getPropValueTexts(desc, key, textLimit = 0) {
  local val = desc[key]
  local tp = ::type(val)

  local text = null
  local addText = ""

  if (val == null) {
    text = "<null>"
  } else if (tp == "array") {
    text = ", ".join(val)
  } else if (tp == "integer" && key.tolower().indexof("color")!=null) {
    text = "".concat("#", string.format("%16X", val).slice(8))
  } else if (tp == "userdata" || tp == "userpointer") {
    text = "<userdata/userpointer>"
  } else {
    local s = val.tostring()
    if (textLimit <= 0)
      text = s
    else {
      text = cutText(s, textLimit)
      if (text.len() + 10 < s.len())
        addText = $"...({utf8?(s).charCount() ?? s.len()})"
      else
        text = s
    }
  }
  return { text, addText }
}

local function propValueColoredText(desc, key) {
  local { text, addText } = getPropValueTexts(desc, key, 200)
  return $"<color={Color(155,255,50)}>{text}</color>{addText}"
}

local textColor = @(sf) sf & S_ACTIVE ? 0xFFFFFF00
  : sf & S_HOVER ? 0xFF80A0FF
  : 0xFFFFFFFF

local function propPanel(desc) {
  local pKeys = desc.keys()
  pKeys.sort()

  return pKeys.map(function(k) {
    local stateFlags = Watched(0)
    return @() {
      watch = stateFlags
      size = [flex(), SIZE_TO_CONTENT]
      rendObj = ROBJ_TEXTAREA
      behavior = [Behaviors.TextArea, Behaviors.Button]
      onElemState = @(sf) stateFlags(sf)
      onClick = @() clipboard.set_text(getPropValueTexts(desc, k).text)
      text = $"{k.tostring()} = {propValueColoredText(desc, k)}"
      color = textColor(stateFlags.value)
      hangingIndent = sh(3)
    }
  })
}

local prepareCallstackText = @(text) //add /t for line wraps
  text.replace("/", "/\t")

local function details() {
  local res = { watch = curData }
  local sel = curData.value
  if (sel == null)
    return res

  local stateFlags = Watched(0)
  local summaryText = @() {
    watch = stateFlags
    size = flex()
    margin = [sh(3), 0, 0, 0]
    rendObj = ROBJ_TEXTAREA
    behavior = [Behaviors.TextArea, Behaviors.WheelScroll, Behaviors.Button]
    onElemState = @(sf) stateFlags(sf)
    onClick = @() clipboard.set_text(sel.locationText)
    text = prepareCallstackText(sel.locationText)
    color = textColor(stateFlags.value)
    hangingIndent = sh(3)
  }

  return res.__update({
    size = [flex(), flex(1)]
    rendObj = ROBJ_SOLID
    color = Color(0,0,50,200)
    flow = FLOW_VERTICAL

    children = propPanel(sel.componentDesc)
      .append(summaryText)
  })
}


local inspectorPanel = @() {
  watch = wndHalign
  rendObj = ROBJ_SOLID
  color = Color(0, 0, 50, 50)
  size = [sw(30), sh(100)]
  hplace = wndHalign.value
  behavior = Behaviors.Button
  clipChildren = true

  flow = FLOW_VERTICAL
  children = [
    panelToolbar,
    details
  ]
}


local function highlightRect() {
  local res = { watch = highlight }
  local hv = highlight.value
  if (hv == null)
    return res
  return res.__update({
    rendObj = ROBJ_SOLID
    color = Color(50, 50, 0, 50)
    pos = [hv[0].x, hv[0].y]
    size = [hv[0].w, hv[0].h]

    children = {
      rendObj = ROBJ_FRAME
      color = Color(200, 0, 0, 180)
      size = [hv[0].w, hv[0].h]
    }
  })
}

local function elemLocationText(elem, builder) {
  local text = "Source: unknown"

  local location = ::locate_element_source(elem)
  if (location)
    text = "".concat(location.stack, "\n-------\n")
  return "".concat(text, (builder ? "\n(Function)" : "\n(Table)"))
}


local elementPicker = @() {
  size = [sw(100), sh(100)]
  behavior = Behaviors.InspectPicker
  cursor = cursors.pick || cursors.normal
  rendObj = ROBJ_SOLID
  color = Color(20,0,0,20)
  onClick = function(data) {
    pickedList((data ?? [])
      .map(@(d) {
        componentDesc  = d.componentDesc
        locationText = elemLocationText(d.elem, d.builder)
      }))
    pickerActive(false)
  }
  onChange = @(hl) highlight(hl)
  children = highlightRect
}


local function inspectorRoot() {
  local res = {
    watch = [pickerActive, shown]
    size = [sw(100), sh(100)]
    zOrder = Layers.Inspector
    skipInspection = true
  }

  if (shown.value)
    res.__update({
      cursor = cursors.normal
      children = [
        (pickerActive.value ? elementPicker : inspectorPanel),
        { hotkeys = [["L.Ctrl L.Shift I", @() shown(false)]] }
      ]
    })

  return res
}


return {
  shown
  root = inspectorRoot
  cursors
}
