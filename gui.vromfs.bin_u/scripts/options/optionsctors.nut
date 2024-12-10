from "%scripts/dagui_library.nut" import *
from "%scripts/utils_sa.nut" import locOrStrip

let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { getRgbStrFromHsv } = require("colorCorrector")
let u = require("%sqStdLibs/helpers/u.nut")

let checkArgument = function(id, arg, varType) {
  if (type(arg) == varType)
    return true

  let msg = "\n".concat(
    $"[ERROR] Wrong argument type supplied for option item '{id}'.",
    $"Value = {toString(arg)}.",
    $"Expected '{varType}' found '{type(arg)}'."
  )

  script_net_assert_once(id, msg)
  return false
}

function create_option_list(id, items, value, cb, isFull, spinnerType = null, optionTag = null, params = null) {
  if (!checkArgument(id, items, "array"))
    return ""

  if (!checkArgument(id, value, "integer"))
    return ""

  let view = {
    id = id
    optionTag = optionTag || "option"
    options = []
    onOptHoverFnName = params?.onOptHoverFnName
  }
  if (params)
    view.__update(params)
  if (cb)
    view.cb <- cb

  foreach (idx, item in items) {
    let opt = type(item) == "string" ? { text = item } : clone item
    opt.selected <- idx == value
    if ("hue" in item)
      opt.hueColor <- getRgbStrFromHsv(item.hue, item?.sat ?? 0.7, item?.val ?? 0.7)
    if ("hues" in item)
      opt.smallHueColor <- item.hues.map(@(hue) { color = getRgbStrFromHsv(hue, 1.0, 1.0) })

    if ("rgb" in item)
      opt.hueColor <- item.rgb

    if ("name" in item)
      opt.optName <- item.name

    if (type(item?.image) == "string") {
      opt.images <- [{ image = item.image }]
      opt.$rawdelete("image")
    }

    if (params?.onOptHoverFnName != null)
      opt.idx <- idx

    opt.enabled <- opt?.enabled ?? true
    if (!opt.enabled)
      spinnerType = "ComboBox" //disabled options can be only in dropright or combobox

    view.options.append(opt)
  }

  if (isFull) {
    let controlTag = spinnerType || "ComboBox"
    view.controlTag <- controlTag
    if (controlTag == "dropright")
      view.isDropright <- true
    if (controlTag == "ComboBox")
      view.isCombobox <- true
  }

  return handyman.renderCached(("%gui/options/spinnerOptions.tpl"), view)
}

function create_options_bar(id, value, text, items, cb, isFull = true, params = null) {
  let view = { id, value, text, cb, isFull, onOptHoverFnName = params?.onOptHoverFnName
    options = items.map(function (item, idx) {
      let option = type(item) == "string" ? { text = item } : clone item
      if (params?.onOptHoverFnName)
        option.__update({ idx })
      return { option }
    })
    optionsCount = items.len()
  }
  return handyman.renderCached(("%gui/options/optionsBar.tpl"), view)
}

function create_option_dropright(id, items, value, cb, isFull) {
  return create_option_list(id, items, value, cb, isFull, "dropright")
}

function create_option_combobox(id, items, value, cb, isFull, params = null) {
  return create_option_list(id, items, value, cb, isFull, "ComboBox", null, params)
}

let create_option_editbox = kwarg(function(id, value = "", password = false, maxlength = 16, charMask = null) {
  return "EditBox { id:t='{id}'; text:t='{text}'; width:t='0.2@sf'; max-len:t='{len}';{type}{charMask}}".subst({
    id = id,
    text = locOrStrip(value.tostring()),
    len = maxlength,
    type = password ? "type:t='password'; password-smb:t='{0}';".subst(loc("password_mask_char", "*")) : "",
    charMask = charMask ? $"char-mask:t='{charMask}';" : ""
  })
})

let create_option_switchbox = @(config) handyman.renderCached(("%gui/options/optionSwitchbox.tpl"), config)

function create_option_row_listbox(id, items, value, cb, isFull, listClass = "options") {
  if (!checkArgument(id, items, "array"))
    return ""
  if (!checkArgument(id, value, "integer"))
    return ""

  local data = "".concat(
    $"id:t = '{id}'; ",
    (cb != null ? $"on_select:t = '{cb}'; " : ""),
    $"on_dbl_click:t = 'onOptionsListboxDblClick'; class:t='{listClass}'; ",
  )

  let view = { items = [] }
  foreach (idx, item in items) {
    let selected = idx == value
    if (u.isString(item))
      view.items.append({ text = item, selected = selected })
    else
      view.items.append({
        text = getTblValue("text", item, "")
        image = getTblValue("image", item)
        disabled = getTblValue("enabled", item) || false
        selected = selected
        tooltip = getTblValue("tooltip", item, "")
      })
  }
  data = "".concat(data, handyman.renderCached("%gui/commonParts/shopFilter.tpl", view))

  if (isFull)
    data = "".concat(
      "HorizontalListBox { height:t='ph-6'; pos:t = 'pw-0.5p.p.w-0.5w, 0.5(ph-h)'; position:t = 'absolute'; ",
      data, "}")
  return data
}

function createOptionRowMultiselect(params) {
  let option = params?.option
  if (option == null
      || !checkArgument(option?.id, option?.items, "array")
      || !checkArgument(option?.id, option?.value, "integer"))
    return ""

  let view = {
    listClass = params?.listClass ?? "options"
    isFull = params?.isFull ?? true
    items = []
  }
  foreach (key in [ "id", "showTitle", "value", "cb" ])
    if ((option?[key] ?? "") != "")
      view[key] <- option[key]
  foreach (key in [ "textAfter" ])
    if ((option?[key] ?? "") != "")
      view[key] <- locOrStrip(option[key])

  foreach (v in option.items) {
    let item = type(v) == "string" ? { text = v, image = "" } : v
    let viewItem = {}
    foreach (key in [ "enabled", "isVisible" ])
      viewItem[key] <- item?[key] ?? true
    foreach (key in [ "id", "image" ])
      if ((item?[key] ?? "") != "")
        viewItem[key] <- item[key]
    foreach (key in [ "text", "tooltip" ])
      if ((item?[key] ?? "") != "")
        viewItem[key] <- locOrStrip(item[key])
    view.items.append(viewItem)
  }

  return handyman.renderCached(("%gui/options/optionMultiselect.tpl"), view)
}

function create_option_vlistbox(id, items, value, cb, isFull) {
  if (!checkArgument(id, items, "array"))
    return ""

  if (!checkArgument(id, value, "integer"))
    return ""

  local data = ""
  local itemNo = 0
  foreach (item in items) {
    data = "".concat(data, "option { text:t = '", item, "'; ", itemNo == value ? "selected:t = 'yes';" : "", " }")
    ++itemNo
  }

  data = "".concat($"id:t = '{id}'; ", cb != null ? $"on_select:t = '{cb}'; " : "", data)

  if (isFull)
    data = "".concat("VericalListBox { ", data, " }")
  return data
}

function create_option_slider(id, value, cb, isFull, sliderType, params = {}) {
  if (!checkArgument(id, value, "integer"))
    return ""

  let minVal = params?.min ?? 0
  let maxVal = params?.max ?? 100
  let step = params?.step ?? 5
  let clickByPoints = params?.clickByPoints ? "yes" : "no"
  let classProp = params?.cssClass ? $"class:t='{params.cssClass}';" : ""
  local data = "".concat(
    $"id:t = '{id}'; min:t='{minVal}'; max:t='{maxVal}'; step:t = '{step}'; value:t = '{value}'; ", classProp
    $"clicks-by-points:t='{clickByPoints}'; fullWidth:t={!params?.needShowValueText  ? "yes" : "no"};",
    cb == null ? "" : $"on_change_value:t = '{cb}'; "
  )
  if (isFull)
    data = "{0} { {1} focus_border{} tdiv{} }".subst(sliderType, data) //tdiv need to focus border not count as slider button

  return data
}

return {
  create_option_list
  create_option_combobox
  create_option_dropright
  create_option_editbox
  create_option_row_listbox
  create_options_bar
  create_option_switchbox
  create_option_slider
  create_option_vlistbox
  createOptionRowMultiselect
}