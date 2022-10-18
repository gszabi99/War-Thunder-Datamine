// configure scene when hosted in game
::gui_scene.config.clickRumbleEnabled = false

require("%rGui/hudChatCtrlsState.nut") //need this for controls mask updated
require("%rGui/ctrlsState.nut")

/*scale px by font size*/
let fontsState = require("%rGui/style/fontsState.nut")
::fpx <- fontsState.getSizePx //equal @sf/1@pf in gui
::dp <- fontsState.getSizeByDp //equal @dp in gui
::scrn_tgt <- fontsState.getSizeByScrnTgt //equal @scrn_tgt in gui
