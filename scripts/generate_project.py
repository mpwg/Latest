#!/usr/bin/env python3
"""Generate the repository-owned Xcode project; no third-party project generator is required."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parent.parent
objects = {}

def key(name):
    return hashlib.sha1(name.encode()).hexdigest()[:24].upper()

def obj(identity, isa, **values):
    identifier = key(identity)
    objects[identifier] = {"isa": isa, **values}
    return identifier

def serialize(value, indent=0):
    if isinstance(value, dict):
        return "{\n" + "\n".join("\t"*(indent+1) + json.dumps(str(k)) + " = " + serialize(v, indent+1) + ";" for k,v in value.items()) + "\n" + "\t"*indent + "}"
    if isinstance(value, list):
        return "(\n" + "\n".join("\t"*(indent+1) + serialize(v, indent+1) + "," for v in value) + "\n" + "\t"*indent + ")"
    return json.dumps(str(value))

package = obj("local-package", "XCLocalSwiftPackageReference", relativePath=".")
config_file = obj("config-file", "PBXFileReference", lastKnownFileType="text.xcconfig", path="Config/App.xcconfig", sourceTree="SOURCE_ROOT")
children = [config_file]
products = []
targets = []

def target(name, source_folder, product_type, dependencies, resources=()):
    tid = key("target-"+name)
    refs=[]; source_files=[]; frameworks=[]; package_products=[]; resource_files=[]
    for path in sorted((ROOT/source_folder).glob("*.swift")):
        relative=str(path.relative_to(ROOT))
        ref=obj("file-"+relative,"PBXFileReference", lastKnownFileType="sourcecode.swift",path=relative,sourceTree="SOURCE_ROOT")
        refs.append(ref);source_files.append(obj("source-"+name+relative,"PBXBuildFile",fileRef=ref))
    for dependency in dependencies:
        pid=obj("dependency-"+name+dependency,"XCSwiftPackageProductDependency",package=package,productName=dependency)
        package_products.append(pid);frameworks.append(obj("link-"+name+dependency,"PBXBuildFile",productRef=pid))
    for path in resources:
        ref=obj("resource-"+path,"PBXFileReference",lastKnownFileType="text.json.xcstrings" if path.endswith("xcstrings") else "folder.icon",path=path,sourceTree="SOURCE_ROOT")
        refs.append(ref);resource_files.append(obj("resource-build-"+name+path,"PBXBuildFile",fileRef=ref))
    children.append(obj("group-"+name,"PBXGroup",name=name,children=refs,sourceTree="<group>"))
    suffix=".app" if product_type.endswith("application") else ".xctest"
    product=obj("product-"+name,"PBXFileReference",explicitFileType="wrapper.application" if suffix==".app" else "wrapper.cfbundle",path=name+suffix,sourceTree="BUILT_PRODUCTS_DIR")
    products.append(product)
    configurations=[]
    for configuration in ["Debug","Release"]:
        settings={"PRODUCT_NAME":name,"PRODUCT_BUNDLE_IDENTIFIER":"io.github.mpwg.Latest"+("" if name=="Latest" else "."+name),"SWIFT_ACTIVE_COMPILATION_CONDITIONS":"DEBUG $(inherited)" if configuration=="Debug" else "$(inherited)","SWIFT_OPTIMIZATION_LEVEL":"-Onone" if configuration=="Debug" else "-O"}
        if name=="Latest":
            settings["SWIFT_DEFAULT_ACTOR_ISOLATION"]="MainActor"
        else:
            settings.update({"GENERATE_INFOPLIST_FILE":"YES","INFOPLIST_FILE":"","TEST_TARGET_NAME":"Latest" if name=="LatestUITests" else ""})
        configurations.append(obj("configuration-"+name+configuration,"XCBuildConfiguration",name=configuration,baseConfigurationReference=config_file,buildSettings=settings))
    configuration_list=obj("configurations-"+name,"XCConfigurationList",buildConfigurations=configurations,defaultConfigurationIsVisible="0",defaultConfigurationName="Release")
    phases=[obj("sources-"+name,"PBXSourcesBuildPhase",buildActionMask="2147483647",files=source_files,runOnlyForDeploymentPostprocessing="0"),obj("frameworks-"+name,"PBXFrameworksBuildPhase",buildActionMask="2147483647",files=frameworks,runOnlyForDeploymentPostprocessing="0"),obj("resources-"+name,"PBXResourcesBuildPhase",buildActionMask="2147483647",files=resource_files,runOnlyForDeploymentPostprocessing="0")]
    obj("target-"+name,"PBXNativeTarget",name=name,productName=name,productType=product_type,productReference=product,buildConfigurationList=configuration_list,buildPhases=phases,dependencies=[],buildRules=[],packageProductDependencies=package_products)
    targets.append(tid)
    return tid

app=target("Latest","Sources/LatestApp","com.apple.product-type.application",["LatestCore","LatestPlatform","Sparkle"],["Sources/LatestApp/Resources/Localizable.xcstrings"])
core_tests=target("LatestCoreTests","Tests/LatestCoreTests","com.apple.product-type.bundle.unit-test",["LatestCore","LatestPlatform"])
ui_tests=target("LatestUITests","Tests/LatestUITests","com.apple.product-type.bundle.ui-testing",[])
proxy=obj("ui-proxy","PBXContainerItemProxy",containerPortal=key("project"),proxyType="1",remoteGlobalIDString=app,remoteInfo="Latest")
objects[ui_tests]["dependencies"]=[obj("ui-dependency","PBXTargetDependency",target=app,targetProxy=proxy)]
product_group=obj("products","PBXGroup",name="Products",children=products,sourceTree="<group>")
main=obj("main","PBXGroup",children=children+[product_group],sourceTree="<group>")
project_configs=[obj("project-config-"+name,"XCBuildConfiguration",name=name,buildSettings={"SDKROOT":"macosx","CLANG_ENABLE_MODULES":"YES","SWIFT_VERSION":"6.0","MACOSX_DEPLOYMENT_TARGET":"27.0","ENABLE_HARDENED_RUNTIME":"YES","ENABLE_USER_SCRIPT_SANDBOXING":"YES"}) for name in ["Debug","Release"]]
configuration_list=obj("project-configs","XCConfigurationList",buildConfigurations=project_configs,defaultConfigurationIsVisible="0",defaultConfigurationName="Release")
project=obj("project","PBXProject",attributes={"LastUpgradeCheck":"2700","LastSwiftUpdateCheck":"2700"},buildConfigurationList=configuration_list,compatibilityVersion="Xcode 14.0",developmentRegion="en",hasScannedForEncodings="0",knownRegions=["en","de","Base"],mainGroup=main,productRefGroup=product_group,projectDirPath="",projectRoot="",targets=targets,packageReferences=[package])
document={"archiveVersion":"1","classes":{},"objectVersion":"60","objects":objects,"rootObject":project}
(ROOT/"Latest.xcodeproj/project.pbxproj").write_text("// !$*UTF8*$!\n"+serialize(document)+"\n")
schemes=ROOT/"Latest.xcodeproj/xcshareddata/xcschemes";schemes.mkdir(parents=True,exist_ok=True)
def reference(identifier,name):
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{identifier}" BuildableName="{name}" BlueprintName="{name.split(".")[0]}" ReferencedContainer="container:Latest.xcodeproj"/>'
(schemes/"Latest.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference(app,"Latest.app")}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{reference(core_tests,"LatestCoreTests.xctest")}</TestableReference><TestableReference skipped="NO">{reference(ui_tests,"LatestUITests.xctest")}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference(app,"Latest.app")}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" useCustomWorkingDirectory="NO"><BuildableProductRunnable runnableDebuggingMode="0">{reference(app,"Latest.app")}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
print("Generated the shared Xcode 27 project and native test scheme.")
