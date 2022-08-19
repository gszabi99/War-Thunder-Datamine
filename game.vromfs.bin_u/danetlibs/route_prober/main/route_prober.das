require DagorDataBlock
require DagorMath
require DagorRandom
require DagorSystem
require DagorTime
require %danetlibs.route_prober.main.net_events
require daslib/algorithm
require ecs
require ClientNet
require net
require statsd

let MAIN_HOST_ROUTE_ID : uint = 0u// strong assumption, but currently there is no way to know, which route is the host
let PERMILLE_PER_PERCENT : int = 10

// TODO(k.zakharchenko): update to description when the logic is established
// When the route evaluation is enabled, there is one route_prober and several route_stats entities (one for each route to the server).
// Route evaluation is executed in a regular period. Route prober takes the last 10 seconds stats of the currently enabled route and
// compares them with the stats of alternative routes. The alternative route stats may be stale because they were obtained the last time
// that route was used. But all routes are used for a brief amount of time at the beginning of the evaluation. The stats difference
// between the current route and an alternative is calculated as an estimated "advantage" of switching to the alternative route. Most of
// the time the absolute value of the advantage is small, like 5-15%. So the advantage is accumulated in route_stats entities. If the
// advantage is mostly positive, the accumulated value soon will cross the threshold. When this happens, the route gets switched to the
// alternative. The accumulated value is clamped to the MIN and MAX limits. Currently, there are two metrics, that affect the evaluation:
// packet loss and RTT estimation. Packet loss has precedence over the RTT. If an alternative route has much worse packet loss, but somehow
// better RTT, it isn't considered to have an advantage over the current route.

// The metric, that signals the need for route change is accumulated over time
// The value is initially set to PERCENT_DIFF_SUM_NEUTRAL and varies from PERCENT_DIFF_SUM_MIN and PERCENT_DIFF_SUM_MAX
// When the value passes the threshold PERCENT_RTT_SUM_THRESHOLD the route changes
let DEFAULT_PERCENT_RTT_SUM_THRESHOLD : int = 100// threshold for measurment aggregated over time
let DEFAULT_PERCENT_DIFF_SUM_MIN : int = -100// lower bound for accumulated metrics

let PERCENT_DIFF_SUM_MAX : int = 100// upper bound for accumulated metrics
let PERCENT_DIFF_SUM_NEUTRAL : int = 0// initial value for accumulated metric
let PERCENT_DIFF_SUM_DECAY_FACTOR : float = 0.95 // so that two routes with a small fluctuating difference won't be constantly switching

// The client evaluates the route over ECHO_HISTORY_MAX_LENGTH * DEFAULT_ECHO_PERIOD_SECONDS seconds
let ECHO_HISTORY_MAX_LENGTH : int = 10
let DEFAULT_ECHO_PERIOD_SECONDS : float = 1.
let RTT_MAX : uint = uint(INT_MAX)

// Echo history has timeouts just alongside regular echo responses, meaning the timeout is indistinguishable from high ping (true to life)
def get_rtt_estimation(echo_history : UInt32List) : uint
  if length(echo_history) == 0 // Happens if the route is unavailable after less than a 1 second of the game (practically impossible)
    return RTT_MAX
  var rttSum : uint = 0u
  for rtt in echo_history
    rttSum += rtt
  let rttAvg : uint = rttSum / uint(length(echo_history))
  var deviationSum : uint = 0u
  for rtt in echo_history
    deviationSum += max(rtt, rttAvg) - min(rtt, rttAvg)
  // Mean Absolute Deviation is less sensitive to outliers than STDDEV; yet huge outliers (like timeouts) are still noticeable in the metric
  let rttMad = deviationSum / uint(length(echo_history))
  return rttAvg + rttMad

def get_circuit_param(param : string; fallback : int) : int
  var val : int = fallback
  get_circuit_conf() <| $(var blk : DataBlock?#)
    let proberBlock : DataBlock const? = blk |> datablock_get_block_by_name_const("route_prober")
    if proberBlock != null
      val = proberBlock |> datablock_getInt(param, fallback)
  return val

def get_circuit_param(param : string; fallback : float) : float
  var val : float = fallback
  get_circuit_conf() <| $(var blk : DataBlock?#)
    let proberBlock : DataBlock const? = blk |> datablock_get_block_by_name_const("route_prober")
    if proberBlock != null
      val = proberBlock |> datablock_getReal(param, fallback)
  return val

def get_settings(param : string; fallback : bool) : bool
  let netBlock = dgs_get_settings() |> datablock_get_block_by_name_const("net")
  return netBlock |> datablock_getBool(param, fallback)

def get_settings(param : string; fallback : int) : int
  let netBlock = dgs_get_settings() |> datablock_get_block_by_name_const("net")
  return netBlock |> datablock_getInt(param, fallback)

// Enables experiment with a given chance depending on current session id (deterministically)
def is_matching_experiment_enabled(chance : float) : bool
  let session : uint64 = get_session_id()
  var seed : int = int(session)
  let r : float = _frnd(seed)// [0, 1)
  return r < chance

def get_percent_diff(x : uint; y : uint) : int// [-100, 100]
  // https://en.wikipedia.org/wiki/Relative_change_and_difference#Formulae
  let m : int = max(int(x), int(y))
  return (m != 0) ? 100 * (int(x) - int(y)) / m : 0

def try_launch_route_prober(add_rtt : int) : void
  let routeCount : uint = get_server_route_count()
  print("Route evaluation of {int(routeCount)} routes; add rtt {add_rtt}")

  if routeCount < 2u
    return

  createEntity("route_prober") <| $(var init : ComponentsInitializer&)
    init |> set("route_count", routeCount)
    init |> set("diff_sum_min", get_circuit_param("diff_sum_min", DEFAULT_PERCENT_DIFF_SUM_MIN))
    init |> set("rtt_sum_threshold", get_circuit_param("rtt_sum_threshold", DEFAULT_PERCENT_RTT_SUM_THRESHOLD))
    init |> set("echo_period_seconds", get_circuit_param("echo_period_seconds", DEFAULT_ECHO_PERIOD_SECONDS))
    init |> set("add_rtt", uint(add_rtt))

  for route_id in urange(routeCount)
    createEntity("route_stats") <| $(var init : ComponentsInitializer&)
      init |> set("route_id", route_id)

def get_diff_bucket_str(rtt_diff : int) : string
  let buckets = [[int-9000; -500; -200; -100; -75; -50; -40; -30; -20; -15; -10; -5; 0; 5; 10; 15; 20; 30; 40; 50; 75; 100; 200; 500; 9000]]
  var lb = lower_bound(buckets, rtt_diff) // lb in [0..length(buckets)]
  if lb == length(buckets)
    lb -= 1
  return "_{buckets[lb]}" // "_" because of grafana bug: https://github.com/grafana/grafana/issues/38993

def report_route_prober_statistics() : void
  var mainRouteRtt : uint = RTT_MAX
  var bestFromTheRest : uint = RTT_MAX

  query() <| $ [es(REQUIRE=routeStats)] (route_id : uint; rtt_estimation : uint)
    if route_id == MAIN_HOST_ROUTE_ID
      mainRouteRtt = rtt_estimation
    else
      bestFromTheRest = min(bestFromTheRest, rtt_estimation)

  let rtt_diff : int = int(mainRouteRtt) - int(bestFromTheRest)
  let percent_diff : int = get_percent_diff(mainRouteRtt, bestFromTheRest)
  print("Reporting RTT diff {rtt_diff} ({percent_diff}%)")

  let mainHostUrl = get_server_route_host(MAIN_HOST_ROUTE_ID)
  statsd_counter("route_prober.pct_diff", 1, "bucket", get_diff_bucket_str(percent_diff), "host_url", mainHostUrl)
  statsd_counter("route_prober.rtt_diff", 1, "bucket", get_diff_bucket_str(rtt_diff), "host_url", mainHostUrl)

def report_route_availability(routeId : uint; echoHistory : UInt32List; lastIsTimeout : bool) : void
  var available : bool = true

  if lastIsTimeout
    available = false
    let timeout : uint = echoHistory[length(echoHistory) - 1]
    for echo in echoHistory
      if echo != timeout
        available = true

  // TODO(k.zakharchenko): add country
  let hostUrl = get_server_route_host(routeId)
  statsd_counter((available ? "net.responsive_route" : "net.unresponsive_route"), 1, "addr", hostUrl)

def report_midgame_switch(target : uint) : void
  print("Midgame switch to #{int(target)}")
  statsd_counter("route_prober.switch", 1, "to", "{int(target)}", "host_url", get_server_route_host(MAIN_HOST_ROUTE_ID))

def report_initial_best(best_route : uint) : void
  print("Initial best route is #{int(best_route)}")
  statsd_counter("route_prober.initial", 1, "route", "{int(best_route)}", "host_url", get_server_route_host(MAIN_HOST_ROUTE_ID))

def report_final_best(initial_best : uint) : void
  let finalBest : uint = get_current_server_route_id()
  let mainHostUrl = get_server_route_host(MAIN_HOST_ROUTE_ID)
  print("Final best route is #{int(finalBest)}")
  if finalBest != initial_best && (finalBest == MAIN_HOST_ROUTE_ID || initial_best == MAIN_HOST_ROUTE_ID)
    // The initial decision was overruled in the midgame; either channel degradation or bad initial evaluation
    statsd_counter("route_prober.final_changed", 1, "route", "{int(finalBest)}", "host_url", mainHostUrl)
  else
    statsd_counter("route_prober.final_stayed", 1, "route", "{int(finalBest)}", "host_url", mainHostUrl)

[es(tag=netClient, no_order)]
def try_launch_route_prober_from_settings(evt : EventOnConnectedToServer)
  if get_settings("useServerRouteEvaluation", false)
    try_launch_route_prober(get_settings("addRtt", 0))

[es(tag=netClient, no_order)]
def try_launch_route_prober_from_matching_params(evt : MatchingRoomExtraParams)
  if !get_settings("useServerRouteEvaluation", false) && is_matching_experiment_enabled(evt.routeEvaluationChance)
    let ddosSimulationEnabled : bool = is_matching_experiment_enabled(evt.ddosSimulationChance)
    try_launch_route_prober(ddosSimulationEnabled ? evt.ddosSimulationAddRtt : 0)

[es(tag=netClient, no_order, on_disappear, REQUIRE=routeProber)]
def cleanup_route_prober(evt : Event; initial_best : uint)
  report_final_best(initial_best)

[es(no_order, REQUIRE=routeProber)]
def route_prober_timers(info : UpdateStageInfoAct;
                        route_count : uint;
                        echo_period_seconds : float;
                        evaluation_period_seconds : float;
                        var next_evaluation : float&;
                        var next_echo_broadcast : float&)
  if info.curTime > next_echo_broadcast
    next_echo_broadcast = info.curTime + echo_period_seconds
    // Maybe do round-robing instead of broadcasting all at once?
    for route_id in urange(route_count)
      send_echo_msg(route_id)
  if info.curTime > next_evaluation
    if next_evaluation != 0.
      // skip the avaluation the first time, because there is not enough echo packets were sent yet
      broadcastEvent([[ChangeServerRoute currentIsUnresponsive=false]])
    next_evaluation = info.curTime + evaluation_period_seconds

[es(no_order, REQUIRE=routeStats)]
def receive_echo_response(response : NetEchoReponse; route_id : uint; var echo_history : UInt32List&)
  if response.routeId != route_id
    return

  echo_history |> push(response.rttOrTimeout)

  if length(echo_history) > ECHO_HISTORY_MAX_LENGTH
    erase(echo_history, 0)
  elif length(echo_history) == ECHO_HISTORY_MAX_LENGTH // condition happens exactly once per route per session
    report_route_availability(route_id, echo_history, response.result != int(EchoResponseResult SUCCESS))

[es(tag=netClient, no_order)]
def evaluate_server_route(evt : ChangeServerRoute)
  let hasRouteProber = find_query() <| $ [es(REQUIRE=routeProber)] (diff_sum_min : int;
                                                                    rtt_sum_threshold : int;
                                                                    add_rtt : uint;
                                                                    var initial_best : uint&;
                                                                    var statistics_reported : bool&)
    let currentRoute : uint = get_current_server_route_id()
    var currentRttEstimation : uint = RTT_MAX

    query() <| $ [es(REQUIRE=routeStats)] (route_id : uint;
                                           echo_history : UInt32List;
                                           var rtt_estimation : uint&)
      rtt_estimation = get_rtt_estimation(echo_history)
      if route_id == MAIN_HOST_ROUTE_ID
        rtt_estimation += add_rtt

      if route_id == currentRoute
        currentRttEstimation = rtt_estimation

    var bestRoute : uint = currentRoute
    var forceChange : bool = evt.currentIsUnresponsive
    var bestRttEstimation : uint = currentRttEstimation
    var maxDiffSum : int = diff_sum_min

    query() <| $ [es(REQUIRE=routeStats)] (route_id : uint;
                                           rtt_estimation : uint;
                                           var rtt_diff_sum : int&)
      if route_id == currentRoute
        return
      let rttDiff : int = get_percent_diff(currentRttEstimation, rtt_estimation)
      // If there is a positive difference in rtt, don't switch immediately.
      // Instead accumulate the difference. Only consistent but small or
      // sudden but huge difference results in the switch. The connection with
      // a "bad record" (the one with accumulated negative difference) will
      // need more time to gain positive sum and prove itself worthy a switch.
      // diff_sum_min may be set to 0, to disable the negative sum logic.
      rtt_diff_sum = int(float(rtt_diff_sum) * PERCENT_DIFF_SUM_DECAY_FACTOR)
      rtt_diff_sum = clamp(rtt_diff_sum + rttDiff, diff_sum_min, PERCENT_DIFF_SUM_MAX)
      maxDiffSum = max(maxDiffSum, rtt_diff_sum)
      if forceChange || rtt_diff_sum >= rtt_sum_threshold
        bestRoute = route_id
        bestRttEstimation = rtt_estimation
        forceChange = false

    print("Current server route #{int(currentRoute)} available={!evt.currentIsUnresponsive} "
        + "rtt estimation={int(currentRttEstimation)} best route #{int(bestRoute)} "
        + "rtt estimation={int(bestRttEstimation)} max diff sum={maxDiffSum}")

    if bestRoute != currentRoute
      report_midgame_switch(bestRoute)
      switch_server_route(bestRoute)
      query() <| $ [es(REQUIRE=routeStats)] (var rtt_diff_sum : int&)
        rtt_diff_sum = PERCENT_DIFF_SUM_NEUTRAL

    if !statistics_reported
      report_route_prober_statistics()
      report_initial_best(bestRoute)
      initial_best = bestRoute
      statistics_reported = true

    return true

  if !hasRouteProber && evt.currentIsUnresponsive // The prober isn't started [yet]
    let serverRouteCount : uint = get_server_route_count()
    if serverRouteCount > 1u
      switch_server_route((get_current_server_route_id() + 1u) % serverRouteCount)
