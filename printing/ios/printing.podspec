#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'printing'
  s.version          = '1.0.0'
  s.summary          = 'Flutter printing plugin'
  s.description      = 'Plugin that allows Flutter apps to generate and print documents to iOS compatible printers'
  s.homepage         = 'https://pub.dev/packages/printing'
  s.license          = { :type => 'Apache2' }
  s.author           = { 'David PHAM-VAN' => 'dev.nfet.net@gmail.com' }
  s.source           = { :git => 'https://github.com/DavBfr/dart_pdf.git', :branch => 'master' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.ios.deployment_target = '8.0'
  s.swift_version = '4.2'
end
