let { format } = require("string")
let string = require("%sqstd/string.nut")
let u = require("%sqStdLibs/helpers/u.nut")

const SHARPEN_SMALL_ICONS = 1.25

local intIconToString = @(id) ""
local getIconPath = @(icon) icon
local getConfig = @() null

let class BhvAvatar
{
  eventMask    = ::EV_ON_CMD
  valuePID     = ::dagui_propid.add_name_id("value")
  isFullPID    = ::dagui_propid.add_name_id("isFull")

  function onAttach(obj)
  {
    this.setIsFull(obj, obj?.isFull == "yes")
    if (obj?.value)
      this.setStringValue(obj, this.validateStrValue(obj.value))
    this.updateView(obj)
    return ::RETCODE_NOTHING
  }

  function validateStrValue(strValue)
  {
    if (strValue in getConfig())
      return strValue
    if (string.isStringInteger(strValue))
      return intIconToString(strValue.tointeger())
    return strValue
  }

  function isFull(obj) { return !!obj.getIntProp(this.isFullPID, 0) }
  function setIsFull(obj, newIsFull)
  {
    if (newIsFull == this.isFull(obj))
      return false
    obj.setIntProp(this.isFullPID, newIsFull ? 1 : 0)
    return true
  }

  function setStringValue(obj, strValue)
  {
    if (obj?.value == strValue)
      return false
    obj.value = strValue
    return true
  }

  function setValue(obj, newValue)
  {
    local shouldUpdate = false
    if (u.isBool(newValue))
      shouldUpdate = this.setIsFull(obj, newValue)
    else if (u.isInteger(newValue))
      shouldUpdate = this.setStringValue(obj, intIconToString(newValue))
    else if (u.isString(newValue))
      shouldUpdate = this.setStringValue(obj, newValue)

    if (shouldUpdate)
      this.updateView(obj)
  }

  function updateView(obj)
  {
    let image = obj?.value ?? ""
    let hasImage = image != ""
    obj.set_prop_latent("background-image", hasImage ? getIconPath(image) : "")
    obj.set_prop_latent("background-color", hasImage ? "#FFFFFFFF" : "#00000000")
    if (!hasImage)
      return

    if (this.isFull(obj))
    {
      obj.set_prop_latent("background-repeat",  "stretch")
      obj.set_prop_latent("background-position", "0")
      obj.set_prop_latent("background-svg-size", "pw,ph")
      obj.updateRendElem()
      return
    }

    let imgBlk = getConfig()?[image]
    let size = clamp(imgBlk?.size || 1.0, 0.01, 1.0)
    let x = imgBlk?.pos?.x ?? 0.0
    let y = imgBlk?.pos?.y ?? 0.0
    let texSize = SHARPEN_SMALL_ICONS / size
    obj.set_prop_latent("background-repeat",  "part")
    obj.set_prop_latent("background-position",
      format("%d,%d,%d,%d",
        (1000 * x).tointeger(), (1000 * y).tointeger(),
        (1000 * (1.0 - x - size)).tointeger(), (1000 * (1.0 - y - size)).tointeger()
    ))
    obj.set_prop_latent("background-svg-size", format("%.3fpw,%.3fph", texSize, texSize))
    obj.updateRendElem()
  }
}

::replace_script_gui_behaviour("bhvAvatar", BhvAvatar)

return {
  init = function(params) {
    intIconToString   = params?.intIconToString   ?? intIconToString
    getIconPath       = params?.getIconPath       ?? getIconPath
    getConfig         = params?.getConfig         ?? getConfig
  }

  getCurParams = @() {
    intIconToString
    getIconPath
    getConfig
  }

  forceUpdateView = @(obj) BhvAvatar.updateView.call(BhvAvatar, obj)
}