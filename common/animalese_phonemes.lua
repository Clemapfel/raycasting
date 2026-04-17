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
    -- vowels
    A = "A", I = "I", U = "U", E = "E", O = "O",
    -- long vowels
    AA = "AA", II = "II", UU = "UU", EE = "EE", OO = "OO",

    -- k
    KA = "KA", KI = "KI", KU = "KU", KE = "KE", KO = "KO",
    -- g
    GA = "GA", GI = "GI", GU = "GU", GE = "GE", GO = "GO",
    -- s
    SA = "SA", SI = "SI", SU = "SU", SE = "SE", SO = "SO",
    -- z
    ZA = "ZA", JI = "JI", ZU = "ZU", ZE = "ZE", ZO = "ZO",
    -- z
    TA = "TA", TI = "TI", TU = "TU", TE = "TE", TO = "TO",
    -- d
    DA = "DA", DI = "DI", DU = "DU", DE = "DE", DO = "DO",
    -- n
    NA = "NA", NI = "NI", NU = "NU", NE = "NE", NO = "NO",
    -- h
    HA = "HA", HI = "HI", HU = "HU", HE = "HE", HO = "HO",
    -- b
    BA = "BA", BI = "BI", BU = "BU", BE = "BE", BO = "BO",
    -- p
    PA = "PA", PI = "PI", PU = "PU", PE = "PE", PO = "PO",
    -- m
    MA = "MA", MI = "MI", MU = "MU", ME = "ME", MO = "MO",
    -- y
    YA = "YA", YU = "YU", YO = "YO",
    -- r
    RA = "RA", RI = "RI", RU = "RU", RE = "RE", RO = "RO",
    -- w
    WA = "WA", WO = "WO",

    -- palatized k
    KYA = "KYA", KYU = "KYU", KYO = "KYO",
    -- palatalized g
    GYA = "GYA", GYU = "GYU", GYO = "GYO",
    -- palatalized sh
    SHA = "SHA", SHI = "SHI", SHU = "SHU", SHE = "SHE", SHO = "SHO",
    -- palatalized j
    JA = "JA", JI = "JI", JU = "JU", JE = "JE", JO = "JO",
    -- palatalized ch
    CHA = "CHA", CHI = "CHI", CHU = "CHU", CHE = "CHE", CHO = "CHO",
    -- palatalized ts
    TSA = "TSA", TSI = "TSI", TSU = "TSU", TSE = "TSE", TSO = "TSO",
    -- palatized n
    NYU = "NYU", NYO = "NYO",
    -- palatized h
    HYA = "HYA", HYU = "HYU", HYO = "HYO",
    -- palatized f
    FA = "FA", FI = "FI", FU = "FU", FE = "FE", FO = "FO",
    -- palatized b
    BYA = "BYA", BYU = "BYU", BYO = "BYO",
    -- palatized p
    PYA = "PYA", PYU = "PYU", PYO = "PYO",
    -- palatized m
    MYA = "MYA", MYU = "MYU", MYO = "MYO",
    -- palatized r
    RYA = "RYA", RYU = "RYU", RYO = "RYO",

    -- v (foreign loans)
    VI = "VI", VU = "VU", VE = "VE", VO = "VO",

    -- foreign stops
    THI = "THI", TYU = "TYU", DYU = "DYU",

    -- moraic nasal
    N = "N",

    -- control characters,
    BEAT = rt.EnglishPhoneme.BEAT,
    QUESTION_MARK = "?"
}

rt.AnimalesePhoneme = meta.enum("AnimalesePhoneme", rt.AnimalesePhoneme)
