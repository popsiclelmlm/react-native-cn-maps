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
  # The provider-agnostic adapter contract is public so a provider package
  # (react-native-cn-maps-amap) can implement it; everything else stays private.
  s.public_header_files = "ios/Adapter/*.h"
  # Keep codegen output / local build artifacts (ios/build) out of the pod —
  # otherwise the glob sweeps generated sources that double-compile against the
  # RNMapsSpecs pod. (K3)
  s.exclude_files = "ios/build/**/*"

  # Core is provider-agnostic — no AMap dependency. The map provider lives in a
  # separate package (e.g. CnMapsAMap) that depends on this pod.
  install_modules_dependencies(s)
end
