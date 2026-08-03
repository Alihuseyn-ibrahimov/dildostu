@echo off
REM DilDostu -- Google Play "flavor" debug APK build (V1 test ucun).
REM Ferqi: arxa fon mekan icazesi YOX, app-daxili yenilenme YOX (bax
REM android/app/src/play/AndroidManifest.xml + .planning/2026-08-03-dildostu-playstore).
REM Gundelik pilot build ucun build_apk.bat isledin, bu skript yalniz
REM Play-e cixmazdan evvel bu flavor-un duzgun islediyini yoxlamaq ucundur.

set "JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot"
set "ANDROID_HOME=C:\Users\Alihuseyn Ibrahimov\android-sdk"
set "ANDROID_SDK_ROOT=C:\Users\Alihuseyn Ibrahimov\android-sdk"
set "PATH=C:\Users\Alihuseyn Ibrahimov\flutter\bin;%JAVA_HOME%\bin;%PATH%"

cd /d "%~dp0android"

echo === Kohne Gradle daemon-lari dayandirilir ===
call gradlew.bat --stop

echo.
echo === Gradle assemblePlayDebug (5-10 deqiqe cheke biler) ===
call gradlew.bat assemblePlayDebug --no-daemon
if errorlevel 1 (
    echo.
    echo XETA: gradle build ugursuz oldu. Bu pencereni acik saxlayin ve Claude-a ekran sheklini gonderin.
    pause
    exit /b 1
)

echo.
echo === UGURLU! APK: ===
set "APK1=%~dp0build\app\outputs\flutter-apk\app-play-debug.apk"
if exist "%APK1%" echo %APK1%
echo.
echo Bu APK-da: oz-yenilenme YOX, arxa fon mekan bildirişi YOX.
echo "Rutin oyrenme" menyusu Profil-de gorunmemelidir -- yoxlayin.
pause
