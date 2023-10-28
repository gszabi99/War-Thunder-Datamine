let {concat, pp} = require("system.nut")

let sys_call = require("system").system
let cdate = require("datetime").date
let {getenv} = require("system")
let {split_by_chars} = require("string")
let {find_files} = require("dagor.fs")
let {loc} = require("dagor.localize")
let remove_file = ::removeFile //require("system").remove

let function normpath(path, path_sep="/"){
  return path_sep.join(split_by_chars(path,"\\/"))
}

let function map_table(table, func){
  let ret = {}
  foreach (k, v in table)
    ret[k]<-func(v)
  return ret
}
/*
  TODO:
  Small and general improvements:
    - make special dialogue with brief system\network information and check boxes of what to collect (5 hours)

  Major and future improvements (can be done mostly after general improvements):
    - network avialibility for main servers (2-8 hours, if http async module is available)
      - auth\sso
      - yupmaster
      - cdns (we need list of cdns available in public internet for this)
      - public configs
        - probably mgates\chars or better whatever else from network.blk?
    - collect logs game (configurable) (3 hours  - need find_files_ex wroking)
*/

let syscall_async_params = {path=null, params = "", folder= "", as_root=false, callback = @(_result) null}
let function syscall_async(params=syscall_async_params){
  let p = syscall_async_params.__merge(params)
  ::executeProcessAndWaitAsync(p.path, p.params, p.folder, p.as_root, p.callback)
}
let function syscall_sync(params=syscall_async_params){
  let p = syscall_async_params.__merge(params)
  sys_call(" ".join([p.path, p.params]))
  p.callback(true)
}

let function mk_cmd_func(cmd, cmdc){
  local params = cmd?.params ?? ""
  let path = cmd.path
  return function(call_params){
    params = concat(params, " ")
    local filename = (call_params?.dir) ? concat(call_params.dir, "\\") : ""
    filename = concat(filename, call_params?.filename ?? "")
    params = concat(params, filename)
    let async = cmdc == syscall_async //-disable-warning:-w286
    pp("going to start", path, params, ", async =", async)

    let callback = function(success){
      pp(path, params, ", cmd call finished:", success)
      let id = call_params.id
      call_params.results.tasks[id] = success
      if (success) {
        call_params.results.files.append(filename)
      }
      call_params.check_results()
    }
    cmdc({path=path, params=params, callback=callback})
  }
}

let function time_str(){
  let date = cdate()
  let months = ["jan","feb","mar","apr","may","jun","jul","aug","sep","oct","nov","dec"]
  date.__update({mmonth = (months?[date?.month] ?? "unk")})
  foreach (k,v in date) {
    if (::type(v)=="integer" && v<10 && v >=0)
      date[k]=concat("0",v)
  }
  return "{year}{mmonth}{day}__{hour}_{min}_{sec}".subst(date)
}


local function zip(dir, zip_file_path=null, callback=@(res) println(res)){
  //windows 8+ only! consider replace with zip.exe or special module
  if (zip_file_path == null) {
    let basepath = split_by_chars(dir,"\\/").slice(-1)?[0] ?? ""
    zip_file_path = concat(dir "\\" basepath ".zip")
  }
  let ndir = normpath(dir,"\\")
  let nzip = normpath(zip_file_path,"\\")
  ::zipFolder(ndir, nzip, callback)
  return zip_file_path
}

let function delete_files(files){
  foreach (file in files)
    remove_file(file)
}
let function open_dir(dir){
  ::shellExecute(dir, "", dir, SW_SHOWNORMAL)
}

let function make_report(res){
  open_dir("https://support.gaijin.net")
  let function onzip_finish(success){
    if(success)
      delete_files(res.files)
    if (res?.dir !=null)
      open_dir(res.dir)
  }
  zip(res.dir, null, onzip_finish)
}

let function collect_log_files(logs_path, logs_mask, maxFiles=10, maxSize=80*1000*1000){
  let mask = concat(logs_path, "\\", logs_mask)
  local cursize = 0
  local sorted_files = find_files(mask)
    .sort(@(a,b) b.creationTime <=> a.creationTime)
    .slice(0,maxFiles)
  foreach(i,v in sorted_files) {
    cursize+=v.size
    if (cursize>maxSize) {
      sorted_files=sorted_files.slice(0,i)
      break;
    }
  }
  sorted_files = sorted_files.map(@(v) v.name)
  return sorted_files
}

let function request_copy_files_async(src, mask, p){
  let files = collect_log_files(src, mask)
  let function cb(result){
    if (result)
      p.results.files.extend(files.map(@(v) concat(p.dir "\\" v)))
    p.results.tasks[p.id]=result
    p.check_results()
  }
  syscall_async({path="robocopy", params=concat(src, " ", p.dir, " ", " ".join(files)), callback=cb})
}
let shellcmds = {
  dxdiag = {path = "dxdiag", params = "/t", async=true, enabled=true}
  driverquery = {path = "driverquery", params = ">"}
  tasklist = {path = "tasklist", params = ">"}
  ipconfig = {path = "ipconfig", params = "/all >"}
  copy_launcher_logs = {asyncfunc = @(p) request_copy_files_async(".launcher_log", "*.txt", p)}
  copy_game_logs = {asyncfunc = @(p) request_copy_files_async(".game_logs", "*.clog", p)}
}

let function perform_tasks(dir, what_to_gather){

  let winVer = ::getWindowsVersion()
  pp("winVerRes:" winVer.result ", winNumVer:" winVer.numVer)
  pp("majorWindowsVer:" winVer.majorVer ", minorVer:" winVer.minorVer)
  if ("flushDebugFile" in getroottable())
    ::flushDebugFile()

  let results = {
    dir = dir,
    files = []
    tasks = map_table(what_to_gather, @(_) null)
  }
  let function check_results(){
    foreach (v in results.tasks){
      if (v==null){
        return
      }
    }
    println("make_report for collect info")
    make_report(results)
  }
  let builders = map_table(shellcmds.filter(@(v) v?.path != null), @(v) mk_cmd_func(v, v?.async ? syscall_async : syscall_sync))
  let asyncfuncs = map_table(shellcmds.filter(@(v) v?.asyncfunc != null), @(v) v.asyncfunc)
  foreach (id, v in what_to_gather) {
    if (v){
      if (id in builders) {
        let filename = concat(id, ".txt")
        let params = {filename=filename, dir=dir, results = results, check_results=check_results, id = id}
        builders[id](params)
      }
      else if (id in asyncfuncs) {
        asyncfuncs[id]({dir=dir, results=results, check_results=check_results, id=id})
      }
      else
        pp("no getter for", id)
    }
  }

}
let function main(what_to_gather){
  let msg = loc("collect_info_message_box")
  if (::questMessage(msg, loc("collect_info_msgbox_title"))) {
    let timestr = concat("_info_for_gaijin_support_", time_str())
    local dir = timestr
    dir = concat(getenv("temp") "\\" dir)
    sys_call(concat("md" dir))
    perform_tasks(dir, what_to_gather)
  }
}

return {
  main
  what_to_gather = map_table(shellcmds, @(v) v?.enabled ?? true)
  open_dir
}
