{
  description = "A very basic flake";

  inputs = {
    # Waiting for merge of https://github.com/NixOS/nixpkgs/pull/410329
    #nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nixpkgs.url = "github:Gigahawk/nixpkgs?ref=ssmm-patcher";
    flake-utils.url = "github:numtide/flake-utils";
    ssmm-patcher = {
      url = "path:./ssmm-patcher";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ps2str = {
      url = "github:Gigahawk/ps2str-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ssmm-mux = {
      url = "github:Gigahawk/ssmm-mux";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ps2isopatcher = {
      url = "github:Gigahawk/ps2isopatcher";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pcsx2-crctool = {
      url = "github:Gigahawk/pcsx2-crctool";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    ssmm-patcher,
    ps2str,
    ssmm-mux,
    ps2isopatcher,
    pcsx2-crctool,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs { inherit system; };
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
      mm-trial-iso = (pkgs.requireFile {
        name = "mm_trial.iso";
        url = "";
        sha256 = "0iabxh2kqgxm8pwn689wi26xziirzgjf1zdmb59bn89jji8nkaqb";
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
      elfNamePnach = builtins.replaceStrings ["." "_"] ["" "-"] elfName;
      pnachName = "${elfNamePnach}_8EFDBAEB";
      patches-buildPhase = files: ''
        runHook preBuild

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

        runHook postBuild
      '';
      # https://discourse.nixos.org/t/how-to-create-a-timestamp-in-a-nix-expression/30329/2
      lastModifiedStr = builtins.readFile "${pkgs.runCommand "timestamp" { when = self.lastModified; } "echo -n `date -d @$when +%Y-%m-%d_%H-%M-%S` > $out"}";
      # https://discourse.nixos.org/t/flakes-accessing-selfs-revision/11237/8
      revStr = "${toString (self.ref or self.shortRev or self.dirtyShortRev or "unknown")}_${lastModifiedStr}";
      version = "1";
      resourceFiles = import ./resource-files.nix;
      resourceFilesStr = builtins.concatStringsSep "\n" resourceFiles;
      fontconfig_file = pkgs.makeFontsConf {
        fontDirectories = [
          pkgs.freefont_ttf
          pkgs.comic-relief
          pkgs.sangyo_ttf
          pkgs.zerocool_ttf
          pkgs.saman_ttf
          pkgs.zcool-qingke-huangyou
          pkgs.fira-sans
        ];
      };
    in {
      packages = {
        default = self.packages.${system}.iso-patched;
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
        iso-trial-extracted = self.packages.${system}.iso-jp-extracted.overrideAttrs (old: {
          pname = "mm-trial-iso-extracted";
          srcs = [
            mm-trial-iso
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
        cutscenes-trial-demuxed = self.packages.${system}.cutscenes-jp-demuxed.overrideAttrs (old: {
          pname = "mm-trial-cutscenes-demuxed";
          buildPhase = cutscenes-demuxed-buildPhase self.packages.${system}.iso-trial-extracted;
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
        cutscenes-trial-mp4 = self.packages.${system}.cutscenes-jp-mp4.overrideAttrs (old: {
          pname = "mm-trial-cutscenes-mp4";
          buildPhase = cutscenes-mp4-buildPhase self.packages.${system}.cutscenes-trial-demuxed;
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
            ssmm-patcher.packages.${system}.ssmm-patcher
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
        data-trial-unpacked = self.packages.${system}.data-jp-unpacked.overrideAttrs (old: {
          pname = "mm-trial-data-unpacked";
          buildPhase = data-unpacked-buildPhase self.packages.${system}.iso-trial-extracted;
        });
        data-jp-unpacked-named = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-jp-data-unpacked-named";
          inherit version;
          src = null;
          dontUnpack = true;

          nativeBuildInputs = [
            ssmm-patcher.packages.${system}.ssmm-patcher
          ];

          dontBuild = true;

          installPhase = data-unpacked-named-installPhase self.packages.${system}.data-jp-unpacked;

          dontFixup = true;
        };
        data-cn-unpacked-named = self.packages.${system}.data-jp-unpacked-named.overrideAttrs (old: {
          pname = "mm-cn-data-unpacked-named";
          installPhase = data-unpacked-named-installPhase self.packages.${system}.data-cn-unpacked;
        });
        data-trial-unpacked-named = self.packages.${system}.data-jp-unpacked-named.overrideAttrs (old: {
          pname = "mm-trial-data-unpacked-named";
          installPhase = data-unpacked-named-installPhase self.packages.${system}.data-trial-unpacked;
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
            ssmm-patcher.packages.${system}.ssmm-patcher
          ];

          buildPhase = ''
            mkdir "$out"
            sv_font_src=070_00940549
            # HACK: need to pre patch sv_msg.gf before we copy it into all our files
            echo "Prepatching $sv_font_src font"
            ssmm-patcher patch-resource \
                -t ${self.packages.${system}.textures-imhex-analysis}/analysis/ \
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
            # Suppress Fontconfig error: Cannot load default config file: No such file: (null)
            export FONTCONFIG_FILE=${fontconfig_file}

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
                # Suppress Fontconfig error: No writable cache directories
                export XDG_CACHE_HOME="$(mktemp -d)"

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
            ssmm-patcher.packages.${system}.ssmm-patcher
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
            ssmm-patcher.packages.${system}.ssmm-patcher
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
            ssmm-patcher.packages.${system}.ssmm-patcher
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
        data-cn-extracted = self.packages.${system}.data-jp-extracted.overrideAttrs (old: {
          pname = "mm-cn-data-extracted";
          buildPhase = data-extracted-buildPhase self.packages.${system}.data-cn-unpacked;
        });
        data-trial-extracted = self.packages.${system}.data-jp-extracted.overrideAttrs (old: {
          pname = "mm-trial-data-extracted";
          buildPhase = data-extracted-buildPhase self.packages.${system}.data-trial-unpacked;
        });
        data-jp-extracted-named = self.packages.${system}.data-jp-extracted.overrideAttrs (old: {
          pname = "mm-jp-data-extracted-named";
          buildPhase = data-extracted-buildPhase self.packages.${system}.data-jp-unpacked-named;
        });
        data-strings-unique = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-data-strings-unique";
          inherit version;
          src = null;
          dontUnpack = true;

          nativeBuildInputs = [
            ssmm-patcher.packages.${system}.ssmm-patcher
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
            ssmm-patcher.packages.${system}.ssmm-patcher
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
        textures-generated = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-textures-generated";
          inherit version;
          src = ./textures;
          dontUnpack = true;
          nativeBuildInputs = [
            pkgs.imagemagick
            pkgs.pngquant
            ssmm-patcher.packages.${system}.ssmm-patcher
          ];

          buildPhase = ''
            export FONTCONFIG_FILE=${fontconfig_file}
            # Suppress Fontconfig error: No writable cache directories
            export XDG_CACHE_HOME="$(mktemp -d)"
            mkdir -p "$out"

            cp -r $src/* $out
            # Why do we need this?
            chmod -R 755 $out

            patchShebangs $out

            find "$out" -type f -name 'build.sh' | \
              xargs -P $NIX_BUILD_CORES -I {} bash -c '
                script_path="{}"
                script_dir=$(dirname "$script_path")
                cd "$script_dir"
                ./build.sh
              '
            wait
          '';

          dontInstall = true;
        };
        textures-imhex-analysis = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-textures-imhex-analysis";
          inherit version;
          src = ./imhex_patterns;
          dontUnpack = true;

          nativeBuildInputs = [
            pkgs.imhex
          ];

          buildPhase = ''
            # Suppress Fontconfig error: Cannot load default config file: No such file: (null)
            export FONTCONFIG_FILE=${fontconfig_file}
            # Suppress Fontconfig error: No writable cache directories
            export XDG_CACHE_HOME="$(mktemp -d)"
            export pattern_path=$src
            export textures_path=${self.packages.${system}.textures-generated}


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

          dontInstall = true;

          dontFixup = true;
        };
        data-patched = with import nixpkgs { inherit system; };
        stdenv.mkDerivation rec {
          pname = "mm-data-patched";
          inherit version;
          srcs = [
            ./strings.yaml
            ./credits.yaml
          ];
          dontUnpack = true;

          nativeBuildInputs = [
            ssmm-patcher.packages.${system}.ssmm-patcher
          ];


          buildPhase = ''
            paths=($srcs)
            export STRINGS_PATH="''${paths[0]}"
            export CREDITS_PATH="''${paths[1]}"
            echo "Strings path is $STRINGS_PATH"
            echo "Credits path is $CREDITS_PATH"
            echo "${resourceFilesStr}" | \
              xargs -P "$NIX_BUILD_CORES" -I {} bash -c '
                name="{}"
                echo "Patching $name"
                ssmm-patcher patch-font \
                  -o "{}" \
                  "${self.packages.${system}.font-prepatched}/sv_font_src" \
                  "${self.packages.${system}.data-jp-extracted}/DATA1/{}"

                ssmm-patcher patch-resource \
                  -s $STRINGS_PATH \
                  -c $CREDITS_PATH \
                  -t ${self.packages.${system}.textures-imhex-analysis}/analysis/ \
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
            ssmm-patcher.packages.${system}.ssmm-patcher
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
            pkgs.clps2c-compiler
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

          nativeBuildInputs = [
            pcsx2-crctool.packages.${system}.default
          ];

          buildPhase = patches-buildPhase "*";

          dontInstall = true;
          dontFixup = true;
        };
        debug-patches-post-patched = self.packages.${system}.debug-patches.overrideAttrs (old: {
          pname = "mm-debug-patches-post-patched";

          postBuild = ''
            new_crc=$(pcsx2-crctool ${self.packages.${system}.elf-patched}/${elfName}_patched)
            new_name="${elfNamePnach}_$new_crc.pnach"
            echo "Patched CRC is $new_crc, copying pnach to $new_name"
            cp "$out/${pnachName}.pnach" "$out/$new_name"
          '';
        });

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
            pkgs.ps2patchelf
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
        packages = [
          ssmm-patcher.packages.${system}.default
          ssmm-mux.packages.${system}.default
          ps2str.packages.${system}.default
          pkgs.ffmpeg
          pkgs.openai-whisper
          pkgs.dos2unix
          pkgs.vlc
          pkgs.imhex
          pkgs.rsbkb  # bgrep
          pkgs.clps2c-compiler
          pkgs.imagemagick
          pkgs.pngquant
        ];
        shellHook = ''
          export FONTCONFIG_FILE=${fontconfig_file}
        '';
      };
      devShells.win = pkgs.mkShell {
        packages = [
          pkgs.wget
          pkgs.apk-tools
          pkgs.qemu-utils
          pkgs.kmod
        ];
      };
    });
}
