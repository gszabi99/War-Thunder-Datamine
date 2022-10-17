#allow-root-table
return{
  is_stereo_mode = @() ::is_stereo_mode?() ?? false
  is_stereo_configured = @() false
  configure_stereo = @() false
}
