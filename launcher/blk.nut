let DataBlock = require("DataBlock")

//----------------------------- BLK processing routines
::get_blk_by_path <- function(func_name, blk, path, def_val) {
  let arr=::split_by_chars(path, "/")
  for (local i=0; i<arr.len()-1; ++i) {
    blk=blk?[arr[i]]
    if (!blk)
      return def_val
  }
  return blk[func_name](arr[arr.len()-1], def_val)
}


::set_blk_by_path <- function(func_name, blk, path, val) {
  let arr=::split_by_chars(path, "/")
  for (local i=0; i<arr.len()-1; ++i)
    blk=blk.addBlock(arr[i])

  return blk[func_name](arr[arr.len()-1], val)
}


::get_blk_str <- function (blk, path, def_val) { return ::get_blk_by_path("getStr" , blk, path, def_val); }
::get_blk_bool <- function(blk, path, def_val) { return ::get_blk_by_path("getBool", blk, path, def_val); }
::get_blk_real <- function(blk, path, def_val) { return ::get_blk_by_path("getReal" , blk, path, def_val); }
::get_blk_int <- function (blk, path, def_val) { return ::get_blk_by_path("getInt" , blk, path, def_val); }

::set_blk_str <- function (blk, path, val) {
  if (typeof(val) == "string")
    return ::set_blk_by_path("setStr" , blk, path, val)
}
::set_blk_bool <- function(blk, path, val) {
  if (typeof(val) == "bool")
    return ::set_blk_by_path("setBool", blk, path, val)
}
::set_blk_real <- function(blk, path, val) {
  if (typeof(val) == "float")
    return ::set_blk_by_path("setReal" , blk, path, val)
}
::set_blk_int <- function(blk, path, val) {
  if (typeof(val) == "integer")
    return ::set_blk_by_path("setInt" , blk, path, val)
}

let function set_values_to_gui(blk, scheme) {
  foreach (name,desc in scheme) {

    local value=null
    if ("getFromBlk" in desc)
      value=desc.getFromBlk(blk, desc)

    switch(desc.type) {

      case "string":
        if (value==null)
          value=::get_blk_str(blk, desc.blk, desc.defVal)
        ::setValue(name, value)
        break;

      case "bool":
        if (value==null)
          value=::get_blk_bool(blk, desc.blk, desc.defVal)
        ::setValue(name, value)
        break;

      case "real":
        if (value==null)
          value=::get_blk_real(blk, desc.blk, desc.defVal)
        ::setValue(name, value)
        break;

      case "int":
        if (value==null)
          value=::get_blk_int(blk, desc.blk, desc.defVal)
        ::setValue(name, value)
        break;
    }
  }
}


let function set_values_from_gui(blk, scheme) {

  foreach (name,desc in scheme) {
    if (::exists(name))
      switch(desc.type) {

        case "string":
          let value=::getValue(name, desc.defVal)
          if ("setToBlk" in desc)
            desc.setToBlk(blk, desc, value)
          else
            ::set_blk_str(blk, desc.blk, value)
          break;

        case "bool":
          let value=::getValue(name, desc.defVal)
          if ("setToBlk" in desc)
            desc.setToBlk(blk, desc, value)
          else
            ::set_blk_bool(blk, desc.blk, value)
          break;

        case "int":
          let value=::getValue(name, desc.defVal)
          if ("setToBlk" in desc)
            desc.setToBlk(blk, desc, value)
          else
            ::set_blk_int(blk, desc.blk, value)
          break;

        case "real":
          let value=::getValue(name, desc.defVal)
          if ("setToBlk" in desc)
            desc.setToBlk(blk, desc, value)
          else
            ::set_blk_real(blk, desc.blk, value)
          break;
      }
  }
}


::load_blk <- function(blk, path) {
  try {
    blk.load(path)
    return true
  }
  catch(e) {
    println("Couldn't load {0}: {1}".subst(path, e))
  }

  return false
}


//Returns DataBlock. It may be empty DataBlock if .blk wasn't loaded or parsed properly
::create_and_load_blk <- function(path) {
  let blk = DataBlock()
  ::load_blk(blk, path)
  return blk
}


//Returns DataBlock or null on error. Not null return means DataBlock was loaded and parsed successfully
::create_and_load_blk_only_if_exist <- function(path) {
  let blk = DataBlock()
  if (::load_blk(blk, path))
    return blk

  return null
}



::Settings <- class {
  scheme=null
  fileNameLoad=null
  fileNameSave=null
  data=null

  constructor(fn, schm) {
    this.scheme=schm
    this.fileNameLoad = ::getSettingsBlkLoadPath(fn)
    this.fileNameSave = ::getSettingsBlkSavePath(fn)

    println($"settings.constructor fileNameLoad = {this.fileNameLoad}" )
    println($"settings.constructor fileNameSave = {this.fileNameSave}")

    this.data = ::create_and_load_blk(this.fileNameLoad)
  }

  function updateGui() {
    set_values_to_gui(this.data, this.scheme)
  }

  function save() {
    ::load_blk(this.data, this.fileNameLoad)
    set_values_from_gui(this.data, this.scheme)

    return this.data.saveToTextFile(this.fileNameSave)
  }
}

