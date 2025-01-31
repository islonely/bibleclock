import gg
import gx

const upper_letters = 'QWERTYUIOPASDFGHJKLZXCVBNM'.bytes()
const lower_letters = 'qwertyuiopasdfghjklzxcvbnm'.bytes()
const upper_symbols = '~!@#$%^&*()_+{}|:"<>?'.bytes()
const lower_symbols = "`1234567890-=[]\\;',./".bytes()

struct Settings {
mut:
	items        []MenuItem
	index        int
	x            int
	y            int
	textcfg      gx.TextCfg = gx.TextCfg{
		color: gx.white
		size:  23
	}
	selected_clr gx.Color = gx.light_blue
}

fn (settings Settings) draw(mut g gg.Context) {
	for i, item in settings.items {
		clr := if i == settings.index { settings.selected_clr } else { settings.textcfg.color }
		item.draw(mut g, settings.x, settings.y + (i * settings.textcfg.size), gx.TextCfg{
			...settings.textcfg
			color: clr
		})
	}
}

fn (mut settings Settings) move_down() {
	if settings.index == settings.items.len - 1 {
		settings.index = 0
		return
	}
	settings.index++
}

fn (mut settings Settings) move_up() {
	if settings.index == 0 {
		settings.index = settings.items.len - 1
		return
	}
	settings.index--
}

fn (mut settings Settings) event(evt &gg.Event) {
	if evt.typ == .key_down {
		if evt.key_code == .down {
			settings.move_down()
			return
		}
		if evt.key_code == .up {
			settings.move_up()
		}
	}
	settings.items[settings.index].event(evt)
}

enum MenuAction {
	left
	right
	activate
	select
}

interface MenuItem {
	draw(mut gg.Context, int, int, gx.TextCfg)
mut:
	event(&gg.Event)
}

struct CycleMenuItem {
mut:
	name   string
	index  int
	values []string
}

fn (item CycleMenuItem) draw(mut g gg.Context, x int, y int, cfg gx.TextCfg) {
	name := '${item.name}: '
	name_sz := name.len * cfg.size / 2
	left_bttn := ' < '
	left_bttn_sz := left_bttn.len * cfg.size / 2
	left_bttn_clr := if item.index == 0 { gx.hex(0xffaaaaaa) } else { gx.white }
	right_bttn := ' > '
	// right_bttn_sz := right_bttn.len * cfg.size / 2
	right_bttn_clr := if item.index == item.values.len - 1 { gx.hex(0xffaaaaaa) } else { gx.white }
	value := item.values[item.index]
	value_sz := value.len * cfg.size / 2
	g.draw_text(x, y, name, cfg)
	g.draw_text(x + name_sz, y, left_bttn, gx.TextCfg{
		...cfg
		color: left_bttn_clr
		bold:  true
	})
	g.draw_text(x + name_sz + left_bttn_sz, y, value, cfg)
	g.draw_text(x + name_sz + left_bttn_sz + value_sz, y, right_bttn, gx.TextCfg{
		...cfg
		color: right_bttn_clr
		bold:  true
	})
}

fn (mut item CycleMenuItem) event(evt &gg.Event) {
	if evt.typ == .key_down {
		if evt.key_code == .left && item.index > 0 {
			item.index--
			return
		}
		if evt.key_code == .right && item.index < item.values.len - 1 {
			item.index++
			return
		}
	}
}

struct FieldMenuItem {
mut:
	name       string
	value      string
	is_editing bool
}

fn (item FieldMenuItem) draw(mut g gg.Context, x int, y int, cfg gx.TextCfg) {
	name := '${item.name}: '
	name_sz := name.len * cfg.size / 2
	clr := if item.is_editing {
		gx.hex(0xffff0000)
	} else {
		gx.white
	}
	value_sz := item.value.len * cfg.size / 2
	g.draw_text(x, y, name + item.value, cfg)
	g.draw_rect_empty(x + name_sz, y, value_sz, cfg.size, clr)
}

fn (mut item FieldMenuItem) event(evt &gg.Event) {
	if evt.typ == .key_down {
		if evt.key_code == .enter {
			item.is_editing = !item.is_editing
		}

		if item.is_editing {
			if evt.key_code in [gg.KeyCode.left_shift, .left_alt, .left_control, .left_super,
				.right_shift, .right_alt, .right_control, .right_super] {
				return
			}
			if evt.key_code == .backspace && item.value.len > 0 {
				item.value = item.value[..item.value.len - 1]
			}
			if u8(evt.key_code) in lower_symbols || u8(evt.key_code) in upper_letters {
				ch := u8(evt.key_code)
				item.value += if ch in lower_symbols {
					if (evt.modifiers & u32(gg.Modifier.shift)) == 1 {
						upper_symbols[lower_symbols.index(ch)].ascii_str()
					} else {
						ch.ascii_str()
					}
				} else {
					if (evt.modifiers & u32(gg.Modifier.shift)) == 1 {
						ch.ascii_str()
					} else {
						ch.ascii_str().to_lower()
					}
				}
			}
		}
	}
}
