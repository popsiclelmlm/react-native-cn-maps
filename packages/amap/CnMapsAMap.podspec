require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "CnMapsAMap"
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
  # Pinned to the version verified in example/ios/Podfile.lock so iOS builds are
  # reproducible instead of floating to the latest published AMap3DMap. (K2)
  s.dependency "AMap3DMap", "~> 11.1.200"
end
