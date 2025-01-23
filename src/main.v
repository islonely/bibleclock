module main

import gg
import gx
import time

@[heap]
struct App {
	gg.Context
mut:
	imgs []gg.Image
	loc  shared struct {
	mut:
		book    Book
		chapter Chapter
		verse   Verse
		time    time.Time
	}

	should_hour_min_separator_blink bool = true
	is_hour_min_separator_visible   bool = true
}

fn main() {
	mut app := &App{}
	app.Context = gg.new_context(
		// ui_mode:           true
		user_data:         app
		frame_fn:          frame
		bg_color:          gx.white
		width:             1024
		height:            600
		font_bytes_normal: $embed_file('./fonts/ubuntu/UbuntuMono-R.ttf').to_bytes()
		// fullscreen: true
	)
	app.init() or {
		println('Init failure: ${err.str()}')
		exit(1)
	}
	app.run()
}

fn frame(mut app App) {
	app.Context.begin()
	// blink between "12:01" and "12 01" every second
	if app.should_hour_min_separator_blink {
		app.is_hour_min_separator_visible = bool(time.now().second % 2 == 0)
	}

	sz := app.window_size()
	app.width = sz.width
	app.height = sz.height
	app.draw_image_background(app.imgs[0])
	app.draw_rect_filled(0, 0, app.width, app.height, gx.rgba(0x00, 0x00, 0x00, 0x80))
	app.draw_verse_time()
	app.Context.end()
}

fn (mut app App) draw_image_background(img gg.Image) {
	scaled_percent := f32(app.width) / f32(img.width)
	w := scaled_percent * img.width
	h := scaled_percent * img.height
	x := 0
	y := (app.height - h) / 2
	app.draw_image(x, y, w, h, img)
}

fn (mut app App) draw_verse_time() {
	verse_padding := 15
	verse_font_size := 40
	max_chars_on_line := (app.width - (verse_padding * 2)) / verse_font_size * 2
	hour_min_sep := if app.is_hour_min_separator_visible {
		':'
	} else {
		' '
	}
	rlock app.loc {
		max_lines := 13
		verse_lines := text_trunc_to_lines(app.loc.verse.text, max_chars_on_line, max_lines)

		max_verse_height := verse_font_size * max_lines
		total_verse_height := verse_font_size * verse_lines.len
		line_y_origin := (max_verse_height - total_verse_height) / 2
		for i, line in verse_lines {
			line_x := (app.width / 2)
			line_y := line_y_origin + verse_font_size * i
			app.draw_text(line_x, line_y, line,
				size:  verse_font_size
				color: gx.white
				align: .center
			)
		}
		am_or_pm := if app.loc.time.hour >= 12 {
			'pm'
		} else {
			'am'
		}
		font_size := 50
		hour := if app.loc.time.hour == 0 {
			12
		} else if app.loc.time.hour > 12 {
			app.loc.time.hour - 12
		} else {
			app.loc.time.hour
		}

		verse_matches_time := app.loc.chapter.id == hour && app.loc.verse.id == app.loc.time.minute
		if !verse_matches_time {
			// have line for verse reference and clock time if the reference does not match the current time
			verse_ref := '${app.loc.book.name} ${app.loc.chapter.id}:${app.loc.verse.id}'
			clock := '${hour}${hour_min_sep}${app.loc.time.minute:02} ${am_or_pm}'
			padding := 20
			clock_width := clock.len * font_size / 2
			verse_ref_height, clock_height := font_size, font_size
			clock_x := app.width - padding - clock_width
			clock_y := app.height - padding - clock_height
			verse_ref_x := padding
			verse_ref_y := app.height - padding - verse_ref_height
			app.draw_text(clock_x, clock_y, clock,
				size:  font_size
				color: gx.white
			)
			app.draw_text(verse_ref_x, verse_ref_y, verse_ref,
				size:  font_size
				color: gx.white
			)
		} else {
			// format as Genesis 1:01 am if verse reference matches current time.
			clock := '${app.loc.book.name} ${app.loc.chapter.id}${hour_min_sep}${app.loc.verse.id:02} ${am_or_pm}'
			clock_width := clock.len * font_size / 2
			clock_height := font_size
			clock_padding := 20
			clock_x := app.width - clock_padding - clock_width
			clock_y := app.height - clock_padding - clock_height
			app.draw_text(clock_x, clock_y, clock,
				size:  font_size
				color: gx.white
			)
		}
	}
}

fn (mut app App) init() ! {
	app.imgs << app.create_image(r'C:\Users\imado\Pictures\Video Projects\emmanuel-phaeton-ZFIkUxRTWHk-unsplash.jpg')!
	app.update_verse()
	spawn fn [mut app] () {
		for {
			mut should_update := false
			rlock app.loc {
				if app.loc.time.minute != time.now().minute {
					should_update = true
				}
			}
			if should_update {
				app.update_verse()
			}
			time.sleep(time.millisecond * 500)
		}
	}()
}

fn (mut app App) update_verse() {
	t := time.now()
	b, c, v := kjv.verse_from_time(t)
	lock app.loc {
		app.loc.book = b
		app.loc.chapter = c
		app.loc.verse = v
		app.loc.time = t
	}
}

fn text_trunc_to_lines(text string, max_chars int, max_lines int) []string {
	mut lines := []string{cap: text.len / max_chars}
	mut buffer := []u8{cap: max_chars}
	mut last_space := -1
	mut start := 0

	for i := 0; i < text.len; i++ {
		buffer << text[i]

		if text[i] == ` ` {
			last_space = i - start
		}

		if buffer.len == max_chars {
			if last_space != -1 {
				lines << buffer[0..last_space].bytestr().trim_space()
				start += last_space + 1
				i = start - 1
			} else {
				lines << buffer.bytestr().trim_space()
				start += max_chars
			}
			buffer = []u8{cap: max_chars}
			last_space = -1
		}
	}

	if buffer.len > 0 {
		lines << buffer.bytestr().trim_space()
	}

	if lines.len > max_lines {
		return lines[..max_lines]
	}

	return lines
}
