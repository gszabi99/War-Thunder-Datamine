::g_script_reloader.loadOnce("sqDagui/daguiUtil.nut")
::g_script_reloader.loadOnce("std/math.nut")

if (!("gui_bhv" in ::getroottable()))
  ::gui_bhv <- {}

if (!("gui_bhv_deprecated" in ::getroottable()))
  ::gui_bhv_deprecated <- {}


foreach (fn in [
                 "wrapDir.nut"
                 "lastNavigatorWrap.nut"
                 "bhvOptionsNavigator.nut"
                 "bhvTableNavigator.nut" //depend on OptionsNavigator
                 "bhvColumnNavigator.nut"
                 "bhvWrapNavigator.nut"
                 "bhvWrapBroadcast.nut"
                 "bhvPosNavigator.nut"
                 "bhvMultiSelect.nut" //depend on PosNavigator
                 "bhvActivateSelect.nut" //depend on PosNavigator
                 "bhvPosOptionsNavigator.nut" //depend on PosNavigator
                 "bhvTimer.nut"
                 "bhvBasic.nut"
                 "bhvControlsGrid.nut"
                 "bhvControlsInput.nut"
                 "bhvAnim.nut"
               ])
  ::g_script_reloader.loadOnce("sqDagui/guiBhv/" + fn)