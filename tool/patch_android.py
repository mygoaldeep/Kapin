#!/usr/bin/env python3
"""Run after `flutter create --platforms=android .` to wire up Kapin's Android
project: permissions, Maps key placeholder, app label and minSdk 23. Idempotent."""
import pathlib
import re
import sys

app = pathlib.Path("android/app")
manifest = app / "src/main/AndroidManifest.xml"
if not manifest.exists():
    sys.exit("android/ not found. Run `flutter create --platforms=android .` first.")

s = manifest.read_text()
if "ACCESS_FINE_LOCATION" not in s:
    perms = (
        '    <uses-permission android:name="android.permission.INTERNET" />\n'
        '    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />\n'
        '    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />\n\n'
    )
    s = s.replace("<application", perms + "    <application", 1)
if "com.google.android.geo.API_KEY" not in s:
    s = re.sub(
        r"(<application\b[^>]*>)",
        r'\1\n        <meta-data android:name="com.google.android.geo.API_KEY" '
        r'android:value="${MAPS_API_KEY}" />',
        s,
        count=1,
    )
s = re.sub(r'android:label="[^"]*"', 'android:label="Kapin"', s, count=1)
manifest.write_text(s)

gradle = next((p for p in (app / "build.gradle.kts", app / "build.gradle") if p.exists()), None)
if gradle is None:
    sys.exit("No android/app/build.gradle(.kts) found.")
g = gradle.read_text()
g = re.sub(r"minSdk(Version)?(\s*=\s*|\s+)flutter\.minSdkVersion", r"minSdk\1\g<2>23", g)
if "MAPS_API_KEY" not in g:
    if gradle.suffix == ".kts":
        line = '        manifestPlaceholders["MAPS_API_KEY"] = System.getenv("MAPS_API_KEY") ?: ""'
    else:
        line = '        manifestPlaceholders = [MAPS_API_KEY: System.getenv("MAPS_API_KEY") ?: ""]'
    g = re.sub(r"(defaultConfig\s*\{)", r"\1\n" + line, g, count=1)
gradle.write_text(g)
print("Android project patched.")

# Some plugins (e.g. geocoding_android) pin compileSdk 33 but pull AndroidX
# libraries that need 34+. Force a modern compileSdk on every plugin module.
root = pathlib.Path("android/build.gradle.kts")
if root.exists():
    r = root.read_text()
    if "Kapin: force compileSdk" not in r:
        block = '''// Kapin: force compileSdk on plugin modules still pinned to an old SDK.
subprojects {
    val forceSdk: (Project) -> Unit = { p ->
        val ext = p.extensions.findByName("android")
        if (ext != null && p.name != "app") {
            ext.javaClass.methods
                .firstOrNull {
                    it.name == "setCompileSdkVersion" &&
                        it.parameterTypes.size == 1 &&
                        it.parameterTypes[0] == Int::class.javaPrimitiveType
                }
                ?.invoke(ext, 36)
        }
    }
    if (state.executed) forceSdk(this) else afterEvaluate { forceSdk(this) }
}

'''
        root.write_text(block + r)
        print("Root build.gradle.kts patched (compileSdk override).")
else:
    print("WARNING: android/build.gradle.kts not found; compileSdk override not applied.")
