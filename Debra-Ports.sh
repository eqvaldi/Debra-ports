#!/bin/sh

if [ "$(id -u)" = "0" ]; then
    echo "ERROR: Do not run Debra-Ports as root." >&2
    exit 1
fi

mkdir ./.TEMP
mkdir ./Bin
cd ./Bin
mkdir ./Dhewm3
mkdir ./Eduke32
mkdir ./NBlood
mkdir ./QuakeSpasm
mkdir ./luanti
mkdir ./Ioq3
mkdir ./taradino
mkdir ./YamagiQ2
mkdir ./YamagiQ2Git
mkdir ./YamagiQ2R
mkdir ./iortcw
mkdir ./Wolf3D
mkdir ./DSDA
mkdir ./UZDoom
mkdir ./VoidSW
mkdir ./Ken-Build
cd ..
cd ./.TEMP



cmd=(dialog --keep-tite --menu "Select a Port:" 22 76 16)

options=(1 "Dhewm3"
         2 "Eduke32"
         3 "NBlood (Blood)"
         4 "Darkplaces (quake 1)"
         5 "QuakeSpasm (quake 1,Librequake)"
         6 "luanti (Minetest)"
         7 "Ioq3 (Quake3)"
         8 "taradino (Rise of the triad)"
         9 "Yamagi Quake II"
         10 "Yamagi Quake II (Git)"
         11 "Yamagi Quake II (Remaster)"
         12 "iortcw (Return to Castle Wolfenstein)"
	 13 "Wolf3D (Wolfenstein 3D)"
	 14 "DSDA-Doom (Doom,Heretic,Hexen)"
	 15 "UZDoom (Doom,Heretic,Hexen)"
	 16 "VoidSW (Shadow Warrior classic redux)"
	 17 "EKen-Build (Ken Silverman's Build Engine Demo)"
	 18 "Exit")

choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)

for choice in $choices
do
    case $choice in
        1)
          git clone https://github.com/dhewm/dhewm3.git
	  cd dhewm3/
	  wget https://github.com/dhewm/dhewm3/releases/download/1.5.5/dhewm3-mods-1.5.5_Linux_amd64.tar.gz
	  tar -xvf ./dhewm3-mods-1.5.5_Linux_amd64.tar.gz
	  cmake ./neo/
	  make -j$(nproc)
	  cd ..
	  cd ..
	  cp ./.TEMP/dhewm3/dhewm3-mods/*.so ./Bin/Dhewm3
	  cp ./.TEMP/dhewm3/dhewm3 ./Bin/Dhewm3
	  cp ./.TEMP/dhewm3/base.so ./Bin/Dhewm3
	  cp ./.TEMP/dhewm3/d3xp.so ./Bin/Dhewm3
          bash ./Debra-Ports.sh
            ;;
        2)
          git clone https://voidpoint.io/terminx/eduke32.git
	  cd eduke32/
	  make -j$(nproc) USE_OPENGL=0 POLYMER=0 USE_LIBVPX=0 OPTLEVEL=2 WITHOUT_GTK=1
	  cd ..
	  cd ..
	  cp ./.TEMP/eduke32/eduke32 ./Bin/Eduke32
	  cp ./.TEMP/eduke32/mapster32 ./Bin/Eduke32
          bash ./Debra-Ports.sh
            ;;
        3)
          git clone https://github.com/NBlood/NBlood.git
          cd ./NBlood/
          make nblood -j$(nproc)
	  cd ..
	  cd ..
	  cp ./.TEMP/NBlood/nblood ./Bin/NBlood
	  cp ./.TEMP/NBlood/nblood.pk3 ./Bin/NBlood
          bash ./Debra-Ports.sh
            ;;
        4)
          git clone https://github.com/DarkPlacesEngine/darkplaces.git
	  cd darkplaces/
	  make -j$(nproc) sdl-release
	  cd ..
	  cd ..
 	  cp -r ./.TEMP/darkplaces/ ./Bin
          bash ./Debra-Ports.sh
            ;;
        5)
          git clone https://github.com/sezero/quakespasm.git
          cd quakespasm/Quake/
          make USE_SDL2=1
          cd ..
	  cd ..
	  cd ..
	  cp -r ./.TEMP/quakespasm/Quake/quakespasm ./Bin/QuakeSpasm
	  cp -r ./.TEMP/quakespasm/Quake/quakespasm.pak ./Bin/QuakeSpasm
	  bash ./Debra-Ports.sh
            ;;
        6)
          git clone --depth 1 https://github.com/luanti-org/luanti.git
	  cd luanti/
	  git clone --depth 1 https://github.com/minetest/minetest_game.git games/minetest_game
 	  git clone --depth 1 https://github.com/minetest/irrlicht.git lib/irrlichtmt
	  git clone https://codeberg.org/SumianVoice/backroomtest.git games/backroomtest
	  cmake . -DRUN_IN_PLACE=TRUE
	  make -j$(nproc)
	  cd ..
	  cd ..
          bash ./Debra-Ports.sh
            ;;
        7)
          git clone https://github.com/ioquake/ioq3.git
	  cd ioq3/
	  cmake ./
	  make -j$(nproc)
	  cd ..
	  cd ..
	  cp -r ./.TEMP/ioq3/Release/* ./Bin/Ioq3
          bash ./Debra-Ports.sh
            ;;
        8)
          git clone https://github.com/fabiangreffrath/taradino.git
	  cd taradino/
	  cmake ./
	  make -j$(nproc)
	  cd ..
	  cd ..
	  cp ./.TEMP/taradino/taradino ./Bin/taradino
          bash ./Debra-Ports.sh
            ;;
        9)
	  wget https://github.com/yquake2/yquake2/archive/refs/tags/QUAKE2_8_70.zip
   	  unzip *.zip
	  rm -rf ./*.zip
   	  cd yquake2-QUAKE2_8_70/
	  make -j$(nproc)
	  cd ..
	  cd ..
	  cp -r ./.TEMP/yquake2-QUAKE2_8_70/release/* ./Bin/YamagiQ2
          bash ./Debra-Ports.sh
            ;;
        10)
          git clone https://github.com/yquake2/yquake2.git
   	  cd yquake2
	  make -j$(nproc)
	  cd ..
	  cd ..
   	  cp -r ./.TEMP/yquake2/release/* ./Bin/YamagiQ2Git
          bash ./Debra-Ports.sh
            ;;
        11)
	  git clone https://github.com/yquake2/yquake2remaster.git
	  cd yquake2remaster/
	  cmake ./
	  make -j$(nproc)
	  cd ..
	  cd ..
   	  cp -r ./.TEMP/yquake2remaster/release/* ./Bin/YamagiQ2R
          bash ./Debra-Ports.sh
            ;;
        12)
          git clone https://github.com/iortcw/iortcw.git
	  cd iortcw/
   	  cd SP/
      	  make -j$(nproc)
      	  cd build/
      	  mv release-linux* SP
	  cd ..
	  cd ..
          cd MP/
	  make -j$(nproc)
	  cd build/
	  mv release-linux* MP
   	  cd ..
	  cd ..
	  cd ..
	  cd ..
	  cp -r ./.TEMP/iortcw/SP/build/* ./Bin/iortcw
	  cp -r ./.TEMP/iortcw/MP/build/* ./Bin/iortcw
          bash ./Debra-Ports.sh
            ;;
        13)
	  git clone https://github.com/ECWolfEngine/ECWolf.git
	  cd ECWolf/
	  cmake ./
	  make  -j$(nproc)
	  cd ..
	  cd ..
	  cp ./.TEMP/ECWolf/ecwolf ./Bin/Wolf3D
	  cp ./.TEMP/ECWolf/ecwolf.pk3 ./Bin/Wolf3D
          bash ./Debra-Ports.sh
            ;;
        14)
	  git clone https://github.com/kraflab/dsda-doom.git
	  cd ./dsda-doom/
          cd ./prboom2/
	  cmake ./
	  make -j$(nproc)
	  cd ..
	  cd ..
    	  cd ..
    	  cp ./.TEMP/dsda-doom/prboom2/dsda-doom ./Bin/DSDA
    	  cp ./.TEMP/dsda-doom/prboom2/dsda-doom.wad ./Bin/DSDA
          bash ./Debra-Ports.sh
            ;;
        15)
          git clone https://github.com/UZDoom/UZDoom.git
	  mkdir -p UZDoom/build
	  cd UZDoom/build
	  cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -G Ninja                             ..
	  cmake --build .
	  cd ..
	  cd ..
    	  cd ..
    	  cp ./.TEMP/UZDoom/build/uzdoom ./Bin/UZDoom
    	  cp ./.TEMP/UZDoom/build/uzdoom.pk3 ./Bin/UZDoom
    	  cp ./.TEMP/UZDoom/build/brightmaps.pk3 ./Bin/UZDoom
    	  cp ./.TEMP/UZDoom/build/lights.pk3 ./Bin/UZDoom
    	  cp ./.TEMP/UZDoom/build/game_widescreen_gfx.pk3 ./Bin/UZDoom
    	  cp ./.TEMP/UZDoom/build/game_support.pk3 ./Bin/UZDoom
    	  cp -r ./.TEMP/UZDoom/build/soundfonts ./Bin/UZDoom
    	  bash ./Debra-Ports.sh
            ;;     
        16)
          git clone https://voidpoint.io/terminx/eduke32.git
	  cd eduke32/
	  make voidsw -j$(nproc) USE_OPENGL=0 POLYMER=0 USE_LIBVPX=0 OPTLEVEL=2 WITHOUT_GTK=1
	  cd ..
	  cd ..
	  cp ./.TEMP/eduke32/voidsw ./Bin/VoidSW
          bash ./Debra-Ports.sh
            ;;
        17)
          git clone https://voidpoint.io/terminx/eduke32.git
	  cd eduke32/
	  make ekenbuild -j$(nproc) USE_OPENGL=0 POLYMER=0 USE_LIBVPX=0 OPTLEVEL=2 WITHOUT_GTK=1
	  cd ..
	  cd ..
	  cp ./.TEMP/eduke32/ekenbuild ./Bin/Ken-Build
          bash ./Debra-Ports.sh
            ;;
        18)
          exit
            ;;

    esac
done
