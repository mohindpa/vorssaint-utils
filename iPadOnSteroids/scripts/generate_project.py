#!/usr/bin/env python3
"""Generate a dependency-free Xcode project with app and XCTest targets."""
from pathlib import Path
import hashlib
ROOT = Path(__file__).resolve().parents[1]
objects = {}
def ident(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def obj(name, text):
    key = ident(name)
    objects[key] = text
    return key
def array(values): return '(' + ', '.join(values) + ',)'
files = sorted((ROOT / 'App').glob('*.swift'))
test_files = sorted((ROOT / 'Tests').glob('*.swift'))
ui_files = sorted((ROOT / 'UITests').glob('*.swift'))
def source_group(name, paths):
    refs, builds = [], []
    for path in paths:
        ref = obj(str(path.relative_to(ROOT)), f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{path.name}"; sourceTree = "<group>";')
        refs.append(ref)
        builds.append(obj('build:'+str(path.relative_to(ROOT)), f'isa = PBXBuildFile; fileRef = {ref};'))
    group = obj('group:'+name, f'isa = PBXGroup; children = {array(refs)}; path = {name}; sourceTree = "<group>";')
    phase = obj('sources:'+name, f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {array(builds)}; runOnlyForDeploymentPostprocessing = 0;')
    return group, phase
app_group, app_sources = source_group('App', files)
privacy_ref = obj('privacy', 'isa = PBXFileReference; lastKnownFileType = text.xml; path = PrivacyInfo.xcprivacy; sourceTree = "<group>";')
privacy_build = obj('privacy-build', f'isa = PBXBuildFile; fileRef = {privacy_ref};')
objects[app_group] = objects[app_group].replace('children = (', f'children = ({privacy_ref}, ')

tests_group, tests_sources = source_group('Tests', test_files)
ui_group, ui_sources = source_group('UITests', ui_files)
app_product = obj('app-product', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = "iPadOnSteroids.app"; sourceTree = BUILT_PRODUCTS_DIR;')
test_product = obj('test-product', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = "iPadOnSteroidsTests.xctest"; sourceTree = BUILT_PRODUCTS_DIR;')
ui_product = obj('ui-product', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = "iPadOnSteroidsUITests.xctest"; sourceTree = BUILT_PRODUCTS_DIR;')
products = obj('products', f'isa = PBXGroup; children = {array([app_product, test_product, ui_product])}; name = Products; sourceTree = "<group>";')
main_group = obj('main-group', f'isa = PBXGroup; children = {array([app_group, tests_group, ui_group, products])}; sourceTree = "<group>";')
common = 'IPHONEOS_DEPLOYMENT_TARGET = 17.0; SDKROOT = iphoneos; SWIFT_VERSION = 5.0; CLANG_ENABLE_MODULES = YES;'
app_settings = '''CODE_SIGN_STYLE = Automatic; GENERATE_INFOPLIST_FILE = YES;
INFOPLIST_KEY_CFBundleDisplayName = "iPad on Steroids";
INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.productivity";
INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
INFOPLIST_KEY_UIApplicationSupportsMultipleScenes = NO;
INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
INFOPLIST_KEY_UILaunchScreen_Generation = YES;
INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
PRODUCT_BUNDLE_IDENTIFIER = com.mohindpa.ipadonsteroids;
PRODUCT_NAME = "$(TARGET_NAME)"; TARGETED_DEVICE_FAMILY = 2;
MARKETING_VERSION = 0.2.0; CURRENT_PROJECT_VERSION = 2;
SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; SUPPORTS_MACCATALYST = NO;
'''
test_settings = '''CODE_SIGN_STYLE = Automatic; GENERATE_INFOPLIST_FILE = YES;
PRODUCT_BUNDLE_IDENTIFIER = com.mohindpa.ipadonsteroids.tests;
PRODUCT_NAME = "$(TARGET_NAME)"; TARGETED_DEVICE_FAMILY = 2;
TEST_HOST = "$(BUILT_PRODUCTS_DIR)/iPadOnSteroids.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/iPadOnSteroids";
BUNDLE_LOADER = "$(TEST_HOST)";
'''
def configs(name, settings):
    ids = []
    for mode in ['Debug', 'Release']:
        optimization = 'SWIFT_OPTIMIZATION_LEVEL = "-Onone"; DEBUG_INFORMATION_FORMAT = dwarf; SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG; ENABLE_TESTABILITY = YES;' if mode == 'Debug' else 'SWIFT_OPTIMIZATION_LEVEL = "-O"; DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";'
        ids.append(obj(name+mode, f'isa = XCBuildConfiguration; buildSettings = {{ {settings} {optimization} }}; name = {mode};'))
    return obj(name+'configs', f'isa = XCConfigurationList; buildConfigurations = {array(ids)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
project_configs = configs('project', common)
app_configs = configs('app', app_settings)
test_configs = configs('test', test_settings)
ui_configs = configs('ui', 'CODE_SIGN_STYLE = Automatic; GENERATE_INFOPLIST_FILE = YES; PRODUCT_BUNDLE_IDENTIFIER = com.mohindpa.ipadonsteroids.uitests; PRODUCT_NAME = "$(TARGET_NAME)"; TARGETED_DEVICE_FAMILY = 2; TEST_TARGET_NAME = iPadOnSteroids;')
app_id = ident('app-target')
project_id = ident('project')
proxy = obj('proxy', f'isa = PBXContainerItemProxy; containerPortal = {project_id}; proxyType = 1; remoteGlobalIDString = {app_id}; remoteInfo = iPadOnSteroids;')
dep = obj('test-dependency', f'isa = PBXTargetDependency; target = {app_id}; targetProxy = {proxy};')
for name, sources, config, product, kind, dependencies in [
    ('app', app_sources, app_configs, app_product, 'application', []),
    ('test', tests_sources, test_configs, test_product, 'bundle.unit-test', [dep]),
    ('ui', ui_sources, ui_configs, ui_product, 'bundle.ui-testing', [dep])]:
    frameworks = obj(name+'frameworks', 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
    resources = obj(name+'resources', f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = {array([privacy_build]) if name == "app" else "()"}; runOnlyForDeploymentPostprocessing = 0;')
    target_name = {'app':'iPadOnSteroids', 'test':'iPadOnSteroidsTests', 'ui':'iPadOnSteroidsUITests'}[name]
    obj(name+'-target', f'isa = PBXNativeTarget; buildConfigurationList = {config}; buildPhases = {array([sources, frameworks, resources])}; buildRules = (); dependencies = {array(dependencies) if dependencies else "()"}; name = {target_name}; productName = {target_name}; productReference = {product}; productType = "com.apple.product-type.{kind}";')
obj('project', f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 1600; BuildIndependentTargetsInParallel = YES; }}; buildConfigurationList = {project_configs}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = {main_group}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = {array([app_id, ident("test-target"), ident("ui-target")])};')
project_dir = ROOT / 'iPadOnSteroids.xcodeproj'
project_dir.mkdir(exist_ok=True)
text = '// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'
text += '\n'.join(f'{key} = {{ {value} }};' for key, value in objects.items())
text += f'\n}}; rootObject = {project_id}; }}\n'
(project_dir / 'project.pbxproj').write_text(text)
schemes = project_dir / 'xcshareddata' / 'xcschemes'
schemes.mkdir(parents=True, exist_ok=True)
def build_ref(target, name):
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="{name}" BlueprintName="{name.split(".")[0]}" ReferencedContainer="container:iPadOnSteroids.xcodeproj"/>'
app_ref = build_ref(app_id, 'iPadOnSteroids.app')
test_ref = build_ref(ident('test-target'), 'iPadOnSteroidsTests.xctest')
ui_ref = build_ref(ident('ui-target'), 'iPadOnSteroidsUITests.xctest')
(schemes / 'iPadOnSteroids.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app_ref}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{test_ref}</TestableReference><TestableReference skipped="NO">{ui_ref}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print(f'Generated {project_dir.name}: {len(files)} app sources, {len(test_files)} test sources')
