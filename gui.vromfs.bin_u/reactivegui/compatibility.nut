local behaviors = {
  TouchScreenButton = "TouchScreenButton"
}
if (getconsttable()?.Behaviors)
  getconsttable().Behaviors = behaviors.__update(getconsttable().Behaviors)
