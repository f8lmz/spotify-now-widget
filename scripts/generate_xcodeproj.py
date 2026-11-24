#!/usr/bin/env python3
"""Write SpotifyNow.xcodeproj. Run this instead of editing the project by hand."""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "SpotifyNow.xcodeproj"


def oid(n: int) -> str:
    value = f"A1{n:022X}"
    if len(value) != 24:
        raise SystemExit(f"bad id length {value}")
    return value


# Stable ids. The scheme file refers to the app target by id.
APP_TARGET = oid(0x81)
WIDGET_TARGET = oid(0x82)
PROJECT_ID = oid(0x91)
APP_PRODUCT = oid(0x31)
WIDGET_PRODUCT = oid(0x32)
APP_SYNC = oid(0x51)
WIDGET_SYNC = oid(0x52)
APP_EXC = oid(0x41)
WIDGET_EXC = oid(0x42)
PACKAGE_REF = oid(0xF1)
APP_DEP = oid(0xF2)
WIDGET_DEP = oid(0xF3)


# Apple's old-style plist reader (the one Xcode uses) only allows these
# characters in an unquoted token. '+' is not one of them, so gnu++20 must
# be quoted or the project is "not a valid property list".
_UNQUOTED = re.compile(r"[A-Za-z0-9_$./:-]+")


def q(value: str) -> str:
    if _UNQUOTED.fullmatch(value) and not value.startswith("-"):
        return value
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def setting(key, value, indent="\t\t\t\t"):
    if isinstance(value, bool):
        rendered = "YES" if value else "NO"
    elif isinstance(value, int) and not isinstance(value, bool):
        rendered = str(value)
    elif isinstance(value, list):
        lines = ",\n".join(f"{indent}\t{q(item)}" for item in value)
        rendered = "(\n" + lines + f",\n{indent})"
    else:
        rendered = q(str(value))
    return f"{indent}{key} = {rendered};"


def config_block(name, settings):
    body = "\n".join(setting(key, settings[key]) for key in settings)
    return body


def pbx_config(object_id, name, settings):
    body = config_block(name, settings)
    return (
        f"\t\t{object_id} /* {name} */ = {{\n"
        f"\t\t\tisa = XCBuildConfiguration;\n"
        f"\t\t\tbuildSettings = {{\n"
        f"{body}\n"
        f"\t\t\t}};\n"
        f"\t\t\tname = {name};\n"
        f"\t\t}};"
    )


PROJECT_DEBUG = {
    "ALWAYS_SEARCH_USER_PATHS": False,
    "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": True,
    "CLANG_ANALYZER_NONNULL": True,
    "CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION": "YES_AGGRESSIVE",
    "CLANG_CXX_LANGUAGE_STANDARD": "gnu++20",
    "CLANG_ENABLE_MODULES": True,
    "CLANG_ENABLE_OBJC_ARC": True,
    "CLANG_ENABLE_OBJC_WEAK": True,
    "CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING": True,
    "CLANG_WARN_BOOL_CONVERSION": True,
    "CLANG_WARN_COMMA": True,
    "CLANG_WARN_CONSTANT_CONVERSION": True,
    "CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS": True,
    "CLANG_WARN_DIRECT_OBJC_ISA_USAGE": "YES_ERROR",
    "CLANG_WARN_EMPTY_BODY": True,
    "CLANG_WARN_ENUM_CONVERSION": True,
    "CLANG_WARN_INFINITE_RECURSION": True,
    "CLANG_WARN_INT_CONVERSION": True,
    "CLANG_WARN_NON_LITERAL_NULL_CONVERSION": True,
    "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF": True,
    "CLANG_WARN_OBJC_LITERAL_CONVERSION": True,
    "CLANG_WARN_OBJC_ROOT_CLASS": "YES_ERROR",
    "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER": True,
    "CLANG_WARN_RANGE_LOOP_ANALYSIS": True,
    "CLANG_WARN_STRICT_PROTOTYPES": True,
    "CLANG_WARN_SUSPICIOUS_MOVE": True,
    "CLANG_WARN_UNGUARDED_AVAILABILITY": "YES_AGGRESSIVE",
    "CLANG_WARN_UNREACHABLE_CODE": True,
    "CLANG_WARN__DUPLICATE_METHOD_MATCH": True,
    "COPY_PHASE_STRIP": False,
    "DEBUG_INFORMATION_FORMAT": "dwarf",
    "ENABLE_PREVIEWS": True,
    "ENABLE_STRICT_OBJC_MSGSEND": True,
    "ENABLE_TESTABILITY": True,
    "ENABLE_USER_SCRIPT_SANDBOXING": True,
    "GCC_C_LANGUAGE_STANDARD": "gnu17",
    "GCC_DYNAMIC_NO_PIC": False,
    "GCC_NO_COMMON_BLOCKS": True,
    "GCC_OPTIMIZATION_LEVEL": "0",
    "GCC_PREPROCESSOR_DEFINITIONS": ["DEBUG=1", "$(inherited)"],
    "LOCALIZATION_PREFERS_STRING_CATALOGS": True,
    "MACOSX_DEPLOYMENT_TARGET": "14.0",
    "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
    "MTL_FAST_MATH": True,
    "ONLY_ACTIVE_ARCH": True,
    "SDKROOT": "macosx",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG $(inherited)",
    "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
    "SWIFT_VERSION": "5.0",
}

PROJECT_RELEASE = {
    "ALWAYS_SEARCH_USER_PATHS": False,
    "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": True,
    "CLANG_ANALYZER_NONNULL": True,
    "CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION": "YES_AGGRESSIVE",
    "CLANG_CXX_LANGUAGE_STANDARD": "gnu++20",
    "CLANG_ENABLE_MODULES": True,
    "CLANG_ENABLE_OBJC_ARC": True,
    "CLANG_ENABLE_OBJC_WEAK": True,
    "CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING": True,
    "CLANG_WARN_BOOL_CONVERSION": True,
    "CLANG_WARN_COMMA": True,
    "CLANG_WARN_CONSTANT_CONVERSION": True,
    "CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS": True,
    "CLANG_WARN_DIRECT_OBJC_ISA_USAGE": "YES_ERROR",
    "CLANG_WARN_EMPTY_BODY": True,
    "CLANG_WARN_ENUM_CONVERSION": True,
    "CLANG_WARN_INFINITE_RECURSION": True,
    "CLANG_WARN_INT_CONVERSION": True,
    "CLANG_WARN_NON_LITERAL_NULL_CONVERSION": True,
    "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF": True,
    "CLANG_WARN_OBJC_LITERAL_CONVERSION": True,
    "CLANG_WARN_OBJC_ROOT_CLASS": "YES_ERROR",
    "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER": True,
    "CLANG_WARN_RANGE_LOOP_ANALYSIS": True,
    "CLANG_WARN_STRICT_PROTOTYPES": True,
    "CLANG_WARN_SUSPICIOUS_MOVE": True,
    "CLANG_WARN_UNGUARDED_AVAILABILITY": "YES_AGGRESSIVE",
    "CLANG_WARN_UNREACHABLE_CODE": True,
    "CLANG_WARN__DUPLICATE_METHOD_MATCH": True,
    "COPY_PHASE_STRIP": False,
    "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
    "ENABLE_NS_ASSERTIONS": False,
    "ENABLE_PREVIEWS": True,
    "ENABLE_STRICT_OBJC_MSGSEND": True,
    "ENABLE_USER_SCRIPT_SANDBOXING": True,
    "GCC_C_LANGUAGE_STANDARD": "gnu17",
    "GCC_NO_COMMON_BLOCKS": True,
    "LOCALIZATION_PREFERS_STRING_CATALOGS": True,
    "MACOSX_DEPLOYMENT_TARGET": "14.0",
    "MTL_ENABLE_DEBUG_INFO": False,
    "MTL_FAST_MATH": True,
    "SDKROOT": "macosx",
    "SWIFT_COMPILATION_MODE": "wholemodule",
    "SWIFT_OPTIMIZATION_LEVEL": "-O",
    "SWIFT_VERSION": "5.0",
}

APP_COMMON = {
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
    "CODE_SIGN_ENTITLEMENTS": "SpotifyNow/SpotifyNow.entitlements",
    "CODE_SIGN_STYLE": "Automatic",
    "COMBINE_HIDPI_IMAGES": True,
    "CURRENT_PROJECT_VERSION": 1,
    "ENABLE_APP_SANDBOX": False,
    "ENABLE_HARDENED_RUNTIME": True,
    "GENERATE_INFOPLIST_FILE": False,
    "INFOPLIST_FILE": "SpotifyNow/Info.plist",
    "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/../Frameworks"],
    "MARKETING_VERSION": "1.0",
    "PRODUCT_BUNDLE_IDENTIFIER": "com.example.spotifynow",
    "PRODUCT_BUNDLE_PACKAGE_TYPE": "APPL",
    "PRODUCT_NAME": "$(TARGET_NAME)",
    "REGISTER_APP_GROUPS": False,
    "SWIFT_EMIT_LOC_STRINGS": True,
}

WIDGET_COMMON = {
    "APPLICATION_EXTENSION_API_ONLY": True,
    "CODE_SIGN_ENTITLEMENTS": "SpotifyNowWidget/SpotifyNowWidget.entitlements",
    "CODE_SIGN_STYLE": "Automatic",
    "CURRENT_PROJECT_VERSION": 1,
    "ENABLE_APP_SANDBOX": True,
    "ENABLE_HARDENED_RUNTIME": True,
    "GENERATE_INFOPLIST_FILE": False,
    "INFOPLIST_FILE": "SpotifyNowWidget/Info.plist",
    "LD_RUNPATH_SEARCH_PATHS": [
        "$(inherited)",
        "@executable_path/../Frameworks",
        "@executable_path/../../../../Frameworks",
    ],
    "MARKETING_VERSION": "1.0",
    "PRODUCT_BUNDLE_IDENTIFIER": "com.example.spotifynow.widget",
    "PRODUCT_BUNDLE_PACKAGE_TYPE": "XPC!",
    "PRODUCT_NAME": "$(TARGET_NAME)",
    "REGISTER_APP_GROUPS": False,
    "SKIP_INSTALL": True,
    "SWIFT_EMIT_LOC_STRINGS": True,
    "WRAPPER_EXTENSION": "appex",
}


def build_file(object_id, comment, product=None, file_ref=None, attributes=None):
    lines = [f"\t\t{object_id} /* {comment} */ = {{", "\t\t\tisa = PBXBuildFile;"]
    if file_ref:
        lines.append(f"\t\t\tfileRef = {file_ref} /* {comment.split(' in ')[0]} */;")
    if product:
        lines.append(f"\t\t\tproductRef = {product} /* SpotifyNowShared */;")
    if attributes:
        rendered = ", ".join(attributes)
        lines.append(f"\t\t\tsettings = {{ATTRIBUTES = ({rendered}, ); }};")
    lines.append("\t\t};")
    return "\n".join(lines)


def main():
    bf_app_pkg = oid(1)
    bf_widget_pkg = oid(2)
    bf_embed = oid(3)
    proxy = oid(0x11)
    embed_phase = oid(0x21)
    fw_app = oid(0x61)
    fw_widget = oid(0x62)
    main_group = oid(0x71)
    products = oid(0x72)
    res_app = oid(0xA1)
    res_widget = oid(0xA2)
    src_app = oid(0xB1)
    src_widget = oid(0xB2)
    dependency = oid(0xC1)
    cfg_proj_debug = oid(0xD1)
    cfg_proj_release = oid(0xD2)
    cfg_app_debug = oid(0xD3)
    cfg_app_release = oid(0xD4)
    cfg_widget_debug = oid(0xD5)
    cfg_widget_release = oid(0xD6)
    list_proj = oid(0xE1)
    list_app = oid(0xE2)
    list_widget = oid(0xE3)

    objects = []

    objects.append("/* Begin PBXBuildFile section */")
    objects.append(build_file(bf_app_pkg, "SpotifyNowShared in Frameworks", product=APP_DEP))
    objects.append(build_file(bf_widget_pkg, "SpotifyNowShared in Frameworks", product=WIDGET_DEP))
    objects.append(
        build_file(
            bf_embed,
            "SpotifyNowWidget.appex in Embed Foundation Extensions",
            file_ref=WIDGET_PRODUCT,
            attributes=["CodeSignOnCopy", "RemoveHeadersOnCopy"],
        )
    )
    objects.append("/* End PBXBuildFile section */")

    objects.append("/* Begin PBXContainerItemProxy section */")
    objects.append(
        f"""\t\t{proxy} /* PBXContainerItemProxy */ = {{
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = {PROJECT_ID} /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = {WIDGET_TARGET};
\t\t\tremoteInfo = SpotifyNowWidget;
\t\t}};"""
    )
    objects.append("/* End PBXContainerItemProxy section */")

    objects.append("/* Begin PBXCopyFilesBuildPhase section */")
    objects.append(
        f"""\t\t{embed_phase} /* Embed Foundation Extensions */ = {{
\t\t\tisa = PBXCopyFilesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tdstPath = "";
\t\t\tdstSubfolderSpec = 13;
\t\t\tfiles = (
\t\t\t\t{bf_embed} /* SpotifyNowWidget.appex in Embed Foundation Extensions */,
\t\t\t);
\t\t\tname = "Embed Foundation Extensions";
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};"""
    )
    objects.append("/* End PBXCopyFilesBuildPhase section */")

    objects.append("/* Begin PBXFileReference section */")
    objects.append(
        f"""\t\t{APP_PRODUCT} /* Spotify Now.app */ = {{
\t\t\tisa = PBXFileReference;
\t\t\texplicitFileType = wrapper.application;
\t\t\tincludeInIndex = 0;
\t\t\tpath = "Spotify Now.app";
\t\t\tsourceTree = BUILT_PRODUCTS_DIR;
\t\t}};
\t\t{WIDGET_PRODUCT} /* SpotifyNowWidget.appex */ = {{
\t\t\tisa = PBXFileReference;
\t\t\texplicitFileType = "wrapper.app-extension";
\t\t\tincludeInIndex = 0;
\t\t\tpath = SpotifyNowWidget.appex;
\t\t\tsourceTree = BUILT_PRODUCTS_DIR;
\t\t}};"""
    )
    objects.append("/* End PBXFileReference section */")

    objects.append("/* Begin PBXFileSystemSynchronizedBuildFileExceptionSet section */")
    objects.append(
        f"""\t\t{APP_EXC} /* Exceptions for "SpotifyNow" folder in "Spotify Now" target */ = {{
\t\t\tisa = PBXFileSystemSynchronizedBuildFileExceptionSet;
\t\t\tmembershipExceptions = (
\t\t\t\tInfo.plist,
\t\t\t\tSpotifyNow.entitlements,
\t\t\t);
\t\t\ttarget = {APP_TARGET} /* Spotify Now */;
\t\t}};
\t\t{WIDGET_EXC} /* Exceptions for "SpotifyNowWidget" folder in "SpotifyNowWidget" target */ = {{
\t\t\tisa = PBXFileSystemSynchronizedBuildFileExceptionSet;
\t\t\tmembershipExceptions = (
\t\t\t\tInfo.plist,
\t\t\t\tSpotifyNowWidget.entitlements,
\t\t\t);
\t\t\ttarget = {WIDGET_TARGET} /* SpotifyNowWidget */;
\t\t}};"""
    )
    objects.append("/* End PBXFileSystemSynchronizedBuildFileExceptionSet section */")

    objects.append("/* Begin PBXFileSystemSynchronizedRootGroup section */")
    objects.append(
        f"""\t\t{APP_SYNC} /* SpotifyNow */ = {{
\t\t\tisa = PBXFileSystemSynchronizedRootGroup;
\t\t\texceptions = (
\t\t\t\t{APP_EXC} /* Exceptions for "SpotifyNow" folder in "Spotify Now" target */,
\t\t\t);
\t\t\texplicitFileTypes = {{}};
\t\t\texplicitFolders = (
\t\t\t);
\t\t\tpath = SpotifyNow;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{WIDGET_SYNC} /* SpotifyNowWidget */ = {{
\t\t\tisa = PBXFileSystemSynchronizedRootGroup;
\t\t\texceptions = (
\t\t\t\t{WIDGET_EXC} /* Exceptions for "SpotifyNowWidget" folder in "SpotifyNowWidget" target */,
\t\t\t);
\t\t\texplicitFileTypes = {{}};
\t\t\texplicitFolders = (
\t\t\t);
\t\t\tpath = SpotifyNowWidget;
\t\t\tsourceTree = "<group>";
\t\t}};"""
    )
    objects.append("/* End PBXFileSystemSynchronizedRootGroup section */")

    objects.append("/* Begin PBXFrameworksBuildPhase section */")
    objects.append(
        f"""\t\t{fw_app} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{bf_app_pkg} /* SpotifyNowShared in Frameworks */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
\t\t{fw_widget} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{bf_widget_pkg} /* SpotifyNowShared in Frameworks */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};"""
    )
    objects.append("/* End PBXFrameworksBuildPhase section */")

    objects.append("/* Begin PBXGroup section */")
    objects.append(
        f"""\t\t{main_group} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{APP_SYNC} /* SpotifyNow */,
\t\t\t\t{WIDGET_SYNC} /* SpotifyNowWidget */,
\t\t\t\t{products} /* Products */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{products} /* Products */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{APP_PRODUCT} /* Spotify Now.app */,
\t\t\t\t{WIDGET_PRODUCT} /* SpotifyNowWidget.appex */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t}};"""
    )
    objects.append("/* End PBXGroup section */")

    objects.append("/* Begin PBXNativeTarget section */")
    objects.append(
        f"""\t\t{APP_TARGET} /* Spotify Now */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {list_app} /* Build configuration list for PBXNativeTarget "Spotify Now" */;
\t\t\tbuildPhases = (
\t\t\t\t{src_app} /* Sources */,
\t\t\t\t{fw_app} /* Frameworks */,
\t\t\t\t{res_app} /* Resources */,
\t\t\t\t{embed_phase} /* Embed Foundation Extensions */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t\t{dependency} /* PBXTargetDependency */,
\t\t\t);
\t\t\tfileSystemSynchronizedGroups = (
\t\t\t\t{APP_SYNC} /* SpotifyNow */,
\t\t\t);
\t\t\tname = "Spotify Now";
\t\t\tpackageProductDependencies = (
\t\t\t\t{APP_DEP} /* SpotifyNowShared */,
\t\t\t);
\t\t\tproductName = "Spotify Now";
\t\t\tproductReference = {APP_PRODUCT} /* Spotify Now.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
\t\t{WIDGET_TARGET} /* SpotifyNowWidget */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {list_widget} /* Build configuration list for PBXNativeTarget "SpotifyNowWidget" */;
\t\t\tbuildPhases = (
\t\t\t\t{src_widget} /* Sources */,
\t\t\t\t{fw_widget} /* Frameworks */,
\t\t\t\t{res_widget} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tfileSystemSynchronizedGroups = (
\t\t\t\t{WIDGET_SYNC} /* SpotifyNowWidget */,
\t\t\t);
\t\t\tname = SpotifyNowWidget;
\t\t\tpackageProductDependencies = (
\t\t\t\t{WIDGET_DEP} /* SpotifyNowShared */,
\t\t\t);
\t\t\tproductName = SpotifyNowWidget;
\t\t\tproductReference = {WIDGET_PRODUCT} /* SpotifyNowWidget.appex */;
\t\t\tproductType = "com.apple.product-type.app-extension";
\t\t}};"""
    )
    objects.append("/* End PBXNativeTarget section */")

    objects.append("/* Begin PBXProject section */")
    objects.append(
        f"""\t\t{PROJECT_ID} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1600;
\t\t\t\tLastUpgradeCheck = 1600;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{APP_TARGET} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;
\t\t\t\t\t\tSystemCapabilities = {{
\t\t\t\t\t\t\tcom.apple.ApplicationGroups.Mac = {{
\t\t\t\t\t\t\t\tenabled = 1;
\t\t\t\t\t\t\t}};
\t\t\t\t\t\t\tcom.apple.HardenedRuntime = {{
\t\t\t\t\t\t\t\tenabled = 1;
\t\t\t\t\t\t\t}};
\t\t\t\t\t\t}};
\t\t\t\t\t}};
\t\t\t\t\t{WIDGET_TARGET} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;
\t\t\t\t\t\tSystemCapabilities = {{
\t\t\t\t\t\t\tcom.apple.ApplicationGroups.Mac = {{
\t\t\t\t\t\t\t\tenabled = 1;
\t\t\t\t\t\t\t}};
\t\t\t\t\t\t\tcom.apple.Sandbox = {{
\t\t\t\t\t\t\t\tenabled = 1;
\t\t\t\t\t\t\t}};
\t\t\t\t\t\t}};
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {list_proj} /* Build configuration list for PBXProject "SpotifyNow" */;
\t\t\tcompatibilityVersion = "Xcode 16.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {main_group};
\t\t\tminimizedProjectReferenceProxies = 1;
\t\t\tpackageReferences = (
\t\t\t\t{PACKAGE_REF} /* XCLocalSwiftPackageReference "Packages/SpotifyNowShared" */,
\t\t\t);
\t\t\tpreferredProjectObjectVersion = 77;
\t\t\tproductRefGroup = {products} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{APP_TARGET} /* Spotify Now */,
\t\t\t\t{WIDGET_TARGET} /* SpotifyNowWidget */,
\t\t\t);
\t\t}};"""
    )
    objects.append("/* End PBXProject section */")

    objects.append("/* Begin PBXResourcesBuildPhase section */")
    objects.append(
        f"""\t\t{res_app} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
\t\t{res_widget} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};"""
    )
    objects.append("/* End PBXResourcesBuildPhase section */")

    objects.append("/* Begin PBXSourcesBuildPhase section */")
    objects.append(
        f"""\t\t{src_app} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
\t\t{src_widget} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};"""
    )
    objects.append("/* End PBXSourcesBuildPhase section */")

    objects.append("/* Begin PBXTargetDependency section */")
    objects.append(
        f"""\t\t{dependency} /* PBXTargetDependency */ = {{
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = {WIDGET_TARGET} /* SpotifyNowWidget */;
\t\t\ttargetProxy = {proxy} /* PBXContainerItemProxy */;
\t\t}};"""
    )
    objects.append("/* End PBXTargetDependency section */")

    objects.append("/* Begin XCBuildConfiguration section */")
    objects.append(pbx_config(cfg_proj_debug, "Debug", PROJECT_DEBUG))
    objects.append(pbx_config(cfg_proj_release, "Release", PROJECT_RELEASE))
    objects.append(pbx_config(cfg_app_debug, "Debug", APP_COMMON))
    objects.append(pbx_config(cfg_app_release, "Release", APP_COMMON))
    objects.append(pbx_config(cfg_widget_debug, "Debug", WIDGET_COMMON))
    objects.append(pbx_config(cfg_widget_release, "Release", WIDGET_COMMON))
    objects.append("/* End XCBuildConfiguration section */")

    objects.append("/* Begin XCConfigurationList section */")
    objects.append(
        f"""\t\t{list_proj} /* Build configuration list for PBXProject "SpotifyNow" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{cfg_proj_debug} /* Debug */,
\t\t\t\t{cfg_proj_release} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{list_app} /* Build configuration list for PBXNativeTarget "Spotify Now" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{cfg_app_debug} /* Debug */,
\t\t\t\t{cfg_app_release} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{list_widget} /* Build configuration list for PBXNativeTarget "SpotifyNowWidget" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{cfg_widget_debug} /* Debug */,
\t\t\t\t{cfg_widget_release} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};"""
    )
    objects.append("/* End XCConfigurationList section */")

    objects.append("/* Begin XCLocalSwiftPackageReference section */")
    objects.append(
        f"""\t\t{PACKAGE_REF} /* XCLocalSwiftPackageReference "Packages/SpotifyNowShared" */ = {{
\t\t\tisa = XCLocalSwiftPackageReference;
\t\t\trelativePath = Packages/SpotifyNowShared;
\t\t}};"""
    )
    objects.append("/* End XCLocalSwiftPackageReference section */")

    objects.append("/* Begin XCSwiftPackageProductDependency section */")
    objects.append(
        f"""\t\t{APP_DEP} /* SpotifyNowShared */ = {{
\t\t\tisa = XCSwiftPackageProductDependency;
\t\t\tpackage = {PACKAGE_REF} /* XCLocalSwiftPackageReference "Packages/SpotifyNowShared" */;
\t\t\tproductName = SpotifyNowShared;
\t\t}};
\t\t{WIDGET_DEP} /* SpotifyNowShared */ = {{
\t\t\tisa = XCSwiftPackageProductDependency;
\t\t\tpackage = {PACKAGE_REF} /* XCLocalSwiftPackageReference "Packages/SpotifyNowShared" */;
\t\t\tproductName = SpotifyNowShared;
\t\t}};"""
    )
    objects.append("/* End XCSwiftPackageProductDependency section */")

    text = (
        "// !$*UTF8*$!\n"
        "{\n"
        "\tarchiveVersion = 1;\n"
        "\tclasses = {\n"
        "\t};\n"
        "\tobjectVersion = 77;\n"
        "\tobjects = {\n\n"
        + "\n\n".join(objects)
        + "\n\t};\n"
        f"\trootObject = {PROJECT_ID} /* Project object */;\n"
        "}\n"
    )
    validate(text)
    dest = PROJECT / "project.pbxproj"
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(text, encoding="utf-8")
    write_scheme()
    write_workspace()
    print(f"wrote {dest}")


def validate(text: str):
    if text.count("{") != text.count("}"):
        raise SystemExit("unbalanced braces")
    definitions = re.findall(r"(?m)^\t\t([A-F0-9]{24}) ", text)
    if len(definitions) != len(set(definitions)):
        raise SystemExit("duplicate object ids")
    refs = set(re.findall(r"\b([A-F0-9]{24})\b", text))
    missing = refs - set(definitions)
    if missing:
        raise SystemExit(f"undefined ids: {sorted(missing)}")
    print(f"project objects: {len(definitions)}")


def write_scheme():
    scheme_dir = PROJECT / "xcshareddata" / "xcschemes"
    scheme_dir.mkdir(parents=True, exist_ok=True)
    scheme = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{APP_TARGET}"
               BuildableName = "Spotify Now.app"
               BlueprintName = "Spotify Now"
               ReferencedContainer = "container:SpotifyNow.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{APP_TARGET}"
            BuildableName = "Spotify Now.app"
            BlueprintName = "Spotify Now"
            ReferencedContainer = "container:SpotifyNow.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{APP_TARGET}"
            BuildableName = "Spotify Now.app"
            BlueprintName = "Spotify Now"
            ReferencedContainer = "container:SpotifyNow.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""
    (scheme_dir / "Spotify Now.xcscheme").write_text(scheme, encoding="utf-8")


def write_workspace():
    workspace = PROJECT / "project.xcworkspace"
    workspace.mkdir(parents=True, exist_ok=True)
    (workspace / "contents.xcworkspacedata").write_text(
        """<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "self:">
   </FileRef>
</Workspace>
""",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
