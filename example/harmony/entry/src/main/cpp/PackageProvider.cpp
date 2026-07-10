#include "RNOH/PackageProvider.h"
#include "generated/RNOHGeneratedPackage.h"

using namespace rnoh;

std::vector<std::shared_ptr<Package>> PackageProvider::getPackages(Package::Context ctx) {
    // 由 `react-native codegen-harmony` 生成：注册 react-native-cn-maps 全部 Fabric
    // 组件的 ComponentDescriptor/JSIBinder（让 JS requireNativeComponent 能解析）
    // 及 RNMapsModule 的 C++ TurboModule 胶水。
    return {
        std::make_shared<RNOHGeneratedPackage>(ctx),
    };
}
