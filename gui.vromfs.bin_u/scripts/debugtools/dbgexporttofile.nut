// warning disable: -file:forbidden-function

/**
 *  export() is a tool for batch exporting a huge amounts of data into blk file without a freeze.
 *  It uses guiScene.performDelayed() to prosess a little part of data on every frame.
 *
 *  @params {table} params - Table of parameters, see EXPORT_PARAMS below.
 *
**/

local EXPORT_PARAMS = { //const
  resultFilePath  = "export/file.blk" // Resulting blk filename to write results to.
  itemsPerFrame   = 1                 // Num of items to process per single frame.
  list            = []                // Array of items to process.
  itemProcessFunc = @(value) null     // Function, takes value from list, returns processed result -
                                      // table { key="id", value = DataBlock }, or null.
                                      // If it returns table, its keys will be written to resulting
                                      // blk this way: resBlk[table.key] <- table.value
  onFinish        = null              // Function to execute when finished, or null.
}

local function export_impl(params, resBlk, idx)
{
  local exportImplFunc = ::callee()
  for(local i = idx; i != params.list.len(); i++)
  {
    if (i != idx && !(i % params.itemsPerFrame)) //avoid freeze
    {
      dlog("GP: " + i + " done.")
      ::get_gui_scene().performDelayed(this, @() exportImplFunc(params, resBlk, i))
      return
    }

    local item = params.list[i]
    local data = item && params.itemProcessFunc(params.list[i])
    if (data)
      resBlk[data.key] <- data.value
  }

  ::dd_mkpath(params.resultFilePath)
  resBlk.saveToTextFile(params.resultFilePath)

  if (params?.onFinish)
    params.onFinish()
}

local function export(params = EXPORT_PARAMS)
{
  params = EXPORT_PARAMS.__merge(params)
  export_impl(params, ::DataBlock(), 0)
}

return {
  export = export
}
