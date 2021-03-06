
// Copyright (C) 2020 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

import bitmap show *
import color_tft show *
import font.matthew_welch.tiny as tiny_4
import font show *
import font.x11_100dpi.sans.sans_10 as sans_10
import font.x11_100dpi.sans.sans_24_bold as sans_24_bold
import gpio
import pixel_display show *
import pixel_display.four_gray show BarCodeEan13
import pixel_display.histogram show TrueColorHistogram
import pixel_display.texture show *
import pixel_display.true_color show *
import spi

get_display -> TrueColorPixelDisplay:
                                                // MHz x    y    xoff yoff sda clock cs  dc  reset backlight invert
  M5_STACK_16_BIT_LANDSCAPE_SETTINGS        ::= [  40, 320, 240, 0,   0,   23, 18,   14, 27, 33,   32,       false, COLOR_TFT_16_BIT_MODE ]
  ST7735_16_BIT_LANDSCAPE_SETTINGS          ::= [  40, 128, 160, 0,   0,   23, 18,   14, 27, 33,   32,       false, COLOR_TFT_16_BIT_MODE ]
  // Note: For the M5Stack Core2 you also need the m5stack_core2 package to
  // power up the display.
  M5_STACK_CORE_2_16_BIT_LANDSCAPE_SETTINGS ::= [  40, 320, 240, 0,   0,   23, 18,   5,  15, null, null,     true,  COLOR_TFT_16_BIT_MODE ]
  WROVER_16_BIT_LANDSCAPE_SETTINGS          ::= [  40, 320, 240, 0,   0,   23, 19,   22, 21, 18,   -5,       false, COLOR_TFT_16_BIT_MODE | COLOR_TFT_FLIP_XY ]
  LILYGO_16_BIT_LANDSCAPE_SETTINGS          ::= [  20, 80,  160, 26,  1,   19, 18,   5 , 23, 26,   27,       true,  COLOR_TFT_16_BIT_MODE ]
  FEATHERWING_16_BIT_SETTINGS               ::= [  20, 320, 240, 0,   0,   23, 22,   15, 33, null, null,     false, COLOR_TFT_16_BIT_MODE | COLOR_TFT_FLIP_XY ]

  // Pick one of the above.
  s := ST7735_16_BIT_LANDSCAPE_SETTINGS

  hz            := 1_000_000 * s[0]
  width         := s[1]
  height        := s[2]
  x_offset      := s[3]
  y_offset      := s[4]
  mosi          := gpio.Pin s[5]
  clock         := gpio.Pin s[6]
  cs            := gpio.Pin s[7]
  dc            := gpio.Pin s[8]
  reset         := s[9] == null ? null : gpio.Pin s[9]
  backlight     := s[10] == null ? null : gpio.Pin s[10]
  invert_colors := s[11]
  flags         := s[12]

  bus := spi.Bus
    --mosi=mosi
    --clock=clock

  device := bus.device
    --cs=cs
    --dc=dc
    --frequency=hz

  driver := ColorTft device width height
    --reset=reset
    --backlight=backlight
    --x_offset=x_offset
    --y_offset=y_offset
    --flags=flags
    --invert_colors=invert_colors
  tft := TrueColorPixelDisplay driver

  return tft

main:
  tft := get_display
  tft.background = get_rgb 0x00 0x00 0x80
  width := 160
  height := 128
  sans := Font [sans_10.ASCII]
  sans_big := Font [sans_24_bold.ASCII]
  tiny := Font [tiny_4.ASCII]
  red_x := 50
  green_x := 50
  red_dir := -3
  green_dir := 3
  sans_big_context := tft.context --landscape --color=WHITE --font=sans_big
  sans_context := tft.context --landscape --color=WHITE --font=sans
  tiny_context := tft.context --landscape --color=WHITE --font=tiny
  ctr := tft.text (sans_big_context.with --alignment=TEXT_TEXTURE_ALIGN_RIGHT) 160 25 "00000"
  ctr_small := tft.text sans_context 160 25 "000"
  red := tft.text (sans_context.with --color=(get_rgb 0x00 0x00 0xff)) red_x 50 "Red"
  green := tft.text (sans_context.with --color=(get_rgb 0x00 0xff 0x00)) green_x 120 "Green"
  numbers := tft.text tiny_context 20 70 "!\"#\$%&/(){}=?+`,;.:-_^~01234567890"
  lc := tft.text tiny_context 20 78 "abcdefghijklmnopqrstuvwxyz"
  uc := tft.text tiny_context 20 86 "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  frame := tft.text (sans_context.with --color=(get_rgb 0x00 0x00 0xff)) 60 230 ""
  // A red histogram stacked on a grey one, so that we can show values
  // that are too high in a different colour.

  histo_context := tft.context --color=WHITE --translate_x=19 --translate_y=130
  histo_transform := histo_context.transform
  red_histo := TrueColorHistogram  1 -20 50 40 histo_transform 1.0 (get_rgb 0xe0 0x20 0x10)
  grey_histo := TrueColorHistogram 1  20 50 50 histo_transform 1.0 (get_rgb 0xe0 0xe0 0xff)
  tft.add red_histo
  tft.add grey_histo
  x_axis := tft.filled_rectangle histo_context -10 70 70 1
  y_axis := tft.filled_rectangle histo_context 0 0 1 80

  code := "$(%06d (random 0 1000000))$(%07d (random 0 10000000))"
  barcode_transform := tft.landscape.translate 200 10
  barcode := BarCodeEan13 code 0 0 barcode_transform
  tft.add barcode

  tft.draw
  sleep --ms=5000

/// Something is wrong after this stage
  sq_x := width > height ? 120 : 80
  sq_y := width > height ? 80 : 120
  t := square_square sq_x sq_y tft.landscape:
    get_rgb (random 50 100) (random 200 255) (random 200 255)
  squares := t[0]
  square := t[1]

  tft.add squares
  tft.add square
  sq_x = square.x
  sq_y = square.y
  x := 0
  y := 0
  last := Time.monotonic_us
  while true:
    sleep --ms=10  // Avoid watchdog.
    square.move_to x y
    if x < sq_x: x += 2
    if y < sq_y: y += 2
    if x > sq_x: x = sq_x
    if y > sq_y: y = sq_y
    ctr.text = "$(%05d last / 1000000)"
    ctr_small.text = "$(%03d (last % 1000000) / 1000)"
    red_x += red_dir
    green_x += green_dir
    if green_x < 0 or red_x < 0:
      green_dir = -green_dir
      red_dir = -red_dir
      histo_transform = histo_transform.rotate_right.translate 0 -70
      red_histo.set_transform histo_transform
      grey_histo.set_transform histo_transform
      x_axis.set_transform histo_transform
      y_axis.set_transform histo_transform
      barcode_transform = (barcode_transform.translate 50 50).rotate_left.translate -50 -50
    else if barcode.transform != barcode_transform:
      barcode.set_transform barcode_transform
    red.move_to red_x 60
    red.color = get_rgb 0xff 0x7f + red_x 0x7f + red_x
    green.move_to green_x 120
    tft.draw
    next := Time.monotonic_us
    // Scale frame time by some random factor and display it on the histogram.
    diff := (next - last) >> 11
    frame.text = "$(%3s (next - last) / 1000)ms"
    grey_histo.add diff
    red_histo.add diff - 50
    last = next
 

square_square x y transform [get_color]:
  POSNS ::= [50, 0, 0, 35, 50, 0, 27, 85, 0, 15, 50, 35, 17, 65, 35, 6, 82, 46, 11, 82, 35, 8, 85, 27, 19, 93, 27, 29, 0, 50, 25, 29, 50, 9, 54, 50, 2, 63, 50, 7, 63, 52, 6, 72, 35, 16, 54, 59, 18, 70, 52, 24, 88, 46, 33, 0, 79, 4, 29, 75, 37, 33, 75, 42, 70, 70]

  texture := null
  group := TextureGroup

  for i := 0; i < POSNS.size; i += 3:
    tex := FilledRectangle
      (get_color.call i / 3)
      x + POSNS[i + 1]
      y + POSNS[i + 2]
      POSNS[i] - 1
      POSNS[i] - 1
      transform
    if not texture:
      texture = tex
    else:
      group.add tex
  return [group, texture]