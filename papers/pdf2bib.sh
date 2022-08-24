#!/bin/bash

set -e

# grep pattern below does the following:
# "\b"        - boundary of the scanned object
# (           - capture group for the entire regex pattern, saves contents
# 10[.][0-9]  - all DOIs start with 10.#
# {4,}        - previous pattern, [0-9], repeating 4 or more times
#
# (?:         - capture group, but without saving contents
# .#+         - look for ".#" as many times as possible
# */          - match the whole group until a "/" is detected
#
# (?:(?!      - this one is complicated; lookahead for the following contents,
#             and if found, stop scanning, returning the matched pattern.
# [\"&\'<>]   - find any of these characters: {", &, ', <, >} they indicate
#             an end of a matched pattern.
# \S          - any whitespace following the flagged characters
# )+          - close capture group and keep repeating if there are any
#             additional numbers after the / which end in the flagged
#             characters (should only be one)
#
# )\b         - close capture group for entire regex pattern at the other
#             boundary of the scanned object.
#
# | head -n 1 - pipe the resulting matched DOIs into a program that selects
#             the first in the list.

# -----------Functions Begin--------------

# stores the generated doi into a variable for later use
function pdf2doi() {
	doi=$(pdftotext "$1" - | grep -oP "\b(10[.][0-9]{4,}(?:[.][0-9]+)*/(?:(?![\"&\'<>])\S)+)\b" | head -n 1 );
}

# creates a newline, then generates bib text from a crossref api call
function doi2bib() {
	echo >> bib.bib;
	curl -s "http://api.crossref.org/works/$1/transform/application/x-bibtex" >> bib.bib;
	echo >> bib.bib;
}

# -----------Functions End--------------

# create bib file if one doesn't exist
touch bib.bib

# search for pdf files in immediate directory
pdf_list=$(find . -maxdepth 1 -name "*.pdf" -type f)

# if number of pdfs equals number of paragraphs (bib entries), exit
if [[ $(cat bib.bib | grep -c "^$") == $(find . -maxdepth 1 -name "*.pdf" -type f | wc -l) ]]; then
	echo "Number of pdfs detected has not changed."
	exit 1
fi

# pdfs changed, copy bib to temp file and then repopulate bib file
mv bib.bib tmp.bib
truncate -s 0 bib.bib

# for each file, process doi, populating a bib file
for file in $pdf_list; do
	pdf2doi $file
	doi2bib $doi
done

# display changes detected
echo "Differences detected between old and new bib.bib files:"
diff -y tmp.bib bib.bib
