#no-func-decl-sugar

local {Watched, Computed} = require("frp")
local {Color, sh, calc_comp_size, gui_scene} = require("daRg")

local {tostring_r} = require("std/string.nut")
local logLib = require("std/log.nut")
local functools = require("std/functools.nut")


local tostringfuncTbl = [
  {
    compare = @(val) val instanceof Watched
    tostring = @(val) "::Watched: {0}".subst(tostring_r(val.value,{maxdeeplevel = 3, splitlines=false}))
  }
]
local log = logLib(tostringfuncTbl)

/*
//===== DARG specific methods=====
  this function create element that has internal basic stateFlags (S_HOVER S_ACTIVE S_DRAG)
*/
local function watchElemState(builder) {
  local stateFlags = Watched(0)
  return function() {
    local desc = builder(stateFlags.value)
    local watch = desc?.watch ?? []
    if (::type(watch) != "array")
      watch = [watch]
    watch.append(stateFlags)
    desc.watch <- watch
    desc.onElemState <- @(sf) stateFlags.update(sf)
    return desc
  }
}


local NamedColor = {
  red = Color(255,0,0)
  blue = Color(0,0,255)
  green = Color(0,255,0)
  magenta = Color(255,0,255)
  yellow = Color(255,255,0)
  cyan = Color(0,255,255)
  gray = Color(128,128,128)
  lightgray = Color(192,192,192)
  darkgray = Color(64,64,64)
  black = Color(0,0,0)
  white = Color(255,255,255)
}

/*
//===== DARG specific methods=====
*/
local function isDargComponent(comp) {
//better to have natived daRg function to check if it is valid component!
  local c = comp
  if (::type(c) == "function") {
    local info = c.getfuncinfos()
    if (info?.parameters && info.parameters.len() > 1)
      return false
    c = c()
  }
  local c_type = ::type(c)
  if (c_type == "null")
    return true
  if (c_type != "table" && c_type != "class")
    return false
  local knownProps = ["size","rendObj","children","watch","behavior","halign","valign","flow","pos","hplace","vplace"]
  foreach(k,val in c) {
    if (knownProps.indexof(k) != null)
      return true
  }
  return false
}

//this function returns sh() for pixels for fullhd resolution (1080p)
local function hdpx(pixels) {
  return sh(100.0 * pixels / 1080)
}

local wrapParams= {width=0, flowElemProto={}, hGap=null, vGap=0, height=null, flow=FLOW_HORIZONTAL}
local function wrap(elems, params=wrapParams) {
  //TODO: move this to native code
  local paddingLeft=params?.paddingLeft
  local paddingRight=params?.paddingRight
  local paddingTop=params?.paddingTop
  local paddingBottom=params?.paddingBottom
  local flow = params?.flow ?? FLOW_HORIZONTAL
  ::assert([FLOW_HORIZONTAL, FLOW_VERTICAL].indexof(flow)!=null, "flow should be FLOW_VERTICAL or FLOW_HORIZONTAL")
  local isFlowHor = flow==FLOW_HORIZONTAL
  local height = params?.height ?? SIZE_TO_CONTENT
  local width = params?.width ?? SIZE_TO_CONTENT
  local dimensionLim = isFlowHor ? width : height
  ::assert(["array"].indexof(::type(elems))!=null, "elems should be array")
  ::assert(["float","integer"].indexof(::type(dimensionLim))!=null, @() "can't flow over {0} non numeric type".subst(isFlowHor ? "width" :"height"))
  local hgap = params?.hGap ?? wrapParams?.hGap
  local vgap = params?.vGap ?? wrapParams?.vGap
  local gap = isFlowHor ? hgap : vgap
  local secondaryGap = isFlowHor ? vgap : hgap
  if (["float","integer"].contains(::type(gap)))
    gap = isFlowHor ? freeze({size=[gap,0]}) : freeze({size=[0,gap]})
  local flowElemProto = params?.flowElemProto ?? {}
  local flowElems = []
  if (paddingTop && isFlowHor)
    flowElems.append(paddingTop)
  if (paddingLeft && !isFlowHor)
    flowElems.append(paddingLeft)
  local tail = elems
  local function buildFlowElem(elems, gap, flowElemProto, dimensionLim) {  //warning disable: -ident-hides-ident
    local children = []
    local curwidth=0.0
    local tailidx = 0
    local flowSizeIdx = isFlowHor ? 0 : 1
    foreach (i, elem in elems) {
      local esize = calc_comp_size(elem)[flowSizeIdx]
      local gapsize = isDargComponent(gap) ? calc_comp_size(gap)[flowSizeIdx] : gap
      if (i==0 && ((curwidth + esize) <= dimensionLim)) {
        children.append(elem)
        curwidth = curwidth + esize
        tailidx = i
      }
      else if ((curwidth + esize + gapsize) <= dimensionLim) {
        children.append(gap, elem)
        curwidth = curwidth + esize + gapsize
        tailidx = i
      }
      else {
        tail = elems.slice(tailidx+1)
        break
      }
      if (i==elems.len()-1){
        tail = []
        break
      }
    }
    flowElems.append(flowElemProto.__merge({children=children flow=isFlowHor ? FLOW_HORIZONTAL : FLOW_VERTICAL size=SIZE_TO_CONTENT}))
  }

  do {
    buildFlowElem(tail, gap, flowElemProto, dimensionLim)
  } while (tail.len()>0)
  if (paddingTop && isFlowHor)
    flowElems.append(paddingBottom)
  if (paddingLeft && !isFlowHor)
    flowElems.append(paddingRight)
  return {flow=isFlowHor ? FLOW_VERTICAL : FLOW_HORIZONTAL gap=secondaryGap children=flowElems halign = params?.halign valign=params?.valign hplace=params?.hplace vplace=params?.vplace size=[width?? SIZE_TO_CONTENT, height ?? SIZE_TO_CONTENT]}
}


local function dump_observables() {
  local list = gui_scene.getAllObservables()
  ::print("{0} observables:".subst(list.len()))
  foreach (obs in list)
    ::print(tostring_r(obs))
}

local colorPart = @(value) ::min(255, (value + 0.5).tointeger())
local function mul_color(color, mult) {
  return Color(  colorPart(((color >> 16) & 0xff) * mult),
                 colorPart(((color >>  8) & 0xff) * mult),
                 colorPart((color & 0xff) * mult),
                 colorPart(((color >> 24) & 0xff) * mult))
}

//frp
::Watched <- Watched //warning disable: -ident-hides-ident
::Computed <- Computed //warning disable: -ident-hides-ident

//darg helpers
::watchElemState <- watchElemState //warning disable: -ident-hides-ident
::NamedColor <- NamedColor //warning disable: -ident-hides-ident
::hdpx <- hdpx //warning disable: -ident-hides-ident
::mul_color <- mul_color //warning disable: -ident-hides-ident
::dump_observables <- dump_observables //warning disable: -ident-hides-ident
::wrap <- wrap //warning disable: -ident-hides-ident

//function tools
::partial <- functools.partial
::pipe <- functools.pipe
::compose <- functools.compose
::kwarg <- functools.kwarg
::kwpartial <- functools.kwpartial
::curry <- functools.curry
::memoize <- functools.memoize

//logging
::dlog <- log.dlog
::log <- log  //warning disable: -ident-hides-ident
::dlogsplit <- log.dlogsplit
::vlog <- log.vlog
::console_print <- log.console_print

::XmbNode <- function XmbNode(params={}) {
  return clone params
}

::XmbContainer <- function XmbContainer(params={}) {
  return ::XmbNode({
    canFocus = @() false
  }.__merge(params))
}
