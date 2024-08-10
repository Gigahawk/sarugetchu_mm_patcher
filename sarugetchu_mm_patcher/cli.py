from pathlib import Path
import gzip
import io
from multiprocessing.pool import ThreadPool, AsyncResult
import os
from time import sleep

from ps2isopatcher.iso import Ps2Iso, TreeFile
import click

import sarugetchu_mm_patcher.util as util
from sarugetchu_mm_patcher.index import (
    IndexEntry, get_index_list, index_list_to_bin
)

EXTRACT_PATH = Path(".extracted")
DATA0_PATH = "/PDATA/DATA0.BIN;1"
DATA1_PATH = "/PDATA/DATA1.BIN;1"

@click.group()
def cli():
    pass

def patch_text(iso: Ps2Iso) -> tuple[bytes, bytes]:
    click.echo("Patching game text")


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
        with io.BytesIO(archive) as bio:
            with gzip.GzipFile(fileobj=bio, mode="rb") as gzip_file:
                extracted = gzip_file.read()
                click.echo(f"Done extracting file {entry.name_str}")
        with open(EXTRACT_PATH / entry.name_str, "wb") as f:
            f.write(extracted)
        click.echo(f"Patching file {entry.name_str}")
        # VS.モード
        old = b"\x0C\x00\x00\x00\x88\xBE\x88\xBB\x89\xD8\x89\xB7\x89\x4E\x89\x9E"
        # VSMODE
        new = b"\x0E\x00\x00\x00\x88\xBE\x88\xBB\x89\xD8\x88\xB5\x88\xB7\x88\xAC\x88\xAD"

        # TODO: actually have a list of translations to edit
        if old in extracted:
            click.echo(f"Found old string in {entry.name_str}")
            extracted = bytearray(extracted)
            extracted = extracted.replace(old, new)
            extracted = bytes(extracted)

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
    "--md5/--no-md5",
    default=True,
)
def patch(input: str | os.PathLike, md5: bool):
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

    data0, data1 = patch_text(iso)

    click.echo("Waiting for mutable copy to open")
    iso_mut: Ps2Iso = iso_async_result.get()
    iso_mut.replace_files([
        (DATA0_PATH, data0),
        (DATA1_PATH, data1),
    ])

    click.echo("Exporting patched ISO")
    iso_mut.write("patched.iso")
    click.echo("Done")










if __name__ == "__main__":
    cli()