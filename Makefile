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

FLUTTER?=$(realpath $(dir $(realpath $(dir $(shell which flutter)))))
FLUTTER_BIN=$(FLUTTER)/bin/flutter
DART_BIN=$(FLUTTER)/bin/dart
DART_SRC=$(shell find . -name '*.dart')
CLNG_SRC=$(shell find printing/ios printing/macos printing/windows printing/linux printing/android -name '*.cpp' -o -name '*.cc' -o -name '*.m' -o -name '*.h' -o -name '*.java')
SWFT_SRC=$(shell find printing/ios printing/macos -name '*.swift')
FONTS=pdf/open-sans.ttf pdf/open-sans-bold.ttf pdf/roboto.ttf pdf/noto-sans.ttf pdf/genyomintw.ttf pdf/hacen-tunisia.ttf pdf/material.ttf pdf/emoji.ttf
COV_PORT=9292
SVG_ASSETS_URL=https://raw.githubusercontent.com/dnfield/flutter_svg/master/packages/flutter_svg/example/assets
SVG=blend_and_mask blend_mode_devil clip_path clip_path_2 clip_path_2 clip_path_3  clip_path_3  dash_path ellipse empty_defs equation fill-rule-inherit group_composite_opacity group_fill_opacity group_mask group_opacity group_opacity_transform hidden href-fill image image_def implicit_fill_with_opacity linear_gradient linear_gradient_2 linear_gradient_absolute_user_space_translate linear_gradient_percentage_bounding_translate linear_gradient_percentage_user_space_translate linear_gradient_xlink male mask mask_with_gradient mask_with_use mask_with_use2 nested_group opacity_on_path radial_gradient radial_gradient_absolute_user_space_translate radial_gradient_focal radial_gradient_percentage_bounding_translate radial_gradient_percentage_user_space_translate radial_gradient_xlink radial_ref_linear_gradient rect_rrect rect_rrect_no_ry stroke_inherit_circles style_attr text text_2 text_3 use_circles use_circles_def use_emc2 use_fill use_opacity_grid width_height_viewbox flutter_logo emoji_u1f600 text_transform dart new-pause-button new-send-circle new-gif new-camera new-image numeric_25 new-mention new-gif-button new-action-expander new-play-button aa alphachannel Ghostscript_Tiger Firefox_Logo_2017 chess_knight Flag_of_the_United_States

all: $(FONTS) demo/assets/logo.svg demo/assets/profile.jpg format printing/example/.metadata get

pdf/open-sans.ttf:
	curl -L "https://fonts.gstatic.com/s/opensans/v17/mem8YaGs126MiZpBA-U1Ug.ttf" > $@

pdf/open-sans-bold.ttf:
	curl -L "https://fonts.gstatic.com/s/opensans/v17/mem5YaGs126MiZpBA-UN7rg-VQ.ttf" > $@

pdf/roboto.ttf:
	curl -L "https://fonts.gstatic.com/s/robotomono/v7/L0x5DF4xlVMF-BfR8bXMIghM.ttf" > $@

pdf/noto-sans.ttf:
	curl -L "https://fonts.gstatic.com/s/notosans/v9/o-0IIpQlx3QUlC5A4PNb4g.ttf" > $@

pdf/genyomintw.ttf:
	curl -L "https://github.com/ButTaiwan/genyo-font/raw/bc2fa246196fefc1ef9e9843bc8cdba22523a39d/TW/GenYoMinTW-Heavy.ttf" > $@

pdf/material.ttf:
	curl -L "https://github.com/google/material-design-icons/raw/master/font/MaterialIcons-Regular.ttf" > $@

pdf/emoji.ttf:
	curl -L https://github.com/googlefonts/noto-emoji/raw/main/fonts/NotoColorEmoji.ttf > $@

demo/assets/logo.svg:
	curl -L "http://pigment.github.io/fake-logos/logos/vector/color/auto-speed.svg" > $@

demo/assets/profile.jpg:
	curl -L "https://www.fakepersongenerator.com/Face/female/female20151024334209870.jpg" > $@

pdf/hacen-tunisia.ttf:
	curl -L "http://www.aboaziz.net/misc/arabic%20fonts%20pack/%CE%D8%E6%D8%20%DA%D1%C8%ED%C9%20%CD%CF%ED%CB%C9%20%E6%E3%E3%ED%D2%C9/%CE%D8%E6%D8%20%DA%D1%C8%ED%C9%20%CD%CF%ED%CB%C9%20%E6%20%E3%E3%ED%D2%C9/Hacen%20Tunisia/Hacen%20Tunisia.ttf" > $@

format: format-dart format-clang format-swift

format-dart: $(DART_SRC)
	$(DART_BIN) format $^

format-clang: $(CLNG_SRC)
	clang-format -style=Chromium -i $^

format-swift: $(SWFT_SRC)
	which swiftformat && swiftformat --swiftversion 5 $^ || true

.coverage:
	which coverage || $(DART_BIN) pub global activate coverage
	touch $@

node_modules:
	npm install lcov-summary

printing/example/.metadata:
	cd printing/example; $(FLUTTER_BIN) create -t app --no-overwrite --org net.nfet --project-name example .
	rm -rf printing/example/test printing/example/integration_test
	mkdir -p printing/example/macos/Runner
	echo '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>com.apple.security.app-sandbox</key><true/><key>com.apple.security.cs.allow-jit</key><true/><key>com.apple.security.network.client</key><true/><key>com.apple.security.network.server</key><true/><key>com.apple.security.print</key><true/></dict></plist>' > printing/example/macos/Runner/DebugProfile.entitlements
	echo '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>com.apple.security.app-sandbox</key><true/><key>com.apple.security.cs.allow-jit</key><true/><key>com.apple.security.network.client</key><true/><key>com.apple.security.print</key><true/></dict></plist>' > printing/example/macos/Runner/Release.entitlements


pdf/pubspec.lock: pdf/pubspec.yaml
	cd pdf; $(DART_BIN) pub get

printing/pubspec.lock: printing/pubspec.yaml
	cd printing; $(FLUTTER_BIN) pub get

demo/pubspec.lock: demo/pubspec.yaml
	cd demo; $(FLUTTER_BIN) pub get

test/pubspec.lock: test/pubspec.yaml
	cd test; $(FLUTTER_BIN) pub get

get: $(FONTS) pdf/pubspec.lock printing/pubspec.lock demo/pubspec.lock test/pubspec.lock

get-all: $(FONTS) demo/assets/logo.svg demo/assets/profile.jpg get

test-pdf: svg $(FONTS) pdf/pubspec.lock .coverage
	cd pdf; $(DART_BIN)  test --coverage=coverage
	cd pdf; $(DART_BIN) pub global run coverage:format_coverage --packages=.dart_tool/package_config.json -i coverage/test --report-on lib --lcov --out lcov.info
	rm -rf pdf/coverage
	cd pdf; for EXAMPLE in $(shell cd pdf; find example -name '*.dart'); do $(DART_BIN) $$EXAMPLE; done
	test/compare-pdf.sh pdf test/golden

test-printing: $(FONTS) printing/pubspec.lock .coverage
	cd printing; $(FLUTTER_BIN) test --coverage --coverage-path lcov.info

test-demo: $(FONTS) demo/pubspec.lock .coverage
	cd demo; $(FLUTTER_BIN) test --coverage --coverage-path lcov.info

test-readme: $(FONTS) test/pubspec.lock
	cd test; $(DART_BIN) extract_readme.dart
	cd test; $(DART_BIN) analyze

test: test-pdf test-printing test-demo node_modules
	cat pdf/lcov.info printing/lcov.info demo/lcov.info | node_modules/.bin/lcov-summary

clean:
	git clean -fdx -e .vscode -e ref

clean-dart:
	for d in $(shell find . -name build -o -name .dart_tool -type directory); do rm -rf $$d; done

publish-pdf: format clean
	test -z "$(shell git status --porcelain)"
	find pdf -name pubspec.yaml -exec sed -i -e 's/^dependency_overrides:/_dependency_overrides:/g' '{}' ';'
	cd pdf; $(DART_BIN) pub publish -f
	find pdf -name pubspec.yaml -exec sed -i -e 's/^_dependency_overrides:/dependency_overrides:/g' '{}' ';'
	git tag $(shell grep version pdf/pubspec.yaml | sed 's/version\s*:\s*/pdf-/g')

publish-printing: format clean
	test -z "$(shell git status --porcelain)"
	find printing -name pubspec.yaml -exec sed -i -e 's/^dependency_overrides:/_dependency_overrides:/g' '{}' ';'
	cd printing; $(DART_BIN) pub publish -f
	find printing -name pubspec.yaml -exec sed -i -e 's/^_dependency_overrides:/dependency_overrides:/g' '{}' ';'
	git tag $(shell grep version printing/pubspec.yaml | sed 's/version\s*:\s*/printing-/g')

publish-wrapper: format clean
	test -z "$(shell git status --porcelain)"
	find widget_wrapper -name pubspec.yaml -exec sed -i -e 's/^dependency_overrides:/_dependency_overrides:/g' '{}' ';'
	cd widget_wrapper; $(DART_BIN) pub publish -f
	find widget_wrapper -name pubspec.yaml -exec sed -i -e 's/^_dependency_overrides:/dependency_overrides:/g' '{}' ';'
	git tag $(shell grep version widget_wrapper/pubspec.yaml | sed 's/version\s*:\s*/wrapper-/g')

.pana:
	which pana || $(DART_BIN) pub global activate pana
	touch $@

analyze-pdf: .pana
	find pdf -name pubspec.yaml -exec sed -i -e 's/^dependency_overrides:/_dependency_overrides:/g' '{}' ';'
	$(DART_BIN) pub global run pana --no-warning --source path pdf
	find pdf -name pubspec.yaml -exec sed -i -e 's/^_dependency_overrides:/dependency_overrides:/g' '{}' ';'

analyze-printing: .pana
	find printing -name pubspec.yaml -exec sed -i -e 's/^dependency_overrides:/_dependency_overrides:/g' '{}' ';'
	$(DART_BIN) pub global run pana --no-warning --source path printing
	find printing -name pubspec.yaml -exec sed -i -e 's/^_dependency_overrides:/dependency_overrides:/g' '{}' ';'

analyze: analyze-pdf analyze-printing

.dartfix:
	which dartfix || $(DART_BIN) pub global activate dartfix
	touch $@

fix: get .dartfix
	cd pdf; $(DART_BIN) pub global run dartfix --pedantic --overwrite .
	cd printing; $(DART_BIN) pub global run dartfix --pedantic --overwrite .

ref/svg/%.svg:
	mkdir -p ref/svg
	curl -L "$(SVG_ASSETS_URL)/simple/$(notdir $@)" > $@

ref/svg/flutter_logo.svg:
	mkdir -p ref/svg
	curl -L "$(SVG_ASSETS_URL)/$(notdir $@)" > $@

ref/svg/dart.svg:
	mkdir -p ref/svg
	curl -L "$(SVG_ASSETS_URL)/$(notdir $@)" > $@

ref/svg/text_transform.svg:
	mkdir -p ref/svg
	curl -L "$(SVG_ASSETS_URL)/$(notdir $@)" > $@

ref/svg/emoji_u1f600.svg:
	mkdir -p ref/svg
	curl -L "$(SVG_ASSETS_URL)/noto-emoji/$(notdir $@)" > $@

ref/svg/new-pause-button.svg:
	mkdir -p ref/svg
	curl -L "$(SVG_ASSETS_URL)/deborah_ufw/$(notdir $@)" > $@

ref/svg/new-send-circle.svg:
	mkdir -p ref/svg
	curl -L "$(SVG_ASSETS_URL)/deborah_ufw/$(notdir $@)" > $@

ref/svg/new-gif.svg:
	mkdir -p ref/svg
	curl -L "$(SVG_ASSETS_URL)/deborah_ufw/$(notdir $@)" > $@

ref/svg/new-camera.svg:
	mkdir -p ref/svg
	curl -L "$(SVG_ASSETS_URL)/deborah_ufw/$(notdir $@)" > $@

ref/svg/new-image.svg:
	mkdir -p ref/svg
	curl -L "$(SVG_ASSETS_URL)/deborah_ufw/$(notdir $@)" > $@

ref/svg/numeric_25.svg:
	mkdir -p ref/svg
	curl -L "$(SVG_ASSETS_URL)/deborah_ufw/$(notdir $@)" > $@

ref/svg/new-mention.svg:
	mkdir -p ref/svg
	curl -L "$(SVG_ASSETS_URL)/deborah_ufw/$(notdir $@)" > $@

ref/svg/new-gif-button.svg:
	mkdir -p ref/svg
	curl -L "$(SVG_ASSETS_URL)/deborah_ufw/$(notdir $@)" > $@

ref/svg/new-action-expander.svg:
	mkdir -p ref/svg
	curl -L "$(SVG_ASSETS_URL)/deborah_ufw/$(notdir $@)" > $@

ref/svg/new-play-button.svg:
	mkdir -p ref/svg
	curl -L "$(SVG_ASSETS_URL)/deborah_ufw/$(notdir $@)" > $@

ref/svg/aa.svg:
	mkdir -p ref/svg
	curl -L "$(SVG_ASSETS_URL)/w3samples/$(notdir $@)" > $@

ref/svg/alphachannel.svg:
	mkdir -p ref/svg
	curl -L "$(SVG_ASSETS_URL)/w3samples/$(notdir $@)" > $@

ref/svg/Ghostscript_Tiger.svg:
	mkdir -p ref/svg
	curl -L "$(SVG_ASSETS_URL)/wikimedia/$(notdir $@)" > $@

ref/svg/Firefox_Logo_2017.svg:
	mkdir -p ref/svg
	curl -L "$(SVG_ASSETS_URL)/wikimedia/$(notdir $@)" > $@

ref/svg/chess_knight.svg:
	mkdir -p ref/svg
	curl -L "$(SVG_ASSETS_URL)/wikimedia/$(notdir $@)" > $@

ref/svg/Flag_of_the_United_States.svg:
	mkdir -p ref/svg
	curl -L "$(SVG_ASSETS_URL)/wikimedia/$(notdir $@)" > $@

svg: $(patsubst %,ref/svg/%.svg,$(SVG))

ref: svg
	mkdir -p ref
	cd $@; curl -OL 'https://ia801003.us.archive.org/5/items/pdf320002008/PDF32000_2008.pdf'
	cd $@; curl -OL 'https://www.adobe.com/content/dam/cc1/en/devnet/pdf/pdfs/adobe_supplement_iso32000_1.pdf'
	cd $@; curl -OL 'https://ia801001.us.archive.org/1/items/pdf1.7/pdf_reference_1-7.pdf'
	cd $@; curl -OL 'https://www.adobe.com/devnet-docs/acrobatetk/tools/DigSigDC/Acrobat_DigitalSignatures_in_PDF.pdf'

gh-social: all
	cd test; $(DART_BIN) --enable-asserts github_social_preview.dart

gh-pages: all
	cd demo; $(FLUTTER_BIN) build web --base-href "/dart_pdf/"
	git checkout gh-pages
	rm -rf assets icons
	mv -fv demo/build/web/* .

.PHONY: test format format-dart format-clang clean publish-pdf publish-printing analyze ref
