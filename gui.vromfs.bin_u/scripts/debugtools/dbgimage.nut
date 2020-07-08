//to correct scale prefer to set 1080p before using this function.
//size:
//   int - image size on 1080p big fonts
//   null - various image sizes
//   string - daguiConstant
local g_path = require("std/path.nut")
local dagor_fs = require("dagor.fs")

::debug_svg <- function debug_svg(image, size = null, bgColor = "#808080")
{
  local baseHeight = ::u.isInteger(size) ? 1080 : ::screen_height()
  local view = {
    image = image
    bgColor = bgColor
    blocks= []
  }

  if (::u.isString(size))
    size = ::to_pixels(size)

  if (::u.isInteger(size) && size > 0)
  {
    local block = { header = size, sizeList = [] }
    local screenHeights = [720, 768, 800, 864, 900, 960, 1024, 1050, 1080, 1200, 1440, 1800, 2160]
    foreach(sf in screenHeights)
      block.sizeList.append({ name = sf, size = (size.tofloat() * sf / baseHeight + 0.5).tointeger() })
    view.blocks.append(block)
  } else
  {
    local screenHeights = [720, 1080, 2160]
    local smallestFont = ::g_font.getSmallestFont(1280, 720)
    if (smallestFont && smallestFont.sizeMultiplier < 1)
      screenHeights.insert(0, smallestFont.sizeMultiplier * 720)
    local sizes = ["@sIco", "@cIco", "@dIco", "@lIco"]
    foreach(sf in screenHeights)
    {
      local block = { header = "screen height " + sf, sizeList = [] }
      view.blocks.append(block)
      foreach(s in sizes)
      {
        local px = ::to_pixels(s)
        block.sizeList.append({ name = " " + s + " ", size = (px.tofloat() * sf / baseHeight + 0.5).tointeger() })
      }
    }
  }

  debug_wnd("gui/debugTools/dbgSvg.tpl", view)
}



::debug_svg_list <- function debug_svg_list(fileMask = null, size = null, bgColor = null)
{
  fileMask  = fileMask  || "*.svg"
  size      = size      || "64@sf/@pf"
  bgColor   = bgColor   || "#808080"

  local skyquakePath = ::debug_get_skyquake_path()
  local dirs = [
    $"{skyquakePath}/develop/gui/hud/gui_skin",
    $"{skyquakePath}/develop/gui/hud/pkg_dev",
  ]

  local filesList = []
  foreach (dir in dirs)
  {
    local filePaths = dagor_fs.scan_folder({root=dir, files_suffix=fileMask, vromfs=false, realfs = true, recursive = true})
    filesList.extend(::u.map(filePaths, @(path) g_path.fileName(path)))
  }
  filesList.sort()

  local view = {
    title = "debug_svg_list(\"" + fileMask + "\")"
    size = ::u.isString(size) ? ::to_pixels(size) : size
    bgColor = bgColor
    files = []
  }

  foreach (filename in filesList)
    view.files.append({
      name = ::g_string.slice(filename, 0, -4)
      image = "!ui/gameuiskin/" + filename
    })

  local handler = {
    scene = null
    guiScene = null

    function onCreate(obj)
    {
      scene = obj
      guiScene = obj.getScene()
    }

    function onImgClick(obj)
    {
      ::view_fullscreen_image(obj.findObject("image"))
    }
  }

  ::debug_wnd("gui/debugTools/dbgSvgList.tpl", view, handler)
}
