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
      mm_iso = (pkgs.requireFile {
        name = "mm.iso";
        url = "";
        sha256 = "0nbsaqdvczcygk4frfyiiy4y3w7v6qc9ig3jvbiy032a11f5aycb";
      });
      version = "1";
      resourceFiles = [
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
        iso-extracted = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-iso-extracted";
          inherit version;
          srcs = [
            mm_iso
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
        cutscenes-demuxed = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-cutscenes-demuxed";
          inherit version;
          src = null;

          nativeBuildInputs = [
            ssmm-mux.packages.${system}.default
          ];

          unpackPhase = ''
            true
          '';

          buildPhase = ''
            find ${self.packages.${system}.iso-extracted} -name '*.PSS' -type f | \
              xargs -P ${processes} -I {} bash -c '
                input="{}"
                output="''${input#${self.packages.${system}.iso-extracted}/extracted/}"
                mkdir -p $(dirname "$output")
                ssmm-demux "$input" "$output"
              '
            wait
          '';

          installPhase = ''
            find . \
              \( -name '*.m2v' -o -name '*.ss2' \) | \
                xargs -P ${processes} -I {} install -Dm 755 "{}" "$out/demuxed/{}"
            wait
          '';
        };
        cutscenes-mp4 = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-cutscenes-mp4";
          inherit version;
          src = null;

          nativeBuildInputs = [
              pkgs.ffmpeg
          ];

          unpackPhase = ''
            true
          '';

          buildPhase = ''
            find ${self.packages.${system}.cutscenes-demuxed} -name '*.m2v' -type f | \
              xargs -P ${processes} -I {} bash -c '
                m2v="{}"
                base_name="''${m2v%.m2v}"
                ss2="''${base_name}.ss2"
                output="''${base_name#${self.packages.${system}.cutscenes-demuxed}/demuxed/}.mp4"
                mkdir -p $(dirname "$output")
                ffmpeg \
                  -i "$m2v" \
                  -i "$ss2" \
                  -c:v copy -c:a aac \
                  "$output"
            '
            wait
          '';
          installPhase = ''
            find . -name '*.mp4' | \
              xargs -P ${processes} -I {} install -Dm 755 "{}" "$out/mp4/{}"
            wait
          '';
        };
        cutscenes-remuxed = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-cutscenes-remuxed";
          inherit version;
          src = ./subs;
          nativeBuildInputs = [
            ps2str.packages.${system}.default
            pkgs.jq
            pkgs.ffmpeg
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
                m2v="${self.packages.${system}.cutscenes-demuxed}/demuxed/$base_name.m2v"
                ss2="${self.packages.${system}.cutscenes-demuxed}/demuxed/$base_name.ss2"
                mux="''${base_name}.mux"
                m2v_subbed="''${base_name}-sub.m2v"
                pss_subbed="''${base_name}-sub.PSS"
                mkdir -p $(dirname "$base_name")
                ffmpeg \
                  -i "$m2v" \
                  -vf "subtitles=$subs_file" \
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
              ${self.packages.${system}.iso-extracted}/extracted/PDATA/DATA0.BIN \
              ${self.packages.${system}.iso-extracted}/extracted/PDATA/DATA1.BIN \
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
          src = mm_iso;

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
          pkgs-clps2c.clps2c-compiler
        ];
        shellHook = ''
          export FONTCONFIG_FILE=${fontconfig_file}
        '';
      };
    });
}
