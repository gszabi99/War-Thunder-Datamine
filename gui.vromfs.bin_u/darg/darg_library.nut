#no-func-decl-sugar

from "frp" import *
from "daRg" import *

local {tostring_r} = require("%sqstd/string.nut")

/*
//===== DARG specific methods=====
  this function create element that has internal basic stateFlags (S_HOVER S_ACTIVE S_DRAG)
*/
local function watchElemState(builder) {
  local stateFlags = Watched(0)
  return function() {
    local desc = builder(stateFlags.value)
    local watch = desc?.watch ?? []
    if (type(watch) != "array")
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
  if (type(c) == "function") {
    local info = c.getfuncinfos()
    if (info?.parameters && info.parameters.len() > 1)
      return false
    c = c()
  }
  local c_type = type(c)
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
//but result is not bigger than 0.75sw (for resolutions narrower than 4x3)
local hdpx = sh(100) <= sw(75)
  ? @(pixels) sh(100.0 * pixels / 1080)
  : @(pixels) sw(75.0 * pixels / 1080)

local fsh = sh(100) <= sw(75) ? sh : @(v) sw(0.75 * v)

local wrapParams= {width=0, flowElemProto={}, hGap=null, vGap=0, height=null, flow=FLOW_HORIZONTAL}
local function wrap(elems, params=wrapParams) {
  //TODO: move this to native code
  local paddingLeft=params?.paddingLeft
  local paddingRight=params?.paddingRight
  local paddingTop=params?.paddingTop
  local paddingBottom=params?.paddingBottom
  local flow = params?.flow ?? FLOW_HORIZONTAL
  assert([FLOW_HORIZONTAL, FLOW_VERTICAL].indexof(flow)!=null, "flow should be FLOW_VERTICAL or FLOW_HORIZONTAL")
  local isFlowHor = flow==FLOW_HORIZONTAL
  local height = params?.height ?? SIZE_TO_CONTENT
  local width = params?.width ?? SIZE_TO_CONTENT
  local dimensionLim = isFlowHor ? width : height
  assert(["array"].indexof(type(elems))!=null, "elems should be array")
  assert(["float","integer"].indexof(type(dimensionLim))!=null, @() "can't flow over {0} non numeric type".subst(isFlowHor ? "width" :"height"))
  local hgap = params?.hGap ?? wrapParams?.hGap
  local vgap = params?.vGap ?? wrapParams?.vGap
  local gap = isFlowHor ? hgap : vgap
  local secondaryGap = isFlowHor ? vgap : hgap
  if (["float","integer"].contains(type(gap)))
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
    flowElems.append(flowElemProto.__merge({children flow=isFlowHor ? FLOW_HORIZONTAL : FLOW_VERTICAL}))
  }

  do {
    buildFlowElem(tail, gap, flowElemProto, dimensionLim)
  } while (tail.len()>0)
  if (paddingTop && isFlowHor)
    flowElems.append(paddingBottom)
  if (paddingLeft && !isFlowHor)
    flowElems.append(paddingRight)
  return {flow=isFlowHor ? FLOW_VERTICAL : FLOW_HORIZONTAL gap=secondaryGap children=flowElems halign = params?.halign valign=params?.valign hplace=params?.hplace vplace=params?.vplace size=[width ?? SIZE_TO_CONTENT, height ?? SIZE_TO_CONTENT]}
}


local function dump_observables() {
  local list = gui_scene.getAllObservables()
  print("{0} observables:".subst(list.len()))
  foreach (obs in list)
    print(tostring_r(obs))
}

local colorPart = @(value) min(255, (value + 0.5).tointeger())
local function mul_color(color, mult) {
  return Color(  colorPart(((color >> 16) & 0xff) * mult),
                 colorPart(((color >>  8) & 0xff) * mult),
                 colorPart((color & 0xff) * mult),
                 colorPart(((color >> 24) & 0xff) * mult))
}

local function XmbNode(params={}) {
  return clone params
}

local function XmbContainer(params={}) {
  return XmbNode({
    canFocus = @() false
  }.__merge(params))
}

local function mkWatched(persistFunc, persistKey, defVal=null, observableInitArg=null){
  local container = persistFunc(persistKey, @() {v=defVal})
  local watch = observableInitArg==null ? Watched(container.v) : Watched(container.v, observableInitArg)
  watch.subscribe(@(v) container.v=v)
  return watch
}

return {
  mkWatched
  XmbNode
  XmbContainer
  mul_color
  wrap
  dump_observables
  hdpx
  watchElemState
  isDargComponent
  fsh
  NamedColor
}