require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "CnMaps"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => min_ios_version_supported }
  s.source       = { :git => "https://github.com/popsiclelmlm/react-native-cn-maps.git", :tag => "#{s.version}" }

  s.source_files = "ios/**/*.{h,m,mm,swift,cpp}"
  s.private_header_files = "ios/**/*.h"
  # Keep codegen output / local build artifacts (ios/build) out of the pod —
  # otherwise the glob sweeps generated sources that double-compile against the
  # RNMapsSpecs pod. (K3)
  s.exclude_files = "ios/build/**/*"

  install_modules_dependencies(s)
  # Pinned to the version verified in example/ios/Podfile.lock so iOS builds are
  # reproducible instead of floating to the latest published AMap3DMap. (K2)
  s.dependency "AMap3DMap", "~> 11.1.200"
end
