#!/bin/sh

set -eu

PACKAGE=ppsspp
DESKTOP=ppsspp-sdl.desktop
ICON=ppsspp.png

export ARCH="$(uname -m)"
export APPIMAGE_EXTRACT_AND_RUN=1
export VERSION=$(pacman -Q "$PACKAGE" | awk 'NR==1 {print $2; exit}')
echo "$VERSION" > ~/version

UPINFO="gh-releases-zsync|$(echo "$GITHUB_REPOSITORY" | tr '/' '|')|latest|*$ARCH.AppImage.zsync"
LIB4BN="https://raw.githubusercontent.com/VHSgunzo/sharun/refs/heads/main/lib4bin"
URUNTIME=$(wget -q https://api.github.com/repos/VHSgunzo/uruntime/releases -O - \
	| sed 's/[()",{} ]/\n/g' | grep -oi "https.*appimage.*dwarfs.*$ARCH$" | head -1)

# Prepare AppDir
mkdir -p ./"$PACKAGE"/AppDir/shared/lib \
	./"$PACKAGE"/AppDir/usr/share/applications \
	./"$PACKAGE"/AppDir/etc \
	./"$PACKAGE"/AppDir/bin
cd ./"$PACKAGE"/AppDir

cp -v /usr/share/applications/$DESKTOP              ./usr/share/applications
cp -v /usr/share/applications/$DESKTOP              ./
cp -v /usr/share/icons/hicolor/128x128/apps/"$ICON" ./

cp -rv /usr/share/ppsspp  ./usr/share
cp -rv /usr/share/glvnd   ./usr/share
cp -rv /usr/share/vulkan  ./usr/share
cp -rv /usr/share/X11     ./usr/share
sed -i 's|/usr/lib/||g'   ./usr/share/vulkan/icd.d/*

rm -rf ./usr/share/vulkan/registry || true

ln -s ../usr/share/ppsspp/assets ./bin
ln -s ./usr/share ./
ln -s ./"$ICON"   ./.DirIcon

# ADD LIBRARIES
wget "$LIB4BN" -O ./lib4bin
chmod +x ./lib4bin
xvfb-run -d -- ./lib4bin -p -v -r -e -s /usr/bin/PPSSPPSDL /usr/bin/PPSSPPHeadless

# Prepare sharun
echo "Preparing sharun..."
ln -s ./bin/PPSSPPSDL ./AppRun
./sharun -g

# MAKE APPIMAGE WITH URUNTIME
cd ..
wget -q "$URUNTIME" -O ./uruntime
chmod +x ./uruntime

#Add udpate info to runtime
echo "Adding update information \"$UPINFO\" to runtime..."
printf "$UPINFO" > data.upd_info
llvm-objcopy --update-section=.upd_info=data.upd_info \
	--set-section-flags=.upd_info=noload,readonly ./uruntime
printf 'AI\x02' | dd of=./uruntime bs=1 count=3 seek=8 conv=notrunc

echo "Generating AppImage..."
./uruntime --appimage-mkdwarfs -f \
	--set-owner 0 --set-group 0 \
	--no-history --no-create-timestamp \
	--compression zstd:level=22 -S22 -B16 \
	--header uruntime \
	-i ./AppDir -o "$PACKAGE"-"$VERSION"-anylinux-"$ARCH".AppImage

echo "Generating zsync file..."
zsyncmake *.AppImage -u *.AppImage

mv ./*.AppImage* ../
cd ..
rm -rf ./"$PACKAGE"
echo "All Done!"
