from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

//--------------------------------------------------------------------//
//----------------------OBSOLETTE SCRIPT FUNCTIONS--------------------//
//-- Do not use them. Use null operators or native functons instead --//
//--------------------------------------------------------------------//

//--------------------------------------------------------------------//
//----------------------COMPATIBILITIES BY VERSIONS-------------------//
// -----------can be removed after version reach all platforms--------//
//--------------------------------------------------------------------//

//----------------------------wop_2_15_1_X---------------------------------//
::apply_compatibilities({
  load_local_settings = @() null
})
