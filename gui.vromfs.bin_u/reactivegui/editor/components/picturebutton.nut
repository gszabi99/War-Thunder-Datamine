local {colors} = require("style.nut")
local cursors = require("cursors.nut")
//local {encodeString} = require("base64")
local defSize = [hdpx(21), hdpx(21)]
local {endswith} = require("string")

/*
local function createBISvg(name, size=null){
  size = size ?? defSize
  if (name != null)
    name = encodeString(name)
  return ::Picture($"b64://{name}.svg:{size[0]}:{size[1]}:K")
}

local function builtinSvgPic(params){
  return{
    rendObj = ROBJ_IMAGE
    image = createBISvg(params?.builtinSvgName)
    size = params?.size ?? defSize
    margin = params?.imageMargin
  }
}
*/

local function imagePic(params){
  local image = params?.image
  local size = params?.size ?? defSize

  if (endswith(image, ".svg"))
    image = $"{image}:{size[0]}:{size[1]}"
  image = ::Picture(image)
  return{
    rendObj = ROBJ_IMAGE
    image
    size
    margin = params?.imageMargin
  }
}

local function canvasPic(params){
  return{
    rendObj = ROBJ_VECTOR_CANVAS
    image = params?.image
    size = params?.size ?? defSize
    margin = params?.imageMargin
  }.__update(params?.canvasObj ?? {})
}

local function picCmp(params){
  //if (params?.builtinSvgName != null)
  //  return builtinSvgPic(params)
  if (params?.canvasObj)
    return canvasPic(params)
  return imagePic(params)
}

local function pictureButton(params) {
  local stateFlags = Watched(0)

  return function() {
    local color = (params?.checked || (stateFlags.value & S_ACTIVE))
                  ? colors.Active
                  : (stateFlags.value & S_HOVER)
                      ? colors.Hover
                      : Color(130,130,130,250)

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
