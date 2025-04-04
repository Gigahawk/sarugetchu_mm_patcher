{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    poetry2nix.url = "github:nix-community/poetry2nix";
    ps2str.url = "github:Gigahawk/ps2str-nix";
    ssmm-mux.url = "github:Gigahawk/ssmm-mux";
    ps2isopatcher.url = "github:Gigahawk/ps2isopatcher";
    bgrep.url = "github:Gigahawk/bgrep-nix";
    # Waiting for merge of https://github.com/NixOS/nixpkgs/pull/339716
    nixpkgs-clps2c.url = "github:Gigahawk/nixpkgs?ref=clps2c-compiler";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    poetry2nix,
    ps2str,
    ssmm-mux,
    ps2isopatcher,
    bgrep,
    nixpkgs-clps2c,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs { inherit system; };
      pkgs-clps2c = import nixpkgs-clps2c { inherit system; };
      mm-jp-iso = (pkgs.requireFile {
        name = "mm.iso";
        url = "";
        sha256 = "0nbsaqdvczcygk4frfyiiy4y3w7v6qc9ig3jvbiy032a11f5aycb";
      });
      mm-cn-iso = (pkgs.requireFile {
        name = "mm_cn.iso";
        url = "";
        sha256 = "1gm322c4sfzy7k5w9zwrwzlx8wad9cqpjla9ldxx8w8iycz19hys";
      });
      cutscenes-demuxed-buildPhase = iso-extracted: ''
        find ${iso-extracted} -name '*.PSS' -type f | \
          xargs -P $NIX_BUILD_CORES -I {} bash -c '
            input="{}"
            output="''${input#${iso-extracted}/extracted/}"
            mkdir -p $(dirname "$output")
            ssmm-demux "$input" "$output"
          '
        wait
      '';
      cutscenes-mp4-buildPhase = cutscenes-demuxed: ''
        find ${cutscenes-demuxed} -name '*.m2v' -type f | \
          xargs -P $NIX_BUILD_CORES -I {} bash -c '
            m2v="{}"
            base_name="''${m2v%.m2v}"
            ss2="''${base_name}.ss2"
            output="''${base_name#${cutscenes-demuxed}/demuxed/}.mp4"
            mkdir -p $(dirname "$output")
            ffmpeg \
              -i "$m2v" \
              -i "$ss2" \
              -c:v copy -c:a aac \
              "$output"
        '
        wait
      '';
      data-unpacked-buildPhase = iso-extracted: ''
        ssmm-patcher unpack-data \
          ${iso-extracted}/extracted/PDATA/DATA0.BIN \
          ${iso-extracted}/extracted/PDATA/DATA1.BIN \
          -o PDATA/DATA1

        # All files in DATA1 are gzip files
        find PDATA/DATA1 -type f | \
          xargs -P $NIX_BUILD_CORES -I {} mv "{}" "{}.gz"
        wait

        ssmm-patcher unpack-data \
          ${iso-extracted}/extracted/PDATA/DATA2.BIN \
          ${iso-extracted}/extracted/PDATA/DATA3.BIN \
          -o PDATA/DATA3
      '';
      data-extracted-buildPhase = data-unpacked: ''
        mkdir -p DATA1
        # All files in DATA1 are gzip files
        find ${data-unpacked}/DATA1 -type f | \
          xargs -P $NIX_BUILD_CORES -I {} bash -c '
            input="{}"
            base_name="''${input#${data-unpacked}/DATA1/}"
            if [[ "$(dirname $base_name)" != "." ]]; then
              mkdir -p "DATA1/$(dirname $base_name)"
            fi
            output="''${base_name%.gz}"
            gzip -d -c "$input" > "DATA1/$output"
          '
        wait
      '';
      data-unpacked-named-installPhase = data-unpacked: ''
        find ${data-unpacked}/DATA1 -type f | \
          xargs -P $NIX_BUILD_CORES -I {} bash -c '
            input="{}"
            base_name=$(basename "$input")
            hash="''${base_name#*_}"
            hash="''${hash%.gz}"
            path=$(ssmm-patcher hash-to-path ${./data0_hashes.csv} $hash)
            if [[ $? -eq 0 ]]; then
              dir=$(dirname $path)
              mkdir -p "$out/DATA1/$dir"
              cp "$input" "$out/DATA1/$path"
            fi
          '
        wait
        find ${data-unpacked}/DATA3 -type f | \
          xargs -P $NIX_BUILD_CORES -I {} bash -c '
            input="{}"
            base_name=$(basename "$input")
            hash="''${base_name#*_}"
            hash="''${hash%.gz}"
            path=$(ssmm-patcher hash-to-path ${./data2_hashes.csv} $hash)
            if [[ $? -eq 0 ]]; then
              dir=$(dirname $path)
              mkdir -p "$out/DATA3/$dir"
              cp "$input" "$out/DATA3/$path"
            fi
          '
        wait
      '';
      version = "1";
      resourceFiles = [
        "043_b1fc2c81" # gz/game_common.gz
        "044_5c272d50" # gz/game_common.story.gz
        "045_3cecf223" # gz/game_common.vs.gz
        #"046_8205e9b5" # gz/game_common_sound_bd.gz
        "047_7243e526" # gz/game_result.story.gz
        "048_4abee95e" # gz/game_result.vs.gz
        #"066_c9448ba5" # gz/menu1.gz
        #"067_a60a8ca5" # gz/menu2.gz
        #"068_245dc640" # gz/menu_character_01.gz
        #"069_0123c740" # gz/menu_character_02.gz
        "070_00940549" # gz/menu_common.gz
        #"083_88455768" # gz/menu_sound.gz"
        "084_87f51e0c" # gz/menu_story.01_boss01_gori01.gz
        "085_41f34892" # gz/menu_story.02_city01_a.gz
        "086_e76bf53f" # gz/menu_story.03_city02_a.gz
        "087_5973ad65" # gz/menu_story.04_metro01_a.gz
        "088_dd798eb5" # gz/menu_story.05_boss02_boss.gz
        "089_44f20e4a" # gz/menu_story.06_bay01_a.gz
        "090_567ea3b3" # gz/menu_story.07_bay02_a.gz
        "091_6cc96933" # gz/menu_story.08_park01_a.gz
        "092_c55668f7" # gz/menu_story.09_stadium_a.gz
        "093_1626079d" # gz/menu_story.10_boss03_fly.gz
        "094_45912030" # gz/menu_story.11_hangar01_a.gz
        "095_c35e32d9" # gz/menu_story.12_hangar02_a.gz
        "096_f2b5553f" # gz/menu_story.13_boss04_gori02.gz
        "097_dcd7b35d" # gz/menu_story.14_elevator_a.gz
        "098_8d3a2011" # gz/menu_story.15_kakeru_spector.gz
        "117_05f7cae8" # gz/menu_title.gz
        "118_3c6cf60b" # gz/menu_vs.gz

        # Stage files are needed for patching the pause menu and other in game text
        "637_aa6f7a50" # gz/stage.01_boss01_gori01.gz
        #"639_a7383ea3"
        "641_58401ea3" # gz/stage.02_city01_a.gz
        #"643_fd32e82a"
        #"645_b7bee92a"
        "646_feb8ca50" # gz/stage.03_city02_a.gz
        #"647_b3534589"
        #"649_780f6c0f"
        "650_ac9781d4" # gz/stage.04_metro01_a.gz
        #"651_e9757ff7"
        "652_b8b90462" # gz/stage.05_boss02_boss.gz
        #"653_4516e70a"
        #"655_f3aac06d"
        "656_cf772913" # gz/stage.06_bay01_a.gz
        #"657_20e3e63d"
        #"659_15659caa"
        "660_e103be7c" # gz/stage.07_bay02_a.gz
        #"661_aaa8edb2"
        #"663_47c63baf"
        "664_83163f44" # gz/stage.08_park01_a.gz
        #"665_8468b140"
        "666_187b3c66" # gz/stage.09_stadium_a.gz
        #"667_25e6d796"
        "668_1566b0a1" # gz/stage.10_boss03_fly.gz
        #"669_8e73be1d"
        #"671_d0473e6c"
        "672_44d1c934" # gz/stage.11_hangar01_a.gz
        #"673_21262baa"
        "674_c29edbdd" # gz/stage.12_hangar02_a.gz
        #"675_e781ab51"
        "676_1530b183" # gz/stage.13_boss04_gori02.gz
        #"677_8ed5ded3"
        #"679_5fd46f14"
        "681_db175d62" # gz/stage.14_elevator_a.gz
        "683_9ce158f2" # gz/stage.15_kakeru_spector.gz
        #"685_ad4e55a8"
        #"687_89e08f98"
        #"689_71a9e042"
        #"691_cdb2d8bf"
        #"693_25839e9b"
        #"695_306a9905"
        #"697_8df2c654"
        #"699_9f2c20a8"
        #"701_932551d9"
        #"703_e4c7004d"
        #"705_5b48bba4"
        #"707_6cc0093a"
        #"709_0320b216"
        #"711_d4165a9b"
        #"713_80fe334e"
        #"715_bcf2c6fc"
        #"717_45e16020"
        #"719_20b329ab"
        #"721_da3e2bab"
        #"723_b2516b88"
        #"725_d990ef67"
        #"727_3e11f98e"
        #"729_8ef4f33d"
        #"731_a32b0671"
        #"733_ff7a6abd"
        #"735_0a42108c"
        "737_e5d5ceb1" # gz/stage.50_k1.gz
        "739_2ff511d3" # gz/stage.51_city.gz
        "741_1e656e38" # gz/stage.52_metro.gz
        "743_9ce16be2" # gz/stage.53_bay.gz
        "745_2b6aedc3" # gz/stage.54_UFO.gz
        "747_48d02db6" # gz/stage.55_park.gz
        "749_4cde5405" # gz/stage.56_daiba.gz
        "751_ea0603ba" # gz/stage.57_k1death.gz
        "753_1988ae91" # gz/stage.58_UFO2.gz
        "755_f25230cc" # gz/stage.60_k1.gz
        "757_4dbdde02" # gz/stage.60_k1death.gz
        #"759_b0ffcadb" # gz/system.gz
        "774_54110b1e" # gz/victory.vs.chall.gz
        "775_38ff898c" # gz/victory.vs.goritron.gz
        "776_dd92277c" # gz/victory.vs.hakase.gz
        "777_04f26afc" # gz/victory.vs.haruka.gz
        "778_5668b0b6" # gz/victory.vs.hiroki.gz
        "779_b3fbe4fc" # gz/victory.vs.kakeru.gz
        "780_33f84ad2" # gz/victory.vs.legend.gz
        "781_b130371d" # gz/victory.vs.natsumi.gz
        "782_76ec174c" # gz/victory.vs.pipo6.gz
        "783_a707263d" # gz/victory.vs.pipotron.gz
        "784_f89bc790" # gz/victory.vs.spector.gz
        "785_aa3bb564" # gz/victory.vs.volcano.gz
      ];
      resourceFilesStr = builtins.concatStringsSep "\n" resourceFiles;
      inherit (poetry2nix.lib.mkPoetry2Nix { inherit pkgs; })
        mkPoetryEnv mkPoetryApplication defaultPoetryOverrides;
      #poetryEnv = mkPoetryEnv {
      #  projectDir = ./.;
      #};
      fontconfig_file = pkgs.makeFontsConf {
        fontDirectories = [
          pkgs.freefont_ttf
          pkgs.rounded-mgenplus
        ];
      };
    in {
      packages = {
        ssmm-patcher = mkPoetryApplication {
          projectDir = ./ssmm-patcher;
          overrides = defaultPoetryOverrides.extend
            (self: super: {
              ps2isopatcher = super.ps2isopatcher.overridePythonAttrs
              (
                old: {
                  buildInputs = (old.buildInputs or [ ]) ++ [
                    super.poetry
                  ];
                }
              );
            });
          # Dependency check is broken for git dependencies on current nixpkgs
          dontCheckRuntimeDeps = true;
        };
        default = self.packages.${system}.ssmm-patcher;
        iso-jp-extracted = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-jp-iso-extracted";
          inherit version;
          srcs = [
            mm-jp-iso
          ];
          sourceRoot = ".";

          nativeBuildInputs = [ pkgs.p7zip pkgs.tree ];

          unpackPhase = ''
            7z x "''${srcs[0]}"
          '';

          dontBuild = true;

          installPhase = ''
            find . -type f | \
              xargs -P $NIX_BUILD_CORES -I {} install -Dm 755 "{}" "$out/extracted/{}"
            wait
          '';

          dontFixup = true;
        };
        iso-cn-extracted = self.packages.${system}.iso-jp-extracted.overrideAttrs (old: {
          pname = "mm-cn-iso-extracted";
          srcs = [
            mm-cn-iso
          ];
        });
        cutscenes-jp-demuxed = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-jp-cutscenes-demuxed";
          inherit version;
          src = null;
          dontUnpack = true;

          nativeBuildInputs = [
            ssmm-mux.packages.${system}.default
          ];

          buildPhase = cutscenes-demuxed-buildPhase self.packages.${system}.iso-jp-extracted;

          installPhase = ''
            find . \
              \( -name '*.m2v' -o -name '*.ss2' \) | \
                xargs -P $NIX_BUILD_CORES -I {} install -Dm 755 "{}" "$out/demuxed/{}"
            wait
          '';

          dontFixup = true;
        };
        cutscenes-cn-demuxed = self.packages.${system}.cutscenes-jp-demuxed.overrideAttrs (old: {
          pname = "mm-cn-cutscenes-demuxed";
          buildPhase = cutscenes-demuxed-buildPhase self.packages.${system}.iso-cn-extracted;
        });
        cutscenes-jp-mp4 = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-jp-cutscenes-mp4";
          inherit version;
          src = null;
          dontUnpack = true;

          nativeBuildInputs = [
              pkgs.ffmpeg
          ];

          buildPhase = cutscenes-mp4-buildPhase self.packages.${system}.cutscenes-jp-demuxed;

          installPhase = ''
            find . -name '*.mp4' | \
              xargs -P $NIX_BUILD_CORES -I {} install -Dm 755 "{}" "$out/mp4/{}"
            wait
          '';

          dontFixup = true;
        };
        cutscenes-cn-mp4 = self.packages.${system}.cutscenes-jp-mp4.overrideAttrs (old: {
          pname = "mm-cn-cutscenes-mp4";
          buildPhase = cutscenes-mp4-buildPhase self.packages.${system}.cutscenes-cn-demuxed;
        });
        cutscenes-remuxed = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-cutscenes-remuxed";
          inherit version;
          src = ./subs;
          dontUnpack = true;

          nativeBuildInputs = [
            ps2str.packages.${system}.default
            pkgs.jq
            pkgs.ffmpeg

            # For xxd single quote hack
            pkgs.unixtools.xxd
          ];

          buildPhase = ''
            export FONTCONFIG_FILE=${fontconfig_file}

            find $src -type f -name '*.json' | \
              xargs -P $NIX_BUILD_CORES -I {} bash -c '
                meta_file="{}"
                subs_file="$(dirname $meta_file)/$(jq -r '.file' $meta_file)"
                bitrate="$(jq -r '.bitrate' $meta_file)"
                base_name=$(echo ''${meta_file%.json} | sed "s#$src/##")
                m2v="${self.packages.${system}.cutscenes-jp-demuxed}/demuxed/$base_name.m2v"
                ss2="${self.packages.${system}.cutscenes-jp-demuxed}/demuxed/$base_name.ss2"
                mux="''${base_name}.mux"
                subtitle_filter="subtitles=$subs_file:force_style="
                echo "$subtitle_filter"
                # Hack to get single quotes in this string without breaking parsing
                subtitle_filter+=$(echo 27 | xxd -p -r)
                subtitle_filter+="FontName=FreeSans,FontSize=20,MarginV=25"
                subtitle_filter+=$(echo 27 | xxd -p -r)
                m2v_subbed="''${base_name}-sub.m2v"
                pss_subbed="''${base_name}-sub.PSS"
                mkdir -p $(dirname "$base_name")
                ffmpeg \
                  -i "$m2v" \
                  -vf "$subtitle_filter" \
                  -b:v "$bitrate" \
                  "$m2v_subbed"
                cat <<EOF > "$mux"
            pss
                stream video:0
                    input "$m2v_subbed"
                end
                stream pcm:0
                    input "$ss2"
                end
            end
            EOF
                ps2str mux "$mux" "$pss_subbed"
              '
            wait
          '';

          installPhase = ''
            find . -name '*-sub.PSS' | \
              xargs -P $NIX_BUILD_CORES \
                -I {} install -Dm 755 "{}" "$out/remuxed/{}"
            wait
          '';

          dontFixup = true;
        };
        cutscenes-size-diff = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "cutscenes-size-diff";
          inherit version;
          src = null;
          dontUnpack = true;

          buildPhase = ''
            report=""
            pushd "${self.packages.${system}.cutscenes-remuxed}/remuxed"
            for m in $(find . -type f); do
              abspath=$(readlink -f "$m")
              isopath="''${m#.}"
              isopath="''${isopath%-sub*}.''${isopath##*.}"
              patchedsize=$(wc -c < $m)
              origsize=$(wc -c < "${self.packages.${system}.iso-jp-extracted}/extracted/$isopath")
              report+="$isopath: orig is $origsize, patched is $patchedsize, diff: $(($origsize-$patchedsize))\n"
            done
            popd
            echo -e "$report" > report.txt
          '';

          installPhase = ''
            install -Dm 755 "report.txt" "$out/report.txt"
          '';

          dontFixup = true;
        };
        data-jp-unpacked = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-jp-data-unpacked";
          inherit version;
          src = null;
          dontUnpack = true;

          nativeBuildInputs = [
            self.packages.${system}.ssmm-patcher
          ];

          buildPhase = data-unpacked-buildPhase self.packages.${system}.iso-jp-extracted;

          installPhase = ''
            mkdir -p "$out/DATA1"
            cp -a PDATA/DATA1/* "$out/DATA1"
            mkdir -p "$out/DATA3"
            cp -a PDATA/DATA3/* "$out/DATA3"
          '';

           dontFixup = true;
        };
        data-cn-unpacked = self.packages.${system}.data-jp-unpacked.overrideAttrs (old: {
          pname = "mm-cn-data-unpacked";
          buildPhase = data-unpacked-buildPhase self.packages.${system}.iso-cn-extracted;
        });
        data-jp-unpacked-named = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-jp-data-unpacked-named";
          inherit version;
          src = null;
          dontUnpack = true;

          nativeBuildInputs = [
            self.packages.${system}.ssmm-patcher
          ];

          dontBuild = true;

          installPhase = data-unpacked-named-installPhase self.packages.${system}.data-jp-unpacked;

          dontFixup = true;
        };
        data-cn-unpacked-named = self.packages.${system}.data-jp-unpacked-named.overrideAttrs (old: {
          pname = "mm-cn-data-unpacked-named";
          installPhase = data-unpacked-named-installPhase self.packages.${system}.data-cn-unpacked;
        });
        data-jp-extracted = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-jp-data-extracted";
          inherit version;
          src = null;
          dontUnpack = true;

          buildPhase = data-extracted-buildPhase self.packages.${system}.data-jp-unpacked;

          installPhase = ''
            mkdir -p "$out/DATA1"
            cp -r DATA1/* "$out/DATA1"
          '';

          dontFixup = true;
        };
        data-imhex-analysis = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-data-imhex-analysis";
          inherit version;
          src = ./imhex_patterns;
          dontUnpack = true;

          nativeBuildInputs = [
            pkgs.imhex
            # Needed to check free memory
            pkgs.procps
          ];

          buildPhase = ''
            mkdir -p $out/analysis
            # Hack: this is a memory intensive process, and will fail if not
            # enough free memory is allocated to each process
            free_mem=$(free --mega | awk '/Mem:/ {print $7}')
            echo "Available memory: $free_mem"
            max_procs=$(($free_mem / 1536))
            if [[ "$max_procs" -gt "$NIX_BUILD_CORES" ]]; then
              max_procs="$NIX_BUILD_CORES"
            fi
            if [[ "$max_procs" -lt "1" ]]; then
              max_procs="1"
            fi
            echo "Generating $max_procs imhex outputs in parallel"
            echo "${resourceFilesStr}" | \
              xargs -P $max_procs -I {} bash -c '
                echo "Analyzing resource {}"
                imhex --pl format --verbose --metadata \
                  --includes "$src/includes/" \
                  --input "${self.packages.${system}.data-jp-extracted}/DATA1/{}" \
                  --pattern "$src/main.hexpat" \
                  --output "$out/analysis/{}.json"
              '
          '';

          dontInstall = true;
          dontFixup = true;

        };
        data-textures-extracted = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-data-textures-extracted";
          inherit version;
          src = null;
          dontUnpack = true;

          nativeBuildInputs = [
            self.packages.${system}.ssmm-patcher
          ];

          buildPhase = ''
            echo "${resourceFilesStr}" | \
              xargs -P $NIX_BUILD_CORES -I {} bash -c '
                echo "Dumping textures from {}"
                ssmm-patcher dump-textures \
                  -o "$out/{}" \
                  "${self.packages.${system}.data-imhex-analysis}/analysis/{}.json"
              '
          '';

          installPhase = ''
            chmod 755 -R $out
          '';

          dontFixup = true;

        };
        data-fonts-extracted = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-data-fonts-extracted";
          inherit version;
          src = null;
          dontUnpack = true;

          nativeBuildInputs = [
            self.packages.${system}.ssmm-patcher
          ];

          buildPhase = ''
            echo "${resourceFilesStr}" | \
              xargs -P $NIX_BUILD_CORES -I {} bash -c '
                ssmm-patcher dump-fonts \
                  -i "${self.packages.${system}.data-imhex-analysis}/analysis/{}.json" \
                  -o "$out/{}"
              '
          '';

          installPhase = ''
            chmod 755 -R $out
          '';

          dontFixup = true;

        };
        data-strings-extracted = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-data-strings-extracted";
          inherit version;
          src = null;
          dontUnpack = true;

          nativeBuildInputs = [
            self.packages.${system}.ssmm-patcher
          ];

          buildPhase = ''
            echo "${resourceFilesStr}" | \
              xargs -P $NIX_BUILD_CORES -I {} bash -c '
                echo "Dumping strings from {}"
                ssmm-patcher dump-strings \
                  -o "$out/{}" \
                  "${self.packages.${system}.data-imhex-analysis}/analysis/{}.json"
              '
          '';

          dontFixup = true;

        };
        textures-imhex-analysis = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-textures-imhex-analysis";
          inherit version;
          srcs = [
            ./imhex_patterns
            ./textures
          ];
          dontUnpack = true;

          nativeBuildInputs = [
            pkgs.imhex
          ];

          buildPhase = ''
            paths=($srcs)
            export pattern_path=''${paths[0]}
            export textures_path=''${paths[1]}


            find "$textures_path" -name 'texture.aseprite' -type f | \
              xargs -P $NIX_BUILD_CORES -I {} bash -c '
                echo "Analyzing texture {}"
                fullpath="{}"
                relpath=''${fullpath#"$textures_path"}
                dirrelpath=''${relpath%"texture.aseprite"}
                dirfullpath=''${fullpath%"texture.aseprite"}

                mkdir -p "$out/analysis/$dirrelpath"
                imhex --pl format --verbose --metadata \
                  --includes "$pattern_path/includes/" \
                  --input "{}" \
                  --pattern "$pattern_path/aseprite_main.hexpat" \
                  --output "$out/analysis/$dirrelpath/texture.json"
                cp "$dirfullpath/manifest.yaml" "$out/analysis/$dirrelpath/manifest.yaml"
              '
          '';

          dontFixup = true;
        };
        data-cn-extracted = self.packages.${system}.data-jp-extracted.overrideAttrs (old: {
          pname = "mm-cn-data-extracted";
          buildPhase = data-extracted-buildPhase self.packages.${system}.data-cn-unpacked;
        });
        data-jp-extracted-named = self.packages.${system}.data-jp-extracted.overrideAttrs (old: {
          pname = "mm-jp-data-extracted-named";
          buildPhase = data-extracted-buildPhase self.packages.${system}.data-jp-unpacked-named;
        });
        data-patched = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-data-patched";
          inherit version;
          src = ./strings.yaml;
          dontUnpack = true;

          nativeBuildInputs = [
            self.packages.${system}.default
          ];

          buildPhase = ''
            echo "${resourceFilesStr}" | \
              xargs -P $NIX_BUILD_CORES -I {} bash -c '
                name="{}"
                ssmm-patcher patch-font \
                  -o "{}" \
                  "${self.packages.${system}.data-jp-extracted}/DATA1/070_00940549" \
                  "${self.packages.${system}.data-jp-extracted}/DATA1/{}"

                ssmm-patcher patch-resource \
                  -s $src \
                  -t ${self.packages.${system}.textures-imhex-analysis}/analysis/{}/ \
                  "{}" \
                  "${self.packages.${system}.data-imhex-analysis}/analysis/{}.json"
              '
          '';

          installPhase = ''
            find . -name '*_patched' -type f | \
              xargs -P $NIX_BUILD_CORES \
                -I {} install -Dm 755 "{}" "$out/DATA1_patched/{}"
            wait
          '';

          dontFixup = true;
        };
        data-patched-compressed = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-data-patched-compressed";
          inherit version;
          src = null;
          dontUnpack = true;

          buildPhase = ''
            echo "${resourceFilesStr}" | \
              xargs -P $NIX_BUILD_CORES -I {} bash -c '
                gzip -9 -c "${self.packages.${system}.data-patched}/DATA1_patched/{}_patched" > "{}_patched.gz"
              '
          '';

          installPhase = ''
            find . -name '*_patched.gz' -type f | \
              xargs -P $NIX_BUILD_CORES \
                -I {} install -Dm 755 "{}" "$out/DATA1_patched/{}"
            wait
          '';

          dontFixup = true;
        };
        data-repacked = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-data-repacked";
          inherit version;
          src = null;
          dontUnpack = true;

          nativeBuildInputs = [
            self.packages.${system}.default
          ];

          buildPhase = ''
            cmd="ssmm-patcher pack-data"
            for f in ${self.packages.${system}.data-jp-unpacked}/DATA1/*; do
              name=$(basename "''${f%.gz}")
              hash="''${name#*_}"
              patched="${self.packages.${system}.data-patched-compressed}/DATA1_patched/''${name}_patched.gz"
              if [[ -e "$patched" ]]; then
                cmd+=" -e $hash $patched"
              else
                cmd+=" -e $hash $f"
              fi
            done
            eval $cmd
            ls
          '';

          installPhase = ''
            find . -name '*.BIN' -type f | \
              xargs -P $NIX_BUILD_CORES \
                -I {} install -Dm 755 "{}" "$out/PDATA/{}"
            wait
          '';

          dontFixup = true;
        };
        iso-patched = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-iso-patched";
          inherit version;
          src = mm-jp-iso;
          dontUnpack = true;

          nativeBuildInputs = [
            ps2isopatcher.packages.${system}.default
          ];

          buildPhase = ''
            cmd="ps2isopatcher patch"
            cmd+=" -r \"/PDATA/DATA0.BIN;1\" \"${self.packages.${system}.data-repacked}/PDATA/DATA0.BIN\""
            cmd+=" -r \"/PDATA/DATA1.BIN;1\" \"${self.packages.${system}.data-repacked}/PDATA/DATA1.BIN\""
            pushd "${self.packages.${system}.cutscenes-remuxed}/remuxed"
            for m in $(find . -type f); do
              abspath=$(readlink -f "$m")
              isopath="''${m#.}"
              isopath="''${isopath%-sub*}.''${isopath##*.};1"
              cmd+=" -r \"$isopath\" \"$abspath\""
            done
            popd
            mkdir -p "$out/iso"
            cmd+=" -o \"$out/iso/mm_patched.iso\" \"$src\""
            eval $cmd
          '';

          dontInstall = true;
          dontFixup = true;
        };
        debug-patches = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-debug-patches";
          inherit version;
          src = ./debug-patches;
          dontUnpack = true;

          nativeBuildInputs = [
            pkgs-clps2c.clps2c-compiler
          ];

          buildPhase = ''
            mkdir -p build
            for f in $src/*.clps2c; do
              name=$(basename $f)
              name="''${name%.clps2c}"
              echo "Building $f to build/$name"
              CLPS2C-Compiler -i "$f" -o "build/$name" -p
            done

            mkdir -p "$out"
            outfile="$out/SCPS-15115_8EFDBAEB.pnach"
            touch "$outfile"
            for f in build/*; do
              echo "[$(basename $f)]" >> $outfile
              cat "$f" | sed ':a; /^\n*$/d; /^\n/s/^\n*//' >> "$outfile"
              echo -e "\n" >> $outfile
            done
          '';

          dontInstall = true;
          dontFixup = true;
        };
      };
      devShells.default = pkgs.mkShell {
        #buildInputs = [
        #  poetryEnv
        #];
        packages = [
          self.packages.${system}.default
        ];
      };
      devShells.poetry = pkgs.mkShell {
        buildInputs = [
          # Required to make poetry shell work properly
          pkgs.bashInteractive
        ];
        packages = [
          ssmm-mux.packages.${system}.default
          ps2str.packages.${system}.default
          #bgrep.packages.${system}.default
          pkgs.poetry
          pkgs.ffmpeg
          pkgs.openai-whisper
          pkgs.dos2unix
          pkgs.vlc
          pkgs.imhex
          pkgs.rsbkb  # bgrep
          pkgs-clps2c.clps2c-compiler
        ];
        shellHook = ''
          export FONTCONFIG_FILE=${fontconfig_file}
        '';
      };
    });
}
