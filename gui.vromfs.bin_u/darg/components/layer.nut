/*
This is a ui manager of ui components that can handle reload of scripts by keeping it in persis table

The idea is to have list of components in a state and a way to add\remove them by some UID
it was implemented differently in code - some implementations consider that component is table and uid can be in it
some consider that component can be found by itself (it doesnt survive reload of scripts)
some use object with uid and component itself and this require to use special methods to get all components and to add\remove them

Here we use the last one, cause it is the only way to handle scripts reload and any component types (functions, tables, classes, null - whatever)
it can even have non darg component in it if is needed for some reason

local l = LayerManager("nameoflayer")
l.add(component, [uid])
l.getComponents() //list of components
l.remove(uid)
l.clear()
l.isInList(uid)

Consider:
  msgboxes should use it too

NOTE:
  we need orderedDictHere in fact. Probably better return it for gerrit to std?
  however. adding and removing windows are rare and amound of windows are also small...
*/

local layerManagersData = persist("windowsManagers", @() {})
local immutable_types = ["string", "float", "integer"]

//clear unaccasseble widgets on reload
foreach (layerName, layerState in layerManagersData){
  layerState.update(@(v) v.filter(@(widget) immutable_types.indexof(::type(widget.uid)!=null)))
}


local LayerManager = class{
  name = null
  state = null
  constructor(params){
    assert (immutable_types.indexof(::type(params?.name)) != null, @() "'name' param is required fo windowsManager of immutable type (string, float, integer), to allow reload script by persist data, type '{0}' for '{1}'".subst(::type(params?.name), params?.name))
    name = params.name
    if (!(name in layerManagersData))
      layerManagersData[name] <- ::Watched([])
    state = layerManagersData[name]
  }
  function add(component, uid=null){
    if (uid == null)
      uid = component
    local curId = state.value.findindex(@(v) v.uid == uid)
    if (curId == null)
      state.update(@(v) v.append({component = component, uid = uid}))
    else
      state.update(@(v) v[curId] = {component = component, uid = uid})
  }

  function remove(uid){
    local curId = state.value.findindex(@(v) v.uid == uid)
    if (curId != null) {
      local val = state.value
      val.remove(curId)
      state.trigger()
    }
  }

  function getComponents(){
    return state.value.map(@(v) v.component)
  }

  function clear(){
    state.update([])
  }

  function getByUid(uid){
    local layer = state.value
    local idx = layer.findindex(@(v) v.uid == uid)
    return idx == null ? null : layer[idx]
  }

  function isUidInList(uid){
    local layer = state.value
    return layer.findindex(@(v) v.uid == uid) != null
  }
}

return LayerManager