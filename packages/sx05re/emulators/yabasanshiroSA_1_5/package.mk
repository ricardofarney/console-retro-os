PKG_NAME="yabasanshiroSA_1_5"
PKG_VERSION="f6f41dd6485c638ab661f3acd2951c9522f34450"
PKG_ARCH="any"
PKG_LICENSE="GPLv2"
PKG_SITE="https://github.com/ticohq/tico-yabasanshiro"
# Arcadia: a branch pi4 foi apagada e a main divergiu deste commit; o codigo vem como
# arquivo do commit (hash fixo) e o submodulo ext/eigen vem do pacote eigen-yabasanshiro.
PKG_SHA256="df5d90c46d7a2052ecf5d45bcd7163052b1e2277135129c69ed7915d0705b9ff"
PKG_URL="${PKG_SITE}/archive/${PKG_VERSION}.tar.gz"
PKG_SOURCE_DIR="tico-yabasanshiro-${PKG_VERSION}"
PKG_DEPENDS_UNPACK="eigen-yabasanshiro"
PKG_DEPENDS_TARGET="toolchain SDL2 boost openal-soft ${OPENGLES} zlib"
PKG_LONGDESC="Yabause is a Sega Saturn emulator and took over as Yaba Sanshiro"
PKG_TOOLCHAIN="cmake-make"
#PKG_BUILD_FLAGS="+speed"

post_unpack() {
  # submodulo ext/eigen (antes vinha pelo git clone)
  mkdir -p ${PKG_BUILD}/yabause/src/retro_arena/nanogui-sdl/ext/eigen
  cp -r $(get_build_dir eigen-yabasanshiro)/* ${PKG_BUILD}/yabause/src/retro_arena/nanogui-sdl/ext/eigen/

  # use host versions
  sed -i "s|COMMAND m68kmake|COMMAND ${PKG_BUILD}/m68kmake_host|" ${PKG_BUILD}/yabause/src/musashi/CMakeLists.txt
  sed -i "s|COMMAND ./bin2c|COMMAND ${PKG_BUILD}/bin2c_host|" ${PKG_BUILD}/yabause/src/retro_arena/nanogui-sdl/CMakeLists.txt
}

pre_make_target() {
  # runs on host so make them manually if  package is not crosscompile friendly
  $HOST_CC ${PKG_BUILD}/yabause/src/retro_arena/nanogui-sdl/resources/bin2c.c -o ${PKG_BUILD}/bin2c_host
  $HOST_CC ${PKG_BUILD}/yabause/src/musashi/m68kmake.c -o ${PKG_BUILD}/m68kmake_host
}

pre_configure_target() {
PKG_CMAKE_OPTS_TARGET="${PKG_BUILD}/yabause \
                         -DYAB_PORTS=retro_arena \
                         -DYAB_WANT_DYNAREC_DEVMIYAX=ON \
                         -DYAB_WANT_ARM7=OFF \
                         -DCMAKE_TOOLCHAIN_FILE=${PKG_BUILD}/yabause/src/retro_arena/n2.cmake \
                         -DYAB_WANT_VULKAN=OFF \
                         -DOPENGL_INCLUDE_DIR=${SYSROOT_PREFIX}/usr/include \
                         -DOPENGL_opengl_LIBRARY=${SYSROOT_PREFIX}/usr/lib \
                         -DOPENGL_glx_LIBRARY=${SYSROOT_PREFIX}/usr/lib \
                         -DLIBPNG_LIB_DIR=${SYSROOT_PREFIX}/usr/lib \
                         -Dpng_STATIC_LIBRARIES=${SYSROOT_PREFIX}/usr/lib/libpng16.a \
			                   -DCMAKE_BUILD_TYPE=Release"
                         
if [[ ${DEVICE} == "OdroidGoAdvance" || ${DEVICE} == "GameForce" ]]; then
	PKG_CMAKE_OPTS_TARGET+=" -DCMAKE_BUILD_TYPE=Release"
fi

}

makeinstall_target() {
mkdir -p ${INSTALL}/usr/bin
cp -a ${PKG_BUILD}/src/retro_arena/yabasanshiro ${INSTALL}/usr/bin/yabasanshiro1_5
cp -a ${PKG_DIR}/scripts/* ${INSTALL}/usr/bin

mkdir -p ${INSTALL}/usr/config/emuelec/configs/yabasanshiro1_5
cp ${PKG_DIR}/config/* ${INSTALL}/usr/config/emuelec/configs/yabasanshiro1_5
} 
