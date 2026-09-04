import "gdk.package" as package

let chunk_availability = @(chunk_id) package.get_package_chunk_availability(package.get_package_id(), chunk_id)
let feature_availability = @(feature) package.get_package_feature_availability(package.get_package_id(), feature)
let install_chunk = @(chunk_id) package.install_package_chunk(package.get_package_id(), chunk_id)
let install_feature = @(feature) package.install_package_feature(package.get_package_id(), feature)
let uninstall_chunk = @(chunk_id) package.uninstall_package_chunk(package.get_package_id(), chunk_id)
let uninstall_feature = @(feature) package.uninstall_package_feature(package.get_package_id(), feature)
let chunk_progress = @(chunk_id) package.get_package_chunk_progress(package.get_package_id(), chunk_id)
let feature_progress = @(feature) package.get_package_feature_progress(package.get_package_id(), feature)
let is_chunk_ready = @(chunk_id) chunk_availability(chunk_id) == package.Availability.Ready
let is_feature_ready = @(feature) feature_availability(feature) == package.Availability.Ready

return freeze({
  Availability = package.Availability
  get_package_id = package.get_package_id

  chunk_availability
  feature_availability
  install_chunk
  install_feature
  uninstall_chunk
  uninstall_feature
  chunk_progress
  feature_progress
  is_chunk_ready
  is_feature_ready
})
