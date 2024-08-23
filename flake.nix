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
      inherit (poetry2nix.lib.mkPoetry2Nix { inherit pkgs; }) mkPoetryEnv defaultPoetryOverrides;
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
        extracted-iso = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-extracted-iso";
          version = "1";
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
              pkgs.ffmpeg
            ] ++ old.nativeBuildInputs
          );
          # TODO: per file bitrate
          buildPhase = ''
            ${old.buildPhase}

            export FONTCONFIG_FILE=${fontconfig_file}


            find ${self}/subs -type f -name '*_jp.srt' | sed "s#${self}/subs/##" | \
              xargs -P ${processes} -I {} bash -c '
                subs_file="{}"
                base_name="''${subs_file%_jp.srt}"
                ffmpeg \
                  -i "''${base_name}.m2v" \
                  -vf "subtitles=${self}/subs/$subs_file" \
                  -b:v 2M \
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
                cat "''${base_name}.mux"
                ps2str mux "''${base_name}.mux" "''${base_name}-sub.PSS"
              '
            wait
          '';
          installPhase = ''
            find . -name '*-sub.PSS' | \
              xargs -I {} install -Dm 755 "{}" "$out/remuxed/{}"
            wait
          '';
        });
      };
      #devShells.default = pkgs.mkShell {
      #  buildInputs = [
      #    poetryEnv
      #  ];
      #};
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