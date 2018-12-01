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
 CLNG_SRC=$(shell find printing/ios -name '*.java' -o -name '*.m' -o -name '*.h') $(shell find printing/android -name '*.java' -o -name '*.m' -o -name '*.h')
 FONTS=pdf/open-sans.ttf pdf/roboto.ttf

all: $(FONTS) format

pdf/open-sans.ttf:
	curl -L "https://github.com/google/fonts/raw/master/apache/opensans/OpenSans-Regular.ttf" > $@

pdf/roboto.ttf:
	curl -L "https://github.com/google/fonts/raw/master/apache/robotomono/RobotoMono-Regular.ttf" > $@

format: format-dart format-clang

format-dart: $(DART_SRC)
	dartfmt -w $^

format-clang: $(CLNG_SRC)
	clang-format -style=Chromium -i $^

pdf/.dart_tool:
	cd pdf ; pub get

test: pdf/.dart_tool $(FONTS)
	cd pdf; for EXAMPLE in $(shell cd pdf; find example -name '*.dart'); do dart $$EXAMPLE; done
	cd pdf; for TEST in $(shell cd pdf; find test -name '*.dart'); do dart $$TEST; done
	# cd printing; flutter test

clean:
	git clean -fdx

publish-pdf: format clean
	cd pdf; pub publish -f

publish-printing: format clean
	cd printing; pub publish -f

.PHONY: test format format-dart format-clang clean publish-pdf publish-printing
