import subprocess
from pprint import pformat
from typing import Any, Iterable
from pathlib import Path
import gzip
import io
from concurrent.futures import ThreadPoolExecutor
from multiprocessing.pool import ThreadPool, AsyncResult
import os
from time import sleep

import yaml
from ps2isopatcher.iso import Ps2Iso, TreeFile, walk_tree
import click

import sarugetchu_mm_patcher.util as util
import sarugetchu_mm_patcher.mux as mux
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
    patch_files = [f.lower() for f in patch_files]
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
            english = info["english"]
            if isinstance(english, str):
                id = None
                try:
                    bs = string_to_bytes(english)[0]
                except IndexError as e:
                    click.echo(
                        f"Error: could not encode {repr(english)}"
                    )
                    raise e
                replacements = {id: bs}
            elif isinstance(english, dict):
                replacements = {}
                for id, s in english.items():
                    replacements[bytes.fromhex(id)] = string_to_bytes(s)[0]
            else:
                raise ValueError(f"invalid translation structure {english}")

            for jb in jap_bytestrs:
                for id, new_bytestr in replacements.items():
                    extracted = extracted.replace(
                        wrap_string(jb, id=id),
                        wrap_string(new_bytestr, id=id),
                    )

        patched_uncompressed_size = len(extracted)
        len_diff = patched_uncompressed_size - orig_uncompressed_size
        extracted = util.patch_offsets(extracted, len_diff)

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
@input_opt
@click.option(
    "--md5/--no-md5",
    default=True,
)
@click.option(
    "--cutscenes/--no-cutscenes",
    default=True,
)
@click.option(
    "--patch-string",
    multiple=True,
    default=[
        "00940549",  # gz/menu_common.gz
        "3C6CF60B",  # gz/menu_vs.gz
        "87F51E0C",  # gz/menu_story.01_boss01_gori01.gz
    ],
)
def patch(
    input: str | os.PathLike,
    md5: bool,
    cutscenes: bool,
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

    click.echo(f"Opening text translation file strings.yaml")
    with open("strings.yaml", "r") as f:
        strings_dict = yaml.safe_load(f)
    if not strings_dict:
        strings_dict = {}

    iso, iso_async_result = open_iso(input, mutable=True)

    data0, data1 = patch_text(iso, strings_dict, patch_string)

    click.echo(f"Opening cutscene translation file subs.yaml")
    with open("subs.yaml", "r") as f:
        subs_dict = yaml.safe_load(f)
    if not subs_dict:
        subs_dict = {}

    if cutscenes:
        cutscene_replacements = patch_cutscenes(iso, subs_dict)
    else:
        cutscene_replacements = []

    click.echo("Waiting for mutable copy to open")
    iso_mut: Ps2Iso = iso_async_result.get()
    iso_mut.replace_files(
        [
            (DATA0_PATH, data0),
            (DATA1_PATH, data1),
        ] + cutscene_replacements
    )

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
    crc = util.gen_packinfo_hash(pack_path)
    print(f"{crc.hex(sep=' ').upper()}: {pack_path}")

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

#@cli.command()
#@click.argument(
#    "pss_file",
#    type=click.Path(),
#)
#def demux(pss_file):
#    data = FileBytes(pss_file)
#    vid_stream, aud_stream = mux.demux(data)
#    #with open("video.m2v", "wb") as f:
#    #    f.write(vid_stream)
#    #with open("audio.ss2", "wb") as f:
#    #    f.write(aud_stream)

if __name__ == "__main__":
    cli()