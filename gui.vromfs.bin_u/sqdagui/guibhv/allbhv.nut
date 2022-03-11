::g_script_reloader.loadOnce("%sqDagui/daguiUtil.nut")
::g_script_reloader.loadOnce("%sqstd/math.nut")

if (!("gui_bhv" in getroottable()))
  ::gui_bhv <- {}

if (!("gui_bhv_deprecated" in getroottable()))
  ::gui_bhv_deprecated <- {}


foreach (fn in [
                 "wrapDir.nut"
                 "bhvPosNavigator.nut"
                 "bhvMultiSelect.nut" //depend on PosNavigator
                 "bhvActivateSelect.nut" //depend on PosNavigator
                 "bhvPosOptionsNavigator.nut" //depend on PosNavigator
                 "bhvHoverNavigator.nut" //depend on PosNavigator
                 "bhvWrapBroadcast.nut"
                 "bhvTimer.nut"
                 "bhvBasic.nut"
                 "bhvControlsInput.nut"
                 "bhvAnim.nut"
               ])
  ::g_script_reloader.loadOnce("%sqDagui/guiBhv/" + fn)