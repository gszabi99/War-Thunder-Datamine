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

local function comp(...) {
  local [styles, children] = partition(vargv, @(v) v instanceof Style)
  local ret = styles.reduce(@(a,b) a.__update(b.value), {})
  children = flatten(children)
  if (ret?.children)
    children = flatten([ret?.children]).extend(children)
  if (children.len()==1)
    children = children[0]
  ret = ret.__update({children})
  if (ret.len()==1)
    ret = ret.children
  return ("watch" in ret) ? @() ret : ret
}

local FlowV = Style({flow = FLOW_VERTICAL})
local FlowH = Style({flow = FLOW_HORIZONTAL})
local Flex = Style({size = flex()})
local vflow = @(...) comp(FlowV, vargv)
local hflow = @(...) comp(FlowH, vargv)
local Text = Style({rendObj = ROBJ_DTEXT})
local Image = Style({rendObj = ROBJ_IMAGE})

local function updateWithStyle(obj, style){
  if (typeof style == "table")
    obj.__update(style)
  else if (style instanceof Style)
    obj.__update(style.value)
  if ("watch" in obj)
    return @() obj
  else
    return obj
}
local function txt(text, style = null) {
  local obj = (typeof text == "string") ? {rendObj = ROBJ_DTEXT text} : text.__merge({rendObj = ROBJ_DTEXT})
  return updateWithStyle(obj, style)
}

local function img(image, style = null) {
  local obj = (typeof image == "table") ? image.__merge({rendObj = ROBJ_IMAGE}) : {rendObj = ROBJ_IMAGE image}
  return updateWithStyle(obj, style)
}


return {
  Style
  comp
  vflow
  hflow
  txt
  img

  FlowV
  FlowH
  Flex
  Text
  Image
}