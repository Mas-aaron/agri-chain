#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint mindspore_lite_flutter.podspec` to validate.
#
Pod::Spec.new do |s|
  s.name             = 'mindspore_lite_flutter'
  s.version          = '0.0.1'
  s.summary          = 'Flutter plugin for MindSpore Lite'
  s.description      = <<-DESC
Flutter plugin for MindSpore Lite AI inference
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '11.0'

  # MindSpore Lite iOS framework
  # You'll need to download and add this manually
  # s.vendored_frameworks = 'Frameworks/mindspore-lite.framework'
  
  # Or use CocoaPods if available
  # s.dependency 'MindSpore'
end
