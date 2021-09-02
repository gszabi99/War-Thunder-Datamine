//experimental framework to simplify making of layout
//rework element in DComp() class with constructor of vargv - {} to merge, FlowV class\instances to props
// elem( Dcomp(flowV, Flex(2), Left, Top, Behavior(a,b) Watch(a,b) SizeContent {size=[]})  Dcomp() Dcomp() elem())
//and/or if arg is Dcomp or array or table or function - add it as children. For tables in param replace with DParams() instance

local function panel(elem_, ...) {
  local children = elem_?.children ?? []
  local add_children = []
  foreach (v in vargv) {
    if (::type(v) != "array")
      add_children.append(v)
    else
      add_children.extend(v)
  }
  if (::type(children) in ["table","class","function"] )
    children = [children]

  children.extend(add_children)

  return elem_.__merge({children=children})
}

return panel