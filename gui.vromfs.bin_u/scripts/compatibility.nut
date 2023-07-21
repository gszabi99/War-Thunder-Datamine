//checked for plus_string
from "%scripts/dagui_library.nut" import *

//--------------------------------------------------------------------//
//----------------------OBSOLETTE SCRIPT FUNCTIONS--------------------//
//-- Do not use them. Use null operators or native functons instead --//
//--------------------------------------------------------------------//

//--------------------------------------------------------------------//
//----------------------COMPATIBILITIES BY VERSIONS-------------------//
// -----------can be removed after version reach all platforms--------//
//--------------------------------------------------------------------//

let {apply_compatibilities} = require("%sqStdLibs/helpers/backCompatibility.nut")

//----------------------------wop_2_27_1_X---------------------------------//
apply_compatibilities({
  EXP_EVENT_HELP_TO_ALLIES = 32
})