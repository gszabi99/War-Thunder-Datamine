from "%scripts/dagui_natives.nut" import get_charserver_time_millisec
from "%scripts/dagui_library.nut" import *
let logOC = log_with_prefix("[CLUSTERS_RTT] ")
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
let { isInMenu } = require("%scripts/clientState/clientStates.nut")
let { isMatchingOnline } = require("%scripts/matching/matchingOnline.nut")
let { clusterHosts } = require("%scripts/onlineInfo/clusterHosts.nut")

const CLIENT_SOCKET_ID = "udp-echo-client-socket"
const ECHO_PORT = 3843
const PACKET_SIZE_BYTES = 32
const REQUEST_BITS_SET_MUL = 31

const REGULAR_PROBE_INTERVAL_SEC = 7200 // How ofter hosts should be probed normally
const FAILED_PROBE_INTERVAL_SEC = 600 // How ofter hosts should be probed when RTT unknown
const CLUSTERS_RECALC_DELAY_SEC = 1 // Delay to prevent updating clusters watch for every packet in a burst
const NEW_HOST_PROBE_MAX_DELAY_SEC = 600 // Max delay to probe a new hosts at a random time
const SAMPLES_COUNT_MAX = 5 // A max number of samples used for the calculation of the moving average
const RETRY_PROBE_DELAY_SEC = 30 // Delay to repoeat request when answer is not received
const MAX_ERRORS = 3 // Stop retries when host not responding multiple times, until next probing of all hosts
const OPTIMAL_RTT_LIMIT_MS = 100 // Hosts whose average RTT falls within the limit are considered to be optimal
const INSIGNIFICANT_RTT_DIFF_MS = 25 // Extra diff to collect more hosts which are not optimal
const MINOR_MS = 1000 // Minor time diff to avoid timer divirgence when collecting hosts to probe

let optimalClusters = hardPersistWatched("optimalClusters", {})
let requestsCounter = hardPersistWatched("requestsCounter", 0)
let hostsCfg = persist("hostsCfg", @() {})
let clusterStats = persist("clusterStats", @() [])
let isProbingActive = Computed(@() isInMenu.value && isMatchingOnline.value)

// Writes to stream a 64-bit integer as Network Endian
let function writeInt64NetBytes(stream, i) {
  for (local n = 56; n >= 0; n -= 8)
    stream.writen((i >> n) & 0xFF, 'c')
}

// Reads from stream a 64-bit integer as Network Endian
let function readInt64NetBytes(stream) {
  local i = 0
  for (local n = 56; n >= 0; n -= 8)
    i = i | (stream.readn('c') << n)
  return i
}

let function toHexStr(str) {
  let arr = []
  foreach (i, c in str) {
    let delim = (i != 0 && i % 8 == 0) ? " " : ""
    arr.append(format("%s%02X", delim, c))
  }
  return "".join(arr)
}

let function getPacketSign(id, timestamp, delayMs) {
  let bits = number_of_set_bits(id) + number_of_set_bits(timestamp) + number_of_set_bits(delayMs)
  let bitsSign = REQUEST_BITS_SET_MUL - (bits % REQUEST_BITS_SET_MUL)
  return ((-1) << bitsSign) ^ (-1)
}

let function checkPacketSign(id, timestamp, sign, delayMs) {
  let bits = number_of_set_bits(id) + number_of_set_bits(timestamp)
    + number_of_set_bits(sign) + number_of_set_bits(delayMs)
  return bits != 0 && bits % REQUEST_BITS_SET_MUL == 0
}

let function mkRequestData(requestNum) {
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

let function isHostNeedRegularUpdate(hostInfo, nowMs) {
  let { lastRequestTimeMs, lastAnswerTimeMs, avgRTT } = hostInfo
  let probingIntervalMs = (avgRTT != null ? REGULAR_PROBE_INTERVAL_SEC : FAILED_PROBE_INTERVAL_SEC) * 1000
  let timeExpiredMs = (nowMs - probingIntervalMs
    + (RETRY_PROBE_DELAY_SEC * 1000 * MAX_ERRORS) + MINOR_MS)
  return (lastRequestTimeMs == 0 || lastRequestTimeMs <= timeExpiredMs)
    && (lastAnswerTimeMs == 0 || lastAnswerTimeMs <= timeExpiredMs)
}

let function isHostNeedRetry(hostInfo, nowMs) {
  let timeNextTryMs = nowMs - (RETRY_PROBE_DELAY_SEC * 1000) + MINOR_MS
  let { errors, lastRequestTimeMs } = hostInfo
  return errors < MAX_ERRORS && lastRequestTimeMs != 0 && lastRequestTimeMs <= timeNextTryMs
}

let isNeedProbeHost = @(hostInfo, nowMs)
  hostInfo.isActive && (isHostNeedRegularUpdate(hostInfo, nowMs) || isHostNeedRetry(hostInfo, nowMs))

let function scheduleNextProbeTime(func) {
  if (!isProbingActive.value)
    return
  let nowMs = get_time_msec()
  let needCheckForNewHosts = requestsCounter.value > 0
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
    // Note about probing new hosts: All clients gets new hosts simultaneously by a pushed message.
    // Probe time is ramdomized for new hosts to avoid rush of simultaneous requests from clients.
    ? (NEW_HOST_PROBE_MAX_DELAY_SEC * rnd_float(0.0, 1.0))
    // If earliestTimeMs is in the past, then either it is initial probing, or player was in a battle
    // or offline, when it was time for a regular probing. In this case lets probe hosts now.
    : max(0.1, (earliestTimeMs - nowMs) / 1000.0)
  if (hasNewHosts)
    logOC($"New hosts detected, probe scheduled in {timeLeftSec} sec")
  resetTimeout(timeLeftSec, func)
}

let function tryProbeHosts() {
  if (!isProbingActive.value)
    return
  let nowMs = get_time_msec()
  hostsCfg.each(function(hostInfo) {
    if (isHostNeedRetry(hostInfo, nowMs)) {
      hostInfo.errors++
      logOC($"Host {hostInfo.ip} failed to respond {hostInfo.errors} time(s)")
    }
    else if (isHostNeedRegularUpdate(hostInfo, nowMs))
      hostInfo.errors = 0
  })
  let hostsToProbe = hostsCfg.filter(@(h) isNeedProbeHost(h, nowMs))
  if (hostsToProbe.len() == 0) {
    scheduleNextProbeTime(callee())
    return
  }
  requestsCounter(requestsCounter.value + 1)
  let id = requestsCounter.value
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

let function updateHostAvgRTT(hostInfo, rtt, receivedTimeMs) {
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

let function getClusterStats() {
  // Usually multiple hosts relates to every cluster (like 5 hosts has "EU" in clustersList),
  // but also, a host can participate in multiple clusters, this is why clustersList is an array.

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

let function getOptimalClusters(stats) {
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

let function onClustersRecalc() {
  clusterStats.clear()
  clusterStats.extend(getClusterStats())
  let newOptimalClusters = getOptimalClusters(clusterStats)
  if (isEqual(newOptimalClusters, optimalClusters.value))
    return
  logOC("Optimal clusters:", newOptimalClusters)
  optimalClusters.update(newOptimalClusters)
}

let logIgnoredMsg = @(evt) logOC($"Ignored packet from {evt.host}: \"{toHexStr(evt.data.as_string())}\"")

let function onUdpPacket(evt) {
  let { socketId, recvTime, data, host } = evt
  let hostInfo = hostsCfg?[host]
  let { lastRequestId = 0, lastRequestTimeMs = 0 } = hostInfo
  if (socketId != CLIENT_SOCKET_ID || data.len() != PACKET_SIZE_BYTES || hostInfo == null || lastRequestTimeMs == 0)
    return logIgnoredMsg(evt)
  let id        = readInt64NetBytes(data)
  let timestamp = readInt64NetBytes(data)
  let sign      = readInt64NetBytes(data)
  let delayMs   = readInt64NetBytes(data)
  let rtt = recvTime - lastRequestTimeMs - delayMs
  if (id != lastRequestId || delayMs < 0 || rtt < 0
      || !checkPacketSign(id, timestamp, sign, delayMs))
    return logIgnoredMsg(evt)
  logOC($"Host {host} responded, RTT: {rtt} ms")
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

let function startProbe() {
  close_socket(CLIENT_SOCKET_ID)
  subscribe("udp.on_packet", onUdpPacket)
  scheduleNextProbeTime(tryProbeHosts)
}

let function stopProbe() {
  close_socket(CLIENT_SOCKET_ID)
  clearTimer(tryProbeHosts)
  clearTimer(onClustersRecalc)
  unsubscribe("udp.on_packet", onUdpPacket)
}

isProbingActive.subscribe(@(v) v? startProbe() : stopProbe())
if (isProbingActive.value)
  startProbe()

return {
  optimalClusters
  clusterStats
}