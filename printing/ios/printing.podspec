#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'printing'
  s.version          = '0.0.1'
  s.summary          = 'Plugin that allows Flutter apps to generate and print documents to android or ios compatible printers'
  s.description      = <<-DESC
Plugin that allows Flutter apps to generate and print documents to android or ios compatible printers
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  
  s.ios.deployment_target = '8.0'
  s.swift_version = '4.2'
end
