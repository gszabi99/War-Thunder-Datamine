let { format } = require("string")
::tonemappingMode_list <- ["#options/hudDefault", "#options/reinard", "#options/polynom", "#options/logarithm"];
::lut_list <- ["#options/hudDefault"];
::lut_textures <- [""];
::lenseFlareMode_list <- ["#options/disabled", "#options/enabled_in_replays", "#options/enabled_in_tps", "#options/enabled_everywhere"];

::g_script_reloader.registerPersistentData("PostFxGlobals", ::getroottable(),
  [
    "lut_list", "lut_textures"
  ])

const scale = 1000
const recScale = 0.001
const maxSliderSteps = 50
const firstColumnWidth = 0.45

::get_lut_index_by_texture <- function get_lut_index_by_texture(texture)
{
  foreach(index, listName in ::lut_textures)
  {
    if (listName == texture)
      return index;
  }
  return 0;
}

::get_default_lut_texture <- function get_default_lut_texture()
{
  return ::getTblValue(0, ::lut_textures, "")
}

::check_cur_lut_texture <- function check_cur_lut_texture()
{
  if (!::isInArray(::get_lut_texture(), ::lut_textures))
    ::set_lut_texture(::get_default_lut_texture())
}

::gui_handlers.PostFxSettings <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName = "%gui/postfxSettings.blk"

  function updateVisibility()
  {
    //tonemapping
    let tm = ::get_tonemappingMode();

    let reinard = tm == 1;
    let polynom = tm == 2;

    scene.findObject("L_inv_white").show(reinard);
    scene.findObject("U_A").show(polynom);
    scene.findObject("U_B").show(polynom);
    scene.findObject("U_C").show(polynom);
    scene.findObject("U_D").show(polynom);
    scene.findObject("U_E").show(polynom);
    scene.findObject("U_F").show(polynom);
    scene.findObject("UWhite").show(polynom);

    //lensFlare
    if (::use_lense_flares())
    {
      let lfm = ::get_lenseFlareMode();
      let showLenseFlareSettings = lfm > 0;
      scene.findObject("lenseFlareHaloPower").show(showLenseFlareSettings);
      scene.findObject("lenseFlareGhostsPower").show(showLenseFlareSettings);
    }
  }

  function updateSliderValue(name, value)
  {
    let valueObj = scene.findObject(name+"_value")
    if (!valueObj) return
    let valueText = value.tostring();
    valueObj.setValue(valueText)
  }

  function createRowMarkup(name, controlMarkup)
  {
    let controlCell = format("td { width:t='%.3fpw'; padding-left:t='@optPad'; %s }", 1.0 - firstColumnWidth, controlMarkup)
    let res = format("tr{ id:t='%s'; td { width:t='%.3fpw'; overflow:t='hidden'; optiontext {text:t='%s'; } } %s }",
      name, firstColumnWidth, "#options/" + name, controlCell)
    return res
  }

  function createOneSlider(name, value, cb, params, showValue)
  {
    params.step <- params?.step ?? max(1, ::round((params.max - params.min) / maxSliderSteps).tointeger())
    local markuo = ::create_option_slider("postfx_settings_" + name, value.tointeger(), cb, true, "slider", params)
    if (showValue)
      markuo += format(" optionValueText { id:t='%s' } ", name+"_value");
    markuo = createRowMarkup(name, markuo)

    let dObj = scene.findObject("postfx_table")
    guiScene.appendWithBlk(dObj, markuo, this)

    if (showValue)
      updateSliderValue(name, value * recScale)
  }

  function createOneSpinner(name, list, value, cb)
  {
    local markuo = ::create_option_list("postfx_settings_" + name, list, value, cb, true)
    markuo = createRowMarkup(name, markuo)
    let dObj = scene.findObject("postfx_table")
    guiScene.appendWithBlk(dObj, markuo, this)
  }

  function createObjects()
  {
    createOneSlider("vignette", (1 - ::get_postfx_vignette_multiplier()) * scale, "onVignetteChanged",
      { min = 0.01 * scale, max = scale }, false)

    createOneSlider("sharpenTPS", ::get_sharpenTPS() * scale, "onSharpenTPSChanged",
      { min = 0, max = 0.4 * scale }, false)
    createOneSlider("sharpenGunner", ::get_sharpenGunner() * scale, "onSharpenGunnerChanged",
      { min = 0, max = 0.7 * scale }, false)
    createOneSlider("sharpenBomber", ::get_sharpenBomber() * scale, "onSharpenBomberChanged",
      { min = 0, max = 0.7 * scale }, false)
    createOneSlider("sharpenCockpit", ::get_sharpenCockpit() * scale, "onSharpenCockpitChanged",
      { min = 0, max = 0.7 * scale }, false)

    createOneSpinner("lutTexture", ::lut_list, get_lut_index_by_texture(::get_lut_texture()), "onLutTextureChanged");

    if (::use_lense_flares())
    {
      createOneSpinner("lenseFlareMode", ::lenseFlareMode_list, ::get_lenseFlareMode(), "onLenseFlareModeChanged")
      createOneSlider("lenseFlareHaloPower", ::get_lenseFlareHaloPower() * scale, "onLenseFlareHaloPowerChanged",
        { min = 0, max = scale }, true)
      createOneSlider("lenseFlareGhostsPower", ::get_lenseFlareGhostsPower() * scale, "onLenseFlareGhostsPowerChanged",
        { min = 0, max = scale }, true)
    }
    createOneSpinner("tonemappingMode", ::tonemappingMode_list, ::get_tonemappingMode(), "onTonemappingModeChanged")
    createOneSlider("L_inv_white", ::get_L_inv_white() * scale, "onLInvWhiteChanged", { min = 0, max = scale }, true)
    createOneSlider("U_A", ::get_U_A() * scale, "onUAChanged", { min = 0.01 * scale, max = 5 * scale }, true)
    createOneSlider("U_B", ::get_U_B() * scale, "onUBChanged", { min = 0.01 * scale, max = 5 * scale }, true)
    createOneSlider("U_C", ::get_U_C() * scale, "onUCChanged", { min = 0.01 * scale, max = 5 * scale }, true)
    createOneSlider("U_D", ::get_U_D() * scale, "onUDChanged", { min = 0.01 * scale, max = 5 * scale }, true)
    createOneSlider("U_E", ::get_U_E() * scale, "onUEChanged", { min = 0.01 * scale, max = 5 * scale }, true)
    createOneSlider("U_F", ::get_U_F() * scale, "onUFChanged", { min = 0.01 * scale, max = 5 * scale }, true)
    createOneSlider("UWhite", ::get_UWhite() * scale, "onUWhiteChanged", { min = 0.01 * scale, max = 4 * scale }, true)

    updateVisibility();
  }

  function setValue(name, value)
  {
    let sliderObj = scene.findObject(name);
    if (::checkObj(sliderObj))
      sliderObj.setValue(value);
  }
  function getValue(name)
  {
    let sliderObj = scene.findObject(name);
    return sliderObj.getValue();
  }

  function initScreen()
  {
    ::enableHangarControls(true)
    //change shader variables
    ::set_tonemappingMode(::get_tonemappingMode());
    if (::use_lense_flares())
      ::set_lenseFlareMode(::get_lenseFlareMode());

    createObjects();
    ::move_mouse_on_child(scene.findObject("postfx_table"), 0)
  }

  function onResetToDefaults(obj)
  {
    setValue("postfx_settings_vignette", ::get_default_postfx_vignette_multiplier() * scale);
    setValue("postfx_settings_sharpenTPS", ::get_default_sharpenTPS() * scale);
    setValue("postfx_settings_sharpenGunner", ::get_default_sharpenGunner() * scale);
    setValue("postfx_settings_sharpenBomber", ::get_default_sharpenBomber() * scale);
    setValue("postfx_settings_sharpenCockpit", ::get_default_sharpenCockpit() * scale);
    setValue("postfx_settings_L_inv_white", ::get_default_L_inv_white() * scale);
    setValue("postfx_settings_U_A", ::get_default_U_A() * scale);
    setValue("postfx_settings_U_B", ::get_default_U_B() * scale);
    setValue("postfx_settings_U_C", ::get_default_U_C() * scale);
    setValue("postfx_settings_U_D", ::get_default_U_D() * scale);
    setValue("postfx_settings_U_E", ::get_default_U_E() * scale);
    setValue("postfx_settings_U_F", ::get_default_U_F() * scale);
    setValue("postfx_settings_UWhite", ::get_default_UWhite() * scale);
    setValue("postfx_settings_fxaa", ::get_default_fxaa());
    setValue("postfx_settings_lutTexture", get_lut_index_by_texture(::get_default_lut_texture()));
    setValue("postfx_settings_tonemappingMode", ::get_default_tonemappingMode());
    if (::use_lense_flares())
    {
      setValue("postfx_settings_lenseFlareMode", ::get_default_lenseFlareMode());
      setValue("postfx_settings_lenseFlareHaloPower", ::get_default_lenseFlareHaloPower() * scale);
      setValue("postfx_settings_lenseFlareGhostsPower", ::get_default_lenseFlareGhostsPower() * scale);
    }

    ::set_postfx_vignette_multiplier(::get_default_postfx_vignette_multiplier());
    ::set_fxaa(::get_default_fxaa());
    ::set_sharpenTPS(::get_default_sharpenTPS());
    ::set_sharpenGunner(::get_default_sharpenGunner());
    ::set_sharpenBomber(::get_default_sharpenBomber());
    ::set_sharpenCockpit(::get_default_sharpenCockpit());
    ::set_L_inv_white(::get_default_L_inv_white());
    ::set_U_A(::get_default_U_A(), true);
    ::set_U_B(::get_default_U_B(), true);
    ::set_U_C(::get_default_U_C(), true);
    ::set_U_D(::get_default_U_D(), true);
    ::set_U_E(::get_default_U_E(), true);
    ::set_U_F(::get_default_U_F(), true);
    ::set_UWhite(::get_default_UWhite(), true);
    ::set_lut_texture(::get_default_lut_texture());
    ::set_tonemappingMode(::get_default_tonemappingMode());
    if (::use_lense_flares())
    {
      ::set_lenseFlareMode(::get_default_lenseFlareMode());
      ::set_lenseFlareHaloPower(::get_default_lenseFlareHaloPower(), true);
      ::set_lenseFlareGhostsPower(::get_default_lenseFlareGhostsPower(), true);
    }
  }

  function goBack()
  {
    ::save_profile(false);
    base.goBack();
  }

  function onVignetteChanged(obj)
  {
    if (!obj) return;
    ::set_postfx_vignette_multiplier(1 - obj.getValue() * recScale);
  }
  function onSharpenTPSChanged(obj)
  {
    if (!obj) return;
    ::set_sharpenTPS(obj.getValue() * recScale);
  }
  function onSharpenGunnerChanged(obj)
  {
    if (!obj) return;
    ::set_sharpenGunner(obj.getValue() * recScale);
  }
  function onSharpenBomberChanged(obj)
  {
    if (!obj) return;
    ::set_sharpenBomber(obj.getValue() * recScale);
  }
  function onSharpenCockpitChanged(obj)
  {
    if (!obj) return;
    ::set_sharpenCockpit(obj.getValue() * recScale);
  }

  function onFXAAChanged(obj)
  {
    if (!obj) return;
    ::set_fxaa(obj.getValue());
  }
  function onLutTextureChanged(obj)
  {
    if (!obj) return;
    ::set_lut_texture(::lut_textures[obj.getValue()]);
  }

  function onLenseFlareModeChanged(obj)
  {
    if (!obj) return;
    ::set_lenseFlareMode(obj.getValue());

    updateVisibility();
  }
  function onLenseFlareHaloPowerChanged(obj)
  {
    if (!obj) return;
    ::set_lenseFlareHaloPower(obj.getValue() * recScale);
    updateSliderValue("lenseFlareHaloPower", obj.getValue() * recScale)
  }
  function onLenseFlareGhostsPowerChanged(obj)
  {
    if (!obj) return;
    ::set_lenseFlareGhostsPower(obj.getValue() * recScale);
    updateSliderValue("lenseFlareGhostsPower", obj.getValue() * recScale)
  }

  function onTonemappingModeChanged(obj)
  {
    if (!obj) return;
    ::set_tonemappingMode(obj.getValue());

    updateVisibility();
  }
  function onLInvWhiteChanged(obj)
  {
    if (!obj) return;
    ::set_L_inv_white(obj.getValue() * recScale);
    updateSliderValue("L_inv_white", obj.getValue() * recScale)
  }

  function onUAChanged(obj)
  {
    if (!obj) return;
    ::set_U_A(obj.getValue() * recScale, true);
    updateSliderValue("U_A", obj.getValue() * recScale)
  }
  function onUBChanged(obj)
  {
    if (!obj) return;
    ::set_U_B(obj.getValue() * recScale, true);
    updateSliderValue("U_B", obj.getValue() * recScale)
  }
  function onUCChanged(obj)
  {
    if (!obj) return;
    ::set_U_C(obj.getValue() * recScale, true);
    updateSliderValue("U_C", obj.getValue() * recScale)
  }
  function onUDChanged(obj)
  {
    if (!obj) return;
    ::set_U_D(obj.getValue() * recScale, true);
    updateSliderValue("U_D", obj.getValue() * recScale)
  }
  function onUEChanged(obj)
  {
    if (!obj) return;
    ::set_U_E(obj.getValue() * recScale, true);
    updateSliderValue("U_E", obj.getValue() * recScale)
  }
  function onUFChanged(obj)
  {
    if (!obj) return;
    ::set_U_F(obj.getValue() * recScale, true);
    updateSliderValue("U_F", obj.getValue() * recScale)
  }
  function onUWhiteChanged(obj)
  {
    if (!obj) return;
    ::set_UWhite(obj.getValue() * recScale, true);
    updateSliderValue("UWhite", obj.getValue() * recScale)
  }
}

::gui_start_postfx_settings <- function gui_start_postfx_settings()
{
  ::postfx_settings_handler = ::handlersManager.loadHandler(::gui_handlers.PostFxSettings)
}
