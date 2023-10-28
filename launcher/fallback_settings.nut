//THIS FILE placed in git launcher/client/scilauncher2/<...>/_launcher_settings. Do not edit it elsewhere
let {print_file_to_debug, concat, pp} = require("system.nut")
let {he, select, h_table, tds, input} = require("build_html.nut")
let {loc} = require("dagor.localize")

let debug = println

let set_blk_bool = ::set_blk_bool
let set_blk_str = ::set_blk_str
let create_and_load_blk = ::create_and_load_blk

let setValue = ::setValue
let getValue = ::getValue

let isEacEnabled = @() ::getValue("use_eac", false)

let hdPackApiOn = ("setHdPackSelector" in getroottable())
let setHdPackSelector = getroottable()?["setHdPackSelector"] ?? @(...) null


debug("game_settings fallback version 0.5.5")

::addLocalization("launcher_settings\\settings.csv")

//  BUILD HTMLS here
::gs <- {}
::gs.getDefaultQualityByVideoCard <- function() {
  if (!("gpuInfo" in getroottable())) {
    let need_check = (!::fileExists("config.blk") || getroottable()?["isFirstRun"])
    ::gpuInfo <- {
      need_check = need_check
      name = (need_check && "getGpuName" in getroottable()) ? getroottable()["getGpuName"]() : "unknown"
      name_underscore = (need_check && "getGpuNameUnderscore" in getroottable()) ? ::getGpuNameUnderscore(): "unknown"
      memory =  (need_check && "getGpuMemory" in getroottable()) ? getroottable()["getGpuMemory"](): 0
    }
  }
  pp($"Default graphics quality for GPU {::gpuInfo.name} ({::gpuInfo.name_underscore}) with {::gpuInfo.memory} memory")
  let cardsCaps = require("card_caps.nut")
  local quality = "high"
  if (::gpuInfo.name_underscore in cardsCaps) {
    let gflops = cardsCaps[::gpuInfo.name_underscore]["gflops"]
    if (gflops < 128)
      quality = "ultralow"
    else if (gflops < 256)
      quality = "low"
    else if (gflops < 512)
      quality = "medium"
    else if (gflops < 2536)
      quality = "high"
    else if (gflops < 4096)
      quality = "max"
    else
      quality = "movie"
  }
  else {
    let lowName = ::gpuInfo.name.tostring().tolower()
    if (lowName.contains("intel")) {
      if (lowName.contains("iris") || lowName.contains("5200"))
        quality = "medium"
      else
        quality = "low"
    }
  }
  let quality_preset_names = ["ultralow", "low", "medium", "high", "max", "movie"]
  let qidx = quality_preset_names.indexof(quality)
  if (qidx!=null && qidx >= 3 && ::gpuInfo.memory < 524288)
    quality = "medium"
  pp("Default quality (can be used on first run):" quality)
  return quality
}

::gs.defaultQualityByVideoCard <- ::gpuInfo.need_check ? ::gs.getDefaultQualityByVideoCard() : "high" //workaround on freeze of use of DDraw!

let function merge(dest, table){
  let ret = {}
  foreach (k,v in dest) {
    ret[k] <- v
  }
  foreach (k,v in table) {
    ret[k] <- v
  }
  return ret
}

let function hselect(params) {
  return select(params, {type="select" style="flow:horizontal;" onClick="advancedClick" onChange="advancedClick"})
}

let function vselect(params) {
  return select(params, {size="1" onClick="advancedClick" onChange="advancedClick" })
}

let function checkbox (params, checked=false, children="") {
  return input(merge({type="checkbox" onClick="advancedClick" extra=(checked)? "checked" : ""}, params), children)
}

let function hslider(params) {
  return input(merge({type="hslider" onClick="advancedClick" onChange="advancedClick" min="0" max="2" value="1" step="1"}, params))
}

let nbsp = @(num=1) "".join(array(num, "&nbsp;"))

// TODO: replace build of html with current scheme, extended with possible values for selects, min\max\step for sliders and render function that creates html of element
// and ui scheme that place item by identificator (like in skyquake), with all unspecified items placed somewhere
//this will dramatically reduce amount of code and errors
let buildDialogSettingsHTML = function() {
  let part1 = h_table({class_= "option_table" col_num=2
    raws = [
      [concat(loc("settings/adv/anisotropy") ":"), hselect({id="anisotropy" value="off" options = ["off" "2X" "4X" "8X" "16X"]}) ],
      [concat(loc("settings/adv/fsaa") ":"),
        he("div",{style="flow:horizontal;"},
          concat(
            vselect({title=loc("settings/adv/fsaa_title") id="antialias" value="off" options = [{value="off" text=loc("setting/none")} {value="2X" text=loc("MSAA 2x")}]})
            vselect({id="postfx_antialiasing"
             options = [
               {value="none" selected="yes" }
               {value="fxaa" text="FXAA"}
               {value="high_fxaa"}
               {value="low_taa" text=loc("TAA")}
             ]
           })
           he("div",{style="padding-left:20dip;padding-top:5dip"}, concat(loc("SSAA")), ":", nbsp())
           vselect({id="ssaa" onClick="ssaaClick" onChange="ssaaClick" options=[{value="none" selected="yes"}, {value = "4X"}]})
      ))],
      [concat(loc("settings/adv/texQuality") ":"), hselect({id="texQuality" options = ["low" "medium" "high"]})],
      [concat(loc("settings/adv/shadowQuality") ":"), hselect({id="shadowQuality" options = ["ultralow" "low" "medium" "high" "ultrahigh"]})]
    ]
  })
  let part2 = h_table({class_= "option_table" style="width:200dip;"col_num=2
    raws = [
      [checkbox({id="shadows"}, true), loc("settings/adv/shadows")],
      [checkbox({id="rendinstGlobalShadows"}), loc("settings/adv/rendinstGlobalShadows")],
      [checkbox({id="staticShadowsOnEffects"}, true), loc("Shadows on effects")],
      [checkbox({id="advancedShore"}, true), loc("settings/adv/advancedShore")],
      [checkbox({id="haze"}, true), loc("settings/adv/haze")],
      [checkbox({id="softFx"}, true), loc("settings/adv/softFx")],
      [checkbox({id="lastClipSize"}), loc("settings/adv/lastClipSize")],
      [checkbox({id="lenseFlares"}), loc("settings/adv/lenseFlares")],
      [checkbox({id="enableSuspensionAnimation"}, true), loc("settings/adv/enableSuspensionAnimation")],
      [checkbox({id="alpha_to_coverage"}), loc("settings/adv/alpha_to_coverage")],

      [checkbox({id="grass" style="display:none;"}, true)],
      [checkbox({id="ssao" style="display:none;"})],
      [checkbox({id="jpegShots"}, true), loc("settings/jpegShots")],
      [checkbox({id="compatibilityMode" onClick="compatibilityModeClick"}), {style="color:gray" v=loc("settings/compatibilityMode")}],
      [checkbox({id="enableHdr"}), loc("settings/enableHdr")]
    ]
  }) + checkbox({id="videoRAMwarningOff" style="display:none;" value="false"})

  let part3 = h_table({class_= "option_table" col_num=4
    raws = [
      [
        tds([loc("settings/backgroundScale"), hslider({id="backgroundScale" max="2" value="2"})], {title=loc("settings/backgroundScale_title")})
        tds([loc("Small shadows"), hslider({id="contactShadowsQuality" min="0" max="2" value="0" onClick="contactShadowsQualityClick" onChange="contactShadowsQualityClick"})])
      ],
      [
        tds([loc("settings/landquality"), hslider({id="landquality" onClick="landqualityClick" onChange="landqualityClick" min="0" max="4" value="2"})], {title=loc("settings/landquality_title")})
        tds([loc("settings/adv/dirtSubDiv"), vselect({id="dirtSubDiv" style="width:110dip;" options=["high", "ultrahigh"]})])
      ],
      [
        tds([loc("settings/rendinstDistMul"), hslider({id="rendinstDistMul" min="50" max="220" value="100"})], {title=loc("settings/rendinstDistMul_title")}),
        tds([loc("settings/adv/tireTracksQuality"), vselect({id="tireTracksQuality" style="width:110dip;" options=["none", "medium", "high", "ultrahigh"]})])
      ],
      [
        tds([loc("settings/fxDensityMul"), hslider({id="fxDensityMul" min="20" max="100" value="80" })], {title=loc("settings/fxDensityMul_title")}),
        tds([loc("settings/adv/waterQuality"), vselect({id="waterQuality" style="width:110dip;" options = ["low", "medium", "high", "ultrahigh"]})])
      ],
      [
        tds([loc("settings/grassRadiusMul"), hslider({onClick="grassClick" onChange="grassClick" id="grassRadiusMul" min="1" max="180" value="100"})]),
        tds([loc("settings/cloudsQuality"), hslider({onClick="cloudsQualityClick" onChange="cloudsQualityClick" id="cloudsQuality" min="0" max="2" value="1"})])
      ],
      {id="ssaoShadowGroup" cols = [
        tds([loc("settings/SSAOquality"), hslider({id="ssaoQuality" min="0" max="2" value="0" onChange="ssaoQualityClick" onClick="ssaoQualityClick"})], {title=loc("settings/SSAOquality_title")}),
        tds([loc("settings/panoramaResolution"), hslider({id="panoramaResolution" min="1024" max="4096" value="2048" step="256"})],{title=loc("settings/panoramaResolution")}),
      ]},
      {id = "ssrGroup" cols = [
        tds([loc("settings/SSRquality"), hslider({id="ssrQuality" min="0" max="2" value="0" onChange="ssrQualityClick" onClick="ssrQualityClick"})], {title=loc("settings/SSRquality_title")}),
        tds([loc("Displacement"), hslider({id="displacementQuality" min="0" max="3" value="2"})])
      ]},
    ]
 })


 let part4 = concat(
   h_table({col_num=3 style="width:600dip;" raws = [
     [he("font", {color="gray" style="padding-bottom:2dip;"}, concat(loc("debug_settings") ":"))],
     [concat(
       he("font", {style="padding-bottom:2dip;vertical-align:middle;"}, loc("settings/adv/renderer"), ":", nbsp(1))
         vselect({
           id="renderer" onClick="rendererClick" onChange="rendererClick" options=[{value="auto" selected="yes"}, {value="dx11" class_="hidden"}, {value="metal" class_=(platformMac ? null : "hidden") text="Metal"}]
         }) vselect({id="driver" class_ = "hidden" extra=".hidden" options = [{value="auto" selected="yes"}, "dx11","metal"]})
       )
       concat(input(merge({id="vrMode", type="checkbox" }, {}), nbsp(1), loc("settings/adv/oculusRift")))
     ],
     [
       {id="enableNvHighlightsDiv", v = concat(
         loc("settings/adv/enableNvHighlights") nbsp(1)
       vselect({id="enableNvHighlights" onClick="" onChange="" options=[{value="auto" text=loc("auto")} "on" "off"]}))},
     ]
   ]})
    vselect({id="instancing" class_="hidden", options=["auto","geom","tex"]})
    checkbox({class_="hidden" id="magnetometerEnabled"})
    checkbox({class_="hidden" id="predictionEnabled"})
    input({id="oculusfovMul" class_="hidden" value="1.2" maxlength="5" type="decimal"})
    input({id="oculusk1" class_="hidden" value="0.5" maxlength="5" type="decimal"})
    input({id="oculusk2" class_="hidden" value="0.666" maxlength="5" type="decimal"})
    input({id="edgeScale" class_="hidden" value="0.95" maxlength="5" type="decimal"})
    input({id="maxSeparation" class_="hidden" value="0.0005" maxlength="7" type="decimal"})
    input({id="zeroParallaxDist" class_="hidden" value="3.0" maxlength="5" type="decimal"})
  )

  let leftCol = concat(
    he("div", {class_="dialog_li"}, part1)
    he("div", {class_="dialog_li"}, part3)
    he("div", {class_="dialog_li"}, part4)
  )

  let rightCol = he("div", {class_="dialog_li"}, part2)

  let vertRows = concat(
    he("div", {style="width:630dip"}, leftCol)
    he("div", {style=""}, rightCol)
  )

  let html = he("div", {style="flow:horizontal"}, vertRows)

  return html
}

let buildFrontSettingsHTML = function() {
  let mode = concat(he("span" {style = "vertical-align:bottom;"} loc("settings/main/resolution") ) nbsp(1)
    vselect({id="resolution" onClick="" onChange="" options = [{value="auto" text="Auto"}]})
    vselect({id="mode" onClick="" onChange=""
      options = [
        {value="fullscreenwindowed" extra="selected" text= loc("settings/main/fullscreenwindowed") }
        {value="fullscreen" text= loc("settings/main/fullscreen") }
        {value="windowed" text= loc("settings/main/windowed") }
       ]
     })
     vselect({ id="vsync" onClick="vsyncClick" onChange="vsyncClick" size="1"
       options = [
         {value="vsync_off" extra="selected" text= loc("settings/main/vsync_off")}
         {value="vsync_on"  text= loc("settings/main/vsync_on")}
         {value="vsync_adaptive"  id="vsync_adaptive" text=loc("settings/main/vsync_adaptive")}
       ]
     })
  )
  let sound =  concat("<input checked type='checkbox' id='sound' onClick='soundClick'>&nbsp;" nbsp(1) loc("settings/main/sound") nbsp(4) loc("settings/main/speaker_title") nbsp(3)
    select({id="speaker" style="flow:horizontal"
      options = [
        {value="auto" selected="yes" text=loc("setting/speaker/auto")}
        {value="stereo" text=loc("setting/speaker/stereo")}
        {value="speakers5.1" text=loc("setting/speaker/5.1")}
        {value="speakers7.1" text=loc("setting/speaker/7.1")}
      ]
    }) nbsp(4)
  )

  let quality_options = [
    {value="ultralow" text=loc("settings/ultralow")}
    {value="low" text=loc("settings/low")}
    {value="medium" text=loc("settings/medium")}
    {value="high" text=loc("settings/high")}
    {value="max" text=loc("settings/max")}
    {value="movie" title=loc("settings/main/graphics_overall") text=loc("settings/movie")}
    {value="custom" onClick="open_settings" text=loc("settings/custom")}
  ]

  foreach (opt in quality_options) {
    if (opt.value == ::gs.defaultQualityByVideoCard)
      opt["selected"] <- "yes"
  }

  let quality = concat(loc("settings/main/graphics") ":"
    hselect({id="graphicsQuality" title=loc("settings/main/graphics_overall") onClick="graphicsQualityClick" onChange="graphicsQualityClick" style="flow:horizontal;" options = quality_options})
    "<button onClick='toggle_settings' title='" loc("settings/toggle_settings") "' style='min-width:30dip'><div style='position:relative;top:2dip;left:7dip;width:15dip;height:16dip;background-image:url(img/common/icon_settings.svg);background-repeat:stretch keep-ratio'></div></button>"
  )

  let html = concat(he("div", {style=""}, mode)
     he("div", {style="margin-top:6dip"}, sound)
     he("div", {style="margin-top:6dip"}, quality)
  )
  return html
}

::setHtml("game_versioned_settings", buildDialogSettingsHTML())
::setHtml("front_game_settings", buildFrontSettingsHTML())
::setVideoModes("resolution", 1024, 720) // move to script as well
if ( !::isNvidia() ) {
  debug("not Nvidia videocard")
  ::display("vsync_adaptive", false)
  ::display("enableNvHighlightsDiv", false)
  ::display("enableNvHighlights", false)
}

if ("isWindows10OrGreater" in getroottable() && !::isWindows10OrGreater())
  ::disable("enableHdr");


//END OF HTML BUILD

//----------------------------- Settings schemes
//  type - data type in UI (if there is no getFromBlk/setToBlk functions, it is also used as data type in BLK).
//  defVal - default value in UI (if there is no getFromBlk/setToBlk functions, it is also used as default value in BLK).
//  blk - path to variable in config.blk (it is not required, if there are getFromBlk/setToBlk functions).
//  getFromBlk - custom function to load value from BLK.
//  setToBlk - custom function to save value to BLK.
let settings_scheme = {
  lastClipSize={
    type="bool" defVal=false
    blk="graphics/lastClipSize"
    getFromBlk=function(blk, desc) {
      local res = false
      let val = ::get_blk_int(blk, desc.blk, 4096)
      if (val == 8192)
        res = true
      else
        res = false
      return res
    }
    setToBlk=function(blk, desc, val) {
      local res = 4096
      if (val)
        res = 8192
      else
        res = 4096
      ::set_blk_int(blk, desc.blk, res)
    }
  }

  backgroundScale = {
    type="int" defVal=1.0 blk="graphics/backgroundScale"
    getFromBlk=function(blk, desc) {
      let val = ::get_blk_real(blk, desc.blk, 1.0)
      local res = 2
      if (val <= 0.7)
        res = 0
      else if ((val <= 0.85) && (val > 0.7))
        res = 1
      else
        res = 2
      return res.tointeger()
    }
    setToBlk=function(blk, desc, val) {
      local res = 1.0
      if (val == 0)
        res = 0.7
      else if (val == 1)
        res = 0.85
      else
        res = 1.0
      if (getValue("ssaa","none") == "4X" && !getValue("compatibilityMode",false))
        res = 2.0
      ::set_blk_real(blk, desc.blk, res)
    }

  }
  compatibilityMode={ type="bool" defVal=false blk="video/compatibilityMode"}
  ssaa={ type="string" defVal="none" blk="graphics/ssaa"
    getFromBlk=function(blk, desc) {
      let val = ::get_blk_real(blk, desc.blk, 1.0)
      local res = "none"
      if (val == 4.0)
        res = "4X"
      return res
    }
    setToBlk=function(blk, desc, val) {
      local res = 1.0
      if (val == "4X")
        res = 4.0
      ::set_blk_real(blk, desc.blk, res)
    }
  }
  postfx_antialiasing={ type="string" defVal="none" blk="video/postfx_antialiasing"
      getFromBlk=function(blk, desc) {
      local val = ::get_blk_str(blk, desc.blk, "none")
      if (val == "high_taa")
        val = "low_taa"
      return val
    }
  }
  clipmapScale={type="int" defVal=100 blk="graphics/clipmapScale"
    getFromBlk=function(blk, desc) {
      let val = ::get_blk_real(blk, desc.blk, 1.0) * 100
      return val.tointeger()
    }
    setToBlk=function(blk, desc, val) { ::set_blk_real(blk, desc.blk, val/100.0) }
  }
  landquality={ type="int" defVal=0 blk="graphics/landquality"}

  ssaoQuality={ type="int" defVal=0 blk="render/ssaoQuality"}
  ssrQuality={ type="int" defVal=0 blk="render/ssrQuality"}

  lenseFlares={ type="bool" defVal=false blk="graphics/lenseFlares"}

  vrMode={type="bool" defVal=false blk="gameplay/enableVR"}

  magnetometerEnabled={type="bool" defVal=false blk="oculus/magnetometerEnabled"} // Requires reset direction key.
  predictionEnabled={type="bool" defVal=false blk="oculus/predictionEnabled"}// Looks better without prediction.
  oculusfovMul={type="real" defVal=1.2 blk="oculus/fovMul"}// Scale of recomended FOV in radians.
  oculusk1={type="real" defVal=0.5 blk="oculus/k1"}// sample points k1,k2,1.0f - size of replication border (as in ce3 paper)
  oculusk2={type="real" defVal=0.666 blk="oculus/k2"}// sample points k1,k2,1.0f - size of replication border (as in ce3 paper)
  edgeScale={type="real" defVal=0.95 blk="oculus/edgeScale"}// decrease final offset a little to fight outline artifacts (half of texel?)  oculus
  maxSeparation={type="real" defVal=0.0005 blk="oculus/maxSeparation"}
  zeroParallaxDist={type="real" defVal=3.0 blk="oculus/zeroParallaxDist"}

  advancedShore={ type="bool" defVal=false blk="graphics/advancedShore" }
  instancing={ type="string" defVal="auto"  blk="video/instancing" }
  renderer={ type="string" defVal="auto"  blk="renderer3" }
  driver={ type="string" defVal="auto"  blk="video/driver" }
  enableNvHighlights={ type="string" defVal="auto" blk="debug/enableNvHighlights" }

  forceEnemiesLowQuality={ type="bool" defVal=false blk="graphics/forceEnemiesLowQuality" }

  shadows={ type="bool" defVal=true blk="render/shadows" }
  shadowQuality= { type="string" defVal="high" blk="graphics/shadowQuality" }

  selfReflection={ type="bool" defVal=true blk="render/selfReflection" }
  waterQuality={ type="string" defVal="high" blk="graphics/waterQuality" }
  haze={ type="bool" defVal=false blk="render/haze" }
  rendinstGlobalShadows={ type="bool" defVal=true blk="render/rendinstGlobalShadows" }
  staticShadowsOnEffects={ type="bool" defVal=false blk="render/staticShadowsOnEffects"  }
  softFx={ type="bool" defVal=true blk="render/softFx" }
  grass={ type="bool" defVal=true blk="render/grass" }
  enableSuspensionAnimation={ type="bool" defVal=false blk="graphics/enableSuspensionAnimation" }
  //TODO - move alpha_to_coverage to postfx settings
  alpha_to_coverage={ type="bool" defVal=false blk="video/alpha_to_coverage" }
  tireTracksQuality={
    type="string" defVal="none" blk="graphics/tireTracksQuality"
    getFromBlk= function(blk, desc) {
      let val = ::get_blk_int(blk, desc.blk, 0)
      local res = "none"
      switch(val) {
        case 0: res = "none"; break;
        case 1: res = "medium"; break;
        case 2: res = "high"; break;
        case 3: res = "ultrahigh"; break;
        default: res = "none"; break;
      }
      return res
    }
    setToBlk=function(blk, desc, val) {
      local res = 0
      switch (val) {
        case "none":        res = 0; break;
        case "medium":      res = 1; break;
        case "high":        res = 2; break;
        case "ultrahigh":   res = 3; break;
        default:            res = 0; break;
      }
      ::set_blk_int(blk, desc.blk, res)
    }
  }
  dirtSubDiv={ type="string" defVal="none" blk="graphics/dirtSubDiv"
    getFromBlk=function(blk, desc) {
      let val = ::get_blk_int(blk, desc.blk, 0)
      local res = "none"
      switch(val) {
        case -1: res = "none"; break;
        case 0: res = "medium"; break;
        case 1: res = "high"; break;
        case 2: res = "ultrahigh"; break;
        case 3: res = "ultrasuperhigh"; break;
        default: pp("unknown value of getDirtSubDiv:" val); break;
      }
      return res
    }
    setToBlk=function(blk, desc, val) {
      local res = 0
      switch(val){
        case "ultrasuperhigh": res = 3; break;
        case "ultrahigh": res = 2; break;
        case "high":      res = 1; break;
        case "medium":    res = 0; break;
        case "none":      res = -1; break;
        default: pp("unknown value of setDirtSubDiv:" val); break;
      }
      ::set_blk_int(blk, desc.blk, res)
    }
  }

  grassRadiusMul={type="int" defVal=80 blk="graphics/grassRadiusMul"
    getFromBlk=function(blk, desc) {
      let val = ::get_blk_real(blk, desc.blk, 1.0) * 100
      return val.tointeger()
    }
    setToBlk=function(blk, desc, val) { ::set_blk_real(blk, desc.blk, val/100.0) }
  }

  displacementQuality = {type="int", defVal=1 blk="graphics/displacementQuality"}
  contactShadowsQuality = { type="int" defVal=0 blk="graphics/contactShadowsQuality"}

  rendinstDistMul={type="int" defVal=100 blk="graphics/rendinstDistMul"
    getFromBlk=function(blk, desc) {
      let val = ::get_blk_real(blk, desc.blk, 1.0) * 100
      return val.tointeger()
    }
    setToBlk=function(blk, desc, val) { ::set_blk_real(blk, desc.blk, val/100.0) }
  }
  fxDensityMul={type="int" defVal=100 blk="graphics/fxDensityMul"
    getFromBlk=function(blk, desc) {
      let val = ::get_blk_real(blk, desc.blk, 1.0) * 100
      return val.tointeger()
    }
    setToBlk=function(blk, desc, val) { ::set_blk_real(blk, desc.blk, val/100.0) }
  }
  skyQuality={type="int" defVal=1 blk="graphics/skyQuality"
    getFromBlk=function(blk, desc) {
      return 2 - ::get_blk_int(blk, desc.blk, 1)
    }
    setToBlk=function(blk, desc, val) {
      ::set_blk_int(blk, desc.blk, 2 - val)
    }
  }
  cloudsQuality={type="int" defVal=1 blk="graphics/cloudsQuality"
    getFromBlk=function(blk, desc) {
      return 2 - ::get_blk_int(blk, desc.blk, 1)
    }
    setToBlk=function(blk, desc, val) {
      ::set_blk_int(blk, desc.blk, 2 - val)
    }
  }
  panoramaResolution={type="int" defVal=2048 blk="graphics/panoramaResolution"} //max 4096, min 1024

  jpegShots={ type="bool" defVal=true blk="debug/screenshotAsJpeg" }

  enableHdr={ type="bool" defVal=false blk="directx/enableHdr" }

  videoRAMwarningOff={ type="bool" defVal=true blk="debug/512mboughttobeenoughforanybody" }

  antialias= {
    type="string" defVal="off" blk="directx/maxaa"
    getFromBlk=function(blk, desc) {
      let aa = ::get_blk_int(blk, desc.blk, 0)
      if (aa == 4) return "4X"
      if (aa == 2) return "2X"
      return "off"
    }
    setToBlk=function(blk, desc, val) {
      local aa = 0
      if (val == "4X") aa = 4
      if (val == "2X") aa = 2
      ::set_blk_int(blk, desc.blk, aa)
    }
  }

  physicsQuality={type="int" defVal=2 blk="graphics/physicsQuality"}

  anisotropy = {
    type="string" defVal="2X" blk="graphics/anisotropy"
    getFromBlk=function(blk, desc) {
      let anis = ::get_blk_int(blk, desc.blk, 2)
      if (anis == 16) return "16X"
      if (anis == 8) return "8X"
      if (anis == 4) return "4X"
      if (anis == 2) return "2X"
      return "off"
    }
    setToBlk=function(blk, desc, val) {
      local anis = 1
      if (val == "16X") anis = 16
      if (val == "8X") anis = 8
      if (val == "4X") anis = 4
      if (val == "2X") anis = 2
      ::set_blk_int(blk, desc.blk, anis)
    }
  }
  texQuality={ type="string" defVal="high" blk="graphics/texquality" }

  graphicsQuality={ type="string" defVal=::gs.defaultQualityByVideoCard blk="graphicsQuality"}

//sound
  sound={ type="bool" defVal=true blk="sound/fmod_sound_enable" }
  speaker={ type="string" defVal="auto" blk="sound/speakerMode" }

  doShowDriversOutdated={ type="bool" defVal=true blk="doShowDriversOutdated" }

  resolution={ type="string" defVal = "auto" blk="video/resolution" }
  mode={ type="string" defVal="fullscreenwindowed"  blk="video/mode"
    setToBlk = function( blk, _desc, val ) {
      set_blk_bool( blk, "video/windowed", val == "windowed" )
      set_blk_str( blk, "video/mode", val )
    }
  }
  vsync={
    type="string" defVal="vsync_off" blk="video/vsync"
    getFromBlk = function( blk, _desc ) {
      let vsync_on = ::get_blk_bool( blk, "video/vsync", false )
      let adaptive_on = ::get_blk_bool( blk, "video/adaptive_vsync", true )

      if (vsync_on && adaptive_on && ::isNvidia())
         return "vsync_adaptive"
      else if ( vsync_on )
        return "vsync_on"
      else
        return "vsync_off"
    }
    setToBlk = function( blk, _desc, val ) {
      set_blk_bool( blk, "video/vsync", val == "vsync_on" || val == "vsync_adaptive" )
      set_blk_bool( blk, "video/adaptive_vsync", val == "vsync_adaptive" )
    }
  }
}

print_file_to_debug("config.blk")

let function gameRqsExist(...){
  foreach (v in vargv)
    if (!::fileExists(::makeFullPath(::getGameDir(), $"content/{v}.rq2")))
      return false
  return true
}
::getCurHdMode <- function(){
  local curSelect = "minimal"
  if (gameRqsExist("pkg_main"))
    curSelect = "hd"
  if (gameRqsExist("pkg_uhq_vehicles", "pkg_uhq_aircraft"))
    curSelect = "uhd_all"
  else if (gameRqsExist("pkg_uhq_aircraft"))
    curSelect = "uhd_aircraft"
  else if (gameRqsExist("pkg_uhq_vehicles"))
    curSelect = "uhd_ground"
  pp("current curSelect", curSelect)
  return curSelect
}
::hd_pack_value <- ::getCurHdMode()

//Fill HD pack options
let function setHdPackS(){
  let curSelect = ::getCurHdMode()
  let sel = [
    { value="minimal", text=loc("client/minimal", "Minimal") contents=["-"]}
    { value="hd", text=loc("client/hd", "HD Client"), contents=["-", "pkg_main"] }
    { value="uhd_ground", text=loc("client/uhd_ground", "Ultra HQ ground models"), contents=["-", "pkg_main", "pkg_uhq_vehicles", "pkg_uhq_environment"] }
    { value="uhd_aircraft", text=loc("client/uhd_aircraft", "Ultra HQ aircraft"), contents=["-", "pkg_main", "pkg_uhq_aircraft", "pkg_uhq_environment"] }
    { value="uhd_all", text=loc("client/uhd_all", "Full Ultra HQ"), contents=["-", "pkg_main", "pkg_uhq_vehicles", "pkg_uhq_aircraft", "pkg_uhq_environment"] }
  ].map(@(opt) opt.value==curSelect ? opt.__merge({selected="yes"}) : opt)
  setHdPackSelector?(sel)
}
if (hdPackApiOn)
  setHdPackS()

let gs_settings = ::Settings("config.blk", settings_scheme)
gs_settings.updateGui()
::launcher_settings_scheme.__update(settings_scheme)

::gs.qualityPresets <- [
  {k="texQuality",           v={ultralow="low",low="medium",medium="high",high="high",  max="high",movie="high"}, compMode=true}
  {k="shadowQuality",        v={ultralow="ultralow",low="ultralow",medium="low",high="medium",max="high",movie="ultrahigh"}}
  {k="anisotropy",           v={ultralow="off",low="off",medium="2X", high="8X", max="16X",movie="16X"}, compMode=true}
  {k="rendinstGlobalShadows",v={ultralow=false,low=false,medium=false,high=true, max=true, movie=true}}
  {k="ssaoQuality",          v={ultralow=0,low=0,medium=0,high=1,max=2,movie=2}}
  {k="ssrQuality",           v={ultralow=0,low=0,medium=0,high=0,max=0,movie=1}}
  {k="contactShadowsQuality",v={ultralow=0,low=0,medium=0,high=0, max=1, movie=2}}
  {k="lenseFlares",          v={ultralow=false,low=false,medium=false,high=true ,max=true, movie=true}}
  {k="shadows",              v={ultralow=false,low=true,medium=true ,high=true ,max=true, movie=true}}
  {k="selfReflection",       v={ultralow=false,low=false,medium=true ,high=true ,max=true, movie=true}}
  {k="waterQuality",         v={ultralow="low",low="low",medium="medium",high="high", max="high", movie="ultrahigh"}, compMode=false}
  {k="grass",                v={ultralow=false,low=false,medium=false,high=true ,max=true, movie=true}}
  {k="displacementQuality",  v={ultralow=0,low=0,medium=0,high=1, max=2, movie=3}}
  {k="dirtSubDiv",           v={ultralow="high",low="high",medium="high",high="high", max="ultrahigh", movie="ultrahigh"}, compMode=true}
  {k="tireTracksQuality"     v={ultralow="none",low="none",medium="medium", high="high", max="high", movie="ultrahigh"}, compMode=true}

  {k="alpha_to_coverage",    v={ultralow=false,low=false,medium=false,high=false ,max=true, movie=true}}
  {k="antialias",            v={ultralow="off",low="off",medium="off",high="off", max="off", movie="off"}, compMode=true}
  {k="postfx_antialiasing",  v={ultralow="none",low="none",medium="fxaa", high="high_fxaa", max="low_taa",movie="low_taa"}}
  {k="ssaa",                 v={ultralow="none",low="none",medium="none", high="none", max="none",movie="none"}}

  {k="enableSuspensionAnimation",v={ultralow=false,low=false,medium=false,high=false ,max=true, movie=true}}
  {k="haze",                 v={ultralow=false,low=false,medium=false,high=false ,max=true, movie=true}}
  {k="softFx",               v={ultralow=false,low=false,medium=true ,high=true ,max=true, movie=true}}
  {k="lastClipSize",         v={ultralow=false,low=false,medium=false,high=false,max=true, movie=true}, compMode=true}
  {k="landquality",          v={ultralow=0,low=0,medium=0 ,high=2,max=3,movie=4}}
  {k="rendinstDistMul",      v={ultralow=50,low=50,medium=85 ,high=100,max=130,movie=180}}
  {k="fxDensityMul",         v={ultralow=20,low=30,medium=75 ,high=80,max=95,movie=100}}
  {k="grassRadiusMul",       v={ultralow=10, low=10, medium=45,high=75,max=100,movie=135}}
  {k="backgroundScale",      v={ultralow=2, low=1, medium=2,high=2,max=2,movie=2}}
  {k="physicsQuality",v={ultralow=0, low=1, medium=2,high=3,max=4,movie=5}}
  {k="advancedShore",        v={ultralow=false,low=false,medium=false,high=false,max=true, movie=true}}
  {k="panoramaResolution",   v={ultralow=1024,low=1024,medium=1536,high=2048,max=2560, movie=3072}}
  {k="cloudsQuality",        v={ultralow=0,low=0,medium=1,high=1,max=1, movie=2}}
  {k="skyQuality",           v={ultralow=0,low=0,medium=1,high=1,max=1, movie=1}}
  {k="forceEnemiesLowQuality",v={ultralow=true,low=true,medium=true,high=false, max=false, movie=false}}
  {k="staticShadowsOnEffects", v={ultralow=false,low=false,medium=false,high=false,max=true, movie=true}}
  {k="compatibilityMode",    v={ultralow=true,low=false,medium=false,high=false ,max=false, movie=false}, compMode=true}
]


::setRendererPreset <- function setRendererPreset() {
  let renderer = ::getValue("renderer", "auto");

  local driver="auto"

  if (renderer=="dx11") {
    driver="dx11"
  }
  else if (renderer=="metal") {
    driver="metal"
  }

  ::setValue("driver", driver);
}

::gs.setGraphicsQuality <- function() {
  ::setRendererPreset()
  let setQualityPreset = function(preset){
    foreach (i in ::gs.qualityPresets){
      if (i.v.rawin(preset))
        ::setValue(i.k,i.v[preset])
      else if (i.v.rawin("medium"))
        ::setValue(i.k,i.v["medium"])
    }
  }

  local quality = ::getValue("graphicsQuality", ::gs.defaultQualityByVideoCard)
  if ((!::gs.qualityPresets[0].v.rawin(quality)) && quality != "custom") {
    debug("broken data in quality. set quality by videocard")
    quality = "high"
  }
  else if (quality == "custom") {
    return
  }
  setQualityPreset(quality)
}

::advancedClick <- function advancedClick() {
  ::setValue("graphicsQuality", "custom")
}

::grassClick <- function grassClick() {
  ::advancedClick()
  if (::getValue("grassRadiusMul", 100) <= 10)
    ::setValue("grass",false)
  else
    ::setValue("grass",true)
}

let isWin64Enabled = function() {
  local config_blk
  local isWin64
  local clientType
  let function getIsWin64(){
    const lastTimeSetWin64 = "lastTimeSetWin64"
    const CONFIG_BLK = "config.blk"
    if (isWin64 != null)
      return isWin64
    if (config_blk==null)
      config_blk = create_and_load_blk(CONFIG_BLK)
    if (clientType == null)
      clientType = ::get_blk_str(config_blk, "clientBitType", "auto")
    if (::get_blk_bool(config_blk, "force_win_32", false))
      isWin64 = false
    else if (clientType == "auto") {
      isWin64 = (::isWindows64() && !::isWindowsXP()) || ::get_blk_bool(config_blk, "force_win_64", false)
      println("setting lastTimeSetWin64")
      try{
        if (isWin64 && ::get_blk_int(config_blk, lastTimeSetWin64, 0) == 0){
          let {time = @() 0} = require_optional("datetime")
          ::set_blk_int(config_blk, lastTimeSetWin64, time())
          config_blk.saveToTextFile(CONFIG_BLK)
        }
      }
      catch(e){
        println($"{e} error while setting lastTimeSetWin64")
      }
    }
    else {
      try{
        let {time = @() 0} = require_optional("datetime")
        let ctime = time()
        let lasttime = ::get_blk_int(config_blk, lastTimeSetWin64, 0)
        println($"time since last try win64 {ctime-lasttime}, lastTimeSetWin64={lasttime}")
        if (lasttime==0 || ctime-lasttime > 3*60*60*24) {//3days
          ::set_blk_int(config_blk, lastTimeSetWin64, ctime)
          ::set_blk_str(config_blk, "clientBitType", "auto")
          config_blk.saveToTextFile(CONFIG_BLK)
          isWin64 = true
        }
        else{
          isWin64 = false
        }
      }
      catch(e){
        println($"{e} error while setting clientBitType")
        isWin64 = false
      }
    }
    return isWin64
  }
  return getIsWin64
}()


::gs.setCompatibilityMode <- function() {
  if (getValue("compatibilityMode")) {
    ::display("antialias",true)
    ::display("postfx_antialiasing",false)
    ::display("ssaa_group",false)
    setValue("backgroundScale",2)
    foreach (i in ::gs.qualityPresets) {
      if (i.rawin("compMode")) {
        if (!i.compMode) {
          ::disable(i.k)
        }
      }
      else {
        ::disable(i.k)
        pp("no compMode of" i.v)
      }

    }
    ::setValue("compatibilityMode",true)

    ::setValue("vrMode", false)
    ::disable("vrMode")
  } else {
    foreach (i in ::gs.qualityPresets)
      ::enable(i.k)
    setValue("compatibilityMode",false)
    ::display("antialias",false)
    ::display("postfx_antialiasing",true)
    ::display("ssaa_group",true)

    if (isWin64Enabled())
      ::enable("vrMode")
    else {
      ::setValue("vrMode", false)
      ::disable("vrMode")
    }
  }
}

::gs.setLandquality <- function() {
  if (getValue("landquality")==0)
    setValue("clipmapScale",50)
  else if (getValue("landquality")==4)
    setValue("clipmapScale",150)
  else
    setValue("clipmapScale",100)
}

::landqualityClick <- function landqualityClick() {
  ::gs.setLandquality()
  ::advancedClick()
}

::ssaoQualityClick <- function ssaoQualityClick(){
  ::advancedClick()
  if(getValue("ssaoQuality") == 0) {
    setValue("ssrQuality",0)
    setValue("contactShadowsQuality",0)
  }
}

::ssrQualityClick <- function ssrQualityClick(){
  ::advancedClick()
  if(getValue("ssrQuality") > 0 && getValue("ssaoQuality") == 0)
    setValue("ssaoQuality",1)
}

::contactShadowsQualityClick <- function contactShadowsQualityClick(){
  ::advancedClick()
  if(getValue("contactShadowsQuality") > 0 && getValue("ssaoQuality") == 0)
    setValue("ssaoQuality",1)
}

::compatibilityModeClick <- function compatibilityModeClick() {
  let msg = loc("error/compatibilityMode")
  if (getValue("compatibilityMode")) {
    if (::questMessage(msg, "")) {
      ::gs.setCompatibilityMode()
      ::advancedClick()
    }
    else
      setValue("compatibilityMode",false)
  }
  ::gs.setCompatibilityMode()
}

::gs.setCustomSettings <- function() {
  ::gs.setGraphicsQuality()
  ::gs.setLandquality()
  ::gs.setCompatibilityMode()
}

::cloudsQualityClick <- function cloudsQualityClick() {
  let cloudsQualityVal = ::getValue("cloudsQuality", 1)
  ::setValue("skyQuality", cloudsQualityVal == 0 ? 0 : 1)
  ::advancedClick()
}

::graphicsQualityClick <- function graphicsQualityClick() {
  let msg = loc("error/compatibilityMode")
  local quality = ::getValue("graphicsQuality", "high")
  if (quality=="ultralow") {
    if (!(::questMessage(msg, ""))) {
      quality="low"
      ::setValue("graphicsQuality", quality)
    }
  }
  ::gs.setCustomSettings()
}

::soundClick <- function soundClick(){
  if (!(::isChecked("sound")))
    ::disable("speaker")
  else
    ::enable("speaker")
}

::rendererClick <- function rendererClick() {
  ::setRendererPreset()
}

::ssaaClick <- function ssaaClick(){
  let msg=loc("SSAA warning")
  if (getValue("ssaa", "none") == "4X") {
    if (::questMessage(msg, "")) {
      setValue("backgroundScale", 2)
      setValue("ssaa", "4X")
    } else {
      setValue("ssaa", "none")
    }
  }
  ::advancedClick()
}

let function onSettingsLoaded() {
  ::gs.setCustomSettings()
  ::soundClick()
}

onSettingsLoaded()


let function getGameExePath(_params={}){
  let startWin64Exe = isWin64Enabled()
  let isSSE41 = ::haveSSE41()
  pp("win64 enabled:", startWin64Exe, "sse41:", isSSE41)
  let exename = startWin64Exe
    ? (isSSE41 || !::fileExists("win64\\aces-min-cpu.exe"))
      ? "win64\\aces.exe"
      : "win64\\aces-min-cpu.exe"
    : "win32\\aces.exe"
  pp("launching game exe", exename)
  return exename
}

let function getLaunchExePathImpl(params={}){
  if (platformMac)
    return "../../.."

  if (platformLinux)
    return "linux64/aces"

  if (isEacEnabled())
    return "win32\\eac_launcher.exe"

  return getGameExePath(params)
}
::getLaunchExePath <- getLaunchExePathImpl

let function getLaunchCommandLineImpl(_params={}){
  if (platformMac || platformLinux)
    return ""

  let startWin64Exe = isWin64Enabled()
  pp("win64 enabled:" startWin64Exe)

  let cmdLine = [
    "-forcestart",
    "-add_file_to_report",
    "\"{0}\"".subst(::getLauncherLogPath())
  ]

  if ("getEpicToken" in getroottable()) {
    let epicToken = ::getEpicToken()

    if (epicToken.len())
      cmdLine.extend(["-epic_token", epicToken]) //warning disable: -extent-to-append
  }
  if (isEacEnabled()) {
    if (startWin64Exe && ::haveSSE41())
        cmdLine.extend(["-eac_launcher_settings", "Settings64.json", "-eac_dir", "..\\EasyAntiCheat"]) //warning disable: -extent-to-append
    else if (startWin64Exe && !::haveSSE41() && ::fileExists("EasyAntiCheat/Launcher/Settings64-min-cpu.json") && ::fileExists("win64/aces-min-cpu.exe"))
      cmdLine.extend(["-eac_launcher_settings", "Settings64-min-cpu.json", "-eac_dir", "..\\EasyAntiCheat"]) //warning disable: -extent-to-append
    else
      cmdLine.extend(["-eac_launcher_settings", "Settings32.json", "-eac_dir", "..\\EasyAntiCheat"]) //warning disable: -extent-to-append
  }

  let dmmUserId = ::getDmmUserId()
  let dmmToken = ::getDmmToken()

  if (dmmUserId.len() > 0 && dmmToken.len() > 0)
    cmdLine.extend(["-dmm_user_id", dmmUserId, "-dmm_token", dmmToken]) //warning disable: -extent-to-append

  if (::launcherCONFIG?.ignoreFileTimeInFastCheck || ("ignoreGameUpdate" in getroottable() && ::ignoreGameUpdate))
    cmdLine.append("-skip_pkg_validation")

  return " ".join(cmdLine)
}
::getLaunchCommandLine <- getLaunchCommandLineImpl

let getGpuMemoryCached = function(){
  local memoryCache = null
  if ("gpuInfo" in getroottable() && ::gpuInfo.memory > 0)
    memoryCache = ::gpuInfo.memory
  else {
    ::getGpuInfo(function(name, memory){
      memoryCache = memory
      println($"videoMemory: {memory}")
      if ("gpuInfo" in getroottable()){
        ::gpuInfo.name = name
        ::gpuInfo.memory = memory
        ::gpuInfo.name_underscore = ::getGpuNameUnderscore()
      }
    })
  }
  return function(){
    pp("get gpuMemoryCached", memoryCache)
    if (memoryCache != null)
      return memoryCache
    if (!("gpuInfo" in getroottable()))
      memoryCache = ("getGpuMemory" in getroottable()) ? getroottable()["getGpuMemory"](): 0
    else
      memoryCache = ::gpuInfo.memory
    pp("gpuMemoryCached updated", memoryCache)
    return memoryCache
  }
}()


::hdPackSelector <- function(mode) {
  let undoHdPackSelector = getroottable()?["undoHdPackSelector"] ?? @(...) null
  pp("current hdPackSelector, mode ", mode)
  let gpuMemoryForUhq = 2.6*1000*1000*1000 //a bit less than 3GB
  let packConf = {
    minimal = { packages = [], dontCheckSpace = true}
    hd = { packages = ["pkg_main"] }
    uhd_ground = { packages = ["pkg_main", "pkg_uhq_vehicles", "pkg_uhq_environment"], gpuMemoryNeeded = gpuMemoryForUhq }
    uhd_aircraft = { packages = ["pkg_main", "pkg_uhq_aircraft", "pkg_uhq_environment"], gpuMemoryNeeded = gpuMemoryForUhq }
    uhd_all = { packages = ["pkg_main", "pkg_uhq_vehicles", "pkg_uhq_aircraft", "pkg_uhq_environment"], gpuMemoryNeeded = gpuMemoryForUhq }
  }
  let allPackages = ["pkg_main", "pkg_uhq_vehicles", "pkg_uhq_aircraft", "pkg_uhq_environment"]
  local doRestart = false

  let gameDir = ::getGameDir()
  let freeDiskSpace = ::getFreeDisk(gameDir)
  if (mode in packConf) {
    let pack = packConf[mode]
    let packagesToDelete = allPackages.filter(@(v) !pack.packages.contains(v))
    let packagesToAdd = allPackages.filter(@(v) pack.packages.contains(v))
    let gpuMemoryNeeded = pack?.gpuMemoryNeeded ?? 0
    packagesToDelete.extend(pack?.del ?? [])
    packagesToDelete.extend(pack?.add ?? [])

    if (packagesToDelete.len() > 0) {
      local willDel = false

      foreach (name in packagesToDelete) {
        let path = ::makeFullPath(gameDir, $"content/{name}.rq2")

        if (::fileExists(path)) {
          willDel = true
          break
        }
      }

      if (willDel) {
        if (!::questMessage(loc("confirm_delete_hd_client"), "")) {
          undoHdPackSelector()
          return
        }
      }

      foreach (name in packagesToDelete) {
        let path = ::makeFullPath(gameDir, $"content/{name}.rq2")

        if (::fileExists(path) && ::removeFile(path)) {
          let verPath = ::makeFullPath(gameDir, $"content/{name}.ver")

          if (::fileExists(verPath))
            ::removeFile(verPath)

          doRestart = true
        }
      }
    }

    if (packagesToAdd.len()>0) {
      local totalSize = 0

      foreach (name in packagesToAdd)
        totalSize += ::getPackFilesSize(gameDir, ::getYupProject(), name)
      let curGpuMemory = getGpuMemoryCached()
      pp("curGpuMemory", curGpuMemory, "neededMemory", gpuMemoryNeeded)

      if ( gpuMemoryNeeded > curGpuMemory && curGpuMemory!=0) {
        if (!::questMessage(loc("not_enough_gpu_memory"),"")) {
          undoHdPackSelector()
          return
        }
      }
      let requiredDiskSpace = (pack?.useExtraSpace ?? true)
         ? min(totalSize*2, totalSize+1*1000*1000*1000) //1GB extra space to make it possible to work for game
         : totalSize
      pp($"requiredDiskSpace = {requiredDiskSpace}, packTotalSize = {totalSize}, freeDiskSpace = {freeDiskSpace}")
      if ( requiredDiskSpace > freeDiskSpace ) {
        ::errorMessage("\n".concat(loc("yuplay/err_free_space"), ::bytesToLocString(requiredDiskSpace - freeDiskSpace)),"") //incorrect localizaton but launcer do not have correct localizatin module AT ALL!
        undoHdPackSelector()
        return
      }

      foreach (name in packagesToAdd) {
        let path = ::makeFullPath(gameDir, $"content/{name}.rq2")

        if (!::fileExists(path)) {
          if (::saveFile(path, "1"))
            doRestart = true
        }
      }
    }
  }

  ::hd_pack_value = mode

  if (doRestart) {
    ::saveAllSettings()
    ::restartLauncher()
  }
}
