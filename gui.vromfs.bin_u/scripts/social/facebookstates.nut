let function isAvailableFacebook() {
  return ::has_feature("Facebook") && ::get_country_code() != "RU"
}

return {
  isAvailableFacebook,
}