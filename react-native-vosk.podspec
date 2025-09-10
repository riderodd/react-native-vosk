require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))
folly_compiler_flags = '-DFOLLY_NO_CONFIG -DFOLLY_MOBILE=1 -DFOLLY_USE_LIBCPP=1 -Wno-comma -Wno-shorten-64-to-32'

Pod::Spec.new do |s|
  s.name         = "react-native-vosk"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => min_ios_version_supported }
  s.source       = { :git => "https://github.com/riderodd/react-native-vosk.git", :tag => "#{s.version}" }

  s.source_files = "ios/**/*.{h,m,mm,cpp,swift}", "ios/vosk-model-spk-0.4/*"
  s.private_header_files = "ios/**/*.h"
  s.frameworks = "Accelerate"
  s.library = "c++"
  s.vendored_frameworks = "ios/libvosk.xcframework"
  s.requires_arc = true

  install_modules_dependencies(s)
end
