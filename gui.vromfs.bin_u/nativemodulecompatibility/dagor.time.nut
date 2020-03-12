return {
  get_time_msec = @() 0
  get_local_unixtime = @() ::get_local_time_sec?() ?? 0
  utc_timetbl_to_unixtime = @(t) ::get_t_from_utc_time(t)
  unixtime_to_utc_timetbl = @(ts) ::get_utc_time_from_t(ts)
  local_timetbl_to_unixtime = @(t) ::mktime(t)
  unixtime_to_local_timetbl = @(ts) ::get_time_from_t(ts)
}