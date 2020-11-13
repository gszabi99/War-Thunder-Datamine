local u = require("sqStdLibs/helpers/u.nut")

//Recursive translator to DataBlock data.
//More conviniet to store, search and use data in DataBlock.
// It saves order of items in tables as an array,
// and block can easily be found by header as in table.

local function fillBlock(id, block, data, arrayKey = "array") {
  if (u.isArray(data)) {
    local newBl = id == arrayKey? block.addNewBlock(id) : block.addBlock(id)
    foreach (idx, v in data)
      fillBlock(v?.label ?? arrayKey, newBl, v)
  }
  else if (u.isTable(data)) {
    local newBl = id == arrayKey? block.addNewBlock(id) : block.addBlock(id)
    foreach (key, val in data)
      fillBlock(key, newBl, val)
  }
  else {
    if (id == arrayKey)
      block[id] <- data
    else
      block[id] = data
  }
}

return {
  fillBlock
}