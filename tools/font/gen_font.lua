-- gen_font.lua — draws the "Karakuri Pop" bitmap UI font with Aseprite.
--
--   aseprite -b --script tools/font/gen_font.lua
--
-- Glyphs are authored as 5x7-ish pixel art (9 rows: 7 cap + 2 descender),
-- upscaled x2 with corner rounding (a convex corner sub-pixel drops to 45%
-- alpha), which is what turns a hard bitmap grid into something that reads
-- soft and toy-like next to the clay buttons. Output:
--   assets/fonts/pixel/karakuri_pop.png   (white glyph atlas, theme tints it)
--   assets/fonts/pixel/karakuri_pop.fnt   (AngelCode BMFont, Godot imports it)
-- Lowercase letters map to the capital glyph rects — the font is deliberately
-- small-caps; anything it lacks falls back to Fredoka via the FontVariation.

local ROOT = app.fs.filePath(app.fs.filePath(app.fs.filePath(debug.getinfo(1).source:sub(2))))
local OUT_DIR = app.fs.joinPath(ROOT, "assets/fonts/pixel")
local SCALE = 2
local ROWS = 9            -- 7 cap rows + 2 descender rows
local CELL_H = ROWS * SCALE
local PAD = 1
local ATLAS_W = 256

-- 1 = ink. Rows above the first listed row are empty ("drop" shifts art down).
local G = {}
local function g(ch, drop, rows)
  G[ch] = { drop = drop, rows = rows }
end

g("A", 0, {"01110","10001","10001","11111","10001","10001","10001"})
g("B", 0, {"11110","10001","10001","11110","10001","10001","11110"})
g("C", 0, {"01110","10001","10000","10000","10000","10001","01110"})
g("D", 0, {"11110","10001","10001","10001","10001","10001","11110"})
g("E", 0, {"11111","10000","10000","11110","10000","10000","11111"})
g("F", 0, {"11111","10000","10000","11110","10000","10000","10000"})
g("G", 0, {"01110","10001","10000","10111","10001","10001","01110"})
g("H", 0, {"10001","10001","10001","11111","10001","10001","10001"})
g("I", 0, {"111","010","010","010","010","010","111"})
g("J", 0, {"00111","00010","00010","00010","00010","10010","01100"})
g("K", 0, {"10001","10010","10100","11000","10100","10010","10001"})
g("L", 0, {"10000","10000","10000","10000","10000","10000","11111"})
g("M", 0, {"10001","11011","10101","10101","10001","10001","10001"})
g("N", 0, {"10001","11001","10101","10011","10001","10001","10001"})
g("O", 0, {"01110","10001","10001","10001","10001","10001","01110"})
g("P", 0, {"11110","10001","10001","11110","10000","10000","10000"})
g("Q", 0, {"01110","10001","10001","10001","10101","10010","01101"})
g("R", 0, {"11110","10001","10001","11110","10100","10010","10001"})
g("S", 0, {"01110","10001","10000","01110","00001","10001","01110"})
g("T", 0, {"11111","00100","00100","00100","00100","00100","00100"})
g("U", 0, {"10001","10001","10001","10001","10001","10001","01110"})
g("V", 0, {"10001","10001","10001","10001","10001","01010","00100"})
g("W", 0, {"10001","10001","10001","10101","10101","10101","01010"})
g("X", 0, {"10001","10001","01010","00100","01010","10001","10001"})
g("Y", 0, {"10001","10001","01010","00100","00100","00100","00100"})
g("Z", 0, {"11111","00001","00010","00100","01000","10000","11111"})

g("0", 0, {"01110","10001","10011","10101","11001","10001","01110"})
g("1", 0, {"00100","01100","00100","00100","00100","00100","01110"})
g("2", 0, {"01110","10001","00001","00110","01000","10000","11111"})
g("3", 0, {"01110","10001","00001","00110","00001","10001","01110"})
g("4", 0, {"00010","00110","01010","10010","11111","00010","00010"})
g("5", 0, {"11111","10000","10000","11110","00001","00001","11110"})
g("6", 0, {"01110","10000","10000","11110","10001","10001","01110"})
g("7", 0, {"11111","00001","00010","00100","01000","01000","01000"})
g("8", 0, {"01110","10001","10001","01110","10001","10001","01110"})
g("9", 0, {"01110","10001","10001","01111","00001","00001","01110"})

g(".", 5, {"11","11"})
g(",", 5, {"11","11","01","10"})
g("!", 0, {"11","11","11","11","11","00","11"})
g("?", 0, {"01110","10001","00001","00110","00100","00000","00100"})
g(":", 1, {"11","11","00","00","11","11"})
g(";", 1, {"11","11","00","00","11","11","01","10"})
g("'", 0, {"11","11","10"})
g("\"", 0, {"11011","11011","10010"})
g("-", 3, {"1111"})
g("+", 2, {"00100","11111","00100"})
g("(", 0, {"001","010","100","100","100","010","001"})
g(")", 0, {"100","010","001","001","001","010","100"})
g("/", 0, {"00001","00010","00010","00100","01000","01000","10000"})
g("=", 2, {"1111","0000","1111"})
g("~", 2, {"01001","10110"})
g("%", 0, {"11001","11010","00010","00100","01000","01011","10011"})
g("&", 0, {"01100","10010","10100","01000","10101","10010","01101"})
g("_", 7, {"11111"})
g("<", 0, {"0001","0010","0100","1000","0100","0010","0001"})
g(">", 0, {"1000","0100","0010","0001","0010","0100","1000"})

local ORDER = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,!?:;'\"-+()/=~%&_<>"

-- Filled test against the padded 9-row grid.
local function ink(gl, r, c)
  local rr = r - gl.drop
  local row = gl.rows[rr + 1]
  if row == nil or c < 0 or c >= #row then return false end
  return row:sub(c + 1, c + 1) == "1"
end

-- Upscale x2 with rounded convex corners.
local function render(img, ox, oy, gl, w)
  local white = app.pixelColor.rgba(255, 255, 255, 255)
  local soft = app.pixelColor.rgba(255, 255, 255, 115)
  for r = 0, ROWS - 1 do
    for c = 0, w - 1 do
      if ink(gl, r, c) then
        local up = ink(gl, r - 1, c)
        local down = ink(gl, r + 1, c)
        local left = ink(gl, r, c - 1)
        local right = ink(gl, r, c + 1)
        for sy = 0, 1 do
          for sx = 0, 1 do
            local corner =
              (sx == 0 and sy == 0 and not up and not left) or
              (sx == 1 and sy == 0 and not up and not right) or
              (sx == 0 and sy == 1 and not down and not left) or
              (sx == 1 and sy == 1 and not down and not right)
            img:drawPixel(ox + c * SCALE + sx, oy + r * SCALE + sy,
              corner and soft or white)
          end
        end
      end
    end
  end
end

-- Layout: row packing, uniform cell height.
local entries = {}
local x, y = PAD, PAD
local row_h = CELL_H + PAD
for i = 1, #ORDER do
  local ch = ORDER:sub(i, i)
  local gl = G[ch]
  local w = #gl.rows[1]
  local pw = w * SCALE
  if x + pw + PAD > ATLAS_W then
    x = PAD
    y = y + row_h
  end
  entries[#entries + 1] = { ch = ch, gl = gl, w = w, x = x, y = y, pw = pw }
  x = x + pw + PAD * 2
end
local atlas_h = y + row_h
local pot = 1
while pot < atlas_h do pot = pot * 2 end

local spr = Sprite(ATLAS_W, pot)
spr.cels[1].image = Image(ATLAS_W, pot, ColorMode.RGBA)
local img = spr.cels[1].image
for _, e in ipairs(entries) do
  render(img, e.x, e.y, e.gl, e.w)
end
app.fs.makeAllDirectories(OUT_DIR)
spr:saveAs(app.fs.joinPath(OUT_DIR, "karakuri_pop.png"))

-- AngelCode .fnt — size 20, cap top sits 3px under the line top, baseline 17.
local fnt = io.open(app.fs.joinPath(OUT_DIR, "karakuri_pop.fnt"), "wb")
local chars = {}
local function char_line(id, e)
  chars[#chars + 1] = string.format(
    "char id=%d x=%d y=%d width=%d height=%d xoffset=0 yoffset=3 xadvance=%d page=0 chnl=15",
    id, e.x, e.y, e.pw, CELL_H, e.pw + 2)
end
for _, e in ipairs(entries) do
  char_line(string.byte(e.ch), e)
  if e.ch >= "A" and e.ch <= "Z" then          -- small-caps: a-z share A-Z art
    char_line(string.byte(e.ch) + 32, e)
  end
end
chars[#chars + 1] = "char id=32 x=0 y=0 width=0 height=0 xoffset=0 yoffset=0 xadvance=8 page=0 chnl=15"
fnt:write('info face="KarakuriPop" size=20 bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1 outline=0\n')
fnt:write(string.format("common lineHeight=22 base=17 scaleW=%d scaleH=%d pages=1 packed=0 alphaChnl=1 redChnl=0 greenChnl=0 blueChnl=0\n", ATLAS_W, pot))
fnt:write('page id=0 file="karakuri_pop.png"\n')
fnt:write(string.format("chars count=%d\n", #chars))
fnt:write(table.concat(chars, "\n") .. "\n")
fnt:close()

-- Preview sheet (scratch, for eyeballing only).
local lines = {
  "KARAKURI STREAM",
  "PLAY  SETTINGS  QUIT",
  "SPRING  AUTUMN  SNOW  NIGHT",
  "HOW TO PLAY?  CTRL+Z UNDO!",
  "0123456789 .,!?:;'\"-+()/=~%&_<>",
}
local by_ch = {}
for _, e in ipairs(entries) do by_ch[e.ch] = e end
local pw_max = 0
for _, s in ipairs(lines) do
  local wsum = 0
  for i = 1, #s do
    local ch = s:sub(i, i)
    wsum = wsum + (ch == " " and 8 or (by_ch[ch] and by_ch[ch].pw + 2 or 0))
  end
  if wsum > pw_max then pw_max = wsum end
end
local prev = Sprite(pw_max + 16, #lines * 26 + 16)
prev.cels[1].image = Image(prev.width, prev.height, ColorMode.RGBA)
local pimg = prev.cels[1].image
local bg = app.pixelColor.rgba(58, 47, 38, 255)
for py = 0, prev.height - 1 do
  for px = 0, prev.width - 1 do pimg:drawPixel(px, py, bg) end
end
for li, s in ipairs(lines) do
  local cx = 8
  local cy = 8 + (li - 1) * 26
  for i = 1, #s do
    local ch = s:sub(i, i)
    if ch == " " then
      cx = cx + 8
    else
      local e = by_ch[ch]
      if e then
        render(pimg, cx, cy, e.gl, e.w)
        cx = cx + e.pw + 2
      end
    end
  end
end
local scratch = os.getenv("KARAKURI_FONT_PREVIEW")
if scratch and #scratch > 0 then
  prev:saveAs(scratch)
end
print("atlas " .. ATLAS_W .. "x" .. pot .. ", glyphs " .. #entries)
