from "functools.nut" import *

local {Task} = require("monads.nut")
local http = require("dagor.http")
//local dlog = require("log.nut")().dlog
/*
  todo:
    ? handle http code different from 200..300 as error
*/

local statusText = {
  [http.SUCCESS] = "SUCCESS",
  [http.FAILED] = "FAILED",
  [http.ABORTED] = "ABORTED",
}

local function httpGet(url, callback){
  http.request({
    url
    method = "GET"
    callback
  })
}
local function TaskHttpGet(url) {
  return Task(function(rejectFn, resolveFn) {
    println($"http 'get' requested for '{url}'")
    http.request({
      url
      method = "GET"
      callback = tryCatch(
        function(response){
          local status = response.status
          local sttxt = statusText?[status]
          println($"http status for '{url}' = {sttxt}")
          if (status != http.SUCCESS) {
            throw($"http error status = {sttxt}")
          }
          resolveFn(response.body)
        },
        rejectFn
      )
    })
  })
}

local UNRESOLVED = persist("UNRESOLVED", @() {})
local RESOLVED = persist("UNRESOLVED", @() {})
local REJECTED = persist("REJECTED", @() {})

local function TaskHttpMultiGet(urls, rejectOne=@(x) x, resolveOne=@(x) x) {
  assert(typeof urls == "array", @() $"expected urls as 'array' got '{typeof urls}'")
  assert(typeof rejectOne == "function" && typeof resolveOne == "function", "incorrect type of arguments")
  return Task(function(rejectFn, resolveFn) {
    local total = urls.len()
    local res = array(total)
    local statuses = array(total, UNRESOLVED)
    local executed = false
    local function checkStatus(){
      local rejected = statuses.findindex(@(v) v==REJECTED) != null
      local resolved = !rejected && statuses.filter(@(v) v==RESOLVED).len() == total
      if (resolved && !executed){
        executed = true
        resolveFn(res)
      }
      if (rejected && !executed){
        executed = true
        rejectFn(res)
      }
    }
    foreach (i, u in urls) {
      local id = i
      local url = u
      println($"http requested get for '{url}'")
      http.request({
        url
        method = "GET"
        callback = tryCatch(
          function(response){
            local status = response.status
            local sttxt = statusText?[status]
            println($"http status for '{url}' = {sttxt}")
            if (status != http.SUCCESS) {
              throw($"http error status = {sttxt}")
            }
            res[id] = resolveOne(response.body)
            statuses[id] = RESOLVED
            checkStatus()
          },
          function(r) {
            res[id] = rejectOne(r)
            statuses[id] = REJECTED
            checkStatus()
          }
        )
      })
    }
  })
}

return{
  TaskHttpGet
  httpGet
  TaskHttpMultiGet
}