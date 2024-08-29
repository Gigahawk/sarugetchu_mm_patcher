{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    poetry2nix.url = "github:nix-community/poetry2nix";
    ps2str.url = "github:Gigahawk/ps2str-nix";
    ssmm-mux.url = "github:Gigahawk/ssmm-mux";
  };

  outputs = { self, nixpkgs, flake-utils, poetry2nix, ps2str, ssmm-mux, ... }:
    flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs { inherit system; };
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
        extracted-iso = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-extracted-iso";
          inherit version;
          srcs = [
            mm_iso
          ];
          sourceRoot = ".";

          nativeBuildInputs = [ pkgs.p7zip pkgs.tree ];

          unpackPhase = ''
            7z x "''${srcs[0]}"
          '';
        };
        cutscenes-demuxed = self.packages.${system}.extracted-iso.overrideAttrs(old: {
          pname = "mm-cutscenes-demuxed";
          nativeBuildInputs = (
            [
              ssmm-mux.packages.${system}.default
            ] ++ old.nativeBuildInputs
          );
          buildPhase = ''
            find . -name '*.PSS' -type f | \
              xargs -P ${processes} -I {} ssmm-demux {}
            wait
          '';
          installPhase = ''
            find . \
              \( -name '*.m2v' -o -name '*.ss2' \) | \
                xargs -P ${processes} -I {} install -Dm 755 "{}" "$out/demuxed/{}"
            wait
          '';
        });
        cutscenes-mp4 = self.packages.${system}.cutscenes-demuxed.overrideAttrs(old: {
          pname = "mm-cutscenes-mp4";
          nativeBuildInputs = (
            [
              pkgs.ffmpeg
            ] ++ old.nativeBuildInputs
          );
          buildPhase = ''

            ${old.buildPhase}

            find . -name '*.PSS' -type f | \
              xargs -P ${processes} -I {} bash -c '
                input_file="{}"
                base_name="''${input_file%.PSS}"
                ffmpeg \
                  -i "''${base_name}.m2v" \
                  -i "''${base_name}.ss2" \
                  -c:v copy -c:a aac \
                  "''${base_name}.mp4"
            '
            wait
          '';
          installPhase = ''
            find . -name '*.mp4' | \
              xargs -P ${processes} -I {} install -Dm 755 "{}" "$out/mp4/{}"
            wait
          '';
        });
        cutscenes-remuxed = self.packages.${system}.cutscenes-demuxed.overrideAttrs(old: {
          pname = "mm-cutscenes-remuxed";
          nativeBuildInputs = (
            [
              ps2str.packages.${system}.default
              pkgs.jq
              pkgs.ffmpeg
            ] ++ old.nativeBuildInputs
          );
          buildPhase = ''
            ${old.buildPhase}

            export FONTCONFIG_FILE=${fontconfig_file}

            find ${self}/subs -type f -name '*.json' | \
              xargs -P ${processes} -I {} bash -c '
                meta_file="{}"
                subs_file="$(dirname $meta_file)/$(jq -r '.file' $meta_file)"
                bitrate="$(jq -r '.bitrate' $meta_file)"
                base_name="$(echo ''${meta_file%.json} | sed 's#${self}/subs/##')"
                ffmpeg \
                  -i "''${base_name}.m2v" \
                  -vf "subtitles=$subs_file" \
                  -b:v "$bitrate" \
                  "''${base_name}-sub.m2v"
                cat <<EOF > "''${base_name}.mux"
            pss
                stream video:0
                    input "''${base_name}-sub.m2v"
                end
                stream pcm:0
                    input "''${base_name}.ss2"
                end
            end
            EOF
                ps2str mux "''${base_name}.mux" "''${base_name}-sub.PSS"
              '
            wait
          '';
          installPhase = ''
            find . -name '*-sub.PSS' | \
              xargs -P ${processes} \
                -I {} install -Dm 755 "{}" "$out/remuxed/{}"
            wait
          '';
        });
        data-unpacked = self.packages.${system}.extracted-iso.overrideAttrs(old: {
          pname = "mm-data-unpacked";
          nativeBuildInputs = (
            [
              self.packages.${system}.ssmm-patcher
            ] ++ old.nativeBuildInputs
          );
          buildPhase = ''
            ssmm-patcher unpack-data PDATA/DATA0.BIN PDATA/DATA1.BIN -o PDATA/DATA1

            # All files in DATA1 are gzip files
            find PDATA/DATA1 -type f | \
              xargs -P ${processes} -I {} mv "{}" "{}.gz"
            wait
          '';
          installPhase = ''
            mkdir -p "$out/DATA1"
            cp -a PDATA/DATA1/* "$out/DATA1"
          '';
        });
        data-extracted = self.packages.${system}.data-unpacked.overrideAttrs(old: {
          pname = "mm-data-extracted";
          buildPhase = ''
            ${old.buildPhase}

            # All files in DATA1 are gzip files
            find PDATA/DATA1 -type f | \
              xargs -P ${processes} -I {} gzip -d "{}"
            wait
          '';
        });
        data-patched = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-data-patched";
          inherit version;
          src = ./strings.yaml;

          nativeBuildInputs = [
            self.packages.${system}.default
          ];

          unpackPhase = ''
            cp $src strings.yaml
          '';

          buildPhase = ''
            echo "${resourceFilesStr}" | \
              xargs -P ${processes} -I {} bash -c '
                ssmm-patcher patch-resource \
                  "${self.packages.${system}.data-extracted}/DATA1/{}"
                gzip "{}_patched"
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
              patched="${self.packages.${system}.data-patched}/DATA1_patched/''${name}_patched.gz"
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
        ];
        shellHook = ''
          export FONTCONFIG_FILE=${fontconfig_file}
        '';
      };
    });
}