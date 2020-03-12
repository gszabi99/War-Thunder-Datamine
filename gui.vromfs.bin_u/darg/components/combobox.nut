local comboStyle = require("combobox.style.nut")


local function combobox(watches, options, combo_style=comboStyle) {
  local comboOpen = ::Watched(false)
  local group = ::ElemGroup()
  local stateFlags = ::Watched(0)
  local doClose = @() comboOpen.update(false)
  local wdata, wdisable, wupdate
  local dropDirDown = combo_style?.dropDir != "up"
  local itemHeight = options.len() > 0 ? ::calc_comp_size(combo_style.listItem(options[0], @() null, false))[1] : sh(5)
  local itemGapHt = ::calc_comp_size(combo_style?.itemGap)[1]
  if (type(watches) == "table") {
    wdata = watches.value
    wdisable = watches?.disable ?? {value=false}
    wupdate = watches?.update ?? @(v) wdata(v)
  } else {
    wdata = watches
    wdisable = {value=false}
    wupdate = @(v) wdata(v)
  }

  local function dropdownList() {
    local xmbNodes = options.map(@(_) ::XmbNode())
    local curXmbNode = xmbNodes?[0]
    local children = options.map(function(item, idx) {
      local value
      local text
      local isCurrent
      local tp = type(item)

      if (tp == "array") {
        value = item[0]
        text  = item[1]
        isCurrent = wdata.value==value
      } else if (tp == "instance") {
        value = item.value()
        text  = item.tostring()
        isCurrent = item.isCurrent()
      } else {
        value = item
        text = value.tostring()
        isCurrent = wdata.value==value
      }

      if (isCurrent)
        curXmbNode = xmbNodes[idx]

      local function handler() {
        wupdate(value)
        comboOpen.update(false)
      }
      return combo_style.listItem(text, handler, isCurrent, { xmbNode = xmbNodes[idx] })
    })


    local overlay = {
      pos = [-9000, -9000]
      size = [19999, 19999]
      behavior = Behaviors.ComboPopup
      eventPassThrough = true
      onClick = doClose
    }

    local baseButtonOverride = combo_style.closeButton(doClose)

    local popupContent = {
      size = [flex(), SIZE_TO_CONTENT]
      rendObj = ROBJ_BOX
      fillColor = combo_style?.popupBgColor ?? Color(10,10,10)
      borderColor = combo_style?.popupBdColor ?? Color(80,80,80)
      borderWidth = combo_style?.popupBorderWidth ?? 0
      padding = combo_style?.popupBorderWidth ?? 0
      stopMouse = true
      clipChildren = true
      xmbNode = ::XmbContainer({ canFocus = @() false })
      children = {
        behavior = Behaviors.WheelScroll
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
      animations = [
        { prop=AnimProp.opacity, from=0, to=1, duration=0.12, play=true, easing=InOutQuad }
        { prop=AnimProp.scale, from=[1,0], to=[1,1], duration=0.12, play=true, easing=InOutQuad }
      ]
    }.__update(combo_style?.mkHandlers(curXmbNode) ?? {})

    local popupWrapper = {
      size = flex()
      flow = FLOW_VERTICAL
      vplace = dropDirDown ? ALIGN_TOP : ALIGN_BOTTOM
      valign = dropDirDown ? ALIGN_TOP : ALIGN_BOTTOM
      //rendObj = ROBJ_SOLID
      //color = Color(0,100,0,50)
      children = [
        {size = [flex(), ph(100)]}
        {size = [flex(), hdpx(2)]}
        popupContent
      ]
    }

    if (!dropDirDown) {
      popupWrapper.children.reverse()
    }

    return {
      zOrder = Layers.ComboPopup
      size = flex()
      children = [
        overlay
        baseButtonOverride
        popupWrapper
      ]
      transform = { pivot=[0.5, dropDirDown ? 1.1 : -0.1]}
      animations = [
        { prop=AnimProp.opacity, from=1, to=0, duration=0.15, playFadeOut=true}
        { prop=AnimProp.scale, from=[1,1], to=[1,0], duration=0.15, playFadeOut=true, easing=OutQuad}
      ]
    }
  }

  local function combo() {
    local curValue = wdata.value
    local labelText = curValue!=null ? curValue.tostring() : ""
    foreach (item in options) {
      local tp = type(item)
      if (tp == "array") {
        if (item[0] == curValue) { labelText = item[1]; break }
      } else if (tp == "instance") {
        if (item.isCurrent()) { labelText = item.tostring(); break }
      } else if (item == curValue)
        break
    }

    local children = (combo_style?.rootCtor !=null) ?
      [
        combo_style.rootCtor({group=group, stateFlags=stateFlags, disabled=wdisable.value, comboOpen=comboOpen, text=labelText})
      ]
    :
      [
        combo_style.label(labelText, group, {disabled=wdisable.value})
      ]

    if (comboOpen.value && !wdisable.value) {
      children.append(dropdownList)
    }

    local clickHandler = wdisable.value ? null : @() comboOpen.update(!comboOpen.value)

    local desc = (combo_style?.root ?? {}).__merge({
      size = flex()
      //behavior = wdisable.value ? null : Behaviors.Button
      behavior = Behaviors.Button
      watch = [comboOpen, watches?.disable, wdata]
      group = group
      onElemState=@(sf) stateFlags(sf)

      children = children
      onClick = wdisable.value ? null : clickHandler
    })

    return desc
  }

  return combo
}


return combobox
