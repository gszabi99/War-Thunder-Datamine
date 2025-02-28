from "%scripts/dagui_natives.nut" import save_profile
from "%scripts/dagui_library.nut" import *
from "%scripts/options/optionsCtors.nut" import create_option_slider, create_option_switchbox, create_option_list

let DataBlock = require("DataBlock")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { move_mouse_on_child, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { format } = require("string")
let { round } = require("math")
let { setPostFxVignetteMultiplier, getPostFxVignetteMultiplier, getDefaultPostFxVignetteMultiplier,
      setSharpenTps, getSharpenTps, getDefaultSharpenTps,
      setSharpenGunner, getSharpenGunner, getDefaultSharpenGunner,
      setSharpenBomber, getSharpenBomber, getDefaultSharpenBomber,
      setSharpenCockpit, getSharpenCockpit, getDefaultSharpenCockpit,
      setLutTexture, getLutTexture,
      setUA, getUA, getDefaultUA,
      setUB, getUB, getDefaultUB,
      setUC, getUC, getDefaultUC,
      setUD, getUD, getDefaultUD,
      setUE, getUE, getDefaultUE,
      setUF, getUF, getDefaultUF,
      setLInvWhite, getLInvWhite, getDefaultLInvWhite,
      setUWhite, getUWhite, getDefaultUWhite,
      setTonemappingMode, getTonemappingMode, getDefaultTonemappingMode,
      useLenseFlares,
      setLenseFlareHaloPower, getLenseFlareHaloPower, getDefaultLenseFlareHaloPower,
      setLenseFlareGhostsPower, getLenseFlareGhostsPower, getDefaultLenseFlareGhostsPower,
      setLenseFlareMode, getLenseFlareMode, getDefaultLenseFlareMode,
      setIsUsingDynamicLut, getIsUsingDynamicLut,
      setEnableFilmGrain, getEnableFilmGrain } = require("postFxSettings")

let tonemappingMode_list = freeze(["#options/hudDefault", "#options/reinard", "#options/polynom", "#options/logarithm"])
let lenseFlareMode_list = freeze(["#options/disabled", "#options/enabled_in_replays", "#options/enabled_in_tps", "#options/enabled_everywhere"])

let lut_list = persist("lut_list", @() ["#options/hudDefault"])
let lut_textures = persist("lut_textures", @() [""])

const scale = 1000
const recScale = 0.001
const maxSliderSteps = 50
const firstColumnWidth = 0.45

function getLutIndexByTexture(texture) {
  foreach (index, listName in lut_textures) {
    if (listName == texture)
      return index;
  }
  return 0;
}

let getDefaultLutTexture = @() lut_textures?[0] ?? ""

function check_cur_lut_texture() {
  if (!isInArray(getLutTexture(), lut_textures))
    setLutTexture(getDefaultLutTexture())
}

gui_handlers.PostFxSettings <- class (gui_handlers.BaseGuiHandlerWT) {
  sceneBlkName = "%gui/postfxSettings.blk"

  function updateVisibility() {

    let isDynamicLut = getIsUsingDynamicLut();
    this.scene.findObject("lutTexture").show(!isDynamicLut);
    this.scene.findObject("tonemappingMode").show(!isDynamicLut);
    this.scene.findObject("L_inv_white").show(!isDynamicLut);
    this.scene.findObject("U_A").show(!isDynamicLut);
    this.scene.findObject("U_B").show(!isDynamicLut);
    this.scene.findObject("U_C").show(!isDynamicLut);
    this.scene.findObject("U_D").show(!isDynamicLut);
    this.scene.findObject("U_E").show(!isDynamicLut);
    this.scene.findObject("U_F").show(!isDynamicLut);
    this.scene.findObject("UWhite").show(!isDynamicLut);

    //lensFlare
    if (useLenseFlares()) {
      let lfm = getLenseFlareMode();
      let showLenseFlareSettings = lfm > 0;
      this.scene.findObject("lenseFlareHaloPower").show(showLenseFlareSettings);
      this.scene.findObject("lenseFlareGhostsPower").show(showLenseFlareSettings);
    }

    if (isDynamicLut)
      return;

    //tonemapping
    let tm = getTonemappingMode();

    let reinard = tm == 1;
    let polynom = tm == 2;

    this.scene.findObject("L_inv_white").show(reinard);
    this.scene.findObject("U_A").show(polynom);
    this.scene.findObject("U_B").show(polynom);
    this.scene.findObject("U_C").show(polynom);
    this.scene.findObject("U_D").show(polynom);
    this.scene.findObject("U_E").show(polynom);
    this.scene.findObject("U_F").show(polynom);
    this.scene.findObject("UWhite").show(polynom);
  }

  function updateSliderValue(name, value) {
    let valueObj = this.scene.findObject($"{name}_value")
    if (!valueObj)
      return
    let valueText = value.tostring();
    valueObj.setValue(valueText)
  }

  function createRowMarkup(name, controlMarkup) {
    let controlCell = format("td { width:t='%.3fpw'; padding-left:t='@optPad'; %s }", 1.0 - firstColumnWidth, controlMarkup)
    let res = format("tr{ id:t='%s'; td { width:t='%.3fpw'; overflow:t='hidden'; optiontext {text:t='%s'; } } %s }",
      name, firstColumnWidth,$"#options/{name}", controlCell)
    return res
  }

  function createOneSlider(name, value, cb, params, showValue) {
    params.step <- params?.step ?? max(1, round((params.max - params.min) / maxSliderSteps).tointeger())
    local markup = create_option_slider($"postfx_settings_{name}", value.tointeger(), cb, true, "slider", params)
    if (showValue)
      markup = "".concat(markup, format(" optionValueText { id:t='%s' } ", $"{name}_value"))
    markup = this.createRowMarkup(name, markup)

    let dObj = this.scene.findObject("postfx_table")
    this.guiScene.appendWithBlk(dObj, markup, this)

    if (showValue)
      this.updateSliderValue(name, value * recScale)
  }

  function createOneSpinner(name, list, value, cb) {
    local markup = create_option_list($"postfx_settings_{name}", list, value, cb, true)
    markup = this.createRowMarkup(name, markup)
    let dObj = this.scene.findObject("postfx_table")
    this.guiScene.appendWithBlk(dObj, markup, this)
  }

  function createOneCheckbox(name, defaultValue, cb) {
    local markup = create_option_switchbox({
      id = $"postfx_settings_{name}"
      value = defaultValue
      textChecked = "On"
      textUnchecked = "Off"
      cb = cb
    })
    markup = this.createRowMarkup(name, markup)
    let dObj = this.scene.findObject("postfx_table")
    this.guiScene.appendWithBlk(dObj, markup, this)
  }

  function createObjects() {
    this.createOneCheckbox("isDynamicLut", getIsUsingDynamicLut(), "onDynamicLutChanged")

    this.createOneSlider("vignette", (1 - getPostFxVignetteMultiplier()) * scale, "onVignetteChanged",
      { min = 0.01 * scale, max = scale }, false)

    this.createOneSlider("sharpenTPS", getSharpenTps() * scale, "onSharpenTpsChanged",
      { min = 0, max = 0.4 * scale }, false)
    this.createOneSlider("sharpenGunner", getSharpenGunner() * scale, "onSharpenGunnerChanged",
      { min = 0, max = 0.7 * scale }, false)
    this.createOneSlider("sharpenBomber", getSharpenBomber() * scale, "onSharpenBomberChanged",
      { min = 0, max = 0.7 * scale }, false)
    this.createOneSlider("sharpenCockpit", getSharpenCockpit() * scale, "onSharpenCockpitChanged",
      { min = 0, max = 0.7 * scale }, false)

    this.createOneSpinner("lutTexture", lut_list, getLutIndexByTexture(getLutTexture()), "onLutTextureChanged");

    if (useLenseFlares()) {
      this.createOneSpinner("lenseFlareMode", lenseFlareMode_list, getLenseFlareMode(), "onLenseFlareModeChanged")
      this.createOneSlider("lenseFlareHaloPower", getLenseFlareHaloPower() * scale, "onLenseFlareHaloPowerChanged",
        { min = 0, max = scale }, true)
      this.createOneSlider("lenseFlareGhostsPower", getLenseFlareGhostsPower() * scale, "onLenseFlareGhostsPowerChanged",
        { min = 0, max = scale }, true)
    }
    this.createOneSpinner("tonemappingMode", tonemappingMode_list, getTonemappingMode(), "onTonemappingModeChanged")
    this.createOneSlider("L_inv_white", getLInvWhite() * scale, "onLInvWhiteChanged", { min = 0, max = scale }, true)
    this.createOneSlider("U_A", getUA() * scale, "onUAChanged", { min = 0.01 * scale, max = 5 * scale }, true)
    this.createOneSlider("U_B", getUB() * scale, "onUBChanged", { min = 0.01 * scale, max = 5 * scale }, true)
    this.createOneSlider("U_C", getUC() * scale, "onUCChanged", { min = 0.01 * scale, max = 5 * scale }, true)
    this.createOneSlider("U_D", getUD() * scale, "onUDChanged", { min = 0.01 * scale, max = 5 * scale }, true)
    this.createOneSlider("U_E", getUE() * scale, "onUEChanged", { min = 0.01 * scale, max = 5 * scale }, true)
    this.createOneSlider("U_F", getUF() * scale, "onUFChanged", { min = 0.01 * scale, max = 5 * scale }, true)
    this.createOneSlider("UWhite", getUWhite() * scale, "onUWhiteChanged", { min = 0.01 * scale, max = 4 * scale }, true)

    this.createOneCheckbox("enableFilmGrain", getEnableFilmGrain(), "onFilmGrainChanged")

    this.updateVisibility();
  }

  function setValue(name, value) {
    let sliderObj = this.scene.findObject(name);
    if (checkObj(sliderObj))
      sliderObj.setValue(value);
  }
  function getValue(name) {
    let sliderObj = this.scene.findObject(name);
    return sliderObj.getValue();
  }

  function initScreen() {
    //change shader variables
    setTonemappingMode(getTonemappingMode());
    if (useLenseFlares())
      setLenseFlareMode(getLenseFlareMode());

    this.createObjects();
    move_mouse_on_child(this.scene.findObject("postfx_table"), 0)
  }

  function onResetToDefaults(_obj) {
    this.setValue("postfx_settings_vignette", getDefaultPostFxVignetteMultiplier() * scale);
    this.setValue("postfx_settings_sharpenTPS", getDefaultSharpenTps() * scale);
    this.setValue("postfx_settings_sharpenGunner", getDefaultSharpenGunner() * scale);
    this.setValue("postfx_settings_sharpenBomber", getDefaultSharpenBomber() * scale);
    this.setValue("postfx_settings_sharpenCockpit", getDefaultSharpenCockpit() * scale);
    this.setValue("postfx_settings_L_inv_white", getDefaultLInvWhite() * scale);
    this.setValue("postfx_settings_U_A", getDefaultUA() * scale);
    this.setValue("postfx_settings_U_B", getDefaultUB() * scale);
    this.setValue("postfx_settings_U_C", getDefaultUC() * scale);
    this.setValue("postfx_settings_U_D", getDefaultUD() * scale);
    this.setValue("postfx_settings_U_E", getDefaultUE() * scale);
    this.setValue("postfx_settings_U_F", getDefaultUF() * scale);
    this.setValue("postfx_settings_UWhite", getDefaultUWhite() * scale);
    this.setValue("postfx_settings_lutTexture", getLutIndexByTexture(getDefaultLutTexture()));
    this.setValue("postfx_settings_tonemappingMode", getDefaultTonemappingMode());
    this.setValue("postfx_settings_isDynamicLut", true);
    if (useLenseFlares()) {
      this.setValue("postfx_settings_lenseFlareMode", getDefaultLenseFlareMode());
      this.setValue("postfx_settings_lenseFlareHaloPower", getDefaultLenseFlareHaloPower() * scale);
      this.setValue("postfx_settings_lenseFlareGhostsPower", getDefaultLenseFlareGhostsPower() * scale);
    }
    this.setValue("postfx_settings_enableFilmGrain", false);

    setPostFxVignetteMultiplier(getDefaultPostFxVignetteMultiplier());
    setSharpenTps(getDefaultSharpenTps());
    setSharpenGunner(getDefaultSharpenGunner());
    setSharpenBomber(getDefaultSharpenBomber());
    setSharpenCockpit(getDefaultSharpenCockpit());
    setLInvWhite(getDefaultLInvWhite());
    setUA(getDefaultUA(), true);
    setUB(getDefaultUB(), true);
    setUC(getDefaultUC(), true);
    setUD(getDefaultUD(), true);
    setUE(getDefaultUE(), true);
    setUF(getDefaultUF(), true);
    setUWhite(getDefaultUWhite(), true);
    setLutTexture(getDefaultLutTexture());
    setIsUsingDynamicLut(true); // need to be before setTonemappingMode
    setTonemappingMode(getDefaultTonemappingMode());
    if (useLenseFlares()) {
      setLenseFlareMode(getDefaultLenseFlareMode());
      setLenseFlareHaloPower(getDefaultLenseFlareHaloPower());
      setLenseFlareGhostsPower(getDefaultLenseFlareGhostsPower());
    }
    setEnableFilmGrain(false);
  }

  function goBack() {
    save_profile(false);
    base.goBack();
  }

  function onDynamicLutChanged(obj) {
    if (!obj)
      return;

    setIsUsingDynamicLut(obj.getValue()); //need to be set first
    setTonemappingMode(getTonemappingMode());
    this.updateVisibility();
  }
  function onVignetteChanged(obj) {
    if (!obj)
      return;
    setPostFxVignetteMultiplier(1 - obj.getValue() * recScale);
  }
  function onSharpenTpsChanged(obj) {
    if (!obj)
      return;
    setSharpenTps(obj.getValue() * recScale);
  }
  function onSharpenGunnerChanged(obj) {
    if (!obj)
      return;
    setSharpenGunner(obj.getValue() * recScale);
  }
  function onSharpenBomberChanged(obj) {
    if (!obj)
      return;
    setSharpenBomber(obj.getValue() * recScale);
  }
  function onSharpenCockpitChanged(obj) {
    if (!obj)
      return;
    setSharpenCockpit(obj.getValue() * recScale);
  }

  function onLutTextureChanged(obj) {
    if (!obj)
      return;
    setLutTexture(lut_textures[obj.getValue()]);
  }

  function onLenseFlareModeChanged(obj) {
    if (!obj)
      return;
    setLenseFlareMode(obj.getValue());

    this.updateVisibility();
  }
  function onLenseFlareHaloPowerChanged(obj) {
    if (!obj)
      return;
    setLenseFlareHaloPower(obj.getValue() * recScale);
    this.updateSliderValue("lenseFlareHaloPower", obj.getValue() * recScale)
  }
  function onLenseFlareGhostsPowerChanged(obj) {
    if (!obj)
      return;
    setLenseFlareGhostsPower(obj.getValue() * recScale);
    this.updateSliderValue("lenseFlareGhostsPower", obj.getValue() * recScale)
  }

  function onTonemappingModeChanged(obj) {
    if (!obj)
      return;
    setTonemappingMode(obj.getValue());

    this.updateVisibility();
  }
  function onLInvWhiteChanged(obj) {
    if (!obj)
      return;
    setLInvWhite(obj.getValue() * recScale);
    this.updateSliderValue("L_inv_white", obj.getValue() * recScale)
  }

  function onUAChanged(obj) {
    if (!obj)
      return;
    setUA(obj.getValue() * recScale, true);
    this.updateSliderValue("U_A", obj.getValue() * recScale)
  }
  function onUBChanged(obj) {
    if (!obj)
      return;
    setUB(obj.getValue() * recScale, true);
    this.updateSliderValue("U_B", obj.getValue() * recScale)
  }
  function onUCChanged(obj) {
    if (!obj)
      return;
    setUC(obj.getValue() * recScale, true);
    this.updateSliderValue("U_C", obj.getValue() * recScale)
  }
  function onUDChanged(obj) {
    if (!obj)
      return;
    setUD(obj.getValue() * recScale, true);
    this.updateSliderValue("U_D", obj.getValue() * recScale)
  }
  function onUEChanged(obj) {
    if (!obj)
      return;
    setUE(obj.getValue() * recScale, true);
    this.updateSliderValue("U_E", obj.getValue() * recScale)
  }
  function onUFChanged(obj) {
    if (!obj)
      return;
    setUF(obj.getValue() * recScale, true);
    this.updateSliderValue("U_F", obj.getValue() * recScale)
  }
  function onUWhiteChanged(obj) {
    if (!obj)
      return;
    setUWhite(obj.getValue() * recScale, true);
    this.updateSliderValue("UWhite", obj.getValue() * recScale)
  }
  function onFilmGrainChanged(obj) {
    if (!obj)
      return;
    setEnableFilmGrain(obj.getValue());
  }
}

function init_postfx() {
  let blk = DataBlock()
  blk.load("config/postFxOptions.blk")
  if (blk?.lut_list) {
    lut_list.clear()
    lut_textures.clear()
    foreach (lut in (blk.lut_list % "lut")) {
      lut_list.append("".concat("#options/", lut.getStr("id", "")))
      lut_textures.append(lut.getStr("texture", ""))
    }
    check_cur_lut_texture()
  }
}


return {
  init_postfx
  guiStartPostfxSettings = @() handlersManager.loadHandler(gui_handlers.PostFxSettings)
}