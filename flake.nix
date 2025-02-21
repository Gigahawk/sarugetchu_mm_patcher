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
      processes = "32";
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
          xargs -P ${processes} -I {} bash -c '
            input="{}"
            output="''${input#${iso-extracted}/extracted/}"
            mkdir -p $(dirname "$output")
            ssmm-demux "$input" "$output"
          '
        wait
      '';
      cutscenes-mp4-buildPhase = cutscenes-demuxed: ''
        find ${cutscenes-demuxed} -name '*.m2v' -type f | \
          xargs -P ${processes} -I {} bash -c '
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
          xargs -P ${processes} -I {} mv "{}" "{}.gz"
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
          xargs -P ${processes} -I {} bash -c '
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
          xargs -P ${processes} -I {} bash -c '
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
          xargs -P ${processes} -I {} bash -c '
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
        #"043_b1fc2c81" # gz/game_common.gz
        #"044_5c272d50" # gz/game_common.story.gz
        #"045_3cecf223" # gz/game_common.vs.gz
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
        #"117_05f7cae8" # gz/menu_title.gz
        "118_3c6cf60b" # gz/menu_vs.gz

        # Stage files are needed for patching the pause menu
        "637_aa6f7a50" # gz/stage.01_boss01_gori01.gz
        #"639_a7383ea3"
        "641_58401ea3" # gz/stage.02_city01_a.gz
        #"643_fd32e82a"
        #"645_b7bee92a"
        #"647_b3534589"
        #"649_780f6c0f"
        #"651_e9757ff7"
        #"653_4516e70a"
        #"655_f3aac06d"
        #"657_20e3e63d"
        #"659_15659caa"
        #"661_aaa8edb2"
        #"663_47c63baf"
        #"665_8468b140"
        #"667_25e6d796"
        #"669_8e73be1d"
        #"671_d0473e6c"
        #"673_21262baa"
        #"675_e781ab51"
        #"677_8ed5ded3"
        #"679_5fd46f14"
        #"681_db175d62"
        #"683_9ce158f2"
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

          buildPhase = ''
            true
          '';

          installPhase = ''
            find . -type f | \
              xargs -P ${processes} -I {} install -Dm 755 "{}" "$out/extracted/{}"
            wait
          '';

          fixupPhase = ''
            true
          '';
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
                xargs -P ${processes} -I {} install -Dm 755 "{}" "$out/demuxed/{}"
            wait
          '';
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
              xargs -P ${processes} -I {} install -Dm 755 "{}" "$out/mp4/{}"
            wait
          '';
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
              xargs -P ${processes} -I {} bash -c '
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
              xargs -P ${processes} \
                -I {} install -Dm 755 "{}" "$out/remuxed/{}"
            wait
          '';
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

          buildPhase = ''
            true
          '';

          installPhase = data-unpacked-named-installPhase self.packages.${system}.data-jp-unpacked;
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
        };
        data-imhex-analysis = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-data-imhex-analysis";
          inherit version;
          src = ./imhex_patterns;
          dontUnpack = true;

          nativeBuildInputs = [
            pkgs.imhex
          ];

          buildPhase = ''
            mkdir -p $out/analysis
            echo "${resourceFilesStr}" | \
              xargs -P ${processes} -I {} bash -c '
                imhex --pl format --verbose --metadata \
                  --includes "$src/includes/" \
                  --input "${self.packages.${system}.data-jp-extracted}/DATA1/{}" \
                  --pattern "$src/main.hexpat" \
                  --output "$out/analysis/{}.json"
              '
          '';
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
              xargs -P ${processes} -I {} bash -c '
                name="{}"
                ssmm-patcher patch-font \
                  -o "{}" \
                  "${self.packages.${system}.data-jp-extracted}/DATA1/070_00940549" \
                  "${self.packages.${system}.data-jp-extracted}/DATA1/{}"

                ssmm-patcher patch-resource \
                  -s $src \
                  "{}" \
                  "${self.packages.${system}.data-imhex-analysis}/analysis/{}.json"
              '

            #cp "${self.packages.${system}.data-jp-extracted}/DATA1/737_e5d5ceb1" 737_e5d5ceb1_patched
            #chmod 777 737_e5d5ceb1_patched
            #printf '\xFF%.0s' {1..21271} | dd of=737_e5d5ceb1_patched bs=1 seek=2245 conv=notrunc
            ##printf '\xFF%.0s' {1..2000} | dd of=737_e5d5ceb1_patched bs=1 seek=679413 conv=notrunc
            ##printf '\xE5%.0s' {1..1} | dd of=737_e5d5ceb1_patched bs=1 seek=877418 conv=notrunc
            ##printf '\x5B%.0s' {1..1} | dd of=737_e5d5ceb1_patched bs=1 seek=877419 conv=notrunc
          '';
          # byte 0xFF start 2254 len 64, whites out first thirdish of 一 and リ (zeroth and first char)
          # byte 0xFF start 2254 len 128, whites out first two thirdsish of 一 and リ (zeroth and first char)
          # byte 0xFF start 2254 len 256, whites out all of of 一 and リ (zeroth and first char) and top little bit of ト and ラ (second/third)
          # byte 0xFF start 2254 len 1, no apparent changes
          # byte 0xFF start 2256 len 1, no apparent changes
          # byte 0xFF start 2256 len 8, whites out first 90% of second line of 一 and リ (zeroth and first char)
          # byte 0xFF start 2256 len 4, whites out first 20% of second line of 一 and リ (zeroth and first char)
          # byte 0xFF start 2256 len 2, whites out first (2 pixels?) of second line of 一 and リ (zeroth and first char)
          # byte 0xFF start 2257 len 1, whites out first (2 pixels?) of second line of 一 and リ (zeroth and first char)
          # byte 0xF0 start 2257 len 8, causes dots on first 90% of second line of 一 and リ (zeroth and first char)
          # byte 0x0F start 2257 len 8, causes dots on first 90% of second line of 一 and リ (zeroth and first char)
          # byte 0xAA start 2257 len 8, bright grey on 16px of second line of 一 and リ (zeroth and first char)
          # byte 0xFF start 2257 len 8, white on 16px of second line of 一 and リ (zeroth and first char)
          # byte 0xCC start 2257 len 8, white on 16px of second line of リ (first char)
          # byte 0x33 start 2257 len 8, white on 16px of second line of 一 (zeroth char)
          # byte 0x03 start 2257 len 1, white on first px of second line of 一 (zeroth char)
          # byte 0x33 start 2257 len 9, white on all of second line (18px) of 一 (zeroth char)
          # byte 0x33 start 2257 len 10, white on all of second line (18px) of 一 (zeroth char)
          # byte 0x33 start 2257 len 33, white on all of three lines after first (18px) of 一 (zeroth char)
          # byte 0x33 start 2257 len 13, white on all of second line (18px) and 2px of next line of 一 (zeroth char)
          # byte 0x33 start 2245 len 1, white on first 2px of first line of 一 (zeroth char)

          installPhase = ''
            find . -name '*_patched' -type f | \
              xargs -P ${processes} \
                -I {} install -Dm 755 "{}" "$out/DATA1_patched/{}"
            wait
          '';
        };
        data-patched-compressed = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-data-patched-compressed";
          inherit version;
          src = null;
          dontUnpack = true;

          buildPhase = ''
            echo "${resourceFilesStr}" | \
              xargs -P ${processes} -I {} bash -c '
                gzip -9 -c "${self.packages.${system}.data-patched}/DATA1_patched/{}_patched" > "{}_patched.gz"
              '
          '';

          installPhase = ''
            find . -name '*_patched.gz' -type f | \
              xargs -P ${processes} \
                -I {} install -Dm 755 "{}" "$out/DATA1_patched/{}"
            wait
          '';
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
              xargs -P ${processes} \
                -I {} install -Dm 755 "{}" "$out/PDATA/{}"
            wait
          '';
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

          installPhase = ''
            true
          '';
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
