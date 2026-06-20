require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "CnMapsTencent"
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
  # Tencent Map iOS SDK (QMapKit). Pin to the version verified in your Podfile.lock.
  s.dependency "QMapKit", "~> 5.6.0"
end
