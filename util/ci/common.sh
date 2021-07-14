#!/bin/bash -e

# Linux build only
install_linux_deps() {
	local pkgs=(cmake libpng-dev \
		libjpeg-dev libxxf86vm-dev libgl1-mesa-dev libsqlite3-dev \
		libhiredis-dev libogg-dev libgmp-dev libvorbis-dev libopenal-dev \
		gettext libpq-dev libleveldb-dev libcurl4-openssl-dev)

	if [[ "$1" == "--old-irr" ]]; then
		shift
		pkgs+=(libirrlicht-dev)
	else
		wget "https://github.com/minetest/irrlicht/releases/download/1.9.0mt2/ubuntu-bionic.tar.gz"
		sudo tar -xaf ubuntu-bionic.tar.gz -C /usr/local
	fi

	sudo apt-get update
	sudo apt-get install -y --no-install-recommends ${pkgs[@]} "$@"

	# workaround for bug with Github Actions' ubuntu-18.04 image
	sudo apt-get remove -y libgcc-11-dev gcc-11 || :
}

# macOS build only
install_macos_deps() {
	local pkgs=(freetype gettext hiredis jpeg leveldb libogg libvorbis luajit)

	if [[ "$1" == "--old-irr" ]]; then
		shift
		pkgs+=(irrlicht)
	else
		wget "https://github.com/FnControlOption/irrlicht/releases/download/1.9.0mt3-macos/macos-catalina.tar.gz"
		# mkdir _irrlicht
		# gtar -xaf macos-catalina.tar.gz -C _irrlicht
		# mv _irrlicht/include/* /usr/local/include
		# mv _irrlicht/lib/*.dylib /usr/local/lib
		# mv _irrlicht/lib/cmake/* /usr/local/lib/cmake
		gtar -xaf macos-catalina.tar.gz -C /usr/local --no-same-permissions
		echo "IrrlichtMt successfully installed"
	fi

	brew update
	brew install ${pkgs[@]} "$@"
}
