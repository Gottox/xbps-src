# Cross build profile for ARMv7 GNU EABI Hard Float.

XBPS_TARGET_ARCH="armv7l"
XBPS_CROSS_TRIPLET="arm-linux-gnueabihf"
XBPS_CFLAGS="-O2 -pipe"
XBPS_CXXFLAGS="$XBPS_CFLAGS"
XBPS_CROSS_CFLAGS="-march=armv7 -mfpu=vfpv3 -mfloat-abi=hard"
XBPS_CROSS_CXXFLAGS="$XBPS_CROSS_CFLAGS"
