//Clones arrays and tables recursively
local recursivetypes =["table","array","class"]
local function isArray(arr){return ::type(arr)=="array"}

local function deep_clone(val) {
  if (recursivetypes.indexof(::type(val)) == null)
    return val
  return val.map(deep_clone)
}


//Updates (mutates) target arrays and tables recursively with source
local function deep_update(target, source) {
  if ((recursivetypes.indexof(::type(source)) == null)) {
    target = source
    return target
  }
  if (::type(target)!=::type(source)){
    target = deep_clone(source)
    return target
  }

  if (isArray(source) && target.len() < source.len()){
    target.resize(source.len())
  }
  foreach(k, v in source){
    if (!(k in target)){
      target[k] <- deep_clone(v)
    }
    else if (recursivetypes.indexof(::type(v)) == null){
      target[k] = v
    }
    else {
      target[k]=deep_update(target[k], v)
    }
  }
  return target
}

local function deep_compare(a, b, params = {ignore_keys = [], compare_only_keys = []}){}
deep_compare = function(a, b, params = {ignore_keys = [], compare_only_keys = []}) {
  local compare_only_keys = params?.compare_only_keys ?? []
  local ignore_keys = params?.ignore_keys ?? []
  local type_a = ::type(a)
  local type_b = ::type(b)

  if (type_a != type_b)
    return false

  if (type_a == "integer" || type_a == "float" || type_a == "bool" || type_a == "string")
    return a == b

  if (type_a == "array") {
    if (a.len() != b.len())
      return false

    foreach (idx, val in a) {
      if (!deep_compare(val, b[idx], params)) {
        return false
      }
    }
  } else if (type_a == "table" || type_a == "class") {
    if (a.len() != b.len())
      return false

    foreach (key, val in a) {
      if (!b.rawin(key)) {
        return false
      }
      if (compare_only_keys.len() > 0) {
        if (compare_only_keys.indexof(key)!=null && !deep_compare(val, b[key], params)) {
          return false
        }
      } else if (ignore_keys.indexof(key)==null && !deep_compare(val, b[key], params)) {
        return false
      }
    }
  }
  return true
}

//Creates new value from target and source, by merges (mutates) target arrays and tables recursively with source
local function deep_merge(target, source) {
  local ret = deep_clone(target)
  return deep_update(ret, source)
}

return {
  _clone = deep_clone,
  _update = deep_update,
  _merge = deep_merge,
  _compare = deep_compare,
}
