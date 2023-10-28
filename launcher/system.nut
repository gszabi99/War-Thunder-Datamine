let {startswith} = require("string")
let {argv} = require("dagor.system")

let function obj2str(val, tostr_func, params={}){
  let add_idx = params?.add_idx ?? false
  let open = params?.open ?? ""
  let close = params?.close ?? ""
  let sep=params?.sep ?? ", "
  let keyvalsep=params?.keyvalsep ?? ":"

  let ret = [open]
  let len = val.len()
  local i = 0
  foreach (idx,v in val) {
    i += 1
    if (add_idx)
      ret.append(idx, keyvalsep)
    ret.append(tostr_func(v))
    if (i < len)
      ret.append(sep)
  }
  ret.append(close)
  return "".join(ret)
}

let function func2str(func, p={}){
  let compact = p?.compact ?? false
  let showsrc = p?.showsrc ?? false
  let showparams = p?.showparams ?? compact
  let showdefparams = p?.showdefparams ?? compact
  let tostr_func = p?.tostr_func ?? @(v) v.tostring()

  if (type(func)=="thread") {
    return $"thread: {func.getstatus()}"
  }

  let out = []
  let info = func.getfuncinfos()

  if (!info.native) {
    let defparams = info?.defparams ?? []
    let params = info.parameters.slice(1)
    let reqparams = params.slice(0, params.len() - defparams.len())
    let optparams = params.slice(reqparams.len())
    local params_str = []
    if (params.len()>0) {
      if (reqparams.len()>0)
        params_str.append(", ".join(reqparams))
      if (optparams.len()>0) {
        foreach (i, op in optparams) {
          params_str.append(op)
          if (showdefparams)
            params_str.append(" = ", tostr_func(defparams?[i] ?? ""))
          if (i+1 < optparams.len())
            params_str.append(", ")
        }
      }
    }
    params_str = "".join(params_str)
    local fname = info.name
    if (fname.slice(0,1)=="(")
      fname = "@"
    if (showsrc)
      out.append("(func): ", (info?.src ?? ""), " ")
    out.append(fname, "(")
    if (!showparams)
      out.append(params_str)
    out.append(")")
  } else if (info.native) {
    out.append("(nativefunc): ", info.name)

  } else {
    out.append(func.tostring())
  }
  return "".join(out)
}
let function tostring_r(val){
  local _tostr
  _tostr = function(val){
    if (["integer","float","string","bool","null"].indexof(typeof val))
      return val
    else if (typeof val == "array")
      return obj2str(val, _tostr, {open="[", close="]"})
    else if (typeof val == "table")
      return obj2str(val, _tostr, {open="{", close="}", add_idx=true})
    else if (typeof val == "function")
      return func2str(val, {tostr_func=_tostr})
    else
     return val.tostring()
  }
  return _tostr(val)
}

let function pp(...){
  println(" ".join(vargv.map(tostring_r)))
}

let function parseCommandline(){
  let kvargv = {}
  foreach(i,v in argv)
    if (startswith(v,"-") && v.len()>1 && argv.len()>i+2) {
      let key = v.slice(1)
      if (kvargv?[key]!=null)
        if ( type(kvargv[key]) == type([]) )
          kvargv[key] = kvargv[key].append(argv[i+1])
        else
          kvargv[key] = [kvargv[key],argv[i+1]]
      else
        kvargv[key]<-argv[i+1]
    }
  return {argv, kvargv}
}
let parsedCommandLine = parseCommandline()


let function print_file_to_debug(file) {
  let fileToPrint = ::loadTextFile(file)

  if (fileToPrint == null) {
    pp(file, "file is null (not presented?)")
    return
  }
  println("\n".join(fileToPrint))
}

let concat = @(...) "".join(vargv)
let unpack = @(v, def=null) type(v)=="function"
  ? v()
  : v ?? def

return {
  concat
  unpack
  parseCommandline
  tostring_r
  parsedCommandLine
  pp
  print_file_to_debug
}
