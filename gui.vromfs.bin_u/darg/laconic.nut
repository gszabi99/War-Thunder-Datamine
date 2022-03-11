from "daRg" import *
from "%sqstd/underscore.nut" import partition, flatten

/*
laconic framework
make layout less nested and allow short way to setup properties (like flow, flex, and so on)

compare
local foo = {
  flow = FLOW_VERTICAL
  children = [
    {rendObj = ...}
    {...}
    {
      flow = FLOW_HORIZONTAL
      children = [child1, child2]
    }
  ]
}
and
local foo = comp(
  FlowV,
  {rendObj = ...},
  {...}
  comp(FlowV, child1, child2)
)
or
local foo = comp(Style({flow = FLOW_HORIZONTAL}, child1, child2))

todo:
  correct combine watch and behaviors (do not override)
*/

local Style = class { //to be able distinguish style elements from components
  value = null
  constructor(...) {
    //I do not know the way to return instance of the same class if it is passed here
    local val = {}
    foreach(v in vargv){
      if (typeof v == "instance" && "value" in v) { //to create Style from Styles
        val.__update(v.value)
      }
      else {
        assert(typeof v == "table")
        val.__update(v)
      }
    }
    value = freeze(val)
  }
}

local extendable = ["watch", "behavior"]
local toArray = @(v) typeof(v) == "array" ? v : [v]

local function comp(...) {
  local [styles, children] = partition(flatten(vargv), @(v) v instanceof Style)
  local ret = styles.reduce(function(a,b) {
    foreach (k, v in b.value){
      local found = false
      foreach (e in extendable) {
        if (k != e)
          continue
        found = true
        if (k not in a) {
          a[k] <- toArray(v)
          break
        }
        else {
          a[k] = toArray(a[k]).extend(toArray(v))
          break
        }
      }
      if (!found) {
        assert(k not in a, @() $"property {k} already exist")
        a[k] <- v
      }
    }
    a.__update(b.value)
    return a
  }, {})

  children = flatten(children)
  if (ret?.children)
    children = flatten([ret?.children]).extend(children)
  if (children.len()>1){
    ret = ret.__update({children})
  }
  else if (children.len()==1) {
    children = children[0]
    ret = ret.__update({children})
  }
  if (ret.len()==1 && "children" in ret)
    ret = type(ret.children) != "array" || ret.children.len()==1 ? ret.children?[0] : ret
  return ("watch" in ret) ? @() ret : ret
}

local FlowV = Style({flow = FLOW_VERTICAL})
local FlowH = Style({flow = FLOW_HORIZONTAL})
local Flex = @(p=null) Style({size = p!=null ? flex(p) : flex()})
local vflow = @(...) comp(FlowV, vargv)
local hflow = @(...) comp(FlowH, vargv)
local Text = Style({rendObj = ROBJ_DTEXT})
local Image = Style({rendObj = ROBJ_IMAGE})
local Gap = @(gap) Style({gap})
local FillColr = @(...) Style({fillColor = Color.acall([null].extend(vargv))})
local BorderColr = @(...) Style({borderColor = Color.acall([null].extend(vargv))})
local BorderWidth = @(...) Style({borderWidth = vargv})
local BorderRadius = @(...) Style({borderRadius = vargv})
local ClipChildren = Style({clipChildren = true})
local Bhv = @(...) Style({behaviors = flatten(vargv)})
local Watch = @(...) Style({watch = flatten(vargv)})
local OnClick = @(func) Style({onClick = func})
local Button = Style({behavior = Behaviors.Button})

local function Size(...) {
  assert(vargv.len()<3)
  local size = vargv
  if (size.len()==1 && typeof size?[0] != "array")
    size = [size[0], size[0]]
  else if (size.len()==0)
    size = null
  return Style({size})
}

local Padding = @(...) Style({padding = vargv.len() > 1 ? vargv : vargv[0]})
local Margin = @(...) Style({margin = vargv.len() > 1 ? vargv : vargv[0]})
local Pos = @(...) Style({pos=vargv})
local YOfs = @(y) Style({pos=[0,y]})
local XOfs = @(x) Style({pos=[0,x]})

local function updateWithStyle(obj, style){
  if (typeof style == "table"){
    foreach (k in style)
      assert(k not in obj)
    obj.__update(style)
  }
  else if (style instanceof Style) {
    foreach (k in style.value)
      assert(k not in obj)
    obj.__update(style.value)
  }
  if ("watch" in obj)
    return @() obj
  else
    return obj
}

local function txt(text, style = null) {
  local obj = (typeof text == "table")
    ? text.__merge({rendObj = ROBJ_DTEXT})
    : {rendObj = ROBJ_DTEXT text}
  return updateWithStyle(obj, style)
}

local function img(image, style = null) {
  local obj = (typeof image == "table") ? image.__merge({rendObj = ROBJ_IMAGE}) : {rendObj = ROBJ_IMAGE image}
  return updateWithStyle(obj, style)
}

local RendObj = @(rendObj) Style({rendObj})
local Colr = @(...) Style({color=Color.acall([null].extend(vargv))})

local HALeft = Style({halign = ALIGN_LEFT})
local HARight = Style({halign = ALIGN_RIGHT})
local HACenter = Style({halign = ALIGN_CENTER})
local VATop = Style({valign = ALIGN_TOP})
local VABottom = Style({valign = ALIGN_BOTTOM})
local VACenter = Style({valign = ALIGN_CENTER})

local Left = Style({hplace = ALIGN_LEFT})
local Right = Style({hplace = ALIGN_RIGHT})
local HCenter = Style({hplace = ALIGN_CENTER})
local Top = Style({vplace = ALIGN_TOP})
local Bottom = Style({vplace = ALIGN_BOTTOM})
local VCenter = Style({vplace = ALIGN_CENTER})

return {
  Style
  comp
  vflow
  hflow
  txt
  img

  FlowV, FlowH, Flex, Text, Image,
  Size, Padding, Margin, Gap, Colr, RendObj, Pos, XOfs, YOfs,
  VCenter, Top, Bottom, VABottom, VATop, VACenter,
  HCenter, Left, Right, HACenter, HALeft, HARight,
  BorderColr, BorderWidth, BorderRadius, FillColr,
  Bhv, ClipChildren, Watch, Button, OnClick
}