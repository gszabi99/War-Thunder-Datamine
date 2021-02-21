local {colors} = require("style.nut")
local cursors = require("cursors.nut")
local fa = require("daRg/components/fontawesome.map.nut")

local defSize = [hdpx(20), hdpx(20)]
local function imagePic(params){
  return{
    rendObj = ROBJ_IMAGE
    image = params?.image
    size = params?.size ?? defSize
    margin = params?.imageMargin
  }
}

local function textPic(params){
  local text = params?.text
  text = params?.fa!=null ? fa[params.fa] : text
  return params.__merge({
    rendObj = ROBJ_STEXT
    text = text
    fontSize = params?.fontSize ?? (defSize[0]/1.5)
    font = params?.font ?? Fonts?.fontawesome ?? 0
    size = params?.size ?? defSize
    margin = params?.imageMargin
    halign=ALIGN_CENTER
  })
}

local function picCmp(params){
  if (params?.rendObj == ROBJ_STEXT || params?.fa!=null)
    return textPic(params)
//  if (::type(params?.image)=="array" || params?.rendObj == ROBJ_VECTOR_CANVAS)
//    return imagePic(params)
  return imagePic(params)
}

local function pictureButton(params) {
  local stateFlags = Watched(0)

  return function() {
    local color = (params?.checked || (stateFlags.value & S_ACTIVE))
                  ? colors.Active
                  : (stateFlags.value & S_HOVER)
                      ? colors.Hover
                      : Color(60,60,60,60)

    return {
      rendObj = ROBJ_SOLID
      size = SIZE_TO_CONTENT
      margin = hdpx(2)
      behavior = Behaviors.Button
      color = color
      watch = stateFlags
      onHover = params?.onHover
      cursor = cursors.normal

      children = picCmp(params)
      onClick = params?.action
      onElemState = @(sf) stateFlags.update(sf)
    }
  }
}


return pictureButton
