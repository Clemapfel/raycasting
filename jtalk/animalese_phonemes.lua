--- @enum rt.Animalese.EnglishPhoneme
--- @see https://en.wikipedia.org/wiki/ARPABET
rt.Animalese.EnglishPhoneme = {
    -- control characters
    PAD = "<pad>",
    UNK = "<unk>",
    START = "<s>",
    END = "</s>",
    BEAT = " ",

    -- monophthongs (pure vowels)
    AA0 = "AA0", AA1 = "AA1", AA2 = "AA2", -- "bot" /ɑ/
    AE0 = "AE0", AE1 = "AE1", AE2 = "AE2", -- "bat" /æ/
    AH0 = "AH0", AH1 = "AH1", AH2 = "AH2", -- "but" /ʌ/
    AO0 = "AO0", AO1 = "AO1", AO2 = "AO2", -- "bought" /ɔ/
    EH0 = "EH0", EH1 = "EH1", EH2 = "EH2", -- "bet" /ɛ/
    IH0 = "IH0", IH1 = "IH1", IH2 = "IH2", -- "bit" /ɪ/
    IY0 = "IY0", IY1 = "IY1", IY2 = "IY2", -- "beat" /i/
    UH0 = "UH0", UH1 = "UH1", UH2 = "UH2", -- "book" /ʊ/
    UW  = "UW",  UW0 = "UW0", UW1 = "UW1", UW2 = "UW2", -- "boot" /u/

    -- diphthongs (gliding vowels)
    AW0 = "AW0", AW1 = "AW1", AW2 = "AW2", -- "bout" /aʊ/
    AY0 = "AY0", AY1 = "AY1", AY2 = "AY2", -- "bite" /aɪ/
    EY0 = "EY0", EY1 = "EY1", EY2 = "EY2", -- "bait" /eɪ/
    OW0 = "OW0", OW1 = "OW1", OW2 = "OW2", -- "boat" /oʊ/
    OY0 = "OY0", OY1 = "OY1", OY2 = "OY2", -- "boy" /ɔɪ/

    -- r-colored vowels
    ER0 = "ER0", ER1 = "ER1", ER2 = "ER2", -- "bird" /ɝ/

    -- stops (consonants)
    B = "B",   -- "bat"
    D = "D",   -- "dog"
    G = "G",   -- "go"
    K = "K",   -- "cat"
    P = "P",   -- "pot"
    T = "T",   -- "top"

    -- fricatives (consonants)
    DH = "DH", -- "that" /ð/
    F  = "F",  -- "fat"
    HH = "HH", -- "hat"
    S  = "S",  -- "sat"
    SH = "SH", -- "shoe" /ʃ/
    TH = "TH", -- "thin" /θ/
    V  = "V",  -- "vat"
    Z  = "Z",  -- "zoo"
    ZH = "ZH", -- "measure" /ʒ/

    -- affricates (consonants)
    CH = "CH", -- "chat" /tʃ/
    JH = "JH", -- "judge" /dʒ/

    -- nasals (consonants)
    M  = "M",  -- "mat"
    N  = "N",  -- "not"
    NG = "NG", -- "sing" /ŋ/

    -- liquids & glides (consonants)
    L = "L",   -- "lot"
    R = "R",   -- "rot"
    W = "W",   -- "wet"
    Y = "Y",   -- "yet"
}
rt.Animalese.EnglishPhoneme = meta.enum("EnglishPhoneme", rt.Animalese.EnglishPhoneme)

--- @enum rt.Animalese.Phoneme
rt.Animalese.Phoneme = {
    -- vowels
    A = "a", I = "i", U = "u", E = "e", O = "o",
    -- long vowels
    AA = "aa", II = "ii", UU = "uu", EE = "ee", OO = "oo",

    -- k
    KA = "ka", KI = "ki", KU = "ku", KE = "ke", KO = "ko",
    -- g
    GA = "ga", GI = "gi", GU = "gu", GE = "ge", GO = "go",
    -- s
    SA = "sa", SHI = "shi", SU = "su", SE = "se", SO = "so",
    -- z
    ZA = "za", JI = "ji", ZU = "zu", ZE = "ze", ZO = "zo",
    -- z
    TA = "ta", CHI = "chi", TSU = "tsu", TE = "te", TO = "to",
    -- d
    DA = "da", DI = "di", DU = "du", DE = "de", DO = "do",
    -- n
    NA = "na", NI = "ni", NU = "nu", NE = "ne", NO = "no",
    -- h
    HA = "ha", HI = "hi", HU = "hu", HE = "he", HO = "ho",
    -- b
    BA = "ba", BI = "bi", BU = "bu", BE = "be", BO = "bo",
    -- p
    PA = "pa", PI = "pi", PU = "pu", PE = "pe", PO = "po",
    -- m
    MA = "ma", MI = "mi", MU = "mu", ME = "me", MO = "mo",
    -- y
    YA = "ya", YU = "yu", YO = "yo",
    -- r
    RA = "ra", RI = "ri", RU = "ru", RE = "re", RO = "ro",
    -- w
    WA = "wa", WO = "wo",

    -- palatized k
    KYA = "kya", KYU = "kyu", KYO = "kyo",
    -- palatalized g
    GYA = "gya", GYU = "gyu", GYO = "gyo",
    -- palatalized sh
    SHA = "sha", SHI = "shi", SHU = "shu", SHE = "she", SHO = "sho",
    -- palatalized j
    JA = "ja", JI = "ji", JU = "ju", JE = "je", JO = "jo",
    -- palatalized ch
    CHA = "cha", CHI = "chi", CHU = "chu", CHE = "che", CHO = "cho",
    -- palatalized ts
    TSA = "tsa", TSI = "tsi", TSU = "tsu", TSE = "tse", TSO = "tso",
    -- palatized n
    NYU = "nyu", NYO = "nyo",
    -- palatized h
    HYA = "hya", HYU = "hyu", HYO = "hyo",
    -- palatized f
    FA = "fa", FI = "fi", FU = "fu", FE = "fe", FO = "fo",
    -- palatized b
    BYA = "bya", BYU = "byu", BYO = "byo",
    -- palatized p
    PYA = "pya", PYU = "pyu", PYO = "pyo",
    -- palatized m
    MYA = "mya", MYU = "myu", MYO = "myo",
    -- palatized r
    RYA = "rya", RYU = "ryu", RYO = "ryo",

    -- v (foreign loans)
    VI = "vi", VU = "vu", VE = "ve", VO = "vo",

    -- foreign stops
    THI = "thi", TYU = "tyu", DYU = "dyu",

    -- moraic nasal
    N = "n",

    -- control characters,
    BEAT = "beat", QUESTION_MARK = "?"
}
rt.Animalese.Phoneme = meta.enum("AnimalesePhoneme", rt.Animalese.Phoneme)
