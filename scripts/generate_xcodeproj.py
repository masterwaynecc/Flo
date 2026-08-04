#!/usr/bin/env python3
"""Generate Dawt.xcodeproj from discovered Swift sources."""

from __future__ import annotations

import os
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IOS = ROOT / "ios" / "Dawt"
PROJECT_DIR = IOS / "Dawt.xcodeproj"
SOURCES = sorted((IOS / "Dawt").rglob("*.swift"))
TESTS = sorted((ROOT / "Tests" / "DawtTests").rglob("*.swift"))


def nid() -> str:
    return uuid.uuid4().hex[:24].upper()


def main() -> None:
    ids = {k: nid() for k in [
        "project", "main_group", "products", "src_group", "test_group",
        "app_target", "test_target", "app_product", "test_product",
        "app_sources", "app_frameworks", "app_resources",
        "test_sources", "test_frameworks",
        "proj_configs", "app_configs", "test_configs",
        "dbg_proj", "rel_proj", "dbg_app", "rel_app", "dbg_test", "rel_test",
        "assets", "assets_build", "info",
        "container", "target_dep",
    ]}

    file_refs = []
    build_app = []
    build_test = []
    src_children = []
    test_children = []

    for path in SOURCES:
        fid, bid = nid(), nid()
        rel = path.relative_to(IOS).as_posix()
        file_refs.append(
            f'\t\t{fid} /* {path.name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = "{path.name}"; path = "{rel}"; sourceTree = "<group>"; }};'
        )
        build_app.append(f'\t\t{bid} /* {path.name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {path.name} */; }};')
        src_children.append(f"\t\t\t\t{fid} /* {path.name} */,")

    for path in TESTS:
        fid, bid = nid(), nid()
        rel = os.path.relpath(path, IOS)
        file_refs.append(
            f'\t\t{fid} /* {path.name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = "{path.name}"; path = "{rel}"; sourceTree = "<group>"; }};'
        )
        build_test.append(f'\t\t{bid} /* {path.name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {path.name} */; }};')
        test_children.append(f"\t\t\t\t{fid} /* {path.name} */,")

    file_refs += [
        f'\t\t{ids["assets"]} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Dawt/Assets.xcassets; sourceTree = "<group>"; }};',
        f'\t\t{ids["info"]} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Dawt/Info.plist; sourceTree = "<group>"; }};',
        f'\t\t{ids["app_product"]} /* Dawt.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Dawt.app; sourceTree = BUILT_PRODUCTS_DIR; }};',
        f'\t\t{ids["test_product"]} /* DawtTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = DawtTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};',
    ]
    build_app.append(
        f'\t\t{ids["assets_build"]} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {ids["assets"]} /* Assets.xcassets */; }};'
    )

    app_source_lines = "\n".join(
        f"\t\t\t\t{line.split()[0]} /* in Sources */," for line in build_app if "in Sources" in line
    )
    test_source_lines = "\n".join(
        f"\t\t\t\t{line.split()[0]} /* in Sources */," for line in build_test if "in Sources" in line
    )

    content = f"""// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{}};
\tobjectVersion = 56;
\tobjects = {{

/* Begin PBXBuildFile section */
{chr(10).join(build_app)}
{chr(10).join(build_test)}
\t\t{ids["container"]} /* PBXContainerItemProxy */ = {{isa = PBXContainerItemProxy; containerPortal = {ids["project"]} /* Project object */; proxyType = 1; remoteGlobalIDString = {ids["app_target"]}; remoteInfo = Dawt; }};
\t\t{ids["target_dep"]} /* PBXTargetDependency */ = {{isa = PBXTargetDependency; target = {ids["app_target"]} /* Dawt */; targetProxy = {ids["container"]} /* PBXContainerItemProxy */; }};
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{chr(10).join(file_refs)}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
\t\t{ids["app_frameworks"]} /* Frameworks */ = {{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};
\t\t{ids["test_frameworks"]} /* Frameworks */ = {{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
\t\t{ids["main_group"]} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{ids["src_group"]} /* Sources */,
\t\t\t\t{ids["test_group"]} /* Tests */,
\t\t\t\t{ids["assets"]} /* Assets.xcassets */,
\t\t\t\t{ids["info"]} /* Info.plist */,
\t\t\t\t{ids["products"]} /* Products */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{ids["products"]} /* Products */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{ids["app_product"]} /* Dawt.app */,
\t\t\t\t{ids["test_product"]} /* DawtTests.xctest */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{ids["src_group"]} /* Sources */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{chr(10).join(src_children)}
\t\t\t);
\t\t\tname = Sources;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{ids["test_group"]} /* Tests */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{chr(10).join(test_children)}
\t\t\t);
\t\t\tname = Tests;
\t\t\tsourceTree = "<group>";
\t\t}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t{ids["app_target"]} /* Dawt */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {ids["app_configs"]} /* Build configuration list for PBXNativeTarget "Dawt" */;
\t\t\tbuildPhases = (
\t\t\t\t{ids["app_sources"]} /* Sources */,
\t\t\t\t{ids["app_frameworks"]} /* Frameworks */,
\t\t\t\t{ids["app_resources"]} /* Resources */,
\t\t\t);
\t\t\tbuildRules = ();
\t\t\tdependencies = ();
\t\t\tname = Dawt;
\t\t\tproductName = Dawt;
\t\t\tproductReference = {ids["app_product"]} /* Dawt.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
\t\t{ids["test_target"]} /* DawtTests */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {ids["test_configs"]} /* Build configuration list for PBXNativeTarget "DawtTests" */;
\t\t\tbuildPhases = (
\t\t\t\t{ids["test_sources"]} /* Sources */,
\t\t\t\t{ids["test_frameworks"]} /* Frameworks */,
\t\t\t);
\t\t\tbuildRules = ();
\t\t\tdependencies = (
\t\t\t\t{ids["target_dep"]} /* PBXTargetDependency */,
\t\t\t);
\t\t\tname = DawtTests;
\t\t\tproductName = DawtTests;
\t\t\tproductReference = {ids["test_product"]} /* DawtTests.xctest */;
\t\t\tproductType = "com.apple.product-type.bundle.unit-test";
\t\t}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{ids["project"]} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1600;
\t\t\t\tLastUpgradeCheck = 1600;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{ids["app_target"]} = {{ CreatedOnToolsVersion = 16.0; }};
\t\t\t\t\t{ids["test_target"]} = {{ CreatedOnToolsVersion = 16.0; TestTargetID = {ids["app_target"]}; }};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {ids["proj_configs"]} /* Build configuration list for PBXProject "Dawt" */;
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (en, Base);
\t\t\tmainGroup = {ids["main_group"]};
\t\t\tproductRefGroup = {ids["products"]} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{ids["app_target"]} /* Dawt */,
\t\t\t\t{ids["test_target"]} /* DawtTests */,
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t{ids["app_resources"]} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{ids["assets_build"]} /* Assets.xcassets in Resources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t{ids["app_sources"]} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{app_source_lines}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
\t\t{ids["test_sources"]} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{test_source_lines}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
\t\t{ids["dbg_proj"]} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{ids["rel_proj"]} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{ids["dbg_app"]} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = dawt/Info.plist;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/Frameworks");
\t\t\t\tMARKETING_VERSION = 0.1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = app.dawt.cycle;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = 1;
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{ids["rel_app"]} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = dawt/Info.plist;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/Frameworks");
\t\t\t\tMARKETING_VERSION = 0.1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = app.dawt.cycle;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = 1;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{ids["dbg_test"]} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tBUNDLE_LOADER = "$(TEST_HOST)";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = app.dawt.cycle.tests;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = 1;
\t\t\t\tTEST_HOST = "$(BUILT_PRODUCTS_DIR)/Dawt.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Dawt";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{ids["rel_test"]} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tBUNDLE_LOADER = "$(TEST_HOST)";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = app.dawt.cycle.tests;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = 1;
\t\t\t\tTEST_HOST = "$(BUILT_PRODUCTS_DIR)/Dawt.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Dawt";
\t\t\t}};
\t\t\tname = Release;
\t\t}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t{ids["proj_configs"]} /* Build configuration list for PBXProject "Dawt" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = ({ids["dbg_proj"]} /* Debug */, {ids["rel_proj"]} /* Release */);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{ids["app_configs"]} /* Build configuration list for PBXNativeTarget "Dawt" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = ({ids["dbg_app"]} /* Debug */, {ids["rel_app"]} /* Release */);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{ids["test_configs"]} /* Build configuration list for PBXNativeTarget "DawtTests" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = ({ids["dbg_test"]} /* Debug */, {ids["rel_test"]} /* Release */);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */
\t}};
\trootObject = {ids["project"]} /* Project object */;
}}
"""

    # Move proxy/dependency out of BuildFile section into proper sections via comment labels — Xcode tolerates mixed but let's fix:
    content = content.replace(
        f'\t\t{ids["container"]} /* PBXContainerItemProxy */ = {{isa = PBXContainerItemProxy; containerPortal = {ids["project"]} /* Project object */; proxyType = 1; remoteGlobalIDString = {ids["app_target"]}; remoteInfo = Dawt; }};\n'
        f'\t\t{ids["target_dep"]} /* PBXTargetDependency */ = {{isa = PBXTargetDependency; target = {ids["app_target"]} /* Dawt */; targetProxy = {ids["container"]} /* PBXContainerItemProxy */; }};\n/* End PBXBuildFile section */',
        "/* End PBXBuildFile section */\n\n/* Begin PBXContainerItemProxy section */\n"
        f'\t\t{ids["container"]} /* PBXContainerItemProxy */ = {{isa = PBXContainerItemProxy; containerPortal = {ids["project"]} /* Project object */; proxyType = 1; remoteGlobalIDString = {ids["app_target"]}; remoteInfo = Dawt; }};\n'
        "/* End PBXContainerItemProxy section */\n\n/* Begin PBXTargetDependency section */\n"
        f'\t\t{ids["target_dep"]} /* PBXTargetDependency */ = {{isa = PBXTargetDependency; target = {ids["app_target"]} /* Dawt */; targetProxy = {ids["container"]} /* PBXContainerItemProxy */; }};\n'
        "/* End PBXTargetDependency section */",
    )

    PROJECT_DIR.mkdir(parents=True, exist_ok=True)
    (PROJECT_DIR / "project.pbxproj").write_text(content)
    print(f"Generated project with {len(SOURCES)} sources, {len(TESTS)} tests")


if __name__ == "__main__":
    main()
