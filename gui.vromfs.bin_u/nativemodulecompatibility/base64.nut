return {
  encodeString = @(str) ::encode_base64(str)
  decodeString = @(str) str
  encodeJson = @(obj) ::json_to_base64(obj)
  encodeBlk = @(blk) ::blk_to_base64(blk)
}
