from "%scripts/dagui_library.nut" import *

let regexp2 = require("regexp2")
let { resetTimeout } = require("dagor.workcycle")
let { OPERATION_COMPLETE } = require("matching.errors")
let { hardPersistWatched } = require("%sqstd/globalState.nut")
let { isInBattleState } = require("%scripts/clientState/clientStates.nut")
let { isMatchingOnline } = require("%scripts/matching/matchingOnline.nut")
let { matchingApiFunc, matchingRpcSubscribe } = require("%scripts/matching/api.nut")

let logCH = log_with_prefix("[CLUSTER_HOSTS] ")

const MAX_FETCH_RETRIES = 5
const MAX_FETCH_DELAY_SEC = 60
const OUT_OF_RETRIES_DELAY_SEC = 300

let clusterHosts = hardPersistWatched("clusterHosts", {})
let clusterHostsChangePending = hardPersistWatched("clusterHostsChangePending", {})
let canFetchHosts = Computed(@() isMatchingOnline.value && !isInBattleState.value)
local isFetching = false
local failedFetches = 0

let reIP = regexp2(@"^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$")

function fetchClusterHosts() {
  if (!canFetchHosts.value || isFetching)
    return

  isFetching = true
  logCH($"fetchClusterHosts (try {failedFetches})")
  let again = callee()
  matchingApiFunc("hmanager.fetch_hosts_list",
    function (result) {
      isFetching = false

      if (result.error == OPERATION_COMPLETE) {
        failedFetches = 0
        let hosts = result.filter(@(_, ip) reIP.match(ip))
        logCH($"Fetched hosts count: {hosts.len()}")
        clusterHosts(hosts)
        return
      }

      failedFetches++
      if (failedFetches < MAX_FETCH_RETRIES)
        resetTimeout(0.1, again)
      else {
        failedFetches = 0
        resetTimeout(OUT_OF_RETRIES_DELAY_SEC, again)
      }
    }, { timeout = MAX_FETCH_DELAY_SEC })
}

function tryFetchHosts() {
  isFetching = false
  failedFetches = 0
  if (canFetchHosts.value && clusterHosts.value.len() == 0)
    fetchClusterHosts()
}

canFetchHosts.subscribe(@(_) tryFetchHosts())

function tryApplyChangedHosts() {
  if (isInBattleState.value || clusterHostsChangePending.value.len() == 0)
    return
  logCH($"Applying changed hosts")
  clusterHosts(clusterHostsChangePending.value)
  clusterHostsChangePending({})
}

isInBattleState.subscribe(@(_) tryApplyChangedHosts())

matchingRpcSubscribe("hmanager.notify_hosts_list_changed", function(result) {
  let hosts = result.filter(@(_, ip) reIP.match(ip))
  logCH($"Changed hosts count: {hosts.len()}")
  clusterHostsChangePending(hosts)
  tryApplyChangedHosts()
})

tryApplyChangedHosts()
tryFetchHosts()

return {
  clusterHosts
}
