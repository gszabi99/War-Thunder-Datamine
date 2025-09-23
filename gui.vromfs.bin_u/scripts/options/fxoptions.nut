from "%scripts/dagui_library.nut" import *
from "%scripts/options/optionsCtors.nut" import create_option_slider

let { save_profile } = require("chard")
let { BaseGuiHandler } = require("%sqDagui/framework/baseGuiHandler.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")

let { getPaperWhiteNits, setPaperWhiteNits, getDefaultPaperWhiteNits,
  getHdrBrightness, setHdrBrightness, getDefaultHdrBrightness,
  getHdrShadows, setHdrShadows, getDefaultHdrShadows, isHdrEnabled } = require("graphicsOptions")

const LOCAL_PATH_SHOWED_HDR_ON_START = "isShowedHdrSettingsOnStart"

let hdrSettingsConfig = [
  { id = "paper_white_nits", minVal = 1, maxVal = 10 step = 5, scale = 50,
    getter = getPaperWhiteNits, setter = setPaperWhiteNits, defgetter = getDefaultPaperWhiteNits }, 

  { id = "hdr_brightness", minVal = 0.5, maxVal = 2, step = 1, scale = 10, recScale = true,
    getter = getHdrBrightness, setter = setHdrBrightness, defgetter = getDefaultHdrBrightness }, 

  { id = "hdr_shadows", minVal = 0, maxVal = 2, step = 1, scale = 10, recScale = true,
    getter = getHdrShadows, setter = setHdrShadows, defgetter = getDefaultHdrShadows }
]

gui_handlers.fxOptions <- class (BaseGuiHandler) {
  sceneTplName = "%gui/options/fxOptions.tpl"
  headerText = "#mainmenu/btnHdrSettings"

  LOCAL_PATH_SHOWED_ON_START = null

  






  settings = null

  function getSceneTplView() {
    let view = {
      headerText = this.headerText
      rows = []
    }

    foreach (_idx, s in this.settings) {
      let { id, minVal, maxVal, scale, step, getter, recScale = false } = s
      local val = getter()
      if (recScale)
        val *= scale

      let ctorParams = { min = minVal * scale, max = maxVal * scale, step }
      view.rows.append({
        id
        option = create_option_slider(id, val.tointeger(), "onSettingChanged", true, "slider", ctorParams)
        leftInfoRows = [{
          label = $"#options/{id}"
          leftInfoWidth = "0.45pw"
        }]
      })
    }

    return view
  }

  function initScreen() {
    foreach (s in this.settings)
      this.onSettingChanged(this.scene.findObject(s.id))
  }

  function onSettingChanged(obj) {
    if (!checkObj(obj))
      return

    let curSetting = this.settings.findvalue(@(s) s.id == obj.id)
    if (!curSetting)
      return

    local val = obj.getValue().tofloat()
    if (curSetting?.recScale)
      val /= curSetting.scale

    this.updateSliderTextValue(obj.id, val)
    curSetting.setter(val, true)
  }

  function onResetToDefaults() {
    foreach (s in this.settings) {
      local defVal = s.defgetter()
      s.setter(defVal, true)
      this.updateSliderTextValue(s.id, defVal)
      if (s?.recScale)
        defVal *= s.scale

      defVal = defVal.tointeger()
      this.updateSliderValue(s.id, defVal)
    }
  }

  function updateSliderValue(name, value) {
    let valueObj = this.scene.findObject(name)
    if (checkObj(valueObj))
      valueObj.setValue(value)
  }

  function updateSliderTextValue(name, value) {
    let valueObj = this.scene.findObject($"value_{name}")
    if (checkObj(valueObj))
      valueObj.setValue(value.tostring())
  }

  function goBack() {
    save_profile(false)
    if (this.LOCAL_PATH_SHOWED_ON_START != null)
      saveLocalByAccount(this.LOCAL_PATH_SHOWED_ON_START, true)
    base.goBack()
  }
}

function openHdrSettings() {
  let openedHdrSettings = handlersManager.findHandlerClassInScene(gui_handlers.fxOptions)
  if (openedHdrSettings != null)
    return

  handlersManager.loadHandler(gui_handlers.fxOptions, {
    settings = hdrSettingsConfig
    LOCAL_PATH_SHOWED_ON_START = LOCAL_PATH_SHOWED_HDR_ON_START
  })
}

return {
  openHdrSettings
  needShowHdrSettingsOnStart = @() isHdrEnabled() && !loadLocalByAccount(LOCAL_PATH_SHOWED_HDR_ON_START, false)
}