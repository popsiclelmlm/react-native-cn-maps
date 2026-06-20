require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "CnMapsBaidu"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => min_ios_version_supported }
  s.source       = { :git => "https://github.com/popsiclelmlm/react-native-cn-maps.git", :tag => "#{s.version}" }

  s.source_files = "ios/**/*.{h,m,mm,swift,cpp}"
  s.exclude_files = "ios/build/**/*"

  install_modules_dependencies(s)

  # The provider-agnostic adapter contract (public headers of the core pod).
  s.dependency "CnMaps"
  # Baidu Map iOS SDK. BaiduMapKit bundles BaiduMapAPI_Map / _Base / _Search etc.
  # Pin to the version verified in your app's Podfile.lock for reproducible builds.
  s.dependency "BaiduMapKit", "~> 6.6.0"
end
