import math
import re
import shutil
import json
from urllib.parse import unquote
from collections import defaultdict
import sys
import zlib
import csv
import subprocess
from pprint import pformat
from typing import Any
from pathlib import Path
from multiprocessing.pool import ThreadPool
import os

import yaml
import click
from PIL import Image
from pathvalidate import sanitize_filepath
from bitstring import Bits

import sarugetchu_mm_patcher.util as util
from sarugetchu_mm_patcher.index import (
    IndexEntry, get_index_list, index_list_to_bin
)
from sarugetchu_mm_patcher.encoding import (
    EncodingTranslator,
    ENCODING_MAP, ENCODING_LIMITS,
    BYTES_TO_CHAR_MINIMAL, BYTES_TO_CHAR_DEFAULT, BYTES_TO_CHAR_SPECIAL,
    BYTES_TO_CHAR_PASSWORD, PASSWORD_STR_IDS,
    token_to_idx, idx_to_token,
    build_credits_bin,
)
from sarugetchu_mm_patcher.aseprite import AsepriteDumper

@click.group()
def cli():
    pass

def _guess_hash(fname: str | Path):
    fname = Path(Path(fname).stem).name.upper()
    _, name_hash = fname.split("_")
    return name_hash

def _parse_imhex_json(imhex_json: str | Path):
    print(f"Opening {imhex_json}")
    with open(imhex_json) as f:
        print(f"Parsing {imhex_json}")
        data = json.load(f)["file"]
        print(f"Parsing complete for {imhex_json}")
        return data

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
        raw = info.get("raw", False)
        if raw:
            jap_bytestrs = [jap_str.encode("utf-8")]
        else:
            jap_bytestrs = source_encoder.string_to_bytes(jap_str)

        # TODO: support other langs?
        try:
            english = info["english"]
        except KeyError:
            click.echo(f"Error: did not find english data for {jap_str}")
            raise

        if isinstance(english, str):
            id = None
            replacements = {id: english}
        elif isinstance(english, dict):
            replacements = {}
            for id, s in english.items():
                replacements[bytes.fromhex(id)] = s
        else:
            raise ValueError(f"invalid translation structure {english}")

        for jb in jap_bytestrs:
            for id, eng_str in replacements.items():
                source_bs_wrapped = source_encoder.wrap_string(jb, id=id)
                if source_bs_wrapped in resource_bytes:
                    try:
                        if raw:
                            new_bs = eng_str.encode("utf-8")
                        else:
                            new_bs = target_encoder.string_to_bytes(eng_str)[0]
                    except IndexError as e:
                        click.echo(f"Error: could not encode {repr(eng_str)}")
                        raise e
                    new_bs_wrapped = target_encoder.wrap_string(new_bs, id=id)
                    resource_bytes.replace_in_place(
                        source_bs_wrapped, new_bs_wrapped
                    )
        if info.get("password", False):
            pw_encoder = EncodingTranslator(encoding=BYTES_TO_CHAR_PASSWORD)
            jap_bytestrs = pw_encoder.string_to_bytes(jap_str)
            if isinstance(english, str):
                id = None
                replacements = {id: english}
            elif isinstance(english, dict):
                replacements = {}
                for id, s in english.items():
                    replacements[bytes.fromhex(id)] = s
            else:
                raise ValueError(f"invalid translation structure {english}")
            for jb in jap_bytestrs:
                for id, eng_str in replacements.items():
                    source_bs_wrapped = pw_encoder.wrap_string(jb, id=id)
                    if source_bs_wrapped in resource_bytes:
                        try:
                            new_bs = pw_encoder.string_to_bytes(eng_str)[0]
                        except IndexError as e:
                            click.echo(f"Error: could not encode password {repr(eng_str)}")
                            raise e
                        new_bs_wrapped = pw_encoder.wrap_string(new_bs, id=id)
                        resource_bytes.replace_in_place(
                            source_bs_wrapped, new_bs_wrapped
                        )
    return resource_bytes

@cli.command()
@click.argument(
    "aseprite_path",
    type=click.Path()
)
@click.option(
    "-o", "--output-path",
    default=None,
    show_default=True,
    type=click.Path(),
)
def flip_font_palettes(aseprite_path, output_path):
    aseprite_path = Path(aseprite_path)
    # Use doubled alphas, patcher will halve them when importing
    font_colors = [
        b"\x00\x00\x00\x00\x00\x00",
        b"\x00\x00\xAF\xAF\xAF\x80",
        b"\x00\x00\xCF\xCF\xCF\xC0",
        b"\x00\x00\xFF\xFF\xFF\xFF",
    ]
    with open(aseprite_path, "rb") as f:
        aseprite_bytes = f.read()
    aseprite_bytes = bytearray(aseprite_bytes)
    if output_path is None:
        output_path = aseprite_path.parent

    ptr = 0
    # Skip header
    ptr += 128
    # Skip to num_chunks in frames header
    ptr += 12

    num_chunks = int.from_bytes(aseprite_bytes[ptr:ptr+4], "little")
    ptr += 4

    for cur_chunk in range(0, num_chunks):
        click.echo(f"Checking for palette chunk in chunk {cur_chunk}")
        chunk_size = int.from_bytes(aseprite_bytes[ptr:ptr+4], "little")
        ptr += 4
        chunk_type = int.from_bytes(aseprite_bytes[ptr:ptr+2], "little")
        ptr += 2
        if chunk_type != AsepriteDumper.PALETTE_CHUNK_ID:
            ptr += chunk_size - 6
            continue
        click.echo(f"Found palette chunk")
        palette_size = int.from_bytes(aseprite_bytes[ptr:ptr+4], "little")
        ptr += 4
        if palette_size != 16:
            click.echo(f"Error: palette size is {palette_size}, is this a font?")
            exit(1)

        # Skip over other stuff in palette header
        ptr += 16

        for palette_idx in range(2):
            output_fpath = (output_path / aseprite_path.name).with_suffix(
                f".{palette_idx}.aseprite"
            )
            click.echo(f"Writing palette {palette_idx} as {output_fpath}")
            if palette_idx == 0:
                palette_data = b"".join([font_colors[i % 4] for i in range(16)])
            else:
                palette_data = b"".join([font_colors[i // 4] for i in range(16)])
            aseprite_bytes[ptr:ptr+len(palette_data)] = palette_data
            with open(output_fpath, "wb") as f:
                f.write(aseprite_bytes)
        return


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
    "-c", "--credits-path",
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
    resource_path, strings_path, credits_path, textures_imhex_path, hash,
    output_path, imhex_json
):
    imhex_analysis = _parse_imhex_json(imhex_json)
    should_patch_strings = _needs_strings_patch(imhex_analysis["texturefactory"])
    if hash is None:
        hash = _guess_hash(resource_path)
    should_patch_credits = False
    if hash == "C63A0383" and credits_path is not None:
        should_patch_credits = True
    resource_path = Path(resource_path)
    if strings_path is not None:
        strings_path = Path(strings_path)
    else:
        should_patch_strings = False
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

    cel_chunk_re = re.compile(r"^CelChunk(?:<\d+>)?$")
    palette_chunk_re = re.compile(r"(?:Old)?PaletteChunk")

    # Note: patch textures first so imhex_json addresses are accurate
    if textures_imhex_path:
        tex_fds = imhex_analysis["texturefactory"]["img_sub_files"]
        for manifest_path in textures_imhex_path.glob("**/manifest.yaml"):
            click.echo(f"Processing {manifest_path}")
            img_data = _parse_imhex_json(
                manifest_path.with_name("texture.json")
            )
            with open(manifest_path, "r") as f:
                tex_manifest = yaml.safe_load(f)
            bpp = tex_manifest["bpp"]
            tex_path = tex_manifest["path"]
            tex_idx = tex_manifest.get("index", 0)
            patch_palette = tex_manifest.get("patch_palette", True)
            cel_chunk = util.ImhexChunkFinder(img_data, cel_chunk_re).chunks[0]
            palette_chunk = util.ImhexChunkFinder(img_data, palette_chunk_re).chunks[0]

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
                    click.echo(f"Found subfile matching {repr(tex_path)}")
                    px_data = util.aseprite_to_pixel_data(
                        cel_chunk_data, bpp
                    )
                    img_data_meta = (
                        subfile["metadata"]["ptr"]["*(ptr)"]
                            ["entries"][0]["data"]["ptr"]["*(ptr)"]
                    )
                    img_bpp = img_data_meta["idk_img_layers"] * 0x10
                    img_data_ptr = img_data_meta["idk_data_ptr"]["nullptr"]
                    img_data_offset = img_bpp*tex_idx
                    img_data_start = img_data_ptr + img_data_offset
                    resource_bytes[
                        img_data_start:img_data_start + len(px_data)
                    ] = px_data

                    # HACK: always force patched images to be unswizzled
                    img_psm_addr = int(img_data_meta["psm_flags"]["__address"])
                    img_psm = resource_bytes[img_psm_addr]
                    img_psm &= 0b10111111
                    resource_bytes[img_psm_addr] = img_psm

                    if patch_palette:
                        palette_meta = (
                            subfile["metadata"]["ptr"]["*(ptr)"]
                                ["entries"][1]["data"]["ptr"]["*(ptr)"]
                        )
                        palette_width = palette_meta["width"]
                        palette_height = palette_meta["height"]
                        plt_data = util.aseprite_to_palette_data(
                            palette_chunk,
                            max_entries=palette_width*palette_height
                        )
                        palette_data_ptr = palette_meta["idk_data_ptr"]["nullptr"]
                        resource_bytes[
                            palette_data_ptr:palette_data_ptr + len(plt_data)
                        ] = plt_data
                    break
            else:
                click.echo(f"Warning: no subfile found matching {repr(tex_path)}")

    # Patch credits prior to strings since credits are near the end
    if should_patch_credits:
        credits_path = Path(credits_path)
        with open(credits_path, "r") as f:
            credits_dict = yaml.safe_load(f)
        credits_bin = build_credits_bin(credits_dict)
        # Start from num_credit_strings.
        # Address isn't shown for primitive types, just grab the first item from the list
        # and go backwards
        credits_start_address = (
            int(imhex_analysis["credit_strings"][0]["__address"]) - 4
        )
        credits_end_address = (
            int(imhex_analysis["credit_strings"][-1]["__address"])
            + int(imhex_analysis["credit_strings"][-1]["__size"])
        )
        resource_bytes[
            credits_start_address:credits_end_address
        ] = credits_bin

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

@cli.command()
@click.argument(
    "original-hash",
    type=str
)
@click.argument(
    "patched-string",
    type=str
)
@click.option(
    "-h", "--patched-hash",
    default=None,
    show_default=True,
    type=str,
)
def decode_patched_string(original_hash, patched_string, patched_hash):
    if patched_hash is None:
        patched_encoding = EncodingTranslator(encoding=BYTES_TO_CHAR_MINIMAL)
    else:
        patched_encoding = EncodingTranslator(hash=patched_hash)
    original_encoding = EncodingTranslator(hash=original_hash)
    click.echo(f"'{patched_string}' may decode to:")
    for b in patched_encoding.string_to_bytes(patched_string):
        click.echo(
            original_encoding.bytes_to_string(b)
        )

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
    "img_path",
    type=click.Path()
)
@click.option(
    "-o", "--output-path",
    default=None,
    show_default=True,
    type=click.Path(),
)
def img_to_aseprite(img_path, output_path):
    img_path = Path(img_path)
    if output_path is None:
        output_path = img_path.with_suffix(".aseprite")
    img = Image.open(img_path)
    if img.mode != "P":
        # TODO: support non paletted image?
        click.echo(f"Error: {img_path} is not a paletted image")
        return
    if img.palette.mode != "RGB":
        click.echo(f"Error: {img_path} palette is not in RGB mode")
        return
    # For some reason palette defaults to RGB with transparency stored
    # separately, we have to reassemble it
    palette_rgb_bytes: bytes = img.palette.getdata()[1]
    # Why doesn't this work?
    #palette_rgb_bytes: bytes = img.palette.tobytes()
    palette_len = len(palette_rgb_bytes) // 3
    palette_a_bytes: bytes = img.info["transparency"]
    palette = []
    for idx in range(0, palette_len):
        color = palette_rgb_bytes[idx*3:idx*3+3]
        # Seems like colors are sorted with transparent ones first.
        # Non transparent colors don't get any entry in the transparency list
        if idx < len(palette_a_bytes):
            color += palette_a_bytes[idx].to_bytes(1)
        else:
            color += b"\xff"
        palette.append(Bits(color))

    pixel_idxs = []
    for y in range(img.height):
        for x in range(img.width):
            # It shouldn't matter how many bpp we use here because aseprite
            # just takes a 1 byte uint always, and the patcher will convert
            # back to the correct bpp when injecting
            pixel_idxs.append(Bits(img.getpixel((x, y)).to_bytes(1)))

    with open(output_path, "wb") as f:
        f.write(
            AsepriteDumper(
                img.width, img.height, palette, pixel_idxs, double_alpha=False
            ).file
        )

@cli.command()
@click.argument(
    "input_yaml",
    type=click.Path()
)
@click.argument(
    "output_list",
    type=click.Path()
)
def collect_strings(input_yaml, output_list):
    try:
        with open(output_list, "r") as f:
            strings = f.read().splitlines()
    except FileNotFoundError:
        strings = []
    with open(input_yaml, "r") as f:
        inputs = yaml.unsafe_load(f)
    strings += inputs.keys()
    strings = list(set(strings))
    with open(output_list, "w") as f:
        f.write("\n".join(strings))

@cli.command()
@click.argument(
    "strings_yaml",
    type=click.Path()
)
@click.argument(
    "all_strings_txt",
    type=click.Path()
)
@click.option(
    "-i", "--ignore-strings-txt",
    default=None,
    type=click.Path()
)
@click.option(
    "-o", "--output-path",
    default=None,
    type=click.Path()
)
def analyze_translation_progress(
    strings_yaml, all_strings_txt, ignore_strings_txt, output_path
):
    if output_path is None:
        output_path = Path(os.getcwd())
    else:
        output_path = Path(output_path)
    output_path.mkdir(parents=True, exist_ok=True)
    missing_strings_path = output_path / "untranslated_strings.txt"
    analysis_path = output_path / "analysis.txt"
    with open(strings_yaml, "r") as f:
        translation_strings = yaml.safe_load(f)
    with open(all_strings_txt, "r") as f:
        all_strings = list(set(f.read().splitlines()))
    if ignore_strings_txt:
        with open(ignore_strings_txt, "r") as f:
            ignore_strings = list(set(f.read().splitlines()))
    else:
        ignore_strings = []
    missing_strings = all_strings.copy()
    for string in translation_strings.keys():
        # HACK: ensure special chars are properly parsed
        string = string.replace("\n", r"\n")
        string = string.replace("\x0c", r"\f")
        try:
            missing_strings.remove(string)
        except ValueError:
            click.echo(f"Warning: string `{repr(string)}` found in translation table but not in string list")
    ignore_strings_count = 0
    for string in ignore_strings:
        try:
            missing_strings.remove(string)
            ignore_strings_count += 1
        except ValueError:
            click.echo(f"Warning: string `{repr(string)}` found in ignored strings list but not in string list")
    with open(missing_strings_path, "w") as f:
        f.write("\n".join(missing_strings))
    with open(analysis_path, "w") as f:
        f.write(f"Total strings: {len(all_strings)}\n")
        f.write(f"Translated strings: {len(translation_strings.keys())}\n")
        f.write(f"Ignored strings: {ignore_strings_count}\n")
        f.write(f"Untranslated strings: {len(missing_strings)}\n")
        f.write(
            "Translation percentage: "
            f"{len(translation_strings)/(len(all_strings) - ignore_strings_count)*100}%\n"
        )

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
    # HACK: generate password specific translator for known string IDs
    pw_translator = EncodingTranslator(encoding=BYTES_TO_CHAR_PASSWORD)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    manifest = defaultdict(list)
    with open(csv_path, "w") as f:
        for string in strings:
            _translator = translator
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
            if str_id in PASSWORD_STR_IDS:
                f.write("String is a password string\n")
                _translator = pw_translator

            try:
                string_tokens = _translator.tokenize_string(string_raw)

                line_out = ""
                for token in string_tokens:
                    line_out += f'"{token.hex().upper()}",'
                f.write(line_out)
                f.write("\n")

                line_out = ""
                full_str = ""
                for token in string_tokens:
                    char = _translator.bytes_to_char[token]
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
                # Write string without furigana
                f.write(re.sub(r"<.*?>", "", full_str))
                f.write("\n")

                if str_id in PASSWORD_STR_IDS:
                    manifest[full_str].append(f"{str_id};(password)")
                else:
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
def dump_credits(imhex_json, hash, output_path):
    imhex_json = Path(imhex_json)
    if output_path is None:
        output_path = Path(os.getcwd()) / imhex_json.name
    output_path = Path(output_path)
    txt_path = output_path.with_suffix(".strings.txt")
    yaml_path = output_path.with_suffix(".strings.yaml")
    if hash is None:
        hash = _guess_hash(imhex_json)
    data = _parse_imhex_json(imhex_json)
    strings = data["credit_strings"]
    try:
        translator = EncodingTranslator(hash)
    except KeyError:
        click.echo(f"Warning: No encoding map defined for {hash}, falling back to default encoding")
        translator = EncodingTranslator(encoding=BYTES_TO_CHAR_DEFAULT)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    manifest = []
    with open(txt_path, "w") as f:
        for string in strings:
            _translator = translator
            tab_mode = string["tab_mode"]
            alloc_len = string["str_len"]
            if alloc_len > 0:
                string_raw = bytes(string["string"]).strip(b'\x00')
            else:
                string_raw = b""
            try:
                string_tokens = _translator.tokenize_string(string_raw)

                full_str = ""
                for token in string_tokens:
                    char = _translator.bytes_to_char[token]
                    if char == "\n":
                        char = "\\n"
                    elif char == "\f":
                        char = "\\f"
                    full_str += char
                tab_mode_map = {
                    1: "",
                    2: "\t",
                    0: "\t\t",
                    3: "<CENTERED> "
                }
                f.write(f"{tab_mode_map[tab_mode]}{full_str}\n")

                manifest.append({
                    "string": full_str,
                    "tab_mode": tab_mode,
                })
            except ValueError as e:
                click.echo(e)
                click.echo(e.args)
                f.write("STRING CONTAINS INVALID TOKENS\n")
                f.write(f'"{string_raw.hex(" ")}"\n')
                f.write(f'"{string_raw}"\n')
                manifest.append({
                    "string": string_raw.decode("utf-8", errors="backslashreplace"),
                    "tab_mode": tab_mode,
                    "raw": True,
                })
    with open(yaml_path, "w") as f:
        f.write(
            yaml.safe_dump(manifest, allow_unicode=True, sort_keys=False)
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
    "-h", "--hash",
    default=None,
    type=str,
)
@click.option(
    "-o", "--output-path",
    default=None,
    show_default=True,
    type=click.Path(),
)
def patch_font(font_src_path, resource_path, output_path, hash):
    font_src_path = Path(font_src_path)
    resource_path = Path(resource_path)

    if hash is None:
        hash = _guess_hash(resource_path)
    encoding_limit = ENCODING_LIMITS.get(hash, None)
    if encoding_limit is None:
        encoding_limit = float("inf")
    else:
        click.echo(f"Warning: Encoding limit for {hash} is {encoding_limit}")

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
        # This file appears to have smaller 16x16 images, not sure what it's
        # used for
        b"sv_msg_2.gf0",
        # Related to passwords?
        b"password.gf0",
        # Pokepi speech
        b"pokepi.gf0",
    ]
    for sd in string_data:
        target_encoding = BYTES_TO_CHAR_MINIMAL
        if sd["value"] in blacklist:
            continue
        if sd["value"] == b"sv_msg.gf0":
            target_encoding = BYTES_TO_CHAR_DEFAULT

        click.echo(f"Patching {resource_path} / {sd['value']}")
        target_ex = util.ImgExtractor(resource_bytes, sd["value"])
        for token, char in target_encoding.items():
            if token in BYTES_TO_CHAR_SPECIAL:
                continue
            target_token_idx = token_to_idx(token)
            if target_token_idx % 2:
                continue
            if target_token_idx >= encoding_limit:
                click.echo(
                    f"Warning: Skipping token index {target_token_idx} {token} ({char})"
                )
                continue
            target_token_idx = token_to_idx(token)//2
            #_token_idx_orig = token_to_idx(token)
            #print(f"Patching target token {token} with texture idx {target_token_idx}, raw idx {_token_idx_orig}")
            source_token = translator.char_to_bytes[char][0]
            source_token_idx = token_to_idx(source_token)//2
            #_src_token_idx_orig = token_to_idx(source_token)
            #print(f"Pulling data from source token {source_token} with texture idx {source_token_idx}, raw idx {_src_token_idx_orig}")
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
            font_new_map[new_token] = "??"

    out = f"BYTES_TO_CHAR_{font_new_path.stem.upper()}"
    tokens = sorted(font_new_map.keys())
    out += " = {\n    **BYTES_TO_CHAR_SPECIAL,\n\n"
    for _t in tokens:
        token = _token_repr(_t)
        char = font_new_map[_t]
        out += f'    b"{token}": "{char}",\n'
    out += "}"
    click.echo(out)



@cli.command()
@click.option(
    "-h", "--hash",
    default="00940549",
    type=str,
)
@click.option(
    "-m", "--minimal",
    is_flag=True
)
@click.argument(
    "string",
    type=click.Path(),
)
def encode_string(hash, string, minimal):
    if minimal:
        encoder = EncodingTranslator(encoding=BYTES_TO_CHAR_MINIMAL)
        hash = "MINIMAL"
    else:
        encoder = EncodingTranslator(hash)
    out = encoder.string_to_bytes(string)
    click.echo(f"Encoding '{string}' with encoder hash {hash}, can be one of:")
    for s in out:
        click.echo(s.hex(sep=" "))

@cli.command()
@click.option(
    "-m", "--meta-path",
    default=Path("subs"),
    type=click.Path(),
)
@click.option(
    "-l", "--low",
    default=1.0,
    type=float,
)
@click.option(
    "-h", "--high",
    default=10.0,
    type=float,
)
def tune_cutscene_bitrate(meta_path, low, high):
    tol = 0.0001
    analysis_re = re.compile(r"([A-Za-z0-9\.\/]+)\: orig is \d+, patched is \d+, diff: ([-\d]+)")
    def calc_mid(_low, _high):
        return _low + (_high - _low) / 2
    def get_size_report() -> dict[Path, int]:
        click.echo("Running new build")
        cmd = [
            "nom", "build", ".#cutscenes-size-diff"
        ]
        subprocess.run(cmd)
        click.echo("Parsing size report")
        with open("result/report.txt", "r") as f:
            report = f.readlines()
        diffs = {}
        for line in report:
            try:
                pss_path, diff = analysis_re.match(line).groups()
            except AttributeError:
                click.echo("Couldn't parse line")
                click.echo(repr(line))
                continue
            pss_path = Path(pss_path)
            diff = int(diff)
            diffs[pss_path] = diff
        return diffs
    def pss_to_json_path(pss_path: Path) -> Path:
        return meta_path / str(pss_path.with_suffix(".json")).lstrip("/")
    def update_meta(pss_path: Path, bitrate=None) -> float:
        json_path = pss_to_json_path(pss_path)
        with open(json_path, "r") as f:
            data = json.load(f)
        last_bitrate = float(data["bitrate"][:-1])
        if bitrate:
            data["bitrate"] = f"{bitrate}M"
            with open(json_path, "w") as f:
                json.dump(data, f, indent=4)
        return last_bitrate
    try:
        size_report = get_size_report()

        search_range = {
            k: (low, update_meta(k), high) for k in size_report.keys()
        }
        while len(search_range) and any(v is not None for v in search_range.values()):
            for path, diff in size_report.items():
                if search_range[path] is None:
                    continue
                _low, _mid, _high = search_range[path]
                json_path = pss_to_json_path(path)
                if diff == 0:
                    click.echo(f"Found optimal bitrate {_mid} for {path}")
                    search_range[path] = None
                    click.echo(f"Disabling encoding of {json_path}")
                    json_path.rename(json_path.with_suffix(".bak"))
                    continue
                elif abs(_mid - high) < tol or abs(_mid - low) < tol:
                    click.echo(f"Warning: bitrate for {path} is set to {_mid} but there is still a diff of {diff}") 
                    click.echo(f"Disabling encoding of {json_path}")
                    search_range[path] = None
                    json_path.rename(json_path.with_suffix(".bak"))
                    continue


                if diff > 0:
                    _low = _mid
                    _mid = calc_mid(_low, _high)
                else:
                    _high = _mid
                    _mid = calc_mid(_low, _high)
                search_range[path] = (_low, _mid, _high)
                click.echo(f"Tuning cutscene bitrate for {path} (current diff is {diff})")
                click.echo(f"Searching between {_low} and {_high}M, currently trying {_mid}M")
                update_meta(path, bitrate=_mid)
            size_report = get_size_report()
    finally:
        click.echo("Restoring disabled json files")
        for path in meta_path.glob("**/*.bak"):
            click.echo(f"Reenabling transcoding of {path.name}")
            path.rename(path.with_suffix(".json"))


if __name__ == "__main__":
    cli()