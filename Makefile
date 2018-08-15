 # Copyright (C) 2018, David PHAM-VAN <dev.nfet.net@gmail.com>
 #
 # This library is free software; you can redistribute it and/or
 # modify it under the terms of the GNU Lesser General
 # License as published by the Free Software Foundation; either
 # version 2.1 of the License, or (at your option) any later version.
 #
 # This library is distributed in the hope that it will be useful,
 # but WITHOUT ANY WARRANTY; without even the implied warranty of
 # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 # Lesser General  License for more details.
 #
 # You should have received a copy of the GNU Lesser General
 # License along with this library; if not, write to the Free Software
 # Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

 DART_SRC=$(shell find . -name '*.dart')
 CLNG_SRC=$(shell find . -name '*.java' -o -name '*.m' -o -name '*.h')

all: pdf/open-sans.ttf format

pdf/open-sans.ttf:
	curl -L "https://github.com/google/fonts/raw/master/apache/opensans/OpenSans-Regular.ttf" > $@

format: format-dart format-clang

format-dart: $(DART_SRC)
	dartfmt -w $^

format-clang: $(CLNG_SRC)
	clang-format -style=Chromium -i $^

test: pdf/open-sans.ttf
	cd pdf; for TEST in $(shell cd pdf; find test -name '*.dart'); do dart $$TEST; done
	cd printing; flutter test

clean:
	git clean -fdx

.PHONY: test format format-dart format-clang clean
