#!/bin/bash
set -e

CORE_GIT=https://github.com/minetest/minetest
CORE_BRANCH=master
CORE_NAME=minetest
GAME_GIT=https://github.com/minetest/minetest_game
GAME_BRANCH=master
GAME_NAME=minetest_game

dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ $# -ne 1 ]; then
	echo "Usage: $0 <build directory>"
	exit 1
fi
builddir=$1
mkdir -p $builddir
builddir="$( cd "$builddir" && pwd )"
libdir=$builddir/libs

# Test which win64 compiler is present
which x86_64-w64-mingw32-gcc &>/dev/null &&
	toolchain_file=$dir/toolchain_x86_64-w64-mingw32.cmake
which x86_64-w64-mingw32-gcc-posix &>/dev/null &&
	toolchain_file=$dir/toolchain_x86_64-w64-mingw32-posix.cmake

if [ -z "$toolchain_file" ]; then
	echo "Unable to determine which mingw32 compiler to use"
	exit 1
fi
echo "Using $toolchain_file"

irrlicht_version=1.9.0mt2
ogg_version=1.3.4
vorbis_version=1.3.7
curl_version=7.76.1
gettext_version=0.20.1
freetype_version=2.10.4
sqlite3_version=3.35.5
luajit_version=2.1.0-beta3
leveldb_version=1.23
zlib_version=1.2.11

mkdir -p $libdir

download () {
	local url=$1
	local filename=$2
	[ -z "$filename" ] && filename=${url##*/}
	local foldername=${filename%%[.-]*}
	local extract=$3
	[ -z "$extract" ] && extract=unzip

	[ -d "./$foldername" ] && return 0
	wget "$url" -c -O "./$filename"
	if [ "$extract" = "unzip" ]; then
		unzip -o "$filename" -d "$foldername"
	elif [ "$extract" = "unzip_nofolder" ]; then
		unzip -o "$filename"
	else
		return 1
	fi
}

# Get stuff
cd $libdir
download "https://github.com/minetest/irrlicht/releases/download/$irrlicht_version/win64.zip" irrlicht-$irrlicht_version.zip
download "http://minetest.kitsunemimi.pw/zlib-$zlib_version-win64.zip"
download "http://minetest.kitsunemimi.pw/libogg-$ogg_version-win64.zip"
download "http://minetest.kitsunemimi.pw/libvorbis-$vorbis_version-win64.zip"
download "http://minetest.kitsunemimi.pw/curl-$curl_version-win64.zip"
download "http://minetest.kitsunemimi.pw/gettext-$gettext_version-win64.zip"
download "http://minetest.kitsunemimi.pw/freetype2-$freetype_version-win64.zip" freetype-$freetype_version.zip
download "http://minetest.kitsunemimi.pw/sqlite3-$sqlite3_version-win64.zip"
download "http://minetest.kitsunemimi.pw/luajit-$luajit_version-win64.zip"
download "http://minetest.kitsunemimi.pw/libleveldb-$leveldb_version-win64.zip" leveldb-$leveldb_version.zip
download "http://minetest.kitsunemimi.pw/openal_stripped64.zip" 'openal_stripped.zip' unzip_nofolder

# Set source dir, downloading Minetest as needed
if [ -n "$EXISTING_MINETEST_DIR" ]; then
	sourcedir="$( cd "$EXISTING_MINETEST_DIR" && pwd )"
else
	sourcedir=$PWD/$CORE_NAME
	[ -d $CORE_NAME ] && { pushd $CORE_NAME; git pull; popd; } || \
		git clone -b $CORE_BRANCH $CORE_GIT $CORE_NAME
	if [ -z "$NO_MINETEST_GAME" ]; then
		[ -d games/$GAME_NAME ] && { pushd games/$GAME_NAME; git pull; popd; } || \
			git clone -b $GAME_BRANCH $GAME_GIT games/$GAME_NAME
	fi
fi

git_hash=$(cd $sourcedir && git rev-parse --short HEAD)

# Build the thing
cd $builddir
[ -d build ] && rm -rf build
mkdir build
cd build

irr_dlls=$(echo $libdir/irrlicht/lib/*.dll | tr ' ' ';')
vorbis_dlls=$(echo $libdir/libvorbis/bin/libvorbis{,file}-*.dll | tr ' ' ';')
gettext_dlls=$(echo $libdir/gettext/bin/lib{intl,iconv}-*.dll | tr ' ' ';')

cmake -S $sourcedir -B . \
	-DCMAKE_TOOLCHAIN_FILE=$toolchain_file \
	-DCMAKE_INSTALL_PREFIX=/tmp \
	-DVERSION_EXTRA=$git_hash \
	-DBUILD_CLIENT=1 -DBUILD_SERVER=0 \
	\
	-DENABLE_SOUND=1 \
	-DENABLE_CURL=1 \
	-DENABLE_GETTEXT=1 \
	-DENABLE_FREETYPE=1 \
	-DENABLE_LEVELDB=1 \
	\
	-DCMAKE_PREFIX_PATH=$libdir/irrlicht \
	-DIRRLICHT_DLL="$irr_dlls" \
	\
	-DZLIB_INCLUDE_DIR=$libdir/zlib/include \
	-DZLIB_LIBRARIES=$libdir/zlib/lib/libz.dll.a \
	-DZLIB_DLL=$libdir/zlib/bin/zlib1.dll \
	\
	-DLUA_INCLUDE_DIR=$libdir/luajit/include \
	-DLUA_LIBRARY=$libdir/luajit/libluajit.a \
	\
	-DOGG_INCLUDE_DIR=$libdir/libogg/include \
	-DOGG_LIBRARY=$libdir/libogg/lib/libogg.dll.a \
	-DOGG_DLL=$libdir/libogg/bin/libogg-0.dll \
	\
	-DVORBIS_INCLUDE_DIR=$libdir/libvorbis/include \
	-DVORBIS_LIBRARY=$libdir/libvorbis/lib/libvorbis.dll.a \
	-DVORBIS_DLL="$vorbis_dlls" \
	-DVORBISFILE_LIBRARY=$libdir/libvorbis/lib/libvorbisfile.dll.a \
	\
	-DOPENAL_INCLUDE_DIR=$libdir/openal_stripped/include/AL \
	-DOPENAL_LIBRARY=$libdir/openal_stripped/lib/libOpenAL32.dll.a \
	-DOPENAL_DLL=$libdir/openal_stripped/bin/OpenAL32.dll \
	\
	-DCURL_DLL=$libdir/curl/bin/libcurl-4.dll \
	-DCURL_INCLUDE_DIR=$libdir/curl/include \
	-DCURL_LIBRARY=$libdir/curl/lib/libcurl.dll.a \
	\
	-DGETTEXT_MSGFMT=`which msgfmt` \
	-DGETTEXT_DLL="$gettext_dlls" \
	-DGETTEXT_INCLUDE_DIR=$libdir/gettext/include \
	-DGETTEXT_LIBRARY=$libdir/gettext/lib/libintl.dll.a \
	\
	-DFREETYPE_INCLUDE_DIR_freetype2=$libdir/freetype/include/freetype2 \
	-DFREETYPE_INCLUDE_DIR_ft2build=$libdir/freetype/include/freetype2 \
	-DFREETYPE_LIBRARY=$libdir/freetype/lib/libfreetype.dll.a \
	-DFREETYPE_DLL=$libdir/freetype/bin/libfreetype-6.dll \
	\
	-DSQLITE3_INCLUDE_DIR=$libdir/sqlite3/include \
	-DSQLITE3_LIBRARY=$libdir/sqlite3/lib/libsqlite3.dll.a \
	-DSQLITE3_DLL=$libdir/sqlite3/bin/libsqlite3-0.dll \
	\
	-DLEVELDB_INCLUDE_DIR=$libdir/leveldb/include \
	-DLEVELDB_LIBRARY=$libdir/leveldb/lib/libleveldb.dll.a \
	-DLEVELDB_DLL=$libdir/leveldb/bin/libleveldb.dll

make -j$(nproc)

[ -z "$NO_PACKAGE" ] && make package

exit 0
# EOF
