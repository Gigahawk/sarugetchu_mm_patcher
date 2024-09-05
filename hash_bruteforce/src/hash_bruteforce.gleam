import gleam/io
import gleam/int
import gleam/string
import gleam/list

const valid_hashes = [
	0xbfa5a81f,
	0xfce0d095,
	0x0a23a5bd,
	0xd1f8159b,
	0xce3a6f7c,
	0x30179100,
	0xc4ba4e70,
	0x71fa643a,
	0xbe275a63,
	0xb24d0148,
	0xe8d1b6f8,
	0xfc039ded,
	0x83033ac6,
	0xac2a442c,
	0xac2b0a09,
	0xbb98018d,
	0xbb98c76a,
	0xbb998d47,
	0xbfbba81c,
	0xac2d5ba0,
	0xac2e217d,
	0xac2ee75a,
	0xd0434d93,
	0xd464a28b,
	0xd4656868,
	0xac46dd1d,
	0xac47a2fa,
	0xac4868d7,
	0xac49f491,
	0x60ecf8b2,
	0x650e4daa,
	0x650f1387,
	0xac4c4628,
	0xac4d0c05,
	0xe10efe5a,
	0xe52f8d75,
	0xe5305352,
	0xe531192f,
	0xac643beb,
	0xac6501c8,
	0xac65c7a5,
	0xac668d82,
	0xac67535f,
	0x812cfcb1,
	0x502d275c,
	0x23f2ec3c,
	0xb5e90582,
	0x26e54372,
	0x5ee9be4a,
	0x0b229e14,
	0xc549606e,
	0x0c2148e1,
	0x2e7774f1,
	0xe55d9a3e,
	0x65a0f965,
	0x1fe66fb7,
	0x661b0314,
	0x3b80ff94,
	0x520641b6,
	0x3a2e2403,
	0xa03a207b,
	0xbb3ef8ea,
	0x941f7953,
	0xc596acfd,
	0xafd734bf,
	0x99844caf,
	0xa58b44c9,
	0xa58c0aa6,
	0x40c65d24,
	0x40c72301,
	0x49059400,
	0x33b4aed2,
	0x33b574af,
	0x03dec536,
	0xcce34339,
	0x1ec36905,
	0x05a8dc3c,
	0x76b34f3b,
	0xb8094359,
	0x470b71e3,
	0x8cbdd0d7,
	0x26d5e4d1,
	0x4660d16f,
	0x68574588,
	0x0c1ef587,
	0x9248f341,
	0x3ff56be7,
	0x65ad7359,
	0xb58e79dd,
	0x4a0ef244,
	0xb3a37e56,
	0x3369c96c,
	0xf76856c5,
	0x9d072616,
	0x30209145,
	0xd9325ec3,
	0x3f55b5f2,
	0x5db3d7dc,
	0x11203a8d,
	0xbb3e1406,
	0x0b5fbb5e,
	0x966a6996,
	0x51048e7a,
	0x8ac9360e,
	0x96c545dd,
	0xa850b2b2,
	0x394c084c,
	0x3c2b7acd,
	0x70ef3ae1,
	0xd23f9149,
	0xa1bdbea5,
	0xb18cbcf2,
	0xe81ec772,
	0x8d870a6e,
	0xcc681b3a,
	0x4e9656ac,
	0xdf9a022f,
	0xe8caf705,
	0x0bf66c3c,
	0x26ae650e,
	0xc07d2290,
	0x9e27ff0b,
	0x68710933,
	0x0055ee50,
	0x80994d77,
	0x3adec3c9,
	0x81135726,
	0x567953a6,
	0x37ea6850,
	0xcc34da2d,
	0x0a084ad9,
	0x4a502f74,
	0xeeb52f65,
	0xb672bb0c,
	0x44323aad,
	0xab7ad397,
	0xcacf88d1,
	0x7f687349,
	0x7522eae4,
	0x7523b0c1,
	0x7524769e,
	0x12f14ff1,
	0x12f215ce,
	0x12f2dbab,
	0x12f3a188,
	0xa449977c,
	0xa44a5d59,
	0xa44b2336,
	0xa44be913,
	0xa44caef0,
	0xa44d74cd,
	0xa44e3aaa,
	0xa44f0087,
	0xa44fc664,
	0xa4508c41,
	0xa466306d,
	0xa466f64a,
	0xa467bc27,
	0xa4688204,
	0xf907b5a9,
	0xf9087b86,
	0xf9094163,
	0xdbab3f9e,
	0xdbac057b,
	0xdbaccb58,
	0xdbad9135,
	0xdbae5712,
	0xdbaf1cef,
	0xdbafe2cc,
	0xdbb0a8a9,
	0xdbb16e86,
	0xdbc712b2,
	0xdbc7d88f,
	0xdbc96449,
	0xc2ee153d,
	0xc2eedb1a,
	0xc2efa0f7,
	0xc2f066d4,
	0xc2f12cb1,
	0xc2f1f28e,
	0xc2f2b86b,
	0xc2f37e48,
	0xc2f44425,
	0xc309e851,
	0xc30aae2e,
	0xc30c39e8,
	0x04e9bb9f,
	0x04ea817c,
	0x04eb4759,
	0x0507e04a,
	0xca3b09c7,
	0xca3bcfa4,
	0xca3c9581,
	0xca3d5b5e,
	0xca3e213b,
	0xca3ee718,
	0xca3facf5,
	0xca4072d2,
	0xca4138af,
	0xca41fe8c,
	0xca57a2b8,
	0xca586895,
	0xca59f44f,
	0xca5aba2c,
	0xca5b8009,
	0x56bf1024,
	0x56bfd601,
	0x56c09bde,
	0x47b0e616,
	0x47b1abf3,
	0x47b271d0,
	0x47b337ad,
	0x47b3fd8a,
	0x47b4c367,
	0x47b58944,
	0x47b64f21,
	0x47b714fe,
	0x47ccb92a,
	0x47cd7f07,
	0x47cf0ac1,
	0x1a9a2b0b,
	0x1a9af0e8,
	0x1a9bb6c5,
	0x1a9c7ca2,
	0x1a9d427f,
	0x1a9e085c,
	0x1a9ece39,
	0x1a9f9416,
	0x1aa059f3,
	0x1ab5fe1f,
	0x1ab6c3fc,
	0x1ab84fb6,
	0x1ab91593,
	0x1ab9db70,
	0x7834a3a7,
	0x78356984,
	0x78362f61,
	0x7836f53e,
	0x7837bb1b,
	0x783880f8,
	0x783946d5,
	0x783a0cb2,
	0x783ad28f,
	0x785076bb,
	0x78513c98,
	0x78520275,
	0x7852c852,
	0x78538e2f,
	0xf0b214fa,
	0xf0b2dad7,
	0xcc06a343,
	0xcc076920,
	0xcc082efd,
	0xcc24c7ee,
	0xe0ff4f2a,
	0xe1001507,
	0xe100dae4,
	0xe11d73d5,
	0x087d7e5b,
	0x087e4438,
	0x087f0a15,
	0x089ba306,
	0xdaad7af8,
	0xdaae40d5,
	0xdaaf06b2,
	0xdaafcc8f,
	0xdab0926c,
	0xdab15849,
	0xdab21e26,
	0xdab2e403,
	0xdab3a9e0,
	0xdab46fbd,
	0xdaca13e9,
	0xdacad9c6,
	0xdacc6580,
	0xddc2a90a,
	0xddc36ee7,
	0xddc434c4,
	0xddc4faa1,
	0xb3c59dba,
	0xb3c66397,
	0xb3c72974,
	0xb3c7ef51,
	0x624f134e,
	0xb6aea84b,
	0xebee623b,
	0x5b1ac5f8,
	0x3f3a9c23,
	0xab84a527,
	0x0515ea09,
	0xb28dfae0,
	0x60dc2280,
	0x01c34ffb,
	0x75675c6f,
	0x0308dea7,
	0x54666f19,
	0xb9d09596,
	0x9c75a642,
	0x04a67254,
	0x2eab06be,
	0xe8358a45,
	0x819960b1,
	0x220d429b,
	0xba4eae6b,
	0xadf77a77,
	0xfad6ba03,
	0x56b96ed9,
	0x446c0bd9,
	0xfe465c24,
	0x5ec0ec61,
	0x36722302,
	0x36eab5ae,
	0x39a8818a,
	0x46c22251,
	0x49e90b95,
	0x4badf777,
	0x5f87ce8a,
	0x626e9127,
	0x7704fede,
	0x88e872cf,
	0xba78933d,
	0xc013db5a,
	0xcfeb47fd,
	0xd3123141,
	0xd4d71d23,
	0xe8b0f436,
	0xeb97b6d3,
	0x002e248a,
	0x1211987b,
	0xf175134c,
	0xb7624e6d,
	0xb7dae119,
	0xbe2bcb15,
	0xc7b24dbc,
	0xcad93700,
	0xcc9e22e2,
	0xe077f9f5,
	0xe35ebc92,
	0xf7f52a49,
	0x09d89e3a,
	0x719b8a25,
	0x38ffa0f7,
	0x397833a3,
	0x494fa046,
	0x4c76898a,
	0x4e3b756c,
	0x62154c7f,
	0x64fc0f1c,
	0x79927cd3,
	0x8b75f0c4,
	0xb64b4faa,
	0xe22217b5,
	0x32840edd,
	0x16a3e508,
	0x82297794,
	0xdbbabc76,
	0x38456b65,
	0xd92c98e0,
	0x4cd0a554,
	0x08db4868,
	0x769df832,
	0x90756803,
	0xdb4b44c1,
	0xbf9ed32a,
	0xa3d0e9ca,
	0x2e22b7be,
	0xd5afa509,
	0x362a3546,
	0x0963158c,
	0xcf5050ad,
	0xcfc8e359,
	0xd619cd55,
	0xdfa04ffc,
	0xe2c73940,
	0xe48c2522,
	0xf865fc35,
	0xfb4cbed2,
	0x0fe32c89,
	0x21c6a07a,
	0x09ed57c2,
	0xee0d2ded,
	0x58ce4a01,
	0xb25f8ee3,
	0xea100b56,
	0x0faeb44a,
	0xb095e1c5,
	0x2439ee39,
	0x0eadb229,
	0x98d5814b,
	0x671a3a70,
	0xdfa25c21,
	0xb1f0172e,
	0x97081c0f,
	0xc60872e3,
	0x058c00a3,
	0xad18edee,
	0x0d937e2b,
	0x44b531d1,
	0x452dc47d,
	0x47f4d6b5,
	0x4b7eae79,
	0x55053120,
	0x582c1a64,
	0x59f10646,
	0x5c2855ec,
	0x6dcadd59,
	0x70b19ff6,
	0x85480dad,
	0x972b819e,
	0x2f731c6e,
	0x89046150,
	0xfba3371e,
	0x14801bea,
	0x3dbf0cdd,
	0xdcf54988,
	0x848236d3,
	0xe4fcc710,
	0x9e4f8684,
	0xb14ddc6b,
	0xb312c84d,
	0xc9d361fd,
	0xde69cfb4,
	0xf04d43a5,
	0x0617eedb,
	0xbe814614,
	0x5f39bc08,
	0xb45e926d,
	0xbc660ff5,
	0xa1aef6ea,
	0xa7ffe0e6,
	0xca4c0fc6,
	0xcd32d263,
	0xf3acb40b,
	0xebbd14c4,
	0x90293271,
	0x7449089c,
	0xdcbcc148,
	0x364e062a,
	0x95ea8ef9,
	0x36d1bc74,
	0xaa75c8e8,
	0x2024ef6c,
	0xff7c1c96,
	0xeb08b1b7,
	0xe23d7d81,
	0x35de8e75,
	0x63b97337,
	0x1d43f6be,
	0x2caf0e2e,
	0x3354c89d,
	0x0bd3041e,
	0x93cf58da,
	0xd6999c72,
	0x9c86d793,
	0x9cff6a3f,
	0xa350543b,
	0xacd6d6e2,
	0xaffdc026,
	0xb1c2ac08,
	0xc59c831b,
	0xdd19b36f,
	0xdd8396b4,
	0xeefd2760,
	0xbc4ba7a4,
	0xf0a16a39,
	0x2aadb450,
	0x67b7e6bf,
	0x21be18e1,
	0x71a0f96e,
	0x3e036ed5,
	0xfd4b2b75,
	0x826cc04f,
	0x779e54ac,
	0xc22b1c48,
	0x58982b3d,
	0xbacdd2d3,
	0x279d8d85,
	0xd997ba72,
	0x50611789,
	0x884c34f3,
	0xdf9515b0,
	0x4bb6332d,
	0x4bb6f90a,
	0x4bbb9c38,
	0x952da051,
	0x952e662e,
	0x9533095c,
	0xf328c22c,
	0xf3298809,
	0xf32a4de6,
	0xf32b13c3,
	0x615a10f6,
	0x615ad6d3,
	0x615b9cb0,
	0x615c628d,
	0x615d286a,
	0x615dee47,
	0x615eb424,
	0x615f7a01,
	0x61603fde,
	0xc02580e9,
	0x85097ed9,
	0x850a44b6,
	0x850b0a93,
	0x850bd070,
	0x850c964d,
	0x850d5c2a,
	0x850e2207,
	0x8e270ce0,
	0x5dd65f79,
	0x5dd72556,
	0x5dd7eb33,
	0x5dd8b110,
	0xb17dca66,
	0xb17e9043,
	0xb17f5620,
	0xb1801bfd,
	0xb180e1da,
	0x6cafc699,
	0xd74d85cd,
	0xd74e4baa,
	0xd74f1187,
	0xd74fd764,
	0xec3ad184,
	0x6c775b9f,
	0x6c78217c,
	0x6c78e759,
	0x6c79ad36,
	0xe2e301ce,
	0x9dd599bc,
	0x9dd65f99,
	0x9dd72576,
	0x9dd7eb53,
	0x070af1d7,
	0xf549763c,
	0xf54a3c19,
	0xf54b01f6,
	0xf54bc7d3,
	0xf54c8db0,
	0xf54d538d,
	0x2a973f0e,
	0x2a9804eb,
	0x2a98cac8,
	0x2a9990a5,
	0x2a9a5682,
	0x8e6ec3a1,
	0xee7fa57b,
	0xee806b58,
	0xee813135,
	0xee81f712,
	0xee82bcef,
	0xee8382cc,
	0xee8448a9,
	0xee850e86,
	0x84e110ba,
	0x302b6873,
	0x302c2e50,
	0x302cf42d,
	0x302dba0a,
	0x633138d2,
	0x0cc4e272,
	0x0cc5a84f,
	0x0cc66e2c,
	0x0cc73409,
	0xee90c4f5,
	0xa7a951eb,
	0xa7aa17c8,
	0xa7aadda5,
	0xa7aba382,
	0x6f8d1d6a,
	0x3bcd20d7,
	0x4f366cb8,
	0xc76d9946,
	0x76deeaa9,
	0xb3939598,
	0xdb15e168,
	0x9c46c276,
	0x4c89f7b8,
	0x6d9a0456,
	0x564c8d59,
	0x84de94c8,
	0xdc6f58d0,
	0xd4f0a427,
	0xcad60422,
	0xb7facda9,
	0x369c2ea8,
	0xce0e262b,
	0x072e4488,
	0xe9b63e95,
	0xe9b70472,
	0xe9b7ca4f,
	0xe9b8902c,
	0xe9b95609,
	0xe9ba1be6,
	0xe9bae1c3,
	0xe9bba7a0,
	0xe9bc6d7d,
	0x66d43e2c,
	0x7a5c2ea7,
	0x7a5cf484,
	0x7a5dba61,
	0x7a5e803e,
	0x7a5f461b,
	0x7a600bf8,
	0x7a60d1d5,
	0xa05fa5c7,
	0xa0606ba4,
	0xa0613181,
	0xa061f75e,
	0xa062bd3b,
	0xa0638318,
	0xa06448f5,
	0xa0650ed2,
	0xe929f539,
	0xdc58f8c7,
	0xd474b65e,
	0x51be2ada,
	0xd96c6d4f,
	0x59afcc76,
	0x13f542c8,
	0x5a29d625,
	0x2f8fd2a5,
	0x982ac32b,
	0x02819180,
	0xf57b2558,
	0xd24e9143,
	0x7cd27b28,
	0x0bbb2e72,
	0xa3e607d0,
	0xdfa8ce24,
	0x4a821ebd,
	0xb37c4b81,
	0xb37d115e,
	0xd1d224eb,
	0xf3216c72,
	0x15cde403,
	0xa5f005f8,
	0x507a6faa,
	0x7b88622f,
	0xa33e38a7,
	0xa33efe84,
	0xa31e4058,
	0xe2896e65,
	0x2ae832fd,
	0x2ae8f8da,
	0x2ae9beb7,
	0x50cab8fe,
	0x894553b3,
	0x0f6b499b,
	0x0f6c0f78,
	0xd48197ac,
	0xf77f75e9,
	0x6204b9b8,
	0x0ae71645,
	0x6dbfe516,
	0x6dc0aaf3,
	0x132977cf,
	0x3de6e320,
	0xaa9b9f38,
	0xaa9c6515,
	0x7cbe03e1,
	0xb2eda8aa,
	0xaf3b006a,
	0xaf3bc647,
	0x443f1683,
	0x40b16884,
	0x663c7b18,
	0x96d7e625,
	0xa1b06615,
	0x1dbe738e,
	0x6c3d81f3,
	0x6c3e47d0,
	0x34c9d144,
	0xaa2b2621,
	0xdddb9ec2,
	0x51ab81e7,
	0x83b13015,
	0xd3ded58e,
	0x146f0e82,
	0x146fd45f,
	0x14709a3c,
	0x625d17db,
	0x57a1497c,
	0xf258e19c,
	0x663ffa19,
	0xa8554ead,
	0xc11836c6,
	0x988fe089,
	0x35e66db2,
	0x42e0a971,
	0x683e65fa,
	0xbfd8b2cd,
	0x29924666,
	0x9b9e8325,
	0x1caada5e,
	0x05996a30,
	0xae0fc5dd,
	0x54c6f28d,
	0x124e0f26,
	0xa8202c9f,
	0xb0050ab0,
	0xd9512593,
	0xd951eb70,
	0x4d00c7e4,
	0xdd672e41,
	0xa4bb485b,
	0xa4bc0e38,
	0x3a09c06c,
	0x656663a9,
	0x16b22003,
	0x16b2e5e0,
	0x9b5a16d4,
	0x3a3f0371,
	0x4e33fe80,
	0x4fa35eed,
	0xfcc6f2bc,
	0xfcc7b899,
	0x2060e145,
	0x4ae4bbfe,
	0xab29b320,
	0xab2a78fd,
	0xab2b3eda,
	0xf8f41489,
	0x886b51b2,
	0x67eecafc,
	0x67ef90d9,
	0x9e5c5785,
	0x8ef9113e,
	0x78de5b15,
	0x3df3f48e,
	0x710565c6,
	0x71062ba3,
	0x7106f180,
	0xbd6a7aff,
	0x3f7a9390,
	0x8c10420a,
	0x36c2df0f,
	0xb1ced5e5,
	0x74100a1e,
	0xd311f52f,
	0xd215ff00,
	0x386e651e,
	0x75058b53,
	0xe26be19c,
	0x45a6fa19,
	0xc3ed6a2b,
	0xa08fe88c,
	0xb62dd048,
	0x50bc6095,
	0x0554de4c,
	0xb33c8e09,
	0xba0306ea,
	0xb2d7346f,
	0x91ae8819,
	0xdc4ee502,
	0xcc3052f2,
	0x3f73ff57,
	0x02debd4d,
	0xabddd6e6,
	0xdbcaffb0,
	0xbee9555d,
	0xb2af2207,
	0xb9d8cde1,
	0x5f3e45f1,
	0x00e3d33e,
	0x81273265,
	0x3b6ca8b7,
	0x81a13c14,
	0x57073894,
	0x4c6c7eb6,
	0xe7e5a903,
	0x0fda4e60,
	0xbffce9fd,
	0x93ea89af,
	0x1e0b1154,
	0x8c89ff38,
	0x7c2792dd,
	0xfc6af204,
	0xb6b06856,
	0xfce4fbb3,
	0xd24af833,
	0x1d3730b1,
	0x4c17ec76,
	0x3d2607a7,
	0x90c79bf8,
	0x64b53baa,
]



fn gen_hash(path: String) -> Int {
  let char_codepoint: List(UtfCodepoint) = string.to_utf_codepoints(path)
  let char_ints: List(Int) = list.map(char_codepoint, fn(c) { string.utf_codepoint_to_int(c) })

  list.fold(char_ints, 0, fn(crc: Int, c: Int) {
    int.bitwise_and(crc * 0x25 + c, 0xFFFFFFFF)
  })
}

pub fn main() {
  let hash = gen_hash("gz/menu_common.gz")
  io.debug(int.to_base16(hash))
  io.debug(list.contains(valid_hashes, hash))

}