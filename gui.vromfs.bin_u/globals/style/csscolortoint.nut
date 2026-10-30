from "%sqstd/string.nut" import hexStringToInt

return @[pure] (text) hexStringToInt(text.len() == 7 ? $"FF{text.slice(1)}" : text.slice(1))
