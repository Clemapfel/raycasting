--- @enum rt.EnglishPhoneme
--- @see https://en.wikipedia.org/wiki/ARPABET
rt.EnglishPhoneme = {
    -- control characters
    PAD = "<pad>",
    UNK = "<unk>",
    START = "<s>",
    END = "</s>",
    BEAT = " ",
    QUESTION_MARK = "?",

    -- monophthongs (pure vowels)
    AA = "AA", AA0 = "AA0", AA1 = "AA1", AA2 = "AA2", -- "bot" /ɑ/
    AE = "AE", AE0 = "AE0", AE1 = "AE1", AE2 = "AE2", -- "bat" /æ/
    AH = "AH", AH0 = "AH0", AH1 = "AH1", AH2 = "AH2", -- "but" /ʌ/
    AO = "AO", AO0 = "AO0", AO1 = "AO1", AO2 = "AO2", -- "bought" /ɔ/
    EH = "EH", EH0 = "EH0", EH1 = "EH1", EH2 = "EH2", -- "bet" /ɛ/
    IH = "IH", IH0 = "IH0", IH1 = "IH1", IH2 = "IH2", -- "bit" /ɪ/
    IY = "IY", IY0 = "IY0", IY1 = "IY1", IY2 = "IY2", -- "beat" /i/
    UH = "UH", UH0 = "UH0", UH1 = "UH1", UH2 = "UH2", -- "book" /ʊ/
    UW = "UW", UW0 = "UW0", UW1 = "UW1", UW2 = "UW2", -- "boot" /u/

    -- diphthongs (gliding vowels)
    AW = "AW", AW0 = "AW0", AW1 = "AW1", AW2 = "AW2", -- "bout" /aʊ/
    AY = "AY", AY0 = "AY0", AY1 = "AY1", AY2 = "AY2", -- "bite" /aɪ/
    EY = "EY", EY0 = "EY0", EY1 = "EY1", EY2 = "EY2", -- "bait" /eɪ/
    OW = "OW", OW0 = "OW0", OW1 = "OW1", OW2 = "OW2", -- "boat" /oʊ/
    OY = "OY", OY0 = "OY0", OY1 = "OY1", OY2 = "OY2", -- "boy" /ɔɪ/

    -- r-colored vowels
    ER = "ER", ER0 = "ER0", ER1 = "ER1", ER2 = "ER2", -- "bird" /ɝ/

    -- stops (consonants)
    B = "B",   -- "bat" /b/
    D = "D",   -- "dog" /d/
    G = "G",   -- "go" /ɡ/
    K = "K",   -- "cat" /k/
    P = "P",   -- "pot" /p/
    T = "T",   -- "top" /t/

    -- fricatives (consonants)
    DH = "DH", -- "that" /ð/
    F  = "F",  -- "fat" /f/
    HH = "HH", -- "hat" /h/
    S  = "S",  -- "sat" /s/
    SH = "SH", -- "shoe" /ʃ/
    TH = "TH", -- "thin" /θ/
    V  = "V",  -- "vat" /v/
    Z  = "Z",  -- "zoo" /z/
    ZH = "ZH", -- "measure" /ʒ/

    -- affricates (consonants)
    CH = "CH", -- "chat" /tʃ/
    JH = "JH", -- "judge" /dʒ/

    -- nasals (consonants)
    M  = "M",  -- "mat" /m/
    N  = "N",  -- "not" /n/
    NG = "NG", -- "sing" /ŋ/

    -- liquids & glides (consonants)
    L = "L",   -- "lot" /l/
    R = "R",   -- "rot" /ɹ/
    W = "W",   -- "wet" /w/
    Y = "Y",   -- "yet" /j/
}
rt.EnglishPhoneme = meta.enum("EnglishPhoneme", rt.EnglishPhoneme)

--- @enum rt.AnimalesePhoneme
rt.AnimalesePhoneme = {
    I = "I", A = "A", O = "O", U = "U", E = "E", AU = "AU", AI = "AI", EI = "EI", OU = "OU", II = "II", UU = "UU", OI = "OI",
    BI = "BI", BO = "BO", BU = "BU", BA = "BA", BE = "BE", BAU = "BAU", BAI = "BAI", BEI = "BEI", BOU = "BOU", BII = "BII", BUU = "BUU", BOI = "BOI",
    DA = "DA", DE = "DE", DI = "DI", DO = "DO", DU = "DU", DAU = "DAU", DAI = "DAI", DEI = "DEI", DOU = "DOU", DII = "DII", DUU = "DUU", DOI = "DOI",
    FA = "FA", FE = "FE", FI = "FI", FO = "FO", FU = "FU", FAU = "FAU", FAI = "FAI", FEI = "FEI", FOU = "FOU", FII = "FII", FUU = "FUU", FOI = "FOI",
    GA = "GA", GE = "GE", GI = "GI", GO = "GO", GU = "GU", GAU = "GAU", GAI = "GAI", GEI = "GEI", GOU = "GOU", GII = "GII", GUU = "GUU", GOI = "GOI",
    HA = "HA", HE = "HE", HI = "HI", HO = "HO", HU = "HU", HAU = "HAU", HAI = "HAI", HEI = "HEI", HOU = "HOU", HII = "HII", HUU = "HUU", HOI = "HOI",
    JA = "JA", JE = "JE", JI = "JI", JO = "JO", JU = "JU", JAU = "JAU", JAI = "JAI", JEI = "JEI", JOU = "JOU", JII = "JII", JUU = "JUU", JOI = "JOI",
    KA = "KA", KE = "KE", KI = "KI", KO = "KO", KU = "KU", KAU = "KAU", KAI = "KAI", KEI = "KEI", KOU = "KOU", KII = "KII", KUU = "KUU", KOI = "KOI",
    MA = "MA", ME = "ME", MI = "MI", MO = "MO", MU = "MU", MAU = "MAU", MAI = "MAI", MEI = "MEI", MOU = "MOU", MII = "MII", MUU = "MUU", MOI = "MOI",
    NA = "NA", NE = "NE", NI = "NI", NO = "NO", NU = "NU", NAU = "NAU", NAI = "NAI", NEI = "NEI", NOU = "NOU", NII = "NII", NUU = "NUU", NOI = "NOI",
    PA = "PA", PE = "PE", PI = "PI", PO = "PO", PU = "PU", PAU = "PAU", PAI = "PAI", PEI = "PEI", POU = "POU", PII = "PII", PUU = "PUU", POI = "POI",
    RA = "RA", RE = "RE", RI = "RI", RO = "RO", RU = "RU", RAU = "RAU", RAI = "RAI", REI = "REI", ROU = "ROU", RII = "RII", RUU = "RUU", ROI = "ROI",
    SA = "SA", SE = "SE", SI = "SI", SO = "SO", SU = "SU", SAU = "SAU", SAI = "SAI", SEI = "SEI", SOU = "SOU", SII = "SII", SUU = "SUU", SOI = "SOI",
    SHA = "SHA", SHE = "SHE", SHI = "SHI", SHO = "SHO", SHU = "SHU", SHAU = "SHAU", SHAI = "SHAI", SHEI = "SHEI", SHOU = "SHOU", SHII = "SHII", SHUU = "SHUU", SHOI = "SHOI",
    TA = "TA", TE = "TE", TI = "TI", TO = "TO", TU = "TU", TAU = "TAU", TAI = "TAI", TEI = "TEI", TOU = "TOU", TII = "TII", TUU = "TUU", TOI = "TOI",
    VA = "VA", VE = "VE", VI = "VI", VO = "VO", VU = "VU", VAU = "VAU", VAI = "VAI", VEI = "VEI", VOU = "VOU", VII = "VII", VUU = "VUU", VOI = "VOI",
    WA = "WA", WE = "WE", WI = "WI", WO = "WO", WU = "WU", WAU = "WAU", WAI = "WAI", WEI = "WEI", WOU = "WOU", WII = "WII", WUU = "WUU", WOI = "WOI",
    YA = "YA", YE = "YE", YI = "YI", YO = "YO", YU = "YU", YAU = "YAU", YAI = "YAI", YEI = "YEI", YOU = "YOU", YII = "YII", YUU = "YUU", YOI = "YOI",
    ZA = "ZA", ZE = "ZE", ZI = "ZI", ZO = "ZO", ZU = "ZU", ZAU = "ZAU", ZAI = "ZAI", ZEI = "ZEI", ZOU = "ZOU", ZII = "ZII", ZUU = "ZUU", ZOI = "ZOI",
    N = "N",

    BEAT = rt.EnglishPhoneme.BEAT,
    QUESTION_MARK = "?"
}

rt.AnimalesePhoneme = meta.enum("AnimalesePhoneme", rt.AnimalesePhoneme)
