module ecs_plot_common shared

let PLOT_HISTORY_MIN = 16
let PLOT_HISTORY_MAX = 90000  
let PLOT_MAX_ASSUMED_FPS = 300
let PLOT_MIN_ASSUMED_TIMESPEED = 0.1f
let PLOT_MAX_ENTRIES = 12
let PLOT_WINDOW_COUNT = 4

struct PlotEntry
  name        : string
  comp_idx    : int
  dim         : int
  eid         : uint
  slot        : uint  
  scale_min   : float
  scale_max   : float
  fit         : bool
  hidden      : bool
  is_int      : bool
  edit_val      : float
  committed_val : float
  values      : array<float>
  write_idx   : int
  count       : int
  found       : bool
  val_editing : bool
  slot_mode   : bool  
  last_discovery_fail_time : float  
  max_dq      : array<int>
  min_dq      : array<int>
  max_head    : int
  max_tail    : int
  min_head    : int
  min_tail    : int

struct PlotWindow
  entries          : array<PlotEntry>
  history_size     : int
  paused           : bool
  grid_x           : int
  grid_y           : int
  y_scale_idx      : int
  ts_write_idx     : int
  ts_count         : int
  plot_duration    : float
  prev_n_entries   : int
  win_size_init    : bool
  timestamps       : array<float>
  max_entry_count  : int
  toolbar_eid       : uint
  toolbar_slot      : uint
  toolbar_slot_mode : bool  
  dirty             : bool
