local comboStyle = require("combobox.style.nut")
local {isTouch} = require("ui/control/active_controls.nut")

local popupContentAnim = [
  { prop=AnimProp.opacity, from=0, to=1, duration=0.12, play=true, easing=InOutQuad }
  { prop=AnimProp.scale, from=[1,0], to=[1,1], duration=0.12, play=true, easing=InOutQuad }
]

local popupWrapperAnim = [
  { prop=AnimProp.opacity, from=1, to=0, duration=0.15, playFadeOut=true}
  { prop=AnimProp.scale, from=[1,1], to=[1,0], duration=0.15, playFadeOut=true, easing=OutQuad}
]


local function itemToOption(item, wdata){
  local tp = ::type(item)
  local value
  local text
  local isCurrent
  if (tp == "array") {
    value = item[0]
    text  = item[1]
    isCurrent = wdata.value==value
  } else if (tp == "instance") {
    value = item.value()
    text  = item.tostring()
    isCurrent = item.isCurrent()
  } else if (item == null) {
    value = null
    text = "NULL"
    isCurrent = false
  } else {
    value = item
    text = value.tostring()
    isCurrent = wdata.value==value
  }
  return {
    value
    isCurrent
    text
  }
}


local function findCurOption(opts, wdata){
  local found
  foreach (item in opts) {
    local f = itemToOption(item, wdata)
    local {value, isCurrent} = f
    if (wdata.value == value || isCurrent) {
      found = f
      break
    }
  }
  return found!=null ? found : itemToOption(opts?[0], wdata)
}


local function setValueByOptions(opts, wdata, wupdate){
  wupdate(findCurOption(opts, wdata).value)
}


local function popupWrapper(popupContent, dropDirDown) {
  local align = dropDirDown ? ALIGN_TOP : ALIGN_BOTTOM
  local children = [
    {size = [flex(), ph(100)]}
    {size = [flex(), hdpx(2)]}
    popupContent
  ]

  if (!dropDirDown)
    children.reverse()

  return {
    size = flex()
    flow = FLOW_VERTICAL
    vplace = align
    valign = align
    //rendObj = ROBJ_SOLID
    //color = Color(0,100,0,50)
    children
  }
}


local function dropdownBgOverlay(onClick) {
  return {
    pos = [-9000, -9000]
    size = [19999, 19999]
    behavior = Behaviors.ComboPopup
    eventPassThrough = true
    onClick
  }
}


local function combobox(watches, options, combo_style=comboStyle) {
  if (::type(options)!="instance")
    options = ::Watched(options)

  local comboOpen = ::Watched(false)
  local group = ::ElemGroup()
  local stateFlags = ::Watched(0)
  local doClose = @() comboOpen.update(false)
  local wdata, wdisable, wupdate
  local dropDirDown = combo_style?.dropDir != "up"
  local itemHeight = options.value.len() > 0 ? ::calc_comp_size(combo_style.listItem(options.value[0], @() null, false))[1] : sh(5)
  local itemGapHt = ::calc_comp_size(combo_style?.itemGap)[1]
  local changeVarOnListUpdate = true
  local xmbNode = combo_style?.xmbNode ?? ::XmbNode()

  if (type(watches) == "table") {
    wdata = watches.value
    wdisable = watches?.disable ?? {value=false}
    wupdate = watches?.update ?? @(v) wdata(v)
    changeVarOnListUpdate = watches?.changeVarOnListUpdate ?? true
  } else {
    wdata = watches
    wdisable = {value=false}
    wupdate = @(v) wdata(v)
  }

  if (changeVarOnListUpdate)
    options.subscribe(@(opts) setValueByOptions(opts, wdata, wupdate))


  local function dropdownList() {
    local xmbNodes = options.value.map(@(_) ::XmbNode())
    local curXmbNode = xmbNodes?[0]
    local children = options.value.map(function(item, idx) {
      local {value, text, isCurrent} = itemToOption(item, wdata)
      if (isCurrent)
        curXmbNode = xmbNodes[idx]

      local function handler() {
        wupdate(value)
        comboOpen.update(false)
      }
      return combo_style.listItem(text, handler, isCurrent, { xmbNode = xmbNodes[idx] })
    })

    local onAttach = null
    local onDetach = null
    if (combo_style?.onOpenDropDown)
      onAttach = @() combo_style.onOpenDropDown(curXmbNode)
    if (combo_style?.onCloseDropDown)
      onDetach = @() combo_style.onCloseDropDown(xmbNode)

    local popupContent = {
      size = [flex(), SIZE_TO_CONTENT]
      rendObj = ROBJ_BOX
      fillColor = combo_style?.popupBgColor ?? Color(10,10,10)
      borderColor = combo_style?.popupBdColor ?? Color(80,80,80)
      borderWidth = combo_style?.popupBorderWidth ?? 0
      padding = combo_style?.popupBorderWidth ?? 0
      stopMouse = true
      clipChildren = true
      xmbNode = ::XmbContainer()
      children = {
        behavior = [Behaviors.WheelScroll, Behaviors.TouchScroll]
        joystickScroll = true
        flow = FLOW_VERTICAL
        children = children
        gap = combo_style?.itemGap
        size = [flex(), SIZE_TO_CONTENT]
        maxHeight = itemHeight*10.5 + itemGapHt*9 //this is ugly workaround with overflow of combobox size
        //we need something much more clever - we need understand how close we to the bottom\top of the screen and set limit to make all elements visible
      }

      transform = {
        pivot = [0.5, dropDirDown ? 0 : 1]
      }
      animations = popupContentAnim
      onAttach
      onDetach
    }


    return {
      zOrder = Layers.ComboPopup
      size = flex()
      watch = options
      children = [
        dropdownBgOverlay(doClose)
        combo_style.closeButton(doClose)
        popupWrapper(popupContent, dropDirDown)
      ]
      transform = { pivot=[0.5, dropDirDown ? 1.1 : -0.1]}
      animations = popupWrapperAnim
    }
  }

  if (changeVarOnListUpdate)
    wdata.subscribe(@(_) setValueByOptions(options.value, wdata, wupdate))


  return function combo() {
    local labelText = findCurOption(options.value, wdata).text
    local showDropdown = comboOpen.value && !wdisable.value
    local children = [
      combo_style.boxCtor({group, stateFlags, disabled=wdisable.value, comboOpen, text=labelText}),
      showDropdown ? dropdownList : null
    ]

    local onClick = wdisable.value ? null : @() comboOpen.update(!comboOpen.value)

    return (combo_style?.rootBaseStyle ?? {}).__merge({
      size = flex()
      //behavior = wdisable.value ? null : Behaviors.Button
      behavior = Behaviors.Button
      eventPassThrough = isTouch.value
      watch = [comboOpen, watches?.disable, wdata, options]
      group
      onElemState = @(sf) stateFlags(sf)

      children
      onClick
      xmbNode
    })
  }
}


return combobox
