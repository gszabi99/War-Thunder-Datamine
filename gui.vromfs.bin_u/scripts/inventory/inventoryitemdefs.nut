import "packed" as packed
from "string" import split_by_chars

let tagsValueRemap = freeze({
  yes         = true,
  no          = false,
  ["true"]    = true,
  ["false"]   = false,
})


let keptItemdefKeys = freeze({ itemdefid = true, tags = true, type = true, Timestamp = true, name = true,
  description = true, icon_url = true, icon_url_large = true })
let isDefaultItemdefValue = @[pure](v) v == "" || (type(v) == "bool" && !v) || (type(v) == "integer" && v == 0)


function parseTags(text) {
  let tags = {}
  local tagLists = null
  foreach (pair in split_by_chars(text, ";")) {
    let parsed = split_by_chars(pair, ":")
    if (parsed.len() != 2)
      continue
    let [name, v] = parsed
    let value = tagsValueRemap?[v] ?? v
    if (name not in tags) {
      tags[name] <- value
      continue
    }
    tagLists = tagLists ?? {}
    if (name not in tagLists)
      tagLists[name] <- [tags[name]]
    tagLists[name].append(value)
  }
  return { tags, tagLists }
}

function mkItemdef(itemdef, parsedTagsCache) {
  let res = {}
  foreach (key, value in itemdef)
    if (key in keptItemdefKeys || !isDefaultItemdefValue(value))
      res[key] <- value
  let text = res.tags
  if (!text) {
    res.tags = null
    return res
  }
  if (text not in parsedTagsCache)
    parsedTagsCache[text] <- parseTags(text)
  let { tags, tagLists } = parsedTagsCache[text]
  res.tags = tags
  if (tagLists != null)
    res.tagLists <- tagLists
  return res
}


function addItemdefs(itemdefs, itemdefList) {
  if (itemdefList.len() == 0)
    return
  let batch = {}
  let parsedTagsCache = {}
  foreach (itemdef in itemdefList)
    batch[itemdef.itemdefid] <- mkItemdef(itemdef, parsedTagsCache)
  let batchView = packed.pack(batch)
  foreach (itemdef in itemdefList)
    itemdefs[itemdef.itemdefid] <- batchView[itemdef.itemdefid]
}

function getItemdefTagValues(itemdef, name) {
  let list = itemdef?.tagLists?[name]
  if (list != null)
    return packed.unpack(list)
  let value = itemdef?.tags?[name]
  return value == null ? [] : [value]
}

let sharedTagsTables = {}


function getSharedItemdefTags(itemdef) {
  let tags = itemdef?.tags
  if (tags == null)
    return null
  let keyParts = []
  foreach (name, value in tags)
    keyParts.append($"{name}={type(value)}:{value}")
  let key = ";".join(keyParts)
  local shared = sharedTagsTables?[key]
  if (shared == null) {
    shared = freeze(packed.unpack(tags))
    sharedTagsTables[key] <- shared.weakref()
  }
  return shared
}

function getItemdefTagsTable(itemdef, table) {
  foreach (name, value in itemdef?.tags ?? {})
    table[name] <- value
  foreach (name, list in itemdef?.tagLists ?? {})
    table[name] <- list[list.len() - 1]
  return table
}

return freeze({
  addItemdefs
  getItemdefTagValues
  getSharedItemdefTags
  getItemdefTagsTable
})
