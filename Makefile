 # Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 #
 # Licensed under the Apache License, Version 2.0 (the "License");
 # you may not use this file except in compliance with the License.
 # You may obtain a copy of the License at
 #
 #     http://www.apache.org/licenses/LICENSE-2.0
 #
 # Unless required by applicable law or agreed to in writing, software
 # distributed under the License is distributed on an "AS IS" BASIS,
 # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 # See the License for the specific language governing permissions and
 # limitations under the License.

 DART_SRC=$(shell find . -name '*.dart')
 CLNG_SRC=$(shell find printing/ios -name '*.java' -o -name '*.m' -o -name '*.h') $(shell find printing/android -name '*.java' -o -name '*.m' -o -name '*.h')
 SWFT_SRC=$(shell find . -name '*.swift')
 FONTS=pdf/open-sans.ttf pdf/open-sans-bold.ttf pdf/roboto.ttf pdf/noto-sans.ttf pdf/genyomintw.ttf
 COV_PORT=9292

all: $(FONTS) format

pdf/open-sans.ttf:
	curl -L "https://github.com/google/fonts/raw/master/apache/opensans/OpenSans-Regular.ttf" > $@

pdf/open-sans-bold.ttf:
	curl -L "https://github.com/google/fonts/raw/master/apache/opensans/OpenSans-Bold.ttf" > $@

pdf/roboto.ttf:
	curl -L "https://github.com/google/fonts/raw/master/apache/robotomono/RobotoMono-Regular.ttf" > $@

pdf/noto-sans.ttf:
	curl -L "https://raw.githubusercontent.com/google/fonts/master/ofl/notosans/NotoSans-Regular.ttf" > $@

pdf/genyomintw.ttf:
	curl -L "https://github.com/ButTaiwan/genyo-font/raw/master/TW/GenYoMinTW-Heavy.ttf" > $@

format: format-dart format-clang format-swift

format-dart: $(DART_SRC)
	dartfmt -w --fix $^

format-clang: $(CLNG_SRC)
	clang-format -style=Chromium -i $^

format-swift: $(SWFT_SRC)
	swiftformat --swiftversion 4.2 $^

.coverage:
	pub global activate coverage
	touch $@

node_modules:
	npm install lcov-summary

get-pdf:
	cd pdf; pub get

get-printing:
	cd printing; flutter packages get
	cd printing/example; flutter packages get

get-readme:
	cd test; flutter packages get

get: get-pdf get-printing get-readme

test-pdf: $(FONTS) get-pdf .coverage
	cd pdf; pub global run coverage:collect_coverage --port=$(COV_PORT) -o coverage.json --resume-isolates --wait-paused &\
	dart --enable-asserts --disable-service-auth-codes --enable-vm-service=$(COV_PORT) --pause-isolates-on-exit test/all_tests.dart
	cd pdf; pub global run coverage:format_coverage --packages=.packages -i coverage.json --report-on lib --lcov --out lcov.info
	cd pdf; for EXAMPLE in $(shell cd pdf; find example -name '*.dart'); do dart $$EXAMPLE; done

test-printing: $(FONTS) get-printing .coverage
	cd printing; flutter test --coverage --coverage-path lcov.info

test-readme: $(FONTS) get-readme
	cd test; dart extract_readme.dart
	cd test; dartanalyzer readme.dart	

test-web:
	cd pdf/web_example; pub get
	cd pdf/web_example; pub run webdev build

test: test-pdf test-printing node_modules test-web
	cat pdf/lcov.info printing/lcov.info | node_modules/.bin/lcov-summary

clean:
	git clean -fdx -e .vscode -e ref

publish-pdf: format clean
	find pdf -name pubspec.yaml -exec sed -i -e 's/^dependency_overrides:/_dependency_overrides:/g' '{}' ';'
	cd pdf; pub publish -f
	find pdf -name pubspec.yaml -exec sed -i -e 's/^_dependency_overrides:/dependency_overrides:/g' '{}' ';'

publish-printing: format clean
	find printing -name pubspec.yaml -exec sed -i -e 's/^dependency_overrides:/_dependency_overrides:/g' '{}' ';'
	cd printing; pub publish -f
	find printing -name pubspec.yaml -exec sed -i -e 's/^_dependency_overrides:/dependency_overrides:/g' '{}' ';'

.pana:
	pub global activate pana
	touch $@

analyze-pdf: .pana
	@find pdf -name pubspec.yaml -exec sed -i -e 's/^dependency_overrides:/_dependency_overrides:/g' '{}' ';'
	@pub global run pana --no-warning --source path pdf 2> /dev/null | python pana_report.py
	@find pdf -name pubspec.yaml -exec sed -i -e 's/^_dependency_overrides:/dependency_overrides:/g' '{}' ';'

analyze-printing: .pana
	@find printing -name pubspec.yaml -exec sed -i -e 's/^dependency_overrides:/_dependency_overrides:/g' '{}' ';'
	@pub global run pana --no-warning --source path printing 2> /dev/null | python pana_report.py
	@find printing -name pubspec.yaml -exec sed -i -e 's/^_dependency_overrides:/dependency_overrides:/g' '{}' ';'

analyze: analyze-pdf analyze-printing

.dartfix:
	pub global activate dartfix
	touch $@

fix: get .dartfix
	cd pdf; pub global run dartfix:fix --overwrite .
	cd printing; pub global run dartfix:fix --overwrite .

ref:
	mkdir -p ref
	cd $@; curl -OL 'https://www.adobe.com/content/dam/acom/en/devnet/pdf/pdfs/PDF32000_2008.pdf'
	cd $@; curl -OL 'https://www.adobe.com/content/dam/acom/en/devnet/pdf/adobe_supplement_iso32000.pdf'
	cd $@; curl -OL 'https://www.adobe.com/content/dam/acom/en/devnet/acrobat/pdfs/pdf_reference_1-7.pdf'

.PHONY: test format format-dart format-clang clean publish-pdf publish-printing analyze ref
