from "%scripts/dagui_library.nut" import *
let logOC = log_with_prefix("[CLUSTERS_RTT] ")
let { get_charserver_time_millisec } = require("chard")
let { subscribe, unsubscribe } = require("eventbus")
let { format } =  require("string")
let { blob } = require("iostream")
let { get_time_msec } = require("dagor.time")
let { resetTimeout, clearTimer } = require("dagor.workcycle")
let { send, last_error, close_socket } = require("dagor.udp")
let { rnd_float } = require("dagor.random")
let { median, number_of_set_bits } = require("%sqstd/math.nut")
let { isEqual } = require("%sqstd/underscore.nut")
let { hardPersistWatched } = require("%sqstd/globalState.nut")
let { isInMenu, isMatchingOnline } = require("%scripts/clientState/clientStates.nut")
let { clusterHosts } = require("%scripts/onlineInfo/clusterHosts.nut")

const CLIENT_SOCKET_ID = "udp-echo-client-socket"
const ECHO_PORT = 3843
const PACKET_SIZE_BYTES = 32
const REQUEST_BITS_SET_MUL = 31

const REGULAR_PROBE_INTERVAL_SEC = 7200 
const FAILED_PROBE_INTERVAL_SEC = 600 
const CLUSTERS_RECALC_DELAY_SEC = 1 
const NEW_HOST_PROBE_MAX_DELAY_SEC = 600 
const SAMPLES_COUNT_MAX = 5 
const RETRY_PROBE_DELAY_SEC = 30 
const MAX_ERRORS = 3 
const OPTIMAL_RTT_LIMIT_MS = 100 
const INSIGNIFICANT_RTT_DIFF_MS = 25 
const MINOR_MS = 1000 

let optimalClusters = hardPersistWatched("optimalClusters", {})
let requestsCounter = hardPersistWatched("requestsCounter", 0)
let hostsCfg = persist("hostsCfg", @() {})
let clusterStats = persist("clusterStats", @() [])
let isProbingActive = Computed(@() isInMenu.get() && isMatchingOnline.get())


function writeInt64NetBytes(stream, i) {
  for (local n = 56; n >= 0; n -= 8)
    stream.writen((i >> n) & 0xFF, 'b')
}


function readInt64NetBytes(stream) {
  local i = 0
  for (local n = 56; n >= 0; n -= 8)
    i = i | (stream.readn('b') << n)
  return i
}

function toHexStr(str) {
  let arr = []
  foreach (i, c in str) {
    let delim = (i != 0 && i % 8 == 0) ? " " : ""
    arr.append(format("%s%02X", delim, c & 0xFF))
  }
  return "".join(arr)
}

function getPacketSign(id, timestamp, delayMs) {
  let bits = number_of_set_bits(id) + number_of_set_bits(timestamp) + number_of_set_bits(delayMs)
  let bitsSign = REQUEST_BITS_SET_MUL - (bits % REQUEST_BITS_SET_MUL)
  return ((-1) << bitsSign) ^ (-1)
}

function checkPacketSign(id, timestamp, sign, delayMs) {
  let bits = number_of_set_bits(id) + number_of_set_bits(timestamp)
    + number_of_set_bits(sign) + number_of_set_bits(delayMs)
  return bits != 0 && bits % REQUEST_BITS_SET_MUL == 0
}

function mkRequestData(requestNum) {
  let id = requestNum
  let timestamp = get_charserver_time_millisec()
  let delayMs = 0
  let sign = getPacketSign(id, timestamp, delayMs)
  let data = blob(PACKET_SIZE_BYTES)
  writeInt64NetBytes(data, id)
  writeInt64NetBytes(data, timestamp)
  writeInt64NetBytes(data, sign)
  writeInt64NetBytes(data, delayMs)
  return data
}

let mkHost = @(ip, port, clustersList) {
  ip
  port
  clustersList
  isActive = true
  rttSamples = []
  avgRTT = null
  lastRequestId = 0
  lastRequestTimeMs = 0
  errors = 0
  lastAnswerTimeMs = 0
}

function isHostNeedRegularUpdate(hostInfo, nowMs) {
  let { lastRequestTimeMs, lastAnswerTimeMs, avgRTT } = hostInfo
  let probingIntervalMs = (avgRTT != null ? REGULAR_PROBE_INTERVAL_SEC : FAILED_PROBE_INTERVAL_SEC) * 1000
  let timeExpiredMs = (nowMs - probingIntervalMs
    + (RETRY_PROBE_DELAY_SEC * 1000 * MAX_ERRORS) + MINOR_MS)
  return (lastRequestTimeMs == 0 || lastRequestTimeMs <= timeExpiredMs)
    && (lastAnswerTimeMs == 0 || lastAnswerTimeMs <= timeExpiredMs)
}

function isHostNeedRetry(hostInfo, nowMs) {
  let timeNextTryMs = nowMs - (RETRY_PROBE_DELAY_SEC * 1000) + MINOR_MS
  let { errors, lastRequestTimeMs } = hostInfo
  return errors < MAX_ERRORS && lastRequestTimeMs != 0 && lastRequestTimeMs <= timeNextTryMs
}

let isNeedProbeHost = @(hostInfo, nowMs)
  hostInfo.isActive && (isHostNeedRegularUpdate(hostInfo, nowMs) || isHostNeedRetry(hostInfo, nowMs))

function scheduleNextProbeTime(func) {
  if (!isProbingActive.get())
    return
  let nowMs = get_time_msec()
  let needCheckForNewHosts = requestsCounter.get() > 0
  local earliestTimeMs = nowMs + (REGULAR_PROBE_INTERVAL_SEC * 1000)
  local hasNewHosts = false
  foreach (hostInfo in hostsCfg) {
    let { lastRequestTimeMs, errors, lastAnswerTimeMs, avgRTT } = hostInfo
    let probingIntervalMs = (avgRTT != null ? REGULAR_PROBE_INTERVAL_SEC : FAILED_PROBE_INTERVAL_SEC) * 1000
    if (lastRequestTimeMs != 0) {
      let waitMs = errors < MAX_ERRORS ? (RETRY_PROBE_DELAY_SEC * 1000) : probingIntervalMs
      earliestTimeMs = min(earliestTimeMs, lastRequestTimeMs + waitMs)
    }
    else {
      hasNewHosts = hasNewHosts || (needCheckForNewHosts && lastAnswerTimeMs == 0 && errors == 0)
      let normalizedAnswerTimeMs = lastAnswerTimeMs != 0 ? lastAnswerTimeMs : (0 - probingIntervalMs)
      earliestTimeMs = min(earliestTimeMs, normalizedAnswerTimeMs + probingIntervalMs)
    }
  }
  let timeLeftSec = hasNewHosts
    
    
    ? (NEW_HOST_PROBE_MAX_DELAY_SEC * rnd_float(0.0, 1.0))
    
    
    : max(0.1, (earliestTimeMs - nowMs) / 1000.0)
  if (hasNewHosts)
    logOC($"New hosts detected, probe scheduled in {timeLeftSec} sec")
  resetTimeout(timeLeftSec, func)
}

function tryProbeHosts() {
  if (!isProbingActive.get())
    return
  let nowMs = get_time_msec()
  hostsCfg.each(function(hostInfo) {
    if (isHostNeedRetry(hostInfo, nowMs)) {
      hostInfo.errors++
      let clustersStr = ",".join(hostInfo.clustersList)
      logOC($"Host {hostInfo.ip} ({clustersStr}) failed to respond {hostInfo.errors} time(s)")
    }
    else if (isHostNeedRegularUpdate(hostInfo, nowMs))
      hostInfo.errors = 0
  })
  let hostsToProbe = hostsCfg.filter(@(h) isNeedProbeHost(h, nowMs))
  if (hostsToProbe.len() == 0) {
    scheduleNextProbeTime(callee())
    return
  }
  requestsCounter.set(requestsCounter.get() + 1)
  let id = requestsCounter.get()
  let data = mkRequestData(id)
  foreach (ip, hostInfo in hostsToProbe) {
    let { port } = hostInfo
    hostInfo.__update({
      lastRequestId = id
      lastRequestTimeMs = nowMs
    })
    if (!send(CLIENT_SOCKET_ID, ip, port, data))
      logOC($"Failed to send request to host {ip}, ERROR: {last_error()}")
  }
  scheduleNextProbeTime(callee())
}

function updateHostAvgRTT(hostInfo, rtt, receivedTimeMs) {
  let { rttSamples } = hostInfo
  if (rttSamples.len() == SAMPLES_COUNT_MAX)
    rttSamples.remove(0)
  rttSamples.append(rtt)
  hostInfo.__update({
    lastRequestId = 0
    lastRequestTimeMs = 0
    errors = 0
    avgRTT = median((clone rttSamples).sort())
    lastAnswerTimeMs = receivedTimeMs
  })
}

function getClusterStats() {
  
  

  let clustersToHostsMap = {}
  foreach (hostInfo in hostsCfg)
    foreach (clusterId in hostInfo.clustersList) {
      if (clustersToHostsMap?[clusterId] == null)
        clustersToHostsMap[clusterId] <- []
      clustersToHostsMap[clusterId].append(hostInfo)
    }

  let res = clustersToHostsMap
    .map(function(hosts, clusterId) {
        let measuredHostsRTT = hosts.map(@(h) h.avgRTT).filter(@(rtt) rtt != null)
        measuredHostsRTT.sort()
        return {
          clusterId
          hostsRTT = median(measuredHostsRTT)
        }
      })
    .values()
  res.sort(@(a, b)
    (a.hostsRTT != null ? -1 : 1) <=> (b.hostsRTT != null ? -1 : 1)
    || a.hostsRTT <=> b.hostsRTT)
  return res
}

function getOptimalClusters(stats) {
  stats = stats.filter(@(c) c.hostsRTT != null)
  if (stats.len() == 0)
    return []

  let fastClusters = stats
    .filter(@(c) c.hostsRTT <= OPTIMAL_RTT_LIMIT_MS)
  if (fastClusters.len())
    return fastClusters.map(@(c) c.clusterId)

  let rttLimit = stats[0].hostsRTT + INSIGNIFICANT_RTT_DIFF_MS
  return stats
    .filter(@(c) c.hostsRTT <= rttLimit)
    .map(@(c) c.clusterId)
}

function onClustersRecalc() {
  clusterStats.clear()
  clusterStats.extend(getClusterStats())
  let newOptimalClusters = getOptimalClusters(clusterStats)
  if (isEqual(newOptimalClusters, optimalClusters.get()))
    return
  logOC("Optimal clusters:", newOptimalClusters)
  optimalClusters.set(newOptimalClusters)
}

function logBadAnswer(evt, hostInfo, reason) {
  let clustersStr = ",".join(hostInfo?.clustersList ?? [])
  logOC($"{reason} packet from {evt.host} ({clustersStr}): \"{toHexStr(evt.data.as_string())}\"")
}

function onUdpPacket(evt) {
  if (evt.socketId != CLIENT_SOCKET_ID)
    return
  let { recvTime, data, host } = evt
  let hostInfo = hostsCfg?[host]
  let { lastRequestId = 0, lastRequestTimeMs = 0, clustersList = [] } = hostInfo
  if (hostInfo == null || lastRequestTimeMs == 0)
    return logBadAnswer(evt, hostInfo, "Ignored unexpected")

  local delayMs = 0
  local comment = ""
  if (data.len() == PACKET_SIZE_BYTES) {
    let id        = readInt64NetBytes(data)
    let timestamp = readInt64NetBytes(data)
    let sign      = readInt64NetBytes(data)
    delayMs       = readInt64NetBytes(data)
    if (id != lastRequestId || delayMs < 0 || !checkPacketSign(id, timestamp, sign, delayMs))
      return logBadAnswer(evt, hostInfo, "Ignored incorrect")
  }
  else
    comment = $" (packet unchecked)"

  let rtt = recvTime - lastRequestTimeMs - delayMs
  if (rtt < 0)
    return logBadAnswer(evt, hostInfo, $"Ignored (RTT {rtt})")

  let clustersStr = ",".join(clustersList)
  logOC($"Host {host} ({clustersStr}) responded, RTT: {rtt} ms{comment}")
  updateHostAvgRTT(hostInfo, rtt, recvTime)
  resetTimeout(CLUSTERS_RECALC_DELAY_SEC, onClustersRecalc)
}

clusterHosts.subscribe(function(v) {
  foreach (ip, clustersList in v)
    if (ip in hostsCfg)
      hostsCfg[ip].clustersList = clustersList
    else
      hostsCfg[ip] <- mkHost(ip, ECHO_PORT, clustersList)
  hostsCfg.each(@(hostInfo, ip) hostInfo.isActive = ip in v)
  scheduleNextProbeTime(tryProbeHosts)
})

isMatchingOnline.subscribe(function(_) {
  hostsCfg.each(@(hostInfo) hostInfo.__update({
    lastRequestId = 0
    lastRequestTimeMs = 0
    errors = 0
  }))
  scheduleNextProbeTime(tryProbeHosts)
})

function startProbe() {
  close_socket(CLIENT_SOCKET_ID)
  subscribe("udp.on_packet", onUdpPacket)
  scheduleNextProbeTime(tryProbeHosts)
}

function stopProbe() {
  close_socket(CLIENT_SOCKET_ID)
  clearTimer(tryProbeHosts)
  clearTimer(onClustersRecalc)
  unsubscribe("udp.on_packet", onUdpPacket)
}

isProbingActive.subscribe(@(v) v? startProbe() : stopProbe())
if (isProbingActive.get())
  startProbe()

return {
  optimalClusters
  clusterStats
}