from "%darg/ui_imports.nut" import *

//local {locate_element_source, sh, ph} = require("daRg")
local {format} = require("string")
local utf8 = require_optional("utf8")
local clipboard = require("daRg.clipboard")
local fieldsMap = require("inspectorViews.nut")

local shown          = persist("shown", @() Watched(false))
local wndHalign      = persist("wndHalign", @() Watched(ALIGN_RIGHT))
local pickerActive   = persist("pickerActive", @() Watched(false))
local highlight      = persist("highlight", @() Watched(null))
local animHighlight  = Watched(null)
local pickedList     = persist("pickedList", @() Watched([], FRP_DONT_CHECK_NESTED))
local viewIdx        = persist("viewIdx", @() Watched(0))

local curData        = Computed(@() pickedList.value?[viewIdx.value])

local fontSize = sh(1.5)
local valColor = Color(155,255,50)

local cursors = {
  normal = null
  pick = null
}

local function textButton(text, action, isEnabled = true) {
  local stateFlags = Watched(0)

  local override = isEnabled
    ? {
        watch = stateFlags
        onElemState = isEnabled ? @(val) stateFlags.update(val) : null
        onClick = isEnabled ? action : null
      }
    : {}

  return function() {
    local sf = stateFlags.value
    local color = !isEnabled ? Color(80, 80, 80, 200)
      : (sf & S_ACTIVE)   ? Color(100, 120, 200, 255)
      : (sf & S_HOVER)    ? Color(110, 135, 220, 255)
      : (sf & S_KB_FOCUS) ? Color(110, 135, 220, 255)
                          : Color(100, 120, 160, 255)
    return {
      rendObj = ROBJ_SOLID
      size = SIZE_TO_CONTENT
      behavior = Behaviors.Button
      focusOnClick = true
      color = color
      padding = [hdpx(5), hdpx(10)]
      children = {
        rendObj = ROBJ_DTEXT
        text = text
        color = isEnabled ? 0xFFFFFFFF : 0xFFBBBBBB
      }
    }.__update(override)
  }
}

local function mkDirBtn(text, dir) {
  local isVisible = Computed(@() pickedList.value.len() > 1)
  local isEnabled = Computed(@() (viewIdx.value + dir) in pickedList.value)
  return @() {
    watch = [isVisible, isEnabled]
    children = !isVisible.value ? null
      : textButton(text, @() isEnabled.value ? viewIdx(viewIdx.value + dir) : null, isEnabled.value)
  }
}

local invAlign = @(align) align == ALIGN_LEFT ? ALIGN_RIGHT : ALIGN_LEFT
local function panelToolbar() {
  local pickBtn = textButton("Pick", @() pickerActive(true))
  local alignBtn = textButton(wndHalign.value == ALIGN_RIGHT ? "<|" : "|>", @() wndHalign(invAlign(wndHalign.value)))
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

local mkColorCtor = @(color) @(content) {
  flow = FLOW_HORIZONTAL
  gap = sh(0.5)
  children = [
    content.__merge({ size = SIZE_TO_CONTENT })
    { rendObj = ROBJ_SOLID, size = [ph(100), ph(100)], color }
  ]
}

local mkImageCtor = @(image) @(content) {
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  children = [
    content
    {
      rendObj = ROBJ_IMAGE
      maxHeight = sh(30)
      keepAspect = true
      imageValign = ALIGN_TOP
      imageHalign = ALIGN_LEFT
      image
    }
  ]
}

local IMAGE_KEYS = ["image", "fallbackImage"]

local function getPropValueTexts(desc, key, textLimit = 0) {
  local val = desc[key]
  local tp = type(val)

  local text = null
  local valCtor = fieldsMap?[key][val]

  if (val == null) {
    text = "<null>"
  } else if (tp == "array") {
    text = ", ".join(val)
  } else if (IMAGE_KEYS.contains(key)) {
    text = val.tostring()
    valCtor = mkImageCtor(val)
  } else if (tp == "integer" && key.tolower().indexof("color") != null) {
    text = "".concat("0x", format("%16X", val).slice(8))
    valCtor = mkColorCtor(val)
  } else if (tp == "userdata" || tp == "userpointer") {
    text = "<userdata/userpointer>"
  } else {
    local s = val.tostring()
    if (textLimit <= 0)
      text = s
    else {
      text = cutText(s, textLimit)
      if (text.len() + 10 < s.len())
        valCtor = $"...({utf8?(s).charCount() ?? s.len()})"
      else
        text = s
    }
  }
  return { text, valCtor }
}

local textColor = @(sf) sf & S_ACTIVE ? 0xFFFFFF00
  : sf & S_HOVER ? 0xFF80A0FF
  : 0xFFFFFFFF

local function mkPropContent(desc, key, sf) {
  local { text, valCtor } = getPropValueTexts(desc, key, 200)
  local keyValue = $"{key.tostring()} = <color={valColor}>{text}</color>"
  if (typeof valCtor == "string")
    keyValue = $"{keyValue} {valCtor}"
  local content = {
    rendObj = ROBJ_TEXTAREA
    size = [flex(), SIZE_TO_CONTENT]
    behavior = Behaviors.TextArea
    color = textColor(sf)
    fontSize
    hangingIndent = sh(3)
    text = keyValue
  }
  if (typeof valCtor == "function")
    content = valCtor?(content)
  return content
}

local function propPanel(desc) {
  local pKeys = []
  if (typeof desc == "class")
    foreach (key, _ in desc)
      pKeys.append(key)
  else
    pKeys = desc.keys()
  pKeys.sort()

  return pKeys.map(function(k) {
    local stateFlags = Watched(0)
    return @() {
      watch = stateFlags
      size = [flex(), SIZE_TO_CONTENT]
      behavior = Behaviors.Button
      onElemState = @(sf) stateFlags(sf)
      onClick = @() clipboard.set_text(getPropValueTexts(desc, k).text)
      children = mkPropContent(desc, k, stateFlags.value)
    }
  })
}

local prepareCallstackText = @(text) //add /t for line wraps
  text.replace("/", "/\t")

local function details() {
  local res = {
    watch = curData
    size = flex()
  }
  local sel = curData.value
  if (sel == null)
    return res

  local summarySF = Watched(0)
  local summaryText = @() {
    watch = summarySF
    size = flex()
    rendObj = ROBJ_TEXTAREA
    behavior = [Behaviors.TextArea, Behaviors.WheelScroll, Behaviors.Button]
    onElemState = @(sf) summarySF(sf)
    onClick = @() clipboard.set_text(sel.locationText)
    text = prepareCallstackText(sel.locationText)
    fontSize
    color = textColor(summarySF.value)
    hangingIndent = sh(3)
  }

  local bb = sel.boundingBox
  local bbText = $"\{ pos = [{bb.x}, {bb.y}], size = [{bb.width}, {bb.height}] \}"
  local bboxSF = Watched(0)
  local bbox = @() {
    watch = bboxSF
    rendObj = ROBJ_TEXTAREA
    behavior = [Behaviors.TextArea, Behaviors.Button]
    function onElemState(sf) {
      bboxSF(sf)
      animHighlight(sf & S_HOVER ? bb : null)
    }
    onDetach = @() animHighlight(null)
    onClick = @() clipboard.set_text(bbText)
    fontSize
    color = textColor(bboxSF.value)
    text = $"bbox = <color={valColor}>{bbText}</color>"
  }

  return res.__update({
    flow = FLOW_VERTICAL
    padding = [hdpx(5), hdpx(10)]
    children = [ bbox ].extend(propPanel(sel.componentDesc)).append(summaryText)
  })
}

local help = {
  rendObj = ROBJ_TEXTAREA
  size = [flex(), SIZE_TO_CONTENT]
  behavior = Behaviors.TextArea
  vplace = ALIGN_BOTTOM
  margin = [hdpx(5), hdpx(10)]
  fontSize
  text = @"L.Ctrl + L.Shift + I - switch inspector off\nL.Ctrl + L.Shift + P - switch picker on/off"
}

local hr = {
  rendObj = ROBJ_SOLID
  color = 0x333333
  size = [flex(), hdpx(1)]
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
  gap = hr
  children = [
    panelToolbar
    details
    help
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

local function animHighlightRect() {
  local res = {
    watch = animHighlight
    animations = [{
      prop = AnimProp.opacity, from = 0.5, to = 1.0, duration = 0.5, easing = CosineFull, play = true, loop = true
    }]
  }
  local ah = animHighlight.value
  if (ah == null)
    return res
  return res.__update({
    size = [ah.width, ah.height]
    pos = [ah.x, ah.y]
    rendObj = ROBJ_FRAME
    color = 0xFFFFFFFF
    fillColor = 0x40404040
  })
}

local function elemLocationText(elem, builder) {
  local text = "Source: unknown"

  local location = locate_element_source(elem)
  if (location)
    text = $"{location.stack}\n-------\n"
  return builder ? $"{text}\n(Function)" : $"{text}\n(Table)"
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
        boundingBox = d.boundingBox
        componentDesc = d.componentDesc
        locationText = elemLocationText(d.elem, d.builder)
      }))
    viewIdx(0)
    pickerActive(false)
  }
  onChange = @(hl) highlight(hl)
  children = highlightRect
}


local function inspectorRoot() {
  local res = {
    watch = [pickerActive, shown]
    size = [sw(100), sh(100)]
    zOrder = getroottable()?.Layers.Inspector ?? 10
    skipInspection = true
  }

  if (shown.value)
    res.__update({
      cursor = cursors.normal
      children = [
        (pickerActive.value ? elementPicker : inspectorPanel),
        animHighlightRect,
        { hotkeys = [
          ["L.Ctrl L.Shift I", @() shown(false)],
          ["L.Ctrl L.Shift P", @() pickerActive(!pickerActive.value)]
        ] }
      ]
    })

  return res
}

local function toggle() {
  shown(!shown.value)
  pickerActive(false)
  pickedList([])
  viewIdx(0)
  highlight(null)
}

return {
  toggle
  root = inspectorRoot
  cursors
}
