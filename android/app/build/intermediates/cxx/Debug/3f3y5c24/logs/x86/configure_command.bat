@echo off
"C:\\Users\\ArturoMtz\\AppData\\Local\\Android\\sdk\\cmake\\3.22.1\\bin\\cmake.exe" ^
  "-HC:\\Flutter\\flutter\\packages\\flutter_tools\\gradle\\src\\main\\groovy" ^
  "-DCMAKE_SYSTEM_NAME=Android" ^
  "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON" ^
  "-DCMAKE_SYSTEM_VERSION=21" ^
  "-DANDROID_PLATFORM=android-21" ^
  "-DANDROID_ABI=x86" ^
  "-DCMAKE_ANDROID_ARCH_ABI=x86" ^
  "-DANDROID_NDK=C:\\Users\\ArturoMtz\\AppData\\Local\\Android\\sdk\\ndk\\29.0.13113456" ^
  "-DCMAKE_ANDROID_NDK=C:\\Users\\ArturoMtz\\AppData\\Local\\Android\\sdk\\ndk\\29.0.13113456" ^
  "-DCMAKE_TOOLCHAIN_FILE=C:\\Users\\ArturoMtz\\AppData\\Local\\Android\\sdk\\ndk\\29.0.13113456\\build\\cmake\\android.toolchain.cmake" ^
  "-DCMAKE_MAKE_PROGRAM=C:\\Users\\ArturoMtz\\AppData\\Local\\Android\\sdk\\cmake\\3.22.1\\bin\\ninja.exe" ^
  "-DCMAKE_LIBRARY_OUTPUT_DIRECTORY=C:\\Users\\ArturoMtz\\StudioProjects\\miauui\\android\\app\\build\\intermediates\\cxx\\Debug\\3f3y5c24\\obj\\x86" ^
  "-DCMAKE_RUNTIME_OUTPUT_DIRECTORY=C:\\Users\\ArturoMtz\\StudioProjects\\miauui\\android\\app\\build\\intermediates\\cxx\\Debug\\3f3y5c24\\obj\\x86" ^
  "-DCMAKE_BUILD_TYPE=Debug" ^
  "-BC:\\Users\\ArturoMtz\\StudioProjects\\miauui\\android\\app\\.cxx\\Debug\\3f3y5c24\\x86" ^
  -GNinja ^
  -Wno-dev ^
  --no-warn-unused-cli
