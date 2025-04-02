import re
import shutil
import json
from urllib.parse import unquote
from collections import defaultdict
import sys
import zlib
import csv
import subprocess
import hashlib
from pprint import pformat
from typing import Any, Iterable
from pathlib import Path, PurePath
import gzip
import io
from concurrent.futures import ThreadPoolExecutor
from multiprocessing.pool import ThreadPool, AsyncResult
import os
from time import sleep

import yaml
from ps2isopatcher.iso import Ps2Iso, TreeFile, walk_tree
import click
from PIL import Image
from pathvalidate import sanitize_filepath
from pathvalidate import sanitize_filename

import sarugetchu_mm_patcher.util as util
import sarugetchu_mm_patcher.mux as mux
from sarugetchu_mm_patcher.index import (
    IndexEntry, get_index_list, index_list_to_bin
)
from sarugetchu_mm_patcher.encoding import (
    EncodingTranslator,
    ENCODING_MAP,
    BYTES_TO_CHAR_MINIMAL, BYTES_TO_CHAR_DEFAULT, BYTES_TO_CHAR_SPECIAL,
    token_to_idx,
    idx_to_token
)
from sarugetchu_mm_patcher.aseprite import AsepriteDumper

EXTRACT_PATH = Path(".extracted")
DATA0_PATH = "/PDATA/DATA0.BIN;1"
DATA1_PATH = "/PDATA/DATA1.BIN;1"

@click.group()
def cli():
    pass

def _guess_hash(fname: str | Path):
    fname = Path(Path(fname).stem).name
    _, name_hash = fname.split("_")
    return name_hash

def _parse_imhex_json(imhex_json: str | Path):
    with open(imhex_json) as f:
        return json.load(f)["file"]

def _print_headers(
        iso: Ps2Iso,
        header_len: int=32
):
    paths = [DATA0_PATH, DATA1_PATH]
    def _extract(path) -> bytes:
        click.echo(f"Opening {path}")
        f: TreeFile = iso.get_object(path)
        data = f.data
        click.echo(f"Done extracting {path}")
        return data
    with ThreadPool(processes=2) as p:
        index, archives = p.map(_extract, paths)
    index_list = get_index_list(index)

    for entry in index_list:
        start = entry.address*iso.block_size
        archive = archives[
            start:start + entry.size
        ]
        with io.BytesIO(archive) as bio:
            with gzip.GzipFile(fileobj=bio, mode="rb") as gzip_file:
                extracted = gzip_file.read()
        click.echo(
            f"{entry.name_str}: {extracted[0:header_len].hex(sep=' ').upper()}"
        )

def _write_mux_file(path: Path, m2v_path: Path, ss2_path: Path):
    template = f"""
pss

	stream video:0
		input "{m2v_path.resolve()}"
	end

	stream pcm:0
		input "{ss2_path.resolve()}"
	end
end
"""
    with open(path, "w") as f:
        f.write(template)

def patch_cutscenes(
    iso: Ps2Iso,
    subs: dict[str, dict[str, str]],
) -> list[tuple[str, bytes]]:
    changes = []
    for path, info in subs.items():
        pss_file = (Path("/") / path).with_suffix(".PSS;1")
        m2v_file = (EXTRACT_PATH / path).with_suffix(".m2v")
        ss2_file = (EXTRACT_PATH / path).with_suffix(".ss2")
        subbed_file = (EXTRACT_PATH / path).with_suffix(".sub.m2v")
        mux_file = (EXTRACT_PATH / path).with_suffix(".mux")
        srt_file = Path("subs") / info["srt"]
        remuxed_file = (EXTRACT_PATH / path).with_suffix(".sub.PSS")
        bitrate = info.get("bitrate", "2M")
        pf: TreeFile = iso.get_object(str(pss_file))
        _export_video(pf)
        cmd = [
            "ffmpeg", "-y",
            "-i", str(m2v_file),
            "-vf", f"subtitles={srt_file}",
            "-b:v", bitrate,
            str(subbed_file)
        ]
        click.echo(f"Encoding subs into {path} with cmd {cmd}")
        subprocess.run(cmd)

        _write_mux_file(mux_file, subbed_file, ss2_file)
        cmd = [
            "ps2str", "mux", str(mux_file), str(remuxed_file)
        ]
        click.echo(f"Encoding done for {path}, remuxing with cmd {cmd}")
        subprocess.run(cmd)
        click.echo(f"Remuxing done for {path}, reading file back")
        with open(remuxed_file, "rb") as f:
            changes.append((str(pss_file), f.read()))
    return changes

def open_mutable(input: str | os.PathLike) -> AsyncResult:
    def _thread():
        return Ps2Iso(input, mutable=True)
    pool = ThreadPool(processes=1)
    async_result = pool.apply_async(_thread)
    return async_result

def open_iso(
        input: str | os.PathLike, mutable=False
) -> tuple[Ps2Iso, AsyncResult | None]:
    click.echo(f"Opening {input}")
    iso = Ps2Iso(input)
    if mutable:
        iso_async_result = open_mutable(input)
    else:
        iso_async_result = None
    return iso, iso_async_result

input_opt = click.option(
    "-i", "--input",
    default="Sarugetchu - Million Monkeys (Japan).iso",
    show_default=True,
    type=click.Path(),
)

@cli.command()
@click.option(
    "-i", "--input",
    default="Sarugetchu - Million Monkeys (Japan).iso",
    show_default=True,
    type=click.Path(),
)
@click.option(
    "-n", "--num-bytes",
    default=32,
    type=int,
)
def print_headers(
    input: str | os.PathLike,
    num_bytes: int
):
    click.echo(f"Opening {input}")
    iso = Ps2Iso(input)
    _print_headers(iso, header_len=num_bytes)

@cli.command()
@click.argument(
    "pack_path",
    type=str
)
def print_hash(pack_path: str):
    hash = util.gen_packinfo_hash(pack_path)
    print(f"{hash.hex(sep=' ').upper()}: {pack_path}")

def _get_row_idx(rows: list[list[Any]], hash: int) -> int | None:
    return next(
        (idx for idx, row in enumerate(rows) if row[0] == hash),
        None
    )

def _read_csv(csv_path) -> list[list[Any]]:
    with open(csv_path, "r", newline="") as csvfile:
        reader = csv.reader(csvfile)
        rows = [row for row in reader]
    for row in rows:
        row[0] = int(row[0], 16)
    return rows

@cli.command()
@click.argument(
    "csv_path",
    type=click.Path()
)
def update_hash_list(csv_path):
    rows = _read_csv(csv_path)

    for line in sys.stdin.readlines():
        line = line.strip()
        hash = util.gen_packinfo_hash(line)
        row_idx = _get_row_idx(rows, int.from_bytes(hash))
        if row_idx is None:
            click.echo(
                f"Warning: '{line}' evaluates to {hash.hex(sep=' ').upper()}, "
                f"which is not a hash that shows up in {csv_path}"
            )
        else:
            if len(rows[row_idx]) > 1:
                rows[row_idx][1] = line
            else:
                rows[row_idx].append(line)

    for row in rows:
        row[0] = f"{row[0]:08x}"
    with open(csv_path, "w", newline="") as csvfile:
        writer = csv.writer(csvfile, dialect=csv.unix_dialect)
        for row in rows:
            writer.writerow(row)

@cli.command()
@click.argument(
    "csv_path",
    type=click.Path()
)
def validate_hash_list(csv_path):
    rows = _read_csv(csv_path)
    ok = True
    num_rows = len(rows)
    num_named = 0
    for row in rows:
        hash, name = row
        if not name:
            continue
        num_named += 1
        hash = hash.to_bytes(4, "big").hex().lower()
        calc_hash = util.gen_packinfo_hash(name).hex().lower()
        if hash != calc_hash:
            click.echo(
                f"Error: '{name}' is linked to '{hash}', "
                f"but hashes to '{calc_hash}'"
            )
            ok = False
    click.echo(
        f"{num_named}/{num_rows} rows have names "
        f"({num_named/num_rows*100:.2f}%)"
    )
    if not ok:
        raise ValueError("Some hashes are incorrect")
    else:
        click.echo("All hashes OK")

@cli.command()
@click.argument(
    "csv_path",
    type=click.Path()
)
@click.argument(
    "hash",
    type=str
)
def hash_to_path(csv_path, hash):
    rows = _read_csv(csv_path)
    row_idx = _get_row_idx(rows, int(hash, 16))
    if row_idx is None:
        click.echo(f"Error: Hash '{hash}' is not present in {csv_path}")
        exit(1)
    path = rows[row_idx][1]
    if not path:
        click.echo(f"Hash '{hash}' does not have a known path name")
        exit(2)
    click.echo(path)

@cli.command()
@click.option(
    "-s", "--strings",
    default="strings.yaml",
    show_default=True,
    type=click.Path(),
)
def print_strings(strings):
    with open(strings, "r") as f:
        strings_dict = yaml.safe_load(f)
    click.echo(pformat(strings_dict))

def _export_video(file: TreeFile, recombine=False):
    click.echo(f"Exporting {file.path}")
    file.export(
        EXTRACT_PATH, preserve_path=True
    )
    src_path = EXTRACT_PATH / file.path_no_ver[1:]
    video_path = src_path.with_suffix(".m2v")
    audio_path = src_path.with_suffix(".ss2")
    combined_path = src_path.with_suffix(".mp4")
    click.echo(f"Done exporting {file.path}")
    # For some reason ps2str breaks on some of the files, use ssmm-demux instead
    #cmd = [
    #    "ps2str", "demux",
    #    "-d", str(EXTRACT_PATH / file.parent.path[1:]),
    #    str(EXTRACT_PATH / file.path_no_ver[1:]),
    #]
    cmd = [
        "ssmm-demux",
        str(src_path),
    ]
    click.echo(f"Demuxing video {src_path} with command: {cmd}")
    subprocess.run(cmd)
    click.echo(f"Done demuxing video {src_path}")

    if recombine:
        cmd = [
            "ffmpeg",
            "-i", str(video_path),
            "-i", str(audio_path),
            "-c:v", "copy",
            "-c:a", "aac",
            str(combined_path),
        ]
        click.echo(f"Combining {src_path} video streams to mp4 with command: {cmd}")
        subprocess.run(cmd)
        click.echo(f"Done combining {src_path} video streams")


@cli.command()
@input_opt
def dump_video(input):
    iso, _ = open_iso(input)
    with ThreadPoolExecutor(max_workers=64) as tpe:
        for _, _, files in walk_tree(iso.tree):
            for file in files:
                path = file.path.split(";")[0].upper()
                if path.endswith(".PSS"):
                    tpe.submit(_export_video, file, {"recombine": True})

    # HACK: console seems to get messed up by the concurrency
    subprocess.run(["stty", "sane"])

@cli.command()
@click.argument(
    "index_path",
    type=click.Path(),
)
@click.argument(
    "data_path",
    type=click.Path(),
)
@click.option(
    "-o", "--output-path",
    default=None,
    show_default=True,
    type=click.Path(),
)
def unpack_data(index_path, data_path, output_path):
    index_path = Path(index_path)
    data_path = Path(data_path)
    if output_path is None:
        output_path = Path(os.getcwd()) / data_path.stem
    else:
        output_path = Path(output_path)
    output_path.mkdir(exist_ok=True, parents=True)
    with open(index_path, "rb") as f:
        index_bytes = f.read()
    with open(data_path, "rb") as f:
        data_bytes = f.read()
    def _dump_entry(t: tuple[int, IndexEntry]):
        idx, entry = t
        start = entry.address*2048
        with open(output_path / f"{idx:03}_{entry.name_str}", "wb") as f:
            f.write(data_bytes[start:start + entry.size])
    index_list = get_index_list(index_bytes)
    with ThreadPool(processes=32) as p:
        p.imap_unordered(_dump_entry, enumerate(index_list))
        p.close()
        p.join()

@cli.command()
@click.option(
    "-i", "--index-path",
    default=None,
    type=click.Path(),
)
@click.option(
    "-d", "--data-path",
    default=None,
    type=click.Path(),
)
@click.option(
    "-e", "--entry",
    nargs=2,
    type=click.Tuple([str, click.Path()]),
    multiple=True
)
def pack_data(index_path, data_path, entry):
    if index_path is None:
        index_path = Path(os.getcwd()) / "DATA0.BIN"
    else:
        index_path = Path(index_path)
    if data_path is None:
        data_path = Path(os.getcwd()) / "DATA1.BIN"
    else:
        data_path = Path(data_path)
    with open(index_path, "wb") as index_file:
        with open(data_path, "wb") as data_file:
            address = 0
            index_list = []
            for hash, entry_name in entry:
                print(f"Creating entry for {hash}")
                hash_bytes = bytes.fromhex(hash)
                if len(hash_bytes) != 4:
                    raise ValueError(f"Invalid hash {hash}")
                with open(entry_name, "rb") as entry_file:
                    entry_bytes = entry_file.read()
                size = len(entry_bytes)
                padded = util.pad(entry_bytes)
                index = IndexEntry(
                    hash_bytes,
                    address,
                    size,
                )
                index_list.append(index)
                data_file.write(padded)
                address += util.blocks_required(size)
            index_file.write(index_list_to_bin(index_list))

def _needs_strings_patch(imhex_analysis) -> bool:
    pattern = re.compile(r"\.gf0")
    return bool(util.find_img_subfile(imhex_analysis, pattern))

def _patch_strings(resource_bytes, hash, strings_path):
    source_encoder = EncodingTranslator(hash)
    with open(strings_path, "r") as f:
        strings_dict = yaml.safe_load(f)
    if not strings_dict:
        raise ValueError(f"Empty strings file {strings_path}")

    if util.find_strings(resource_bytes, "sv_msg.gf0"):
        # Sorta hacky, technically this should always be the default font
        target_encoder = EncodingTranslator(hash)
    else:
        target_encoder = EncodingTranslator(encoding=BYTES_TO_CHAR_MINIMAL)

    for jap_str, info in strings_dict.items():
        jap_bytestrs = source_encoder.string_to_bytes(jap_str)

        # TODO: support other langs?
        try:
            english = info["english"]
        except KeyError:
            click.echo(f"Error: did not find english data for {jap_str}")
            raise

        if isinstance(english, str):
            id = None
            try:
                bs = target_encoder.string_to_bytes(english)[0]
            except IndexError as e:
                click.echo(
                    f"Error: could not encode {repr(english)}"
                )
                raise e
            replacements = {id: bs}
        elif isinstance(english, dict):
            replacements = {}
            for id, s in english.items():
                replacements[bytes.fromhex(id)] = target_encoder.string_to_bytes(s)[0]
        else:
            raise ValueError(f"invalid translation structure {english}")

        for jb in jap_bytestrs:
            for id, new_bytestr in replacements.items():
                resource_bytes.replace_in_place(
                    source_encoder.wrap_string(jb, id=id),
                    target_encoder.wrap_string(new_bytestr, id=id),
                )
    return resource_bytes


@cli.command()
@click.argument(
    "resource_path",
    type=click.Path(),
)
@click.argument(
    "imhex_json",
    type=click.Path()
)
@click.option(
    "-s", "--strings-path",
    default=None,
    show_default=True,
    type=click.Path(),
)
@click.option(
    "-t", "--textures-imhex-path",
    default=None,
    show_default=True,
    type=click.Path()
)
@click.option(
    "--hash",
    default=None,
    type=str
)
@click.option(
    "-o", "--output-path",
    default=None,
    show_default=True,
    type=click.Path(),
)
def patch_resource(
    resource_path, strings_path, textures_imhex_path, hash, output_path, imhex_json
):
    imhex_analysis = _parse_imhex_json(imhex_json)
    should_patch_strings = _needs_strings_patch(imhex_analysis["texturefactory"])
    if hash is None:
        hash = _guess_hash(resource_path)
    resource_path = Path(resource_path)
    if strings_path is None:
        strings_path = Path(os.getcwd()) / "strings.yaml"
    else:
        strings_path = Path(strings_path)
    if textures_imhex_path:
        textures_imhex_path = Path(textures_imhex_path)
        if not textures_imhex_path.is_dir():
            click.echo(f"Warning: texture path {textures_imhex_path} does not exist.")
            textures_imhex_path = None
    if output_path is None:
        output_path = Path(os.getcwd()) / f"{resource_path.stem}_patched"
    else:
        output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with open(resource_path, "rb") as f:
        resource_bytes = util.TrackedByteArray(f.read())

    # Note: patch textures first so imhex_json addresses are accurate
    if textures_imhex_path:
        tex_fds = imhex_analysis["texturefactory"]["img_sub_files"]
        for manifest_path in textures_imhex_path.glob("**/manifest.yaml"):
            img_data = _parse_imhex_json(
                manifest_path.with_name("texture.json")
            )
            with open(manifest_path, "r") as f:
                tex_manifest = yaml.safe_load(f)
            bpp = tex_manifest["bpp"]
            tex_path = tex_manifest["path"]
            cel_chunk = util.ImhexChunkFinder(img_data, "CelChunk").chunks[0]
            palette_chunk = util.ImhexChunkFinder(img_data, "PaletteChunk").chunks[0]

            if "COMPRESSED_IMG" in cel_chunk["type"]:
                cel_chunk_data = bytes(cel_chunk["data"])
                cel_chunk_data = zlib.decompress(cel_chunk_data)
            elif "RAW" in cel_chunk["type"]:
                cel_chunk_data = bytes(cel_chunk["data"]["data"])

            # Aseprite will do shift the texture position to avoid storing
            # blank rows and columns, add them back in
            cel_x_pos = cel_chunk["x_pos"]
            cel_y_pos = cel_chunk["y_pos"]
            cel_width = cel_chunk["width"]
            cel_height = cel_chunk["height"]
            canvas_width = img_data["header"]["px_width"]
            canvas_height = img_data["header"]["px_height"]
            trans_idx = img_data["header"]["transparent_color_idx"]
            cel_chunk_data = util.recenter_aseprite_cel_data(
                cel_chunk_data, trans_idx, canvas_width, canvas_height,
                cel_x_pos, cel_y_pos, cel_width, cel_height
            )


            for fd in tex_fds:
                if "img_sub_file" in fd:
                    subfile = fd["img_sub_file"]
                elif "img_sub_file2" in fd:
                    subfile = fd["img_sub_file2"]
                else:
                    print("no subfile found")
                    import pdb;pdb.set_trace()
                    continue
                fname = subfile["fname"]["string"]
                if tex_path == fname:
                    px_data = util.aseprite_to_pixel_data(
                        cel_chunk_data, bpp
                    )
                    img_data_ptr = (
                        subfile["metadata"]["ptr"]["*(ptr)"]
                            ["entries"][0]["data"]["ptr"]["*(ptr)"]
                            ["idk_data_ptr"]["nullptr"]
                    )
                    resource_bytes[
                        img_data_ptr:img_data_ptr + len(px_data)
                    ] = px_data

                    palette_meta = (
                        subfile["metadata"]["ptr"]["*(ptr)"]
                            ["entries"][1]["data"]["ptr"]["*(ptr)"]
                    )
                    palette_width = palette_meta["width"]
                    palette_height = palette_meta["height"]
                    plt_data = util.aseprite_to_palette_data(
                        palette_chunk["entries"],
                        max_entries=palette_width*palette_height
                    )
                    palette_data_ptr = palette_meta["idk_data_ptr"]["nullptr"]
                    resource_bytes[
                        palette_data_ptr:palette_data_ptr + len(plt_data)
                    ] = plt_data

    if should_patch_strings:
        resource_bytes = _patch_strings(resource_bytes, hash, strings_path)

    resource_bytes = util.patch_file_offsets(resource_bytes, imhex_analysis)
    #resource_bytes = util.patch_entity_addrs(resource_bytes, orig_entity_offset_idxs)
    with open(output_path, "wb") as f:
        f.write(resource_bytes)

@cli.command()
@click.argument(
    "target",
    type=str,
)
@click.argument(
    "extracted_path",
    type=click.Path(),
)
@click.option(
    "-c", "--csv-path",
    type=click.Path(),
    default=None
)
@click.option(
    "--hex/--no-hex", "hex_",
    default=False,
)
@click.option(
    "--hash",
    default=None,
    type=str
)
@click.option(
    "--print-to-null/--no-print-to-null",
    default=True,
)
def find_string(target, extracted_path, csv_path, print_to_null, hash, hex_):
    if csv_path is not None:
        rows = _read_csv(csv_path)
    else:
        rows = []
    encoder = EncodingTranslator(hash)
    if not hex_:
        target_bytes = encoder.string_to_bytes(target)
    else:
        _target_bytes = bytes(bytearray.fromhex(target))
        target = encoder.bytes_to_string(_target_bytes)
        target_bytes = [_target_bytes]
    click.echo(f"Looking for '{target}'")
    for tb in target_bytes:
        click.echo(tb.hex(sep=" "))
    extracted_path = Path(extracted_path)
    for path in extracted_path.glob("**/*"):
        if not path.is_file():
            continue
        with open(path, "rb") as f:
            data = f.read()
        for tb in target_bytes:
            if tb in data:
                try:
                    hash = int(str(path).split("_")[-1], 16)
                except ValueError:
                    hash = 0
                row_idx = _get_row_idx(rows, hash)
                if row_idx is not None:
                    name = rows[row_idx][1]
                else:
                    name = ""
                file_idx = data.index(tb)
                if print_to_null:
                    null_idx = data.index(b"\x00", file_idx)
                    tb = data[file_idx:null_idx]
                string = encoder.bytes_to_string(tb)
                click.echo(
                    f"Found match in {path} ({name}) at {hex(file_idx)}:{tb.hex(sep=" ")}"
                )
                click.echo(string)
                click.echo(tb.hex(sep=" "))

def _empty_buffers(root: dict):
    if isinstance(root, dict):
        for key in root.keys():
            obj = root[key]
            if isinstance(obj, list):
                if all([isinstance(i, int) for i in obj]):
                    root[key] = "<list<int>>"
                else:
                    root[key] = [
                        _empty_buffers(i) for i in obj
                    ]
            elif isinstance(obj, dict):
                root[key] = _empty_buffers(obj)
    return root

@cli.command()
@click.argument(
    "imhex_json",
    type=click.Path()
)
@click.option(
    "-o", "--output-path",
    default=None,
    show_default=True,
    type=click.Path(),
)
@click.option(
    "-e", "--exclude-exts",
    multiple=True,
    default=[".gf0", ".gf1"],
    type=str
)
@click.option(
    "-i", "--include-exts",
    multiple=True,
    default=[],
    type=str
)
def dump_textures(imhex_json, output_path, include_exts, exclude_exts):
    imhex_json = Path(imhex_json)
    if output_path is None:
        output_path = Path(os.getcwd()) / imhex_json.with_suffix(".textures")
    else:
        output_path = Path(output_path)
    data = _parse_imhex_json(imhex_json)["texturefactory"]
    file_descriptors = data["img_sub_files"]
    for fd in file_descriptors:
        class_id = fd["class_id"]
        if "img_sub_file" in fd:
            subfile = fd["img_sub_file"]
        elif "img_sub_file2" in fd:
            subfile = fd["img_sub_file2"]
        else:
            print(f"warning: no subfile found in {imhex_json}")
            continue
        fname = unquote(subfile["fname"]["string"])
        # Strip leading slashes
        _fname = fname
        while _fname[0] in ["/", "\\"]:
            _fname = _fname[1:]
        target_path = sanitize_filepath(output_path / _fname)
        click.echo(f"Found file '{fname}' with class ID {class_id}")

        ext = Path(fname.strip('\x00')).suffix.lower()
        if (ext in exclude_exts) or (include_exts and ext not in include_exts):
            click.echo(f"Skipping file with extension '{ext}'")
            continue

        target_path.mkdir(parents=True, exist_ok=True)

        metadata = subfile["metadata"]["ptr"]["*(ptr)"]
        num_entries = metadata["num_entries"]
        if num_entries in [1, 2]:
            img_data = metadata["entries"][0]
            img_width = img_data["width"]
            img_height = img_data["height"]
            click.echo(f"width, height = {img_width}, {img_height}")
            img_pxs, img_bins = util.px_data_to_imgs(img_data)

            if num_entries == 2:
                click.echo("Image appears to be paletted")
                plt_data = metadata["entries"][1]

                plt_pxs, plt_bins = util.px_data_to_imgs(plt_data, unswizzle_plt=True)
                plt_px, plt_bin = plt_pxs[0], plt_bins[0]

                plt_width = plt_data["width"]
                plt_height = plt_data["height"]
                plt_pil = util.img_buf_to_pillow(
                    plt_px, plt_width, plt_height
                )
                plt_pil.save(target_path / "palette.png")
                with open(target_path / "palette.bin", "wb") as f:
                    f.write(plt_bin)
            else:
                click.echo("Image appears to be direct color")
                plt_px = None

            for idx, (img_px, img_bin) in enumerate(zip(img_pxs, img_bins)):
                img_pil = util.img_buf_to_pillow(
                    img_px, img_width, img_height, plt_img=plt_px
                )
                img_pil.save(target_path / f"{idx:04d}.png")
                with open(target_path / f"{idx:04d}.bin", "wb") as f:
                    f.write(img_bin)

                if plt_px:
                    with open(target_path / f"{idx:04d}.aseprite", "wb") as f:
                        f.write(
                            AsepriteDumper(
                                img_width, img_height, plt_px, img_px
                            ).file
                        )
        else:
            click.echo(
                f"WARNING: metadata contains {num_entries} pixel data entries, "
                "not parsing"
            )

        manifest = _empty_buffers(fd)
        with open(target_path / "manifest.yaml", "w") as f:
            yaml.dump(manifest, f)



@cli.command()
@click.argument(
    "imhex_json",
    type=click.Path()
)
@click.option(
    "-h", "--hash",
    default=None,
    show_default=True,
    type=str,
)
@click.option(
    "-o", "--output-path",
    default=None,
    show_default=True,
    type=click.Path(),
)
def dump_strings(imhex_json, hash, output_path):
    imhex_json = Path(imhex_json)
    if output_path is None:
        output_path = Path(os.getcwd()) / imhex_json.name
    output_path = Path(output_path)
    csv_path = output_path.with_suffix(".strings.csv")
    yaml_path = output_path.with_suffix(".strings.yaml")
    if hash is None:
        hash = _guess_hash(imhex_json)
    data = _parse_imhex_json(imhex_json)
    strings = data["strings"]
    try:
        translator = EncodingTranslator(hash)
    except KeyError:
        click.echo(f"Warning: No encoding map defined for {hash}, falling back to default encoding")
        translator = EncodingTranslator(encoding=BYTES_TO_CHAR_DEFAULT)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    manifest = defaultdict(list)
    with open(csv_path, "w") as f:
        for string in strings:
            addr = hex(int(string["__address"]))
            str_id = string["id"].to_bytes(4, "little").hex()
            string_raw = bytes(string["string"]).strip(b'\x00')
            alloc_len = string["str_len"]
            actual_len = len(string_raw)

            f.write(
                f"\"Found string at {addr} with id {str_id}; "
                f"allocation length {alloc_len}; "
                f"actual length {actual_len}\"\n"
            )
            if alloc_len > actual_len:
                f.write("ALLOC BIGGER THAN STRING LEN\n")

            try:
                string_tokens = translator.tokenize_string(string_raw)

                line_out = ""
                for token in string_tokens:
                    line_out += f'"{token.hex().upper()}",'
                f.write(line_out)
                f.write("\n")

                line_out = ""
                full_str = ""
                for token in string_tokens:
                    char = translator.bytes_to_char[token]
                    if char == "\n":
                        char = "\\n"
                    elif char == "\f":
                        char = "\\f"
                    full_str += char
                    line_out += f'"{char}",'
                f.write(line_out)
                f.write("\n")
                f.write(full_str)
                f.write("\n")

                manifest[full_str].append(str_id)
            except ValueError:
                f.write("STRING CONTAINS INVALID TOKENS\n")
                f.write(f'"{string_raw.hex(" ")}"\n')
                f.write(f'"{string_raw}"\n')
    with open(yaml_path, "w") as f:
        f.write(
            yaml.dump(manifest, allow_unicode=True, default_style='"')
        )

@cli.command()
@click.option(
    "-i", "--imhex-json",
    default=None,
    show_default=True,
    type=click.Path(),
)
@click.option(
    "-t", "--textures-path",
    default=None,
    show_default=True,
    type=click.Path(),
)
@click.option(
    "-o", "--output-path",
    default=None,
    show_default=True,
    type=click.Path(),
)
@click.pass_context
def dump_fonts(ctx, imhex_json, textures_path, output_path):
    font_exts = [".gf0", ".gf1"]
    imhex_json = Path(imhex_json)
    if not output_path and textures_path:
        output_path = textures_path
    elif not textures_path and output_path:
        textures_path = output_path
    else:
        output_path = Path(os.getcwd()) / imhex_json.name
        textures_path = output_path
    output_path = Path(output_path)
    textures_path = Path(textures_path)

    if imhex_json:
        ctx.invoke(
            dump_textures,
            imhex_json=imhex_json,
            output_path=textures_path,
            include_exts=font_exts,
            exclude_exts=[]
        )
    else:
        textures_path = Path(textures_path)


    for root, _, _ in textures_path.walk():
        if root.suffix not in font_exts:
            continue
        file_idx = int(str(root)[-1])
        for img in root.glob("*.png"):
            try:
                img_idx = int(img.stem)
            except ValueError:
                continue
            font_idx = img_idx*2 + file_idx
            try:
                token = idx_to_token(font_idx).hex().upper()
            except KeyError:
                click.echo(f"Warning: no token precomputed for index {font_idx}")
                token = "????"
            _out_dir = output_path / (root.with_suffix(".gf").name)
            _out_dir.mkdir(parents=True, exist_ok=True)
            _out_path = _out_dir / f"{font_idx:04d}_{token}.png"
            click.echo(f"Found texture file {img}, copying to {_out_path}")
            shutil.copyfile(img, _out_path)


@cli.command()
@click.argument(
    "font_src_path",
    type=click.Path(),
)
@click.argument(
    "resource_path",
    type=click.Path(),
)
@click.option(
    "-o", "--output-path",
    default=None,
    show_default=True,
    type=click.Path(),
)
def patch_font(font_src_path, resource_path, output_path):
    font_src_path = Path(font_src_path)
    resource_path = Path(resource_path)

    if output_path is None:
        output_path = Path(os.getcwd()) / f"{resource_path.stem}_patched"
    else:
        output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with open(font_src_path, "rb") as f:
        font_src_bytes = bytearray(f.read())
    with open(resource_path, "rb") as f:
        resource_bytes = bytearray(f.read())

    translator = EncodingTranslator(encoding=BYTES_TO_CHAR_DEFAULT)
    source_ex = util.ImgExtractor(font_src_bytes, "sv_msg.gf0")
    string_data = util.find_strings(resource_bytes, ".gf0")
    blacklist = [
        # Don't patch the base font
        b"sv_msg.gf0",
        # This file appears to have smaller 16x16 images, not sure what it's
        # used for
        b"sv_msg_2.gf0"
    ]
    for sd in string_data:
        if sd["value"] in blacklist:
            continue
        click.echo(f"Patching {resource_path} / {sd['value']}")
        target_ex = util.ImgExtractor(resource_bytes, sd["value"])
        for token, char in BYTES_TO_CHAR_MINIMAL.items():
            if token in BYTES_TO_CHAR_SPECIAL:
                continue
            target_token_idx = token_to_idx(token)
            if target_token_idx % 2:
                continue
            target_token_idx = token_to_idx(token)//2
            _token_idx_orig = token_to_idx(token)
            print(f"Patching target token {token} with texture idx {target_token_idx}, raw idx {_token_idx_orig}")
            source_token = translator.char_to_bytes[char][0]
            source_token_idx = token_to_idx(source_token)//2
            _src_token_idx_orig = token_to_idx(source_token)
            print(f"Pulling data from source token {source_token} with texture idx {source_token_idx}, raw idx {_src_token_idx_orig}")
            pxl_data = source_ex.get_pixel_bytes(source_token_idx)
            #_source_img = source_ex.get_image(source_token_idx)
            #_source_img.save(
            #    sanitize_filename(f"{_token_idx_orig}_{source_token}_{source_token_idx}_{char}.png")
            #)

            target_ex.overwrite_pixel_bytes(target_token_idx, pxl_data)
        resource_bytes = target_ex.data
    with open(output_path, "wb") as f:
        f.write(resource_bytes)

def _parse_font_imgs(font_path: Path) -> dict[bytes, Image]:
    font_imgs = {}
    for img in font_path.glob("*.png"):
        _, token = img.stem.split("_")
        try:
            token = int(token, 16).to_bytes(2)
        except ValueError:
            click.echo(f"Not opening file with malformed token {img}")
            continue

        img_pil = Image.open(img)

        # Crop image to be square
        width = min(img_pil.width, img_pil.height)
        img_pil = img_pil.crop((0, 0, width, width))
        font_imgs[token] = img_pil
    return font_imgs

def _token_repr(token: bytes):
    return f'{"".join([f"\\x{t.upper()}" for t in token.hex(sep=" ").split()])}'

@cli.command()
@click.option(
    "-h", "--src-hash",
    default="00940549",
    type=str,
)
@click.argument(
    "font_src_path",
    type=click.Path(),
)
@click.argument(
    "font_new_path",
    type=click.Path(),
)
def match_font(src_hash, font_src_path, font_new_path):
    font_src_map = ENCODING_MAP[src_hash.upper()]
    font_src_path = Path(font_src_path)
    font_new_path = Path(font_new_path)

    font_src_imgs = _parse_font_imgs(font_src_path)
    font_new_imgs = _parse_font_imgs(font_new_path)

    font_new_map = {}
    for new_token, new_img in font_new_imgs.items():
        for src_token, src_img in font_src_imgs.items():
            if new_img == src_img:
                char = font_src_map[src_token]
                click.echo(
                    f"New token {_token_repr(new_token)} maps "
                    f"to source token {_token_repr(src_token)} "
                    f"({char})"
                )
                if char in ["I", "1"]:
                    click.echo("WARNING: 'I' and '1' are not distinguishable by texture")
                font_new_map[new_token] = char
                break
        else:
            click.echo(f"Warning: no match found for new token {new_token}")

    out = f"BYTES_TO_CHAR_{font_new_path.stem.upper()}"
    out += " = {\n    **BYTES_TO_CHAR_SPECIAL,\n\n"
    for token, char in font_new_map.items():
        token = _token_repr(token)
        out += f'    b"{token}": "{char}",\n'
    out += "}"
    click.echo(out)



@cli.command()
@click.option(
    "-h", "--hash",
    default="00940549",
    type=str,
)
@click.argument(
    "string",
    type=click.Path(),
)
def encode_string(hash, string):
    encoder = EncodingTranslator(hash)
    out = encoder.string_to_bytes(string)
    click.echo(f"Encoding '{string}' with encoder hash {hash}, can be one of:")
    for s in out:
        click.echo(s.hex(sep=" "))


if __name__ == "__main__":
    cli()