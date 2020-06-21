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
 FONTS=pdf/open-sans.ttf pdf/open-sans-bold.ttf pdf/roboto.ttf pdf/noto-sans.ttf pdf/genyomintw.ttf demo/assets/roboto1.ttf demo/assets/roboto2.ttf demo/assets/roboto3.ttf demo/assets/open-sans.ttf demo/assets/open-sans-bold.ttf pdf/hacen-tunisia.ttf
 COV_PORT=9292

all: $(FONTS) demo/assets/logo.png demo/assets/profile.jpg format printing/example/.metadata get

pdf/open-sans.ttf:
	curl -L "https://fonts.gstatic.com/s/opensans/v17/mem8YaGs126MiZpBA-U1Ug.ttf" > $@

demo/assets/open-sans.ttf: pdf/open-sans.ttf
	cp $^ $@

pdf/open-sans-bold.ttf:
	curl -L "https://fonts.gstatic.com/s/opensans/v17/mem5YaGs126MiZpBA-UN7rg-VQ.ttf" > $@
	cp $@ demo/assets/

demo/assets/open-sans-bold.ttf: pdf/open-sans-bold.ttf
	cp $^ $@

pdf/roboto.ttf:
	curl -L "https://fonts.gstatic.com/s/robotomono/v7/L0x5DF4xlVMF-BfR8bXMIghM.ttf" > $@

pdf/noto-sans.ttf:
	curl -L "https://fonts.gstatic.com/s/notosans/v9/o-0IIpQlx3QUlC5A4PNb4g.ttf" > $@

pdf/genyomintw.ttf:
	curl -L "https://github.com/ButTaiwan/genyo-font/raw/bc2fa246196fefc1ef9e9843bc8cdba22523a39d/TW/GenYoMinTW-Heavy.ttf" > $@

demo/assets/roboto1.ttf:
	curl -L "https://fonts.gstatic.com/s/roboto/v20/KFOlCnqEu92Fr1MmSU5vAw.ttf" > $@

demo/assets/roboto2.ttf:
	curl -L "https://fonts.gstatic.com/s/roboto/v20/KFOlCnqEu92Fr1MmWUlvAw.ttf" > $@

demo/assets/roboto3.ttf:
	curl -L "https://fonts.gstatic.com/s/roboto/v20/KFOkCnqEu92Fr1MmgWxP.ttf" > $@

demo/assets/logo.png:
	curl -L "https://pigment.github.io/fake-logos/logos/medium/color/auto-speed.png" > $@

demo/assets/profile.jpg:
	curl -L "https://www.fakepersongenerator.com/Face/female/female20151024334209870.jpg" > $@

pdf/hacen-tunisia.ttf:
	curl -L "https://arbfonts.com/font_files/hacen/Hacen Tunisia.ttf" > $@

format: format-dart format-clang format-swift

format-dart: $(DART_SRC)
	dartfmt -w --fix $^

format-clang: $(CLNG_SRC)
	clang-format -style=Chromium -i $^

format-swift: $(SWFT_SRC)
	swiftformat --swiftversion 4.2 $^

.coverage:
	which coverage || pub global activate coverage
	touch $@

node_modules:
	npm install lcov-summary

printing/example/.metadata:
	cd printing/example; flutter create -t app --no-overwrite --org net.nfet --project-name example .
	rm -rf printing/example/test

pdf/pubspec.lock: pdf/pubspec.yaml
	cd pdf; pub get

printing/pubspec.lock: printing/pubspec.yaml
	cd printing; flutter packages get

demo/pubspec.lock: demo/pubspec.yaml
	cd demo; flutter packages get

test/pubspec.lock: test/pubspec.yaml
	cd test; flutter packages get

get: $(FONTS) pdf/pubspec.lock printing/pubspec.lock demo/pubspec.lock test/pubspec.lock

test-pdf: $(FONTS) pdf/pubspec.lock .coverage
	cd pdf; pub global run coverage:collect_coverage --port=$(COV_PORT) -o coverage.json --resume-isolates --wait-paused &\
	dart --enable-asserts --disable-service-auth-codes --enable-vm-service=$(COV_PORT) --pause-isolates-on-exit test/all_tests.dart
	cd pdf; pub global run coverage:format_coverage --packages=.packages -i coverage.json --report-on lib --lcov --out lcov.info
	cd pdf; for EXAMPLE in $(shell cd pdf; find example -name '*.dart'); do dart $$EXAMPLE; done
	test/compare-pdf.sh pdf test/golden

test-printing: $(FONTS) printing/pubspec.lock .coverage
	cd printing; flutter test --coverage --coverage-path lcov.info

test-demo: $(FONTS) demo/pubspec.lock .coverage
	cd demo; flutter test --coverage --coverage-path lcov.info

test-readme: $(FONTS) test/pubspec.lock
	cd test; dart extract_readme.dart
	cd test; dartanalyzer readme-*.dart

test: test-pdf test-printing test-demo node_modules
	cat pdf/lcov.info printing/lcov.info demo/lcov.info | node_modules/.bin/lcov-summary

clean:
	git clean -fdx -e .vscode -e ref

publish-pdf: format clean
	test -z "$(shell git status --porcelain)"
	find pdf -name pubspec.yaml -exec sed -i -e 's/^dependency_overrides:/_dependency_overrides:/g' '{}' ';'
	cd pdf; pub publish -f
	find pdf -name pubspec.yaml -exec sed -i -e 's/^_dependency_overrides:/dependency_overrides:/g' '{}' ';'
	git tag $(shell grep version pdf/pubspec.yaml | sed 's/version\s*:\s*/pdf-/g')

publish-printing: format clean
	test -z "$(shell git status --porcelain)"
	find printing -name pubspec.yaml -exec sed -i -e 's/^dependency_overrides:/_dependency_overrides:/g' '{}' ';'
	cd printing; pub publish -f
	find printing -name pubspec.yaml -exec sed -i -e 's/^_dependency_overrides:/dependency_overrides:/g' '{}' ';'
	git tag $(shell grep version printing/pubspec.yaml | sed 's/version\s*:\s*/printing-/g')

.pana:
	which pana || pub global activate pana
	touch $@

analyze-pdf: .pana
	@find pdf -name pubspec.yaml -exec sed -i -e 's/^dependency_overrides:/_dependency_overrides:/g' '{}' ';'
	@pub global run pana --no-warning --source path pdf 2> /dev/null | python test/pana_report.py
	@find pdf -name pubspec.yaml -exec sed -i -e 's/^_dependency_overrides:/dependency_overrides:/g' '{}' ';'

analyze-printing: .pana
	@find printing -name pubspec.yaml -exec sed -i -e 's/^dependency_overrides:/_dependency_overrides:/g' '{}' ';'
	@pub global run pana --no-warning --source path printing 2> /dev/null | python test/pana_report.py
	@find printing -name pubspec.yaml -exec sed -i -e 's/^_dependency_overrides:/dependency_overrides:/g' '{}' ';'

analyze: analyze-pdf analyze-printing

analyze-ci-pdf: .pana
	@find pdf -name pubspec.yaml -exec sed -i -e 's/^dependency_overrides:/_dependency_overrides:/g' '{}' ';'
	@pub global run pana --no-warning --source path pdf
	@find pdf -name pubspec.yaml -exec sed -i -e 's/^_dependency_overrides:/dependency_overrides:/g' '{}' ';'

analyze-ci-printing: .pana
	@find printing -name pubspec.yaml -exec sed -i -e 's/^dependency_overrides:/_dependency_overrides:/g' '{}' ';'
	@pub global run pana --no-warning --source path printing
	@find printing -name pubspec.yaml -exec sed -i -e 's/^_dependency_overrides:/dependency_overrides:/g' '{}' ';'

.dartfix:
	which dartfix || pub global activate dartfix
	touch $@

fix: get .dartfix
	cd pdf; pub global run dartfix:fix --overwrite .
	cd printing; pub global run dartfix:fix --overwrite .

ref:
	mkdir -p ref
	cd $@; curl -OL 'https://www.adobe.com/content/dam/acom/en/devnet/pdf/pdfs/PDF32000_2008.pdf'
	cd $@; curl -OL 'https://www.adobe.com/content/dam/acom/en/devnet/pdf/adobe_supplement_iso32000.pdf'
	cd $@; curl -OL 'https://www.adobe.com/content/dam/acom/en/devnet/acrobat/pdfs/pdf_reference_1-7.pdf'

gh-pages:
	cd demo; flutter build web
	git checkout gh-pages
	rm -rf assets icons
	mv -fv demo/build/web/* .

.PHONY: test format format-dart format-clang clean publish-pdf publish-printing analyze ref
