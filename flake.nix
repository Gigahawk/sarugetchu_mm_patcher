{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    poetry2nix.url = "github:nix-community/poetry2nix";
    ps2str.url = "github:Gigahawk/ps2str-nix";
    ssmm-mux.url = "github:Gigahawk/ssmm-mux";
    ps2isopatcher.url = "github:Gigahawk/ps2isopatcher";
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
      version = "1";
      resourceFiles = [
        "044_5c272d50" # gz/game_common.story.gz
        "070_00940549" # gz/menu_common.gz
        "084_87f51e0c" # gz/menu_story.01_boss01_gori01.gz
        "118_3c6cf60b" # gz/menu_vs.gz
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

          nativeBuildInputs = [
            ssmm-mux.packages.${system}.default
          ];

          unpackPhase = ''
            true
          '';

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

          nativeBuildInputs = [
              pkgs.ffmpeg
          ];

          unpackPhase = ''
            true
          '';

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
          nativeBuildInputs = [
            ps2str.packages.${system}.default
            pkgs.jq
            pkgs.ffmpeg

            # For xxd single quote hack
            pkgs.unixtools.xxd
          ];

          unpackPhase = ''
            true
          '';

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

          unpackPhase = ''
            true
          '';

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
        data-unpacked = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-data-unpacked";
          inherit version;
          src = null;

          nativeBuildInputs = [
            self.packages.${system}.ssmm-patcher
          ];

          unpackPhase = ''
            true
          '';

          buildPhase = ''
            ssmm-patcher unpack-data \
              ${self.packages.${system}.iso-jp-extracted}/extracted/PDATA/DATA0.BIN \
              ${self.packages.${system}.iso-jp-extracted}/extracted/PDATA/DATA1.BIN \
              -o PDATA/DATA1

            # All files in DATA1 are gzip files
            find PDATA/DATA1 -type f | \
              xargs -P ${processes} -I {} mv "{}" "{}.gz"
            wait
          '';
          installPhase = ''
            mkdir -p "$out/DATA1"
            cp -a PDATA/DATA1/* "$out/DATA1"
          '';
        };
        data-extracted = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-data-extracted";
          inherit version;
          src = null;

          unpackPhase = ''
            true
          '';

          buildPhase = ''
            mkdir -p DATA1
            # All files in DATA1 are gzip files
            find ${self.packages.${system}.data-unpacked}/DATA1 -type f | \
              xargs -P ${processes} -I {} bash -c '
                input="{}"
                base_name=$(basename "$input")
                output="''${base_name%.gz}"
                gzip -d -c "$input" > "DATA1/$output"
              '
            wait
          '';

          installPhase = ''
            mkdir -p "$out/DATA1"
            cp DATA1/* "$out/DATA1"
          '';
        };
        data-patched = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-data-patched";
          inherit version;
          src = ./strings.yaml;

          nativeBuildInputs = [
            self.packages.${system}.default
          ];

          unpackPhase = ''
            true
          '';

          buildPhase = ''
            echo "${resourceFilesStr}" | \
              xargs -P ${processes} -I {} bash -c '
                ssmm-patcher patch-resource \
                  -s $src \
                  "${self.packages.${system}.data-extracted}/DATA1/{}"
              '
          '';

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

          unpackPhase = ''
            true
          '';

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

          nativeBuildInputs = [
            self.packages.${system}.default
          ];

          unpackPhase = ''
            true
          '';

          buildPhase = ''
            cmd="ssmm-patcher pack-data"
            for f in ${self.packages.${system}.data-unpacked}/DATA1/*; do
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

          nativeBuildInputs = [
            ps2isopatcher.packages.${system}.default
          ];

          unpackPhase = ''
            true
          '';

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
          pkgs.poetry
          pkgs.ffmpeg
          pkgs.openai-whisper
          pkgs.dos2unix
          pkgs.vlc
          pkgs-clps2c.clps2c-compiler
        ];
        shellHook = ''
          export FONTCONFIG_FILE=${fontconfig_file}
        '';
      };
    });
}
