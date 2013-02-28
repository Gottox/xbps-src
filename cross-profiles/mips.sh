# Cross build profile for MIPS BE soft float.

XBPS_TARGET_ARCH="mips"
XBPS_CROSS_TRIPLET="mips-softfloat-linux-gnu"
XBPS_CFLAGS="-O2 -pipe"
XBPS_CXXFLAGS="$XBPS_CFLAGS"
XBPS_CROSS_CFLAGS="-mtune=mips32r2 -mabi=32 -msoft-float"
XBPS_CROSS_CXXFLAGS="$XBPS_CROSS_CFLAGS"
