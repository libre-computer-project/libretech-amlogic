#!/bin/bash

set -ex

AML_BOARD=g12b_w400_v1
LC_BOARD=aml-a311d-cc
NEED_DDR_FILES=1
LC_BR_BRANCH=suspend-resume/aml-a311d-cc

if ! which aarch64-elf-gcc; then
	if [ ! -f gcc-linaro-7.5.0-2019.12-x86_64_aarch64-elf.tar.xz ]; then
		wget https://releases.linaro.org/components/toolchain/binaries/latest-7/aarch64-elf/gcc-linaro-7.5.0-2019.12-x86_64_aarch64-elf.tar.xz
	fi
	if [ ! -d gcc-linaro-7.5.0-2019.12-x86_64_aarch64-elf ]; then
		tar -xf gcc-linaro-7.5.0-2019.12-x86_64_aarch64-elf.tar.xz
	fi
	export PATH=$PWD/gcc-linaro-7.5.0-2019.12-x86_64_aarch64-elf/bin:$PATH
fi

if ! which arm-none-eabi-gcc; then
	if [ ! -f gcc-arm-none-eabi-7-2018-q2-update-linux.tar.bz2 ]; then
		wget --content-disposition https://developer.arm.com/-/media/Files/downloads/gnu-rm/7-2018q2/gcc-arm-none-eabi-7-2018-q2-update-linux.tar.bz2?revision=bc2c96c0-14b5-4bb4-9f18-bceb4050fee7?product=GNU%20Arm%20Embedded%20Toolchain,64-bit,,Linux,7-2018-q2-update
	fi
	if [ ! -d gcc-arm-none-eabi-7-2018-q2-update ]; then
		tar -xf gcc-arm-none-eabi-7-2018-q2-update-linux.tar.bz2
	fi
	export PATH=$PWD/gcc-arm-none-eabi-7-2018-q2-update/bin:$PATH
fi


LAB=libretech-amlogic-boot

if [ ! -d "$LAB" ]; then
	git clone --single-branch --branch boot-g12 --depth 1 https://github.com/libre-computer-project/$LAB.git
fi

# build bl2, bl30, bl31
cd $LAB
./mk $AML_BOARD
cd ..


LBS=libretech-builder-simple

if [ ! -d "$LBS" ]; then
	git clone --single-branch --branch master --depth 1 https://github.com/libre-computer-project/$LBS.git
	cd $LBS
	./setup.sh
	./build.sh $LC_BOARD
	cd ..
fi

LBS_AML=$LBS/vendor/amlogic
if [ ! -d "$LBS_AML" ]; then
	mkdir -p "$LBS_AML"
fi

LBS_AML_BLX=$LBS_AML/blx
if [ ! -d "$LBS_AML_BLX" ]; then
	git clone --single-branch --branch master --depth 1 https://github.com/libre-computer-project/libretech-amlogic-blx.git $LBS_AML_BLX
fi

SOC_ARCH=${AML_BOARD%%_*}

# copy newly built bl2, bl30, bl31
$LBS/vendor/amlogic/blx/copy.sh $LAB/fip/_tmp $LBS/vendor/amlogic/blx/$LC_BOARD

# copy ddr binaries
if [ "$NEED_DDR_FILES" -eq 1 ]; then
	DDR_FILES_PATH=$LBS/vendor/amlogic/blx/init/$SOC_ARCH
	for ddr_file in $(ls "$DDR_FILES_PATH"); do
		cp "$LAB/fip/$SOC_ARCH/$ddr_file" "$DDR_FILES_PATH/$ddr_file"
	done
fi

# copy aml_encrypt binary
cp $LAB/fip/$SOC_ARCH/aml_encrypt_$SOC_ARCH $LBS/vendor/amlogic/blx/aml_encrypt_$SOC_ARCH


# build upstream u-boot
cd $LBS
./build.sh $LC_BOARD
cd ..

LBR=libretech-buildroot

if [ ! -d "$LBR" ]; then
	git clone --single-branch --branch $LC_BR_BRANCH --depth 1 https://github.com/libre-computer-project/libretech-buildroot.git
fi

cp $LBS/out/$LC_BOARD $LBR/board/librecomputer/project/suspend-resume/$LC_BOARD

# build upstream linux and package as image
cd $LBR
LBR_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$LBR_BRANCH" != "$LC_BR_BRANCH" ]; then
	# check if branch exists
	if git rev-parse --verify $LC_BR_BRANCH; then
		git checkout $LC_BR_BRANCH
		git pull origin $LC_BR_BRANCH
	else
		git fetch origin $LC_BR_BRANCH
		git checkout FETCH_HEAD -b $LC_BR_BRANCH
	fi
fi

make -j `nproc --all`
cd ..
cp $LBR/output/images/sdcard.img .
