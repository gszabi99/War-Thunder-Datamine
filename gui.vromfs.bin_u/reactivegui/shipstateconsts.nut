const FIRST_ROW_SIGNAL_TRIGGER = "reload_alarm_first_row"
const SECOND_ROW_SIGNAL_TRIGGER = "reload_alarm_second_row"

enum gunState {
  OVERHEAT = 0
  NORMAL = 1
  INOPERABLE = 2
  DEADZONE = 3
}

return {
  FIRST_ROW_SIGNAL_TRIGGER,
  SECOND_ROW_SIGNAL_TRIGGER,
  gunState
}