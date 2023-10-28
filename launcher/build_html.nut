let { concat } = require("system.nut")
let { loc } = require("dagor.localize")

local elem_tostr

elem_tostr = function(elem){
  if (type(elem) == "function")
    return elem()
  if (type(elem) == "array")
    return elem.reduce(@(a,b) a+elem_tostr(b), "")
  else
    return elem.tostring()
}

let function _html(html_tag, params={}, reserved_params={}) {
  let html = ["<",html_tag]
  local title = ("title" in params) ? params.title : null
  if ("id" in params)  {
    if (loc(concat("settings/adv/"params.id"_title")) != concat("settings/adv/"params.id "_title"))
      title = loc(concat("settings/adv/" params.id"_title"))
    else if (loc(concat("settings/" params.id"_title")) != concat("settings/"params.id"_title"))
      title = loc(concat("settings/"params.id"_title"))
  }
  foreach (k, val in params) {
    if (!(k in reserved_params) && k != "extra" && k != "class_" && k != "title")
      html.append(" ",k,"='",val,"'")
    if (k == "extra")
      html.append(" ",val)
    if (k == "class_")
      html.append(" class='",val, "'")
  }
  if (title != "" && title != null){
    if (title.contains("'"))
      html.append(" title=\"",title,"\"")
    else
      html.append(" title='",title,"'")
  }
  html.append(">")
  return "".join(html)
}

let function build_td(td) {
  //td = "some html"
  //or td={v="some html", class_=class, extra=".hidden", title="some title"}
  if (type(td)=="string")
    return concat("<td>",td,"</td>\n")
  if (["table","instance"].indexof(type(td)) != null) {
    local ret = _html("td", td, {v=""})
    let v = ("v" in td) ? td.v : ""
    ret = concat(ret,v)
    ret = concat(ret,"</td>\n")
    return ret
  }
  return ""
}

let function build_tr(params={}, num=null) {
  //params = {title="title" extra=".hidden" class_="some class" cols = "some html"}
  //params = {title="title" extra=".hidden" class_="some class" cols = ["some html1","some html2"]}
  //params = {title="title" extra=".hidden" class_="some class" cols = [{v="some html1"},"some html2"]}

  //cols = string, list of strings, list of tables for build_td, table for build_td

  let tr = [_html("tr", params, {cols=""})]
  local columns = ("cols" in params) ? params.cols : []
  local isError = false
  if (type(columns) != "array")
    columns = [columns]

  local td_num = 0
  foreach (c in columns) {
    if (type(c)=="array") {
      foreach (i in c) {
        if (type(i)=="array") {
          foreach (j in i) {
            tr.append(build_td(j))
            td_num += 1
          }
        } else {
          tr.append(build_td(i))
          td_num += 1
        }
      }
    }
    else {
      tr.append(build_td(c))
      td_num += 1
    }
  }
  if (num) {
    while (td_num < num) {
      tr.append("<td></td>")
      td_num +=1
    }
    if (td_num > num) {
      println($"bad table raw - too many columns, columns should be = {num}, but total = {td_num}" )
      isError = true
    }
  }
  tr.append("</tr>\n")
  if (!isError)
    return "".join(tr)
  return ""
}

let function h_table(params={}) {
  let html = [concat(_html("table", params, {col_num="",raws=""}), "\n")]
  let col_num = ("col_num" in params) ? params.col_num : null
  let raws = ("raws" in params) ? params.raws : []
  foreach (raw in raws) {
    if (type(raw) == "array" || type(raw) == "string") {
      html.append(build_tr({cols = raw}, col_num))
    }
    else if (type(raw) == "table")
      html.append(build_tr(raw, col_num))
  }
  html.append("</table>\n")
  return "".join(html)
}

let function tds(vals,params={}) {
  let ret = []
  foreach (v in vals) {
    let i = clone params
    i["v"] <- v
    ret.append(i)
  }
  return ret
}

let function select(def, params_={}) {
  let params = params_.__merge(def)
  let html = [concat(_html("select", params, {options=[]}), "\n")]
  foreach (opt in params.options) {
    local o = opt
    if (type(opt) != "table")
      o = {value = opt}
    html.append(_html("option", o, {text=""}))
    if ("text" in o)
      html.append(o.text)
    else {
      if (loc(concat("setting/",o.value)) != concat("setting/",o.value))
        html.append(loc(concat("setting/", o.value)))
      else
        html.append(o.value)
    }
    html.append("</option>\n")
  }
  html.append("</select>\n")
  return "".join(html)
}

let function he(tag, params, ...) {
  assert(type(tag) == "string", @() $"{tag} is not string")
  return concat(_html(tag, params), "".join(vargv.map(elem_tostr)), "</", tag, ">")
}


let function input(params, ...) {
  return he.acall([null, "input", params].extend(vargv))
}

//print(build_tr({extra="", cols = [loc("settings/landquality"), "a","b","c"]},4))
//print(build_td("some html"))
//print(build_td({title="some title" extra=".hidden" v="another_html"}))
//print(build_tr({title="some title" extra=".hidden" cols=[{v="another_html"}, {v="another_html2"}]}))
//print(build_tr({title="some title" extra=".hidden" cols={v="another_html"}}))
return {
  he
  input
  select
  tds
  h_table
  _html
  build_td
  build_tr
}
