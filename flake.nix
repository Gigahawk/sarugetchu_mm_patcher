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
    # Waiting for merge of https://github.com/NixOS/nixpkgs/pull/406377
    nixpkgs-ps2patchelf.url = "github:Gigahawk/nixpkgs?ref=ps2patchelf";
    # Waiting for merge of https://github.com/NixOS/nixpkgs/pull/410329
    nixpkgs-sangyo.url = "github:Gigahawk/nixpkgs?ref=sangyo_ttf";
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
    nixpkgs-ps2patchelf,
    nixpkgs-sangyo,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs { inherit system; };
      pkgs-clps2c = import nixpkgs-clps2c { inherit system; };
      pkgs-ps2patchelf = import nixpkgs-ps2patchelf { inherit system; };
      pkgs-sangyo = import nixpkgs-sangyo { inherit system; };
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
        export FONTCONFIG_FILE=${fontconfig_file}

        find ${cutscenes-demuxed} -name '*.m2v' -type f | \
          xargs -P $NIX_BUILD_CORES -I {} bash -c '
            m2v="{}"
            base_name="''${m2v%.m2v}"
            meta_file="$src/''${base_name#${cutscenes-demuxed}/demuxed/}.json"
            if [[ -e "$meta_file" ]]; then
              subs_file="$(dirname $meta_file)/$(jq -r '.file' $meta_file)"
              style="$(jq -r ".style // \"\"" $meta_file)"
              if [[ -z "$style" && "$subs_file" == *.srt ]]; then
                style="FontName=FreeSans,FontSize=16,MarginV=8"
              fi
              subtitle_filter="-vf subtitles=$subs_file"
              if [[ -n "$style" ]]; then
                subtitle_filter+=":force_style="
                # Hack to get single quotes in this string without breaking parsing
                subtitle_filter+=$(echo 27 | xxd -p -r)
                subtitle_filter+="$style"
                subtitle_filter+=$(echo 27 | xxd -p -r)
              fi
              echo "$subtitle_filter"
            else
              subtitle_filter=""
            fi
            ss2="''${base_name}.ss2"
            output="''${base_name#${cutscenes-demuxed}/demuxed/}.mp4"
            mkdir -p $(dirname "$output")
            ffmpeg_args=(
              -i "$m2v"
              -i "$ss2"
              -c:a aac
            )
            if [[ -n "$subtitle_filter" ]]; then
              ffmpeg_args+=(
                -c:v libx265 -crf 18
                $subtitle_filter
              )
            else
              ffmpeg_args+=(-c:v copy)
              exit 0
            fi
            ffmpeg_args+=("$output")

            ffmpeg "''${ffmpeg_args[@]}"
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
      elfName = "SCPS_151.15";
      pnachName = "SCPS-15115_8EFDBAEB";
      patches-buildPhase = files: ''
        mkdir -p "$out"
        outfile="$out/${pnachName}.pnach"
        touch "$outfile"
        for f in ${self.packages.${system}.debug-patches-pnaches}/*; do
          name=$(basename "$f")
          if [[ ${files} != "*" ]]; then
            if [[ "${files}" != *"$name"* ]]; then
              echo "Skipping $name"
              continue
            fi
          fi
          echo "[$name]" >> $outfile
          # Remove leading newline
          cat "$f" | sed ':a; /^\n*$/d; /^\n/s/^\n*//' >> "$outfile"
          echo -e "\n" >> $outfile
        done
      '';
      version = "1";
      resourceFiles = [
        "043_b1fc2c81" # gz/game_common.gz
        "044_5c272d50" # gz/game_common.story.gz
        "045_3cecf223" # gz/game_common.vs.gz
        #"046_8205e9b5" # gz/game_common_sound_bd.gz
        "047_7243e526" # gz/game_result.story.gz
        "048_4abee95e" # gz/game_result.vs.gz
        "066_c9448ba5" # gz/menu1.gz
        "067_a60a8ca5" # gz/menu2.gz
        "068_245dc640" # gz/menu_character_01.gz
        "069_0123c740" # gz/menu_character_02.gz
        "070_00940549" # gz/menu_common.gz
        "071_d2aeb433" # gz/menu_edit1.gz
        "072_af74b533" # gz/menu_edit2.gz
        "073_36c5de03" # ??
        "074_3943e3cc" # gz/menu_edit_sarubook_in_pipo6.gz
        "075_0569c31e" # gz/menu_edit_sound.gz
        "076_3cdca805" # ??
        "077_3b4fb376" # gz/menu_edit_sprite.ga_kakeru.gz
        "078_594309b8" # gz/menu_edit_sprite.ga_natsumi.gz
        "079_e3710b47" # ??
        "080_d7d0bd8c" # ??
        "081_d1e4d526" # gz/menu_edit_sprite.gf_spector.gz
        "082_6fd16046" # gz/menu_edit_summon.gz
        "083_88455768" # gz/menu_sound.gz
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
        "099_06143ebb" # gz/menu_story.15_pipo_spector.gz
        "100_5ebb5f0b" # gz/menu_story.16_kakeru_goritron.gz
        "101_96696a96" # gz/menu_story.16_pipo_kakeru.gz
        "102_7a8e0451" # gz/menu_story.17_city01_vr.gz
        "103_0e36c98a" # gz/menu_story.18_bay01_vr.gz
        "104_dd45c596" # gz/menu_story.19_park01_vr.gz
        "105_b2b250a8" # gz/menu_story.20_boss07_grid.gz
        "106_4c084c39" # gz/menu_story.21_stadium_b.gz
        "107_cd7a2b3c" # gz/menu_story.22_park01_b.gz
        "108_e13aef70" # gz/menu_story.23_bay02_b.gz
        "109_49913fd2" # gz/menu_story.24_bay01_b.gz
        "110_a5bebda1" # gz/menu_story.25_boss08_boss.gz
        "111_f2bc8cb1" # gz/menu_story.26_metro01_b.gz
        "112_72c71ee8" # gz/menu_story.27_city02_b.gz
        "113_6e0a878d" # gz/menu_story.28_city01_b.gz
        "114_3a1b68cc" # gz/menu_story.29_boss09_boss.gz
        "115_ac56964e" # gz/menu_story.30_daiba02_b.gz
        "116_2f029adf" # gz/menu_story.31_boss10_boss.gz
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
        "685_ad4e55a8" # gz/stage.15_pipo_spector.gz
        "687_89e08f98" # gz/stage.16_kakeru_goritron.gz
        "689_71a9e042" # gz/stage.16_pipo_kakeru.gz
        "691_cdb2d8bf" # gz/stage.17_city01_vr.gz
        "693_25839e9b" # gz/stage.18_bay01_vr.gz
        "695_306a9905" # gz/stage.19_park01_vr.gz
        "697_8df2c654" # gz/stage.20_boss07_grid.gz
        "699_9f2c20a8" # gz/stage.21_stadium_b.gz
        #"701_932551d9"
        "703_e4c7004d" # gz/stage.22_park01_b.gz
        #"705_5b48bba4"
        "707_6cc0093a" # gz/stage.23_bay02_b.gz
        #"709_0320b216"
        "711_d4165a9b" # gz/stage.24_bay01_b.gz
        "713_80fe334e" # gz/stage.25_boss08_boss.gz
        #"715_bcf2c6fc"
        "717_45e16020" # gz/stage.26_metro01_b.gz
        #"719_20b329ab"
        #"721_da3e2bab"
        "722_8914f4f8" # gz/stage.27_city02_b.gz
        #"723_b2516b88"
        #"725_d990ef67"
        "726_85575c9e" # gz/stage.28_city01_b.gz
        #"727_3e11f98e"
        "728_155bde78" # gz/stage.29_boss09_boss.gz
        #"729_8ef4f33d"
        #"731_a32b0671"
        "733_ff7a6abd" # gz/stage.30_daiba02_b.gz
        "735_0a42108c" # gz/stage.31_boss10_boss.gz
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
        "762_e1cdd8b9" # gz/victory.col.chall.gz
        "763_f1453e5f" # gz/victory.col.goritron.gz
        "764_3ed3e300" # gz/victory.col.hakase.gz
        "765_65322781" # gz/victory.col.haruka.gz
        "766_b7a86c3b" # gz/victory.col.hiroki.gz
        "767_143ca181" # gz/victory.col.kakeru.gz
        "768_94380757" # gz/victory.col.legend.gz
        "769_b67e6c4c" # gz/victory.col.natsumi.gz
        "770_03a9e5e7" # gz/victory.col.pipo6.gz
        "771_604eda0f" # gz/victory.col.pipotron.gz
        "772_fde9fcbf" # gz/victory.col.spector.gz
        "773_af89ea93" # gz/victory.col.volcano.gz
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
          pkgs.comic-relief
          pkgs-sangyo.sangyo_ttf
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
          src = ./subs;
          dontUnpack = true;

          nativeBuildInputs = [
              pkgs.jq
              pkgs.ffmpeg

              # For xxd single quote hack
              pkgs.unixtools.xxd
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

            find "$src" \( -type f -o -xtype f \) -name '*.json' | \
              xargs -P $NIX_BUILD_CORES -I {} bash -c '
                meta_file="{}"
                subs_file="$(dirname $meta_file)/$(jq -r '.file' $meta_file)"
                bitrate="$(jq -r '.bitrate' $meta_file)"
                style="$(jq -r ".style // \"\"" $meta_file)"
                if [[ -z "$style" && "$subs_file" == *.srt ]]; then
                  style="FontName=FreeSans,FontSize=16,MarginV=8"
                fi
                base_name=$(echo ''${meta_file%.json} | sed "s#$src/##")
                m2v="${self.packages.${system}.cutscenes-jp-demuxed}/demuxed/$base_name.m2v"
                ss2="${self.packages.${system}.cutscenes-jp-demuxed}/demuxed/$base_name.ss2"
                mux="''${base_name}.mux"
                subtitle_filter="subtitles=$subs_file"
                if [[ -n "$style" ]]; then
                  subtitle_filter+=":force_style="
                  # Hack to get single quotes in this string without breaking parsing
                  subtitle_filter+=$(echo 27 | xxd -p -r)
                  subtitle_filter+="$style"
                  subtitle_filter+=$(echo 27 | xxd -p -r)
                fi
                echo "$subtitle_filter"
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
        data-imhex-preanalysis = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-data-imhex-preanalysis";
          inherit version;
          src = null;
          dontUnpack = true;
          installPhase = ''
            mkdir -p "$out"
            while IFS= read -r f; do
              cp  "${self.packages.${system}.data-jp-extracted}/DATA1/$f" "$out/$f"
            done <<< "${resourceFilesStr}"
          '';
        };
        font-prepatched = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-font-patched";
          inherit version;
          src = null;
          dontUnpack = true;

          nativeBuildInputs = [
            self.packages.${system}.default
          ];

          buildPhase = ''
            mkdir "$out"
            sv_font_src=070_00940549
            # HACK: need to pre patch sv_msg.gf before we copy it into all our files
            echo "Prepatching $sv_font_src font"
            ssmm-patcher patch-resource \
                -t ${self.packages.${system}.textures-imhex-analysis}/analysis/all/ \
                -o "$out/sv_font_src" \
                "${self.packages.${system}.data-jp-extracted}/DATA1/$sv_font_src" \
                "${self.packages.${system}.data-imhex-analysis}/analysis/$sv_font_src.json"
            '';

          dontInstall = true;
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
            # Needed to retry, builds still sometimes fail even with memory limits
            pkgs.parallel
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
              parallel --retries 5 -P $max_procs -I {} '
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
        font-prepatched-imhex-analysis = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-font-prepatched-imhex-analysis";
          inherit version;
          src = ./imhex_patterns;
          dontUnpack = true;

          nativeBuildInputs = [
            pkgs.imhex
          ];

          buildPhase = ''
            mkdir -p "$out"
            echo "Generating imhex analysis for prepatched font resource"
            imhex --pl format --verbose --metadata \
              --includes "$src/includes/" \
              --input "${self.packages.${system}.font-prepatched}/sv_font_src" \
              --pattern "$src/main.hexpat" \
              --output "$out/sv_font_src.json"
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
        data-strings-unique = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-data-strings-unique";
          inherit version;
          src = null;
          dontUnpack = true;

          nativeBuildInputs = [
            self.packages.${system}.ssmm-patcher
          ];

          buildPhase = ''
            mkdir -p "$out"
            echo "${resourceFilesStr}" | \
              # Don't run this multithreaded
              xargs -P "1" -I {} bash -c '
                echo "Finding unique strings from {}"
                ssmm-patcher collect-strings \
                  "${self.packages.${system}.data-strings-extracted}/{}.strings.yaml" \
                  "$out/unique_strings.txt"
              '
          '';

          dontFixup = true;

        };
        data-translation-analysis = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-data-translation-analysis";
          inherit version;
          srcs = [
            ./strings.yaml
            ./ignored_strings.txt
          ];
          dontUnpack = true;

          nativeBuildInputs = [
            self.packages.${system}.ssmm-patcher
          ];

          buildPhase = ''
            mkdir -p "$out"
            paths=($srcs)
            strings=''${paths[0]}
            ignored_strings=''${paths[1]}
            ssmm-patcher analyze-translation-progress \
              -o "$out" \
              -i "$ignored_strings" \
              "$strings" \
              "${self.packages.${system}.data-strings-unique}/unique_strings.txt" \
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
              xargs -P "$NIX_BUILD_CORES" -I {} bash -c '
                name="{}"
                echo "Patching $name"
                ssmm-patcher patch-font \
                  -o "{}" \
                  "${self.packages.${system}.font-prepatched}/sv_font_src" \
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
        debug-patches-pnaches = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-debug-patches-pnaches";
          inherit version;
          src = ./debug-patches;
          dontUnpack = true;

          nativeBuildInputs = [
            pkgs-clps2c.clps2c-compiler
          ];

          buildPhase = ''
            mkdir -p "$out"
            for f in $src/*.clps2c; do
              name=$(basename $f)
              name="''${name%.clps2c}"
              echo "Building $f to $out/$name"
              CLPS2C-Compiler -i "$f" -o "$out/$name" -p
            done
          '';

          dontInstall = true;
          dontFixup = true;
        };
        debug-patches = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-debug-patches";
          inherit version;
          src = null;
          dontUnpack = true;

          buildPhase = patches-buildPhase "*";

          dontInstall = true;
          dontFixup = true;
        };
        prod-patches = self.packages.${system}.debug-patches.overrideAttrs (old:
        let
          prodPatchNames = [
            "font_scale"
            "enable_log_print"
          ];
          prodPatchNamesStr = builtins.concatStringsSep "," prodPatchNames;
        in
        {
          pname = "mm-prod-patches";
          buildPhase = patches-buildPhase prodPatchNamesStr;
        });
        elf-patched = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-elf-patched";
          inherit version;
          src = null;
          dontUnpack = true;

          nativeBuildInputs = [
            pkgs-ps2patchelf.ps2patchelf
          ];

          buildPhase = ''
            mkdir -p "$out"
            cp "${self.packages.${system}.iso-jp-extracted}/extracted/${elfName}" .
            chmod 777 "${elfName}"
            PS2PatchElf \
              ${elfName} \
              "${self.packages.${system}.prod-patches}/${pnachName}.pnach" \
              "$out/${elfName}_patched"
          '';

          dontInstall = true;
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
            cmd+=" -r \"/${elfName};1\" \"${self.packages.${system}.elf-patched}/${elfName}_patched\""
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
