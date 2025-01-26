module main

import gg
import gx
import os
import time
import rand
import math

@[heap]
struct App {
	gg.Context
mut:
	state            AppState = .clock
	img_offset_x     int
	img_offset_x_vel f32
	img_idx          int
	img_paths        []string
	img              struct {
	mut:
		prev gg.Image
		curr gg.Image
		next gg.Image
	}
	loc              shared struct {
	mut:
		book    Book
		chapter Chapter
		verse   Verse
		time    time.Time
	}

	should_hour_min_separator_blink bool = true
	is_hour_min_separator_visible   bool = true
}

enum AppState {
	clock
	settings
}

fn main() {
	mut app := &App{}
	app.Context = gg.new_context(
		// ui_mode:           true
		user_data:         app
		frame_fn:          frame
		event_fn:          event
		bg_color:          gx.white
		width:             1024
		height:            600
		font_bytes_normal: $embed_file('./fonts/ubuntu/UbuntuMono-R.ttf').to_bytes()
		// fullscreen: true
	)
	app.init() or {
		println(err)
		exit(1)
	}
	app.run()
}

// event handles touch, mouse, and keyboard events for the app.
fn event(evt &gg.Event, mut app App) {
	if evt.typ == .mouse_move && app.mouse_buttons.has(.left) {
		app.img_offset_x_vel = evt.mouse_dx
		app.img_offset_x += int(evt.mouse_dx)
	}
}

// frame is invoked to draw to the screen.
fn frame(mut app App) {
	app.Context.begin()
	// blink between "12:01" and "12 01" every second
	if app.should_hour_min_separator_blink {
		app.is_hour_min_separator_visible = bool(time.now().second % 2 == 0)
	}

	sz := app.window_size()
	app.width = sz.width
	app.height = sz.height

	if app.state == .clock {
		app.slide_to_nearest_img()
		app.draw_image_background()
		app.draw_rect_filled(0, 0, app.width, app.height, gx.rgba(0x00, 0x00, 0x00, 0x80))
		app.draw_verse_time()
	} else if app.state == .settings {
	}
	app.Context.end()
}

// slide_to_nearest_img continues to slide the image after the user has swiped until
// the next image is fully in view.
fn (mut app App) slide_to_nearest_img() {
	if app.img_offset_x > app.width {
		app.img_offset_x = app.width
		return
	}
	if app.img_offset_x < -app.width {
		app.img_offset_x = -app.width
		return
	}
	if app.mouse_buttons.has(.left) {
	} else {
		if app.img_offset_x % app.width == 0 && app.img_offset_x_vel != 0 {
			app.img_offset_x = 0
			if app.img_offset_x_vel > 0 {
				app.img_idx--
			} else {
				app.img_idx++
			}
			app.uncache_imgs()
			app.load_imgs() or {
				println(err)
				exit(1)
			}
			app.img_offset_x_vel = 0
			return
		}
		app.img_offset_x += int(app.img_offset_x_vel)
	}
}

// draw_image_background draws the previous, current, and next background images.
fn (mut app App) draw_image_background() {
	gen_rect := fn [app] (img gg.Image) (f32, f32, f32, f32) {
		scaled_percent := f32(app.width) / f32(img.width)
		w := scaled_percent * img.width
		h := scaled_percent * img.height
		x := app.img_offset_x
		y := (app.height - h) / 2
		return x, y, w, h
	}

	x, y, w, h := gen_rect(app.img.curr)
	app.draw_image(x, y, w, h, app.img.curr)

	if app.img_offset_x != 0 {
		_, py, pw, ph := gen_rect(app.img.prev)
		px := x - app.width
		_, ny, nw, nh := gen_rect(app.img.next)
		nx := x + app.width
		app.draw_image(px, py, pw, ph, app.img.prev)
		app.draw_image(nx, ny, nw, nh, app.img.next)
	}
}

// draw_verse_time draws the current verse text to the screen and the verses reference
// and current time.
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

// init is called before the App is started.
fn (mut app App) init() ! {
	os.walk('./pictures', fn [mut app] (file string) {
		app.img_paths << file
	})
	rand.shuffle(mut app.img_paths) or { println('[Notice] Failed to randomize pictures: ${err}') }
	app.load_imgs()!

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

// uncache_imgs removes the images from the Context.
fn (mut app App) uncache_imgs() {
	app.remove_cached_image_by_idx(app.img.next.id)
	app.remove_cached_image_by_idx(app.img.curr.id)
	app.remove_cached_image_by_idx(app.img.prev.id)
}

// load_imgs reads the images from a file and caches them to the context.
fn (mut app App) load_imgs() ! {
	app.img.prev = app.create_image(wrapping_index(app.img_paths, app.img_idx - 1))!
	app.img.curr = app.create_image(wrapping_index(app.img_paths, app.img_idx))!
	app.img.next = app.create_image(wrapping_index(app.img_paths, app.img_idx + 1))!
}

// update_verse sets the selected verse to the current time.
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

// wrapping_index takes in any positive or negative number and returns a value from the array.
// If we have `arr := [0, 1, 2]`, then an index of -1 returns `arr[arr.len - 1]`. It also returns
// a value when you provide a absolute index greater than array length. Index of 13 returns
// the value of `arr[1]`.
fn wrapping_index[T](arr []T, index int) T {
	i := if index < 0 {
		arr.len - (math.abs(index) % arr.len)
	} else if index >= arr.len {
		index % arr.len
	} else {
		index
	}

	return arr[i]
}

// text_trunc_to_lines returns the provided text as an array of lines with a max length
// of `max_chars` per line. If the array of lines exceeds `max_lines`, then only the
// first `max_lines` is returned.
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
			if lines.len == max_lines {
				return lines
			}
			buffer = []u8{cap: max_chars}
			last_space = -1
		}
	}

	if buffer.len > 0 {
		lines << buffer.bytestr().trim_space()
	}

	return lines
}
