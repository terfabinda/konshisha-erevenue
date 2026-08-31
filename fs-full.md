# Project Structure

```
├── android
    ├── app
    │   ├── src
    │   │   ├── debug
    │   │   │   └── AndroidManifest.xml
    │   │   ├── main
    │   │   │   ├── java
    │   │   │   │   └── io
    │   │   │   │   │   └── flutter
    │   │   │   │   │       └── plugins
    │   │   │   │   │           └── GeneratedPluginRegistrant.java
    │   │   │   ├── kotlin
    │   │   │   │   └── com
    │   │   │   │   │   └── erevenue
    │   │   │   │   │       └── app
    │   │   │   │   │           └── erevenue
    │   │   │   ├── res
    │   │   │   │   ├── drawable
    │   │   │   │   │   └── launch_background.xml
    │   │   │   │   ├── drawable-v21
    │   │   │   │   │   └── launch_background.xml
    │   │   │   │   ├── mipmap-hdpi
    │   │   │   │   │   └── ic_launcher.png
    │   │   │   │   ├── mipmap-mdpi
    │   │   │   │   │   └── ic_launcher.png
    │   │   │   │   ├── mipmap-xhdpi
    │   │   │   │   │   └── ic_launcher.png
    │   │   │   │   ├── mipmap-xxhdpi
    │   │   │   │   │   └── ic_launcher.png
    │   │   │   │   ├── mipmap-xxxhdpi
    │   │   │   │   │   └── ic_launcher.png
    │   │   │   │   ├── values
    │   │   │   │   │   └── styles.xml
    │   │   │   │   └── values-night
    │   │   │   │   │   └── styles.xml
    │   │   │   └── AndroidManifest.xml
    │   │   └── profile
    │   │   │   └── AndroidManifest.xml
    │   └── build.gradle.kts
    ├── gradle
    │   └── wrapper
    │   │   ├── gradle-wrapper.jar
    │   │   └── gradle-wrapper.properties
    ├── build.gradle.kts
    ├── erevenue_android.iml
    ├── gradle.properties
    ├── gradlew
    ├── gradlew.bat
    ├── local.properties
    └── settings.gradle.kts
├── ios
    ├── Flutter
    │   ├── ephemeral
    │   │   ├── flutter_lldb_helper.py
    │   │   └── flutter_lldbinit
    │   ├── AppFrameworkInfo.plist
    │   ├── Debug.xcconfig
    │   ├── flutter_export_environment.sh
    │   ├── Generated.xcconfig
    │   └── Release.xcconfig
    ├── Runner
    │   ├── Assets.xcassets
    │   │   ├── AppIcon.appiconset
    │   │   │   ├── Contents.json
    │   │   │   ├── Icon-App-1024x1024@1x.png
    │   │   │   ├── Icon-App-20x20@1x.png
    │   │   │   ├── Icon-App-20x20@2x.png
    │   │   │   ├── Icon-App-20x20@3x.png
    │   │   │   ├── Icon-App-29x29@1x.png
    │   │   │   ├── Icon-App-29x29@2x.png
    │   │   │   ├── Icon-App-29x29@3x.png
    │   │   │   ├── Icon-App-40x40@1x.png
    │   │   │   ├── Icon-App-40x40@2x.png
    │   │   │   ├── Icon-App-40x40@3x.png
    │   │   │   ├── Icon-App-60x60@2x.png
    │   │   │   ├── Icon-App-60x60@3x.png
    │   │   │   ├── Icon-App-76x76@1x.png
    │   │   │   ├── Icon-App-76x76@2x.png
    │   │   │   └── Icon-App-83.5x83.5@2x.png
    │   │   └── LaunchImage.imageset
    │   │   │   ├── Contents.json
    │   │   │   ├── LaunchImage.png
    │   │   │   ├── LaunchImage@2x.png
    │   │   │   ├── LaunchImage@3x.png
    │   │   │   └── README.md
    │   ├── Base.lproj
    │   │   ├── LaunchScreen.storyboard
    │   │   └── Main.storyboard
    │   ├── AppDelegate.swift
    │   ├── GeneratedPluginRegistrant.h
    │   ├── GeneratedPluginRegistrant.m
    │   ├── Info.plist
    │   └── Runner-Bridging-Header.h
    ├── Runner.xcodeproj
    │   ├── project.xcworkspace
    │   │   ├── xcshareddata
    │   │   │   ├── IDEWorkspaceChecks.plist
    │   │   │   └── WorkspaceSettings.xcsettings
    │   │   └── contents.xcworkspacedata
    │   ├── xcshareddata
    │   │   └── xcschemes
    │   │   │   └── Runner.xcscheme
    │   └── project.pbxproj
    ├── Runner.xcworkspace
    │   ├── xcshareddata
    │   │   ├── IDEWorkspaceChecks.plist
    │   │   └── WorkspaceSettings.xcsettings
    │   └── contents.xcworkspacedata
    └── RunnerTests
    │   └── RunnerTests.swift
├── lib
    ├── core
    │   ├── constants
    │   │   ├── api_constants.dart
    │   │   └── app_strings.dart
    │   ├── network
    │   │   └── dio_client.dart
    │   ├── theme
    │   └── utils
    ├── data
    │   ├── models
    │   ├── repositories
    │   └── sources
    │   │   ├── local
    │   │   └── remote
    ├── domain
    │   ├── entities
    │   ├── repositories
    │   └── usecases
    ├── presentation
    │   ├── blocs
    │   ├── screens
    │   │   ├── auth
    │   │   ├── home
    │   │   ├── payment
    │   │   └── printer
    │   └── widgets
    ├── services
    │   └── printer_service
    │   │   ├── printer_manager.dart
    │   │   └── receipt_builder.dart
    └── main.dart
├── linux
    ├── flutter
    │   ├── ephemeral
    │   ├── CMakeLists.txt
    │   ├── generated_plugin_registrant.cc
    │   ├── generated_plugin_registrant.h
    │   └── generated_plugins.cmake
    ├── runner
    │   ├── CMakeLists.txt
    │   ├── main.cc
    │   ├── my_application.cc
    │   └── my_application.h
    └── CMakeLists.txt
├── macos
    ├── Flutter
    │   ├── ephemeral
    │   │   ├── flutter_export_environment.sh
    │   │   └── Flutter-Generated.xcconfig
    │   ├── Flutter-Debug.xcconfig
    │   ├── Flutter-Release.xcconfig
    │   └── GeneratedPluginRegistrant.swift
    ├── Runner
    │   ├── Assets.xcassets
    │   │   └── AppIcon.appiconset
    │   │   │   ├── app_icon_1024.png
    │   │   │   ├── app_icon_128.png
    │   │   │   ├── app_icon_16.png
    │   │   │   ├── app_icon_256.png
    │   │   │   ├── app_icon_32.png
    │   │   │   ├── app_icon_512.png
    │   │   │   ├── app_icon_64.png
    │   │   │   └── Contents.json
    │   ├── Base.lproj
    │   │   └── MainMenu.xib
    │   ├── Configs
    │   │   ├── AppInfo.xcconfig
    │   │   ├── Debug.xcconfig
    │   │   ├── Release.xcconfig
    │   │   └── Warnings.xcconfig
    │   ├── AppDelegate.swift
    │   ├── DebugProfile.entitlements
    │   ├── Info.plist
    │   ├── MainFlutterWindow.swift
    │   └── Release.entitlements
    ├── Runner.xcodeproj
    │   ├── project.xcworkspace
    │   │   └── xcshareddata
    │   │   │   └── IDEWorkspaceChecks.plist
    │   ├── xcshareddata
    │   │   └── xcschemes
    │   │   │   └── Runner.xcscheme
    │   └── project.pbxproj
    ├── Runner.xcworkspace
    │   ├── xcshareddata
    │   │   └── IDEWorkspaceChecks.plist
    │   └── contents.xcworkspacedata
    └── RunnerTests
    │   └── RunnerTests.swift
├── test
    └── widget_test.dart
├── web
    ├── icons
    │   ├── Icon-192.png
    │   ├── Icon-512.png
    │   ├── Icon-maskable-192.png
    │   └── Icon-maskable-512.png
    ├── favicon.png
    ├── index.html
    └── manifest.json
├── windows
    ├── flutter
    │   ├── ephemeral
    │   ├── CMakeLists.txt
    │   ├── generated_plugin_registrant.cc
    │   ├── generated_plugin_registrant.h
    │   └── generated_plugins.cmake
    ├── runner
    │   ├── resources
    │   │   └── app_icon.ico
    │   ├── CMakeLists.txt
    │   ├── flutter_window.cpp
    │   ├── flutter_window.h
    │   ├── main.cpp
    │   ├── resource.h
    │   ├── runner.exe.manifest
    │   ├── Runner.rc
    │   ├── utils.cpp
    │   ├── utils.h
    │   ├── win32_window.cpp
    │   └── win32_window.h
    └── CMakeLists.txt
├── analysis_options.yaml
├── erevenue.iml
├── pubspec.lock
├── pubspec.yaml
└── README.md
```
