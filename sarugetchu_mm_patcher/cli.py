from typing import Any, Iterable
from pathlib import Path
import gzip
import io
from multiprocessing.pool import ThreadPool, AsyncResult
import os
from time import sleep

import yaml
from ps2isopatcher.iso import Ps2Iso, TreeFile
import click

import sarugetchu_mm_patcher.util as util
from sarugetchu_mm_patcher.index import (
    IndexEntry, get_index_list, index_list_to_bin
)
from sarugetchu_mm_patcher.encoding import (
    string_to_bytes, wrap_string
)

EXTRACT_PATH = Path(".extracted")
DATA0_PATH = "/PDATA/DATA0.BIN;1"
DATA1_PATH = "/PDATA/DATA1.BIN;1"

@click.group()
def cli():
    pass

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

def patch_text(
        iso: Ps2Iso,
        strings: dict[str, dict[str, Any]],
        patch_files: Iterable[str]
    ) -> tuple[bytes, bytes]:
    click.echo(f"Patching game text in the following files: {patch_files}")


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

    def _patch_archive(entry: IndexEntry) -> bytes:
        click.echo(f"Extracting file {entry.name_str}")
        start = entry.address*iso.block_size
        archive = archives[
            start:start + entry.size
        ]
        if entry.name_str not in patch_files:
            click.echo(f"Not patching file {entry.name_str}")
            return util.pad(archive), len(archive)
        with io.BytesIO(archive) as bio:
            with gzip.GzipFile(fileobj=bio, mode="rb") as gzip_file:
                extracted = gzip_file.read()
                orig_uncompressed_size = len(extracted)
                click.echo(
                    f"Done extracting file {entry.name_str}, "
                    f"uncompressed size is {orig_uncompressed_size}, "
                    f"({hex(orig_uncompressed_size)})"
                )
        click.echo(f"Patching file {entry.name_str}")
        with open(f".extracted/{entry.name_str}", "wb") as f:
            f.write(extracted)

        extracted = bytearray(extracted)
        for jap_str, info in strings.items():
            jap_bytestrs = string_to_bytes(jap_str)
            # TODO: support other langs?
            new_bytestr = string_to_bytes(info["english"])[0]
            id = info.get("id", None)
            if id:
                id = bytes.fromhex(id)
            for jb in jap_bytestrs:
                extracted = extracted.replace(
                    wrap_string(jb, id=id),
                    wrap_string(new_bytestr, id=id),
                )

        # HACK: This offset has something to do with `menu_common/icon.bimg`
        # If it's not patched the game crashes when trying to go to gameplay
        patched_uncompressed_size = len(extracted)
        len_diff = patched_uncompressed_size - orig_uncompressed_size
        orig_addr = 0x001A4A29
        new_addr = orig_addr + len_diff
        extracted = extracted.replace(
            orig_addr.to_bytes(length=4, byteorder="little"),
            new_addr.to_bytes(length=4, byteorder="little"),
        )

        extracted = bytes(extracted)
        with open(f".extracted/{entry.name_str}_patched", "wb") as f:
            f.write(extracted)

        click.echo(
            f"Finished patching file {entry.name_str}, "
            f"new uncompressed size: {patched_uncompressed_size}, "
            f"({hex(patched_uncompressed_size)}), "
            f"size increased by {len_diff}"
        )

        click.echo(f"Recompressing file {entry.name_str}")
        recompressed = io.BytesIO()
        with gzip.GzipFile(fileobj=recompressed, mode="wb") as gzip_file:
            gzip_file.write(extracted)
        recompressed = recompressed.getvalue()
        new_size = len(recompressed)
        padded = util.pad(recompressed)
        click.echo(
            f"Finished patching file {entry.name_str}, "
            f"new size is {new_size}, was {entry.size}")
        return padded, new_size

    with ThreadPool(processes=16) as p:
        files = p.map(_patch_archive, index_list)

    click.echo("Repacking archive and updating index")
    new_index_list = []
    data1 = bytearray()
    address = 0
    for index, (bin, size) in zip(index_list, files):
        new_index = IndexEntry(
            index.name,
            address,
            size
        )
        new_index_list.append(new_index)
        data1 += bin
        address += util.blocks_required(size)
    data0 = index_list_to_bin(new_index_list)
    click.echo("Done repacking")
    return data0, data1


def open_mutable(input: str | os.PathLike) -> AsyncResult:
    def _thread():
        return Ps2Iso(input, mutable=True)
    pool = ThreadPool(processes=1)
    async_result = pool.apply_async(_thread)
    return async_result

@cli.command()
@click.option(
    "-i", "--input",
    default="Sarugetchu - Million Monkeys (Japan).iso",
    show_default=True,
    type=click.Path(),
)
@click.option(
    "-s", "--strings",
    default="strings.yaml",
    show_default=True,
    type=click.Path(),
)
@click.option(
    "--md5/--no-md5",
    default=True,
)
@click.option(
    "--patch-string",
    multiple=True,
    default=["00940549"],
)
def patch(
    input: str | os.PathLike,
    strings: str | os.PathLike,
    md5: bool,
    patch_string: Iterable[str],
):
    if md5:
        click.echo(f"Checking MD5 on {input}")
        expected_md5 = "946d0aeb90772efd9105b0f785b2c7ec"
        actual_md5 = util.md5(input)
        if expected_md5 != actual_md5:
            click.echo("Error: MD5 mismatch")
            click.echo(f"Got:      {actual_md5}")
            click.echo(f"Expected: {expected_md5}")
            exit(1)
        click.echo("MD5 OK")
    click.echo(f"Opening {input}")
    iso = Ps2Iso(input)
    iso_async_result = open_mutable(input)

    click.echo(f"Opening translation file {strings}")
    with open(strings, "r") as f:
        strings_dict = yaml.safe_load(f)
    if not strings_dict:
        strings_dict = {}

    data0, data1 = patch_text(iso, strings_dict, patch_string)

    click.echo("Waiting for mutable copy to open")
    iso_mut: Ps2Iso = iso_async_result.get()
    iso_mut.replace_files([
        (DATA0_PATH, data0),
        (DATA1_PATH, data1),
    ])

    click.echo("Exporting patched ISO")
    iso_mut.write("patched.iso")
    click.echo("Done")

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
def gen_crc(pack_path: str):
    crc = 0
    for c in pack_path:
        crc = (crc * 0x25) + ord(c)
        crc &= 0xFFFFFFFF
    crc = crc.to_bytes(length=4, byteorder="little")
    print(f"{crc.hex(sep=' ').upper()}: {pack_path}")











if __name__ == "__main__":
    cli()