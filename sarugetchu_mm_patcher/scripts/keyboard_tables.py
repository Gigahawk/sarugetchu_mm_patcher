keyboard_tables = [
    # あ table 0
    (
        "亜 哀 愛 悪 握 圧 安 暗 案 行 扱 阿 藍 葵 茜\n"
        "旭 昌 晃 晟 彬 渥 曙 梓 敦 綾 鮎 嵐 晏 杏",
        "89E5 89E6 89E7 89E8 89E9 89EA 89EB 89EC 89ED 8CC4 9442 9443 9444 9445 9446 0A "
        "9447 9448 9449 944A 944B 944C 944D 944E 944F 9450 9451 9452 9453 9454"
    ),
    # い table 0
    (
        "以 位 依 偉 医 囲 委 威 尉 意 慰 胃 為 異 移\n"
        "維 緯 衣 違 遺 域 育 一 壱 逸 印 員 因 姻 引\n"
        "院 陰 隠 韻 飲 唯 易 音 芋 亥 伊 莞 斐 郁 磯\n"
        "猪 巌 允 胤",
        "89E5 89E6 89E7 89E8 89E9 89EA 89EB 89EC 89ED 8CC4 9442 9443 9444 9445 9446 0A "
        "9447 9448 9449 944A 944B 944C 944D 944E 944F 9450 9451 9452 9453 9454"
    ),
    # う table 0
    (
        "石 宇 羽 雨 運 雲 有 畝 卯 丑 唄",
        "9344 9345 9346 9347 9348 9349 934A 934B 934C 934D 934E"
    ),
    # え table 0
    (
        "宮 影 衛 映 栄 永 泳 英 詠 鋭 易 液 疫 益 駅\n"
        "悦 謁 越 閲 円 園 塩 宴 延 援 沿 演 炎 煙 猿\n"
        "縁 遠 鉛 会 依 回 恵 繧 役 慧 瑛 叡 苑\n",
        "8A5A 8A5B 8A5C 8A5D 8A5E 8A5F 8A60 8A61 8A62 8A63 8A64 8A65 8A66 8A67 8A68 0A "
        "8A69 8A6A 8A6B 8A6C 8A6D 8A6E 8A6F 8A70 8A71 8A72 8A73 8A74 8A75 8A76 8A77 0A "
        "8A78 8A79 8A7A 8AB8 89F0 8AB9 8C4E 8AC8 935F 9464 9465 9466 9467"
    )

]



for table in keyboard_tables:
    kanji, bin = table
    kanji = kanji.replace("\n", " \\n ")
    kanji = kanji.split()
    bin = bin.split()
    kanji_idx = 0
    bin_idx = 0
    for k, b in zip(kanji, bin):
        print(b, k)
    print("")