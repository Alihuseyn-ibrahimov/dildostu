@echo off
REM DilDostu debug APK build (v5 - SDK paylasilan home qovluguna kocuruldu).

set "JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot"
set "ANDROID_HOME=C:\Users\Alihuseyn Ibrahimov\android-sdk"
set "ANDROID_SDK_ROOT=C:\Users\Alihuseyn Ibrahimov\android-sdk"
set "PATH=C:\Users\Alihuseyn Ibrahimov\flutter\bin;%JAVA_HOME%\bin;%PATH%"

cd /d "%~dp0android"

echo === Kohne Gradle daemon-lari dayandirilir ===
call gradlew.bat --stop

echo.
echo === Gradle assembleDebug (5-10 deqiqe cheke biler) ===
call gradlew.bat assembleDebug --no-daemon
if errorlevel 1 (
    echo.
    echo XETA: gradle build ugursuz oldu. Bu pencereni acik saxlayin ve Claude-a ekran sheklini gonderin.
    pause
    exit /b 1
)

echo.
echo === UGURLU! APK: ===
set "APK1=%~dp0build\app\outputs\flutter-apk\app-debug.apk"
if exist "%APK1%" echo %APK1%
echo.
echo Bitdi. Bu pencereni baglaya bilersiniz - Claude APK-ni telefona quracaq.
pause
