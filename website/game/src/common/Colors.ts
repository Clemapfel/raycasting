export type RGBA = {
    r : number; // in [0, 1]
    g : number; // in [0, 1]
    b : number; // in [0, 1]
    a : number; // in [0, 1]
}

export type HSVA = {
    h : number; // in [0, 1]
    s : number; // in [0, 1]
    v : number; // in [0, 1]
    a : number; // in [0, 1]
}

export type LCHA = {
    l : number; // in [0, 1]
    c : number; // in [0, 1]
    h : number; // in [0, 1]
    a : number; // in [0, 1]
}

export function hsva_to_rgba(hsva : HSVA) : RGBA {
    // h, s, v, a are all in [0, 1], RGBA are all in [0, 1]
}

export function lcha_to_rgba(lcha : LCHA) : RGBA {
    // l, c, h, a are all in [0, 1], RGBA are all in [0, 1]
}