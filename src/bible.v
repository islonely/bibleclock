module main

import time
import rand
import encoding.xml

const raw = {
	Version.kjv: './bibles/kjv.xml'
}

const book_names = ['Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy', 'Joshua', 'Judges',
	'Ruth', '1 Samuel', '2 Samuel', '1 Kings', '2 Kings', '1 Chronicles', '2 Chronicles', 'Ezra',
	'Nehemiah', 'Esther', 'Job', 'Psalms', 'Proverbs', 'Ecclesiastes', 'Song of Solomon', 'Isaiah',
	'Jeremiah', 'Lamentations', 'Ezekiel', 'Daniel', 'Hosea', 'Joel', 'Amos', 'Obadiah', 'Jonah',
	'Micah', 'Nahum', 'Habakkuk', 'Zephaniah', 'Haggai', 'Zechariah', 'Malachi', 'Matthew', 'Mark',
	'Luke', 'John', 'Acts', 'Romans', '1 Corinthians', '2 Corinthians', 'Galatians', 'Ephesians',
	'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians', '1 Timothy', '2 Timothy',
	'Titus', 'Philemon', 'Hebrews', 'James', '1 Peter', '2 Peter', '1 John', '2 John', '3 John',
	'Jude', 'Revelation']

const kjv = Bible.kjv()

enum Version {
	kjv
}

@[noinit]
struct Bible {
mut:
	language string
	version  string
	old      []Book
	new      []Book
}

struct Book {
mut:
	id       int
	name     string
	chapters []Chapter
}

struct Chapter {
mut:
	id     int
	verses []Verse
}

struct Verse {
mut:
	id   int
	text string
}

fn Bible.kjv() Bible {
	return Bible.new(.kjv) or { panic(err.str()) }
}

fn Bible.new(version Version) !Bible {
	doc := xml.XMLDocument.from_file(raw[version])!

	translation := doc.get_elements_by_tag('bible')[0].attributes['translation'].split(' ')

	testaments := doc.get_elements_by_tag('testament')
	mut bible := Bible{
		language: translation[0]
		version:  translation[1]
		old:      Bible.gen_testament(testaments[0])
		new:      Bible.gen_testament(testaments[1])
	}
	return bible
}

fn Bible.gen_testament(xml_node xml.XMLNode) []Book {
	testament_size := if xml_node.attributes['name'] == 'Old' {
		39
	} else {
		27
	}
	mut books := []Book{cap: testament_size}
	xml_book_nodes := xml_node.get_elements_by_tag('book')
	for xml_book_node in xml_book_nodes {
		book_num := xml_book_node.attributes['number'].int()
		books << Book{
			id:       book_num
			name:     book_names[book_num - 1]
			chapters: Book.gen_chapters(xml_book_node)
		}
	}
	return books
}

fn Book.gen_chapters(xml_node xml.XMLNode) []Chapter {
	xml_chapter_nodes := xml_node.get_elements_by_tag('chapter')
	mut chapters := []Chapter{cap: xml_chapter_nodes.len}
	for xml_chapter_node in xml_chapter_nodes {
		chapters << Chapter{
			id:     xml_chapter_node.attributes['number'].int()
			verses: Chapter.gen_verses(xml_chapter_node)
		}
	}
	return chapters
}

fn Chapter.gen_verses(xml_node xml.XMLNode) []Verse {
	xml_verse_nodes := xml_node.get_elements_by_tag('verse')
	mut verses := []Verse{cap: xml_verse_nodes.len}
	for xml_verse_node in xml_verse_nodes {
		verses << Verse{
			id:   xml_verse_node.attributes['number'].int()
			text: xml_verse_node.children[0] as string
		}
	}
	return verses
}

fn (chapter Chapter) verse(i int) Verse {
	return chapter.verses[i - 1]
}

fn (book Book) chapter(i int) Chapter {
	return book.chapters[i - 1]
}

fn (book Book) chapter_verse(i int, j int) Verse {
	return book.chapter(i).verse(j)
}

fn (bible Bible) book_from_name(name string) Book {
	return bible.book(book_names.index(name) + 1)
}

fn (bible Bible) book(i int) Book {
	return if i < bible.old.len {
		bible.old[i]
	} else {
		bible.new[i - bible.old.len]
	}
}

fn (bible Bible) ref_verse_from_time(t time.Time) (string, string) {
	book, chapter, verse := bible.verse_from_time(t)
	return '${book.name} ${chapter.id}:${verse.id}', verse.text
}

fn (bible Bible) verse_from_time(t time.Time) (Book, Chapter, Verse) {
	mut book_idx := 0
	mut chapter_idx := if t.hour > 12 {
		t.hour - 12
	} else {
		if t.hour == 0 {
			12
		} else {
			t.hour
		}
	}
	mut verse_idx := t.minute
	mut book := Book{}
	mut chapter := Chapter{}
	mut verse := Verse{}
	random_verse := fn [bible] () (Book, Chapter, Verse) {
		book_idx := rand.int_in_range(1, 67) or { panic(err.str()) }
		book := bible.book(book_idx)
		chapter_idx := rand.int_in_range(0, book.chapters.len) or { panic(err.str()) }
		chapter := book.chapters[chapter_idx]
		verse_idx := rand.int_in_range(0, chapter.verses.len) or { panic(err.str()) }
		verse := chapter.verses[verse_idx]
		return book, chapter, verse
	}
	// return random verse on the hour
	if verse_idx == 0 {
		return random_verse()
	}

	// return random book at hour:minute as the chapter:verse reference.
	max_tries := 1000
	for _ in 0 .. max_tries {
		book_idx = rand.int_in_range(0, 66) or { panic(err.str()) }
		book = bible.book(book_idx)
		if chapter_idx - 1 >= book.chapters.len {
			continue
		}
		chapter = book.chapter(chapter_idx)
		if verse_idx - 1 >= chapter.verses.len {
			continue
		}

		verse = chapter.verse(verse_idx)
		return book, chapter, verse
	}
	return random_verse()
}
