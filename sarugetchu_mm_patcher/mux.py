from io import BytesIO
from bitstring import Bits

class BitScanner():
    def __init__(self, data: bytes):
        self._idx = 0
        self.all_bits = Bits(bytes=data)

    def _consume_bits(self, num_bits: int) -> Bits:
        bits = self.all_bits[
            self._idx:self._idx+num_bits
        ]
        self._idx += num_bits
        return bits


class Header(BitScanner):
    def __init__(self, data: bytes):
        super().__init__(data)
        self.sync_bits = self._consume_bits(32)
        self.bit_length = None

    @property
    def byte_length(self) -> int:
        length: float = self.bit_length/8
        assert(length.is_integer())
        return int(length)

    @property
    def bits(self) -> Bits:
        return self.all_bits[:self.bit_length]

    @property
    def bytes(self) -> bytes:
        return self.bits.bytes

    @property
    def sync_bytes(self):
        return self.sync_bits.bytes

class PesHeader(Header):
    def __init__(self, data: bytes):
        super().__init__(data)
        self.packet_len_bits = self._consume_bits(16)
        self.bit_length = self._idx + self.packet_len*8

    @property
    def packet_len(self) -> int:
        return self.packet_len_bits.uint

class PesExtensionHeader(PesHeader):
    def __init__(self, data: bytes):
        # https://dvd.sourceforge.net/dvdinfo/pes-hdr.html
        super().__init__(data)
        self.marker_bits0 = self._consume_bits(2)
        self.pes_scrambling_ctrl_bits = self._consume_bits(2)
        self.pes_priority_bit = self._consume_bits(1)
        self.data_alignment_bit = self._consume_bits(1)
        self.copyright_bit = self._consume_bits(1)
        self.original_bit = self._consume_bits(1)
        self.pts_flag_bit = self._consume_bits(1)
        self.dts_flag_bit = self._consume_bits(1)
        if self.dts_flag and not self.pts_flag:
            raise ValueError("DTS can not be enabled without PTS")
        self.escr_flag_bit = self._consume_bits(1)
        self.es_rate_flag_bit = self._consume_bits(1)
        self.dsm_trick_mode_flag_bit = self._consume_bits(1)
        self.additional_copy_info_flag_bit = self._consume_bits(1)
        self.pes_crc_flag_bit = self._consume_bits(1)
        self.pes_extension_flag_bit = self._consume_bits(1)
        self.pes_header_length_bits = self._consume_bits(8)

        if self.pts_flag:
            self.marker_bits1 = self._consume_bits(4)
            self.pts_bits_32_30 = self._consume_bits(3)
            self.marker_bits2 = self._consume_bits(1)
            self.pts_bits_29_15 = self._consume_bits(15)
            self.marker_bits3 = self._consume_bits(1)
            self.pts_bits_14_00 = self._consume_bits(15)
            self.marker_bits4 = self._consume_bits(1)
        if self.dts_flag:
            self.marker_bits5 = self._consume_bits(4)
            self.dts_bits_32_30 = self._consume_bits(3)
            self.marker_bits6 = self._consume_bits(1)
            self.dts_bits_29_15 = self._consume_bits(15)
            self.marker_bits7 = self._consume_bits(1)
            self.dts_bits_14_00 = self._consume_bits(15)
            self.marker_bits8 = self._consume_bits(1)

        if self.escr_flag:
            self.marker_bits9 = self._consume_bits(2)
            self.escr_base_bits_32_30 = self._consume_bits(3)
            self.marker_bits10 = self._consume_bits(1)
            self.escr_base_bits_29_15 = self._consume_bits(15)
            self.marker_bits11 = self._consume_bits(1)
            self.escr_base_bits_14_00 = self._consume_bits(15)
            self.marker_bits12 = self._consume_bits(1)
            self.escr_ext_bits = self._consume_bits(9)
            self.marker_bits13 = self._consume_bits(1)

        if self.es_rate_flag:
            self.marker_bits14 = self._consume_bits(1)
            self.es_rate_bits = self._consume_bits(22)

        if self.additional_copy_info_flag:
            self.marker_bits15 = self._consume_bits(1)
            self.additional_copy_info_bits = self._consume_bits(7)

        if self.pes_crc_flag:
            self.pes_crc_bits = self._consume_bits(16)

        if self.pes_extension_flag:
            self.pes_private_data_flag_bit = self._consume_bits(1)
            self.pack_header_field_flag_bit = self._consume_bits(1)
            self.prog_packet_sequence_counter_flag_bit = self._consume_bits(1)
            self.p_std_buffer_flag_bit = self._consume_bits(1)
            self.marker_bits16 = self._consume_bits(3)
            # PS2 doesn't support this flag, but it's always set to 1
            #self.pes_extension2_flag_bit = self._consume_bits(1)
            self.marker_bits_ext2 = self._consume_bits(1)


        if self.pes_private_data_flag:
            self.pes_private_data_bits = self._consume_bits(16*8)

        if self.pack_header_field_flag:
            self.pack_header_field_bits = self._consume_bits(8)

        if self.prog_packet_sequence_counter_flag:
            self.marker_bits17 = self._consume_bits(1)
            self.packet_seq_count_bits = self._consume_bits(7)
            self.marker_bits18 = self._consume_bits(1)
            self.mpeg1_or_2_bit = self._consume_bits(1)
            self.original_stuffing_length_bits = self._consume_bits(6)

        if self.p_std_buffer_flag:
            self.marker_bits19 = self._consume_bits(2)
            self.p_std_buffer_scale_bit = self._consume_bits(1)
            self.p_std_buffer_size = self._consume_bits(13)

        #if self.pes_extension2_flag_bit:
        #    self.marker_bits20 = self._consume_bits(1)
        #    self.pes_extension2_field_length_bits = self._consume_bits(7)
        #    self.pes_extension2_reserved_bits = self._consume_bits(8)
        #    self.pes_extension2_data = self._consume_bits(
        #        self.pes_extension2_field_length*8
        #    )
        self.stuffing_bits = self._consume_bits(
            self.pes_header_length*8 - (self._idx - 9*8)
        )
        self.data_bits = self._consume_bits(self.bit_length - self._idx)
        import pdb;pdb.set_trace()

    @property
    def pts_flag(self) -> bool:
        return self.pts_flag_bit[0]
    @property
    def dts_flag(self) -> bool:
        return self.dts_flag_bit[0]
    @property
    def escr_flag(self) -> bool:
        return self.escr_flag_bit[0]
    @property
    def es_rate_flag(self) -> bool:
        return self.es_rate_flag_bit[0]
    @property
    def additional_copy_info_flag(self) -> bool:
        return self.additional_copy_info_flag_bit[0]
    @property
    def pes_crc_flag(self) -> bool:
        return self.pes_crc_flag_bit[0]
    @property
    def pes_extension_flag(self) -> bool:
        return self.pes_extension_flag_bit[0]
    @property
    def pes_private_data_flag(self) -> bool:
        if not self.pes_extension_flag:
            return False
        return self.pes_private_data_flag_bit[0]
    @property
    def pack_header_field_flag(self) -> bool:
        if not self.pes_extension_flag:
            return False
        return self.pack_header_field_flag_bit[0]
    @property
    def prog_packet_sequence_counter_flag(self) -> bool:
        if not self.pes_extension_flag:
            return False
        return self.prog_packet_sequence_counter_flag_bit[0]
    @property
    def p_std_buffer_flag(self) -> bool:
        if not self.pes_extension_flag:
            return False
        return self.p_std_buffer_flag_bit[0]
    #@property
    #def pes_extension2_flag(self) -> bool:
    #    if not self.pes_extension_flag:
    #        return False
    #    return self.pes_extension2_flag_bit[0]
    #@property
    #def pes_extension2_field_length(self) -> int:
    #    if not self.pes_extension_flag:
    #        return False
    #    return self.pes_extension2_field_length_bits.uint
    @property
    def pes_header_length(self) -> int:
        return self.pes_header_length_bits.uint
    @property
    def pts_bits(self) -> Bits:
        return (
            self.pts_bits_32_30
            + self.pts_bits_29_15
            + self.pts_bits_14_00
        )
    @property
    def dts_bits(self) -> Bits:
        return (
            self.dts_bits_32_30
            + self.dts_bits_29_15
            + self.dts_bits_14_00
        )
    @property
    def escr_base_bits(self) -> Bits:
        return (
            self.escr_base_bits_32_30
            + self.escr_base_bits_29_15
            + self.escr_base_bits_14_00
        )
    @property
    def pts(self) -> int:
        return self.pts_bits.uint
    @property
    def dts(self) -> int:
        return self.dts_bits.uint
    @property
    def escr_base(self) -> int:
        return self.escr_base_bits.uint
    @property
    def system_clock_ref(self) -> int:
        return self.system_clock_ref_bits.uint
    @property
    def data_bytes(self) -> bytes:
        return self.data_bits.bytes


class PackHeader(Header):
    def __init__(self, data: bytes):
        # https://en.wikipedia.org/wiki/MPEG_program_stream#Coding_details
        super().__init__(data)
        self.marker_bits0 = self._consume_bits(2)
        self.system_clock_bits_32_30 = self._consume_bits(3)
        self.marker_bits1 = self._consume_bits(1)
        self.system_clock_bits_29_15 = self._consume_bits(15)
        self.marker_bits2 = self._consume_bits(1)
        self.system_clock_bits_14_00 = self._consume_bits(15)
        self.marker_bits3 = self._consume_bits(1)
        self.scr_extension_bits = self._consume_bits(9)
        self.marker_bits4 = self._consume_bits(1)
        self.bit_rate_bits = self._consume_bits(22)
        self.marker_bits5 = self._consume_bits(2)
        self.reserved_bits = self._consume_bits(5)
        self.stuffing_len_bits = self._consume_bits(3)
        self.stuffing_bits = self._consume_bits(self.stuffing_len*8)
        self.all_marker_bits_ok()
        self.bit_length = self._idx

    @property
    def system_clock_ref_bits(self) -> Bits:
        return (
            self.system_clock_bits_32_30
            + self.system_clock_bits_29_15
            + self.system_clock_bits_14_00
        )

    @property
    def system_clock_ref(self) -> int:
        return self.system_clock_ref_bits.uint

    @property
    def scr(self) -> int:
        return self.system_clock_ref

    @property
    def scr_extension(self) -> int:
        return self.scr_extension_bits.uint

    @property
    def scr_ext(self) -> int:
        return self.scr_extension

    @property
    def stuffing_len(self) -> int:
        return self.stuffing_len_bits.uint

    @property
    def bit_rate(self) -> int:
        return self.bit_rate_bits.uint


    def __str__(self):
        return (
            f"SCR: {self.scr}, SCR_EXT: {self.scr_ext}, "
            f"Bitrate: {self.bit_rate}"
        )


    def all_marker_bits_ok(self) -> bool:
        ok = True
        if self.marker_bits0 != Bits("0b01"):
            print(
                "WARNING: marker_bits0 is incorrect: "
                f"{self.marker_bits0}"
            )
            ok = False
        if self.marker_bits1 != Bits("0b1"):
            print(
                "WARNING: marker_bits1 is incorrect: "
                f"{self.marker_bits1}"
            )
            ok = False
        if self.marker_bits2 != Bits("0b1"):
            print(
                "WARNING: marker_bits2 is incorrect: "
                f"{self.marker_bits2}"
            )
            ok = False
        if self.marker_bits3 != Bits("0b1"):
            print(
                "WARNING: marker_bits3 is incorrect: "
                f"{self.marker_bits3}"
            )
            ok = False
        if self.marker_bits4 != Bits("0b1"):
            print(
                "WARNING: marker_bits4 is incorrect: "
                f"{self.marker_bits4}"
            )
            ok = False
        if self.marker_bits5 != Bits("0b11"):
            print(
                "WARNING: marker_bits5 is incorrect: "
                f"{self.marker_bits5}"
            )
            ok = False
        return ok

class StreamHeader(BitScanner):
    def __init__(self, data: bytes):
        super().__init__(data)
        self.id_bits = self._consume_bits(8)
        self.marker_bits0 = self._consume_bits(2)
        if self.id_bits == Bits("0b10110111"):
            self.marker_bits1 = self._consume_bits(7)
            self.id_ext = self._consume_bits(7)
            self.marker_bits2 = self._consume_bits(8)
            self.marker_bits3 = self._consume_bits(2)
            self.pstd_buffer_bound_scale_bit = self._consume_bits(1)
            self.pstd_buffer_size_bound_bits = self._consume_bits(13)
        else:
            self.pstd_buffer_bound_scale_bit = self._consume_bits(1)
            self.pstd_buffer_size_bound_bits = self._consume_bits(13)
        self.bit_length = self._idx

class SystemHeader(PesHeader):
    def __init__(self, data: bytes):
        # Rec. ITU-T H.222.0 (06/2021) section 2.5.3.5 and 2.5.3.6
        super().__init__(data)
        self.marker_bits0 = self._consume_bits(1)
        self.rate_bound_bits = self._consume_bits(22)
        self.marker_bits1 = self._consume_bits(1)
        self.audio_bound_bits = self._consume_bits(6)
        self.fixed_flag_bit = self._consume_bits(1)
        self.csps_flag_bit = self._consume_bits(1)
        self.sys_audio_lock_flag_bit = self._consume_bits(1)
        self.sys_video_lock_flag_bit = self._consume_bits(1)
        self.marker_bits2 = self._consume_bits(1)
        self.video_bound_bits = self._consume_bits(5)
        self.packet_rate_restriction_flag_bit = self._consume_bits(1)
        self.reserved_bits = self._consume_bits(7)
        self.streams = []
        idx = 96
        while idx < self.bit_length:
            stream = StreamHeader(self.all_bits[idx:].bytes)
            idx += stream.bit_length
            self.streams.append(stream)
        import pdb;pdb.set_trace()

    @property
    def rate_bound(self) -> int:
        return self.rate_bound_bits.uint
    @property
    def audio_bound(self) -> int:
        return self.audio_bound_bits.uint
    @property
    def video_bound(self) -> int:
        return self.video_bound_bits.uint


class PaddingHeader(PesHeader):
    pass

def demux(data: bytes) -> tuple[BytesIO, BytesIO]:
    idx = 0
    video_stream = BytesIO()
    audio_stream = BytesIO()
    while idx < len(data):
        id = data[idx:idx+4]
        if id == b"\x00\x00\x01\xb9":
            print(f"Found program end at {hex(idx)}")
            break
        elif id == b"\x00\x00\x01\xba":
            hdr = PackHeader(data[idx:])
            print(
                f"Found pack header at {hex(idx)} "
                f"with size {hex(hdr.byte_length)}")
        elif id == b"\x00\x00\x01\xbb":
            hdr = SystemHeader(data[idx:])
            print(
                f"Found system header at {hex(idx)} "
                f"with size {hex(hdr.byte_length)}")
        elif id == b"\x00\x00\x01\xbe":
            hdr = PaddingHeader(data[idx:])
            print(
                f"Found padding header at {hex(idx)} "
                f"with size {hex(hdr.byte_length)}")
            import pdb;pdb.set_trace()
        elif id[0:3] == b"\x00\x00\x01":
            if 0xE0 <= id[3] <= 0xEF:
                hdr = PesExtensionHeader(data[idx:])
                print(
                    f"Found PES video header at {hex(idx)} "
                    f"with size {hex(hdr.byte_length)}")
                video_stream.write(hdr.data_bytes)
            elif id[3] == 0xBD:
                hdr = PesExtensionHeader(data[idx:])
                print(
                    f"Found PES private stream 1 header at {hex(idx)} "
                    f"with size {hex(hdr.byte_length)}")
                substream_id = hdr.data_bytes[0:4]
                if substream_id == b"\xff\xa0\x00\x00":
                    print("Packet contains SS2 sound data")
                    audio_stream.write(hdr.data_bytes[4:])
                else:
                    print(f"Unknown substream ID {substream_id.hex()}")
                    import pdb;pdb.set_trace()

            else:
                print(f"Unknown PES packet: {id.hex()} at {hex(idx)}")
                hdr = PesHeader(data[idx:])
                import pdb;pdb.set_trace()
        else:
            print(f"Unknown ID: {id.hex()} at {hex(idx)}")
            import pdb;pdb.set_trace()
            exit(-1)

        idx += hdr.byte_length
    return video_stream, audio_stream