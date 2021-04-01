local needShowOverrideSlotbar = @(event) event?.showEditSlotbar ?? false

local getCustomViewCountryData = @(event) event?.customViewCountry

return {
  needShowOverrideSlotbar
  getCustomViewCountryData
}