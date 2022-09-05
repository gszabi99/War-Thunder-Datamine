from "daRg" import *

let function image(val, params={}, addchildren = null) {

  local children = params?.children
  if (children && type(children) !="array")
    children = [children]
  if (addchildren && children) {
    if (type(addchildren)=="array")
      children.extend(addchildren)
    else
      children.append(addchildren)
  }

  if (type(val)=="string")
    val=Picture(val) //handle svg here!!

  return {
    rendObj = ROBJ_IMAGE
    image = val
    size=SIZE_TO_CONTENT
  }.__update(params, {children})
}

return image