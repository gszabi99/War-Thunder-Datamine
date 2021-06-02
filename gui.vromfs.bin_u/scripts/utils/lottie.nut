local imageSource = "#ui/gameuiskin#render{lottie:t={image};canvasWidth:i={width};canvasHeight:i={height};loop:b={loop};play:b={play};}.render"

local getLottieImage = ::kwarg(function getLottieImage(image, width, height = null, loop = true, play = true) {
  width = ::to_pixels(width)
  height = height != null ? ::to_pixels(height) : width
  return imageSource.subst({image, width, height, loop, play})
})

return getLottieImage