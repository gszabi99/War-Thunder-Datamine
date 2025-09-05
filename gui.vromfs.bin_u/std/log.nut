
import "math" as math
import "dagor.debug" as dagorDebug
import "string.nut" as string
from "string" import split_by_chars

let tostring_r = string.tostring_r
let join = string.join 

function print_(val, separator="\n"){
  print($"{val}{separator}")
}
const DEF_MAX_DEEPLEVEL = 4
function Log(tostringfunc=null) {
  function vlog(...){
    local out = ""
    if (vargv.len()==1)
      out = tostring_r(vargv[0],{splitlines=false, compact=true, maxdeeplevel=DEF_MAX_DEEPLEVEL, tostringfunc=tostringfunc})
    else
      out = join(vargv.map(@(val) tostring_r(val,{splitlines=false, compact=true, maxdeeplevel=DEF_MAX_DEEPLEVEL, tostringfunc=tostringfunc}))," ")
    dagorDebug.screenlog(out.slice(0,math.min(out.len(),200)))
  }

  function log(...) {
    if (vargv.len()==1)
      print_(tostring_r(vargv[0],{compact=true, maxdeeplevel=DEF_MAX_DEEPLEVEL tostringfunc=tostringfunc}))
    else
      print_(" ".join(vargv.map(@(v) tostring_r(v,{compact=true, maxdeeplevel=DEF_MAX_DEEPLEVEL tostringfunc=tostringfunc}))))
  }

  function dlog(...) {
    vlog.acall([this].extend(vargv))
    log.acall([this].extend(vargv))
    dagorDebug.console_print(" ".join(vargv.map(@(v) tostring_r(v, {maxdeeplevel=DEF_MAX_DEEPLEVEL, showArrIdx=false, tostringfunc=tostringfunc}))))
  }

  function dlogsplit(...) {
    log.acall([this].extend(vargv))
    if (vargv.len()==1)
      vargv=vargv[0]
    let out = tostring_r(vargv,{tostringfunc=tostringfunc})
    let s = split_by_chars(out,"\n")
    for (local i=0; i < math.min(80,s.len()); i++) {
      dagorDebug.screenlog(s[i])
    }
  }
  function debugTableData(value, params={recursionLevel=3, addStr="", printFn=null, silentMode=true}){
    let addStr = params?.addStr ?? ""
    let silentMode = params?.silentMode ?? true
    let recursionLevel = params?.recursionLevel ?? 3
    let printFn = params?.printFn ?? print
    let prefix = silentMode ? "" : "DD: "

    let newline = $"\n{prefix}{addStr}"
    let maxdeeplevel = recursionLevel+1

    if (addStr=="" && !silentMode)
      printFn("DD: START")
    printFn(tostring_r(value,{compact=false, maxdeeplevel=maxdeeplevel, newline=newline, showArrIdx=false, tostringfunc=tostringfunc}))
  }

  function console_print(...) {
    dagorDebug.console_print(" ".join(vargv.map(@(v) tostring_r(v, {maxdeeplevel=DEF_MAX_DEEPLEVEL, showArrIdx=false, tostringfunc=tostringfunc}))))
  }

  function with_prefix(prefix) {
    return @(...) log("".concat(prefix, " ".join(vargv.map(@(val) tostring_r(val, {compact=true, maxdeeplevel=DEF_MAX_DEEPLEVEL tostringfunc=tostringfunc})))))
  }
  function dlog_prefix(prefix) {
    return @(...) dlog.acall([null, prefix].extend(vargv))  
  }

  function wlog(watched, prefix = null, transform=null, logger = log) {
    local ftransform = transform ?? @(v) v
    local fprefix = prefix
    if (type(prefix) == "function") {
      ftransform = prefix
      fprefix = transform
    }
    if (type(transform) == "string")
      fprefix = transform
    if (type(watched) != "array")
      watched = [watched]
    fprefix = fprefix != "" ? fprefix : null
    if (fprefix != null)
      foreach (w in watched) {
        logger(fprefix, ftransform(w.get()))
        w.subscribe(@(v) logger(fprefix, ftransform(v)))
      }
    else
      foreach (w in watched) {
        logger(ftransform(w.get()))
        w.subscribe(@(v) logger(ftransform(v)))
      }
  }

  return {
    vlog
    v = vlog
    log
    dlog 
    d = dlog
    dlogsplit
    debugTableData
    console_print
    with_prefix
    dlog_prefix
    wlog
    
    debug = dagorDebug.debug
    logerr = dagorDebug.logerr
    screenlog = dagorDebug.screenlog
  }
}

return Log
