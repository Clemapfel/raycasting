export class RGBA {
    r : number;
    g : number;
    b : number;
    a : number;

    constructor(r : number = 0, g : number = 0, b : number = 0, a : number = 1) {
        this.r = r;
        this.g = g;
        this.b = b;
        this.a = a;
    }

    public clone(out? : RGBA) {
        if (out !== undefined) {
            out.r = this.r;
            out.g = this.g;
            out.b = this.b;
            out.a = this.a;
            return out;
        }

        return new RGBA(this.r, this.g, this.b, this.a);
    }
}

export class HSVA {
    h : number;
    s : number;
    v : number;
    a : number;

    constructor(h : number = 0, s : number = 0, v : number = 0, a : number = 1) {
        this.h = h;
        this.s = s;
        this.v = v;
        this.a = a;
    }

    public clone(out? : HSVA) {
        if (out !== undefined) {
            out.h = this.h;
            out.s = this.s;
            out.v = this.v;
            out.a = this.a;
            return out;
        }

        return new HSVA(this.h, this.s, this.v, this.a);
    }

    public toRGBA(out? : RGBA): RGBA {
        let hue = this.h;
        let value = this.v;
        let saturation = this.s;
        let alpha = this.a;

        const chroma = value * saturation;
        const hue_sector = hue * 360 / 60;
        const x = chroma * (1 - Math.abs(hue_sector % 2 - 1));
        const m = value - chroma;

        out ??= new RGBA();

        if (hue_sector < 1) {
            out.r = chroma + m;
            out.g = x + m;
            out.b = m;
            out.a = alpha;
            return out;
        }

        if (hue_sector < 2) {
            out.r = x + m;
            out.g = chroma + m;
            out.b = m;
            out.a = alpha;
            return out;
        }

        if (hue_sector < 3) {
            out.r = m;
            out.g = chroma + m;
            out.b = x + m;
            out.a = alpha;
            return out;
        }

        if (hue_sector < 4) {
            out.r = m;
            out.g = x + m;
            out.b = chroma + m;
            out.a = alpha;
            return out;
        }

        if (hue_sector < 5) {
            out.r = x + m;
            out.g = m;
            out.b = chroma + m;
            out.a = alpha;
            return out;
        }

        out.r = chroma + m;
        out.g = m;
        out.b = x + m;
        out.a = alpha;
        return out;
    }
}

export class LCHA {
    l : number;
    c : number;
    h : number;
    a : number;

    constructor(l : number = 0, c : number = 0, h : number = 0, a : number = 1) {
        this.l = l;
        this.c = c;
        this.h = h;
        this.a = a;
    }

    public clone(out? : LCHA) {
        if (out !== undefined) {
            out.l = this.l;
            out.c = this.c;
            out.h = this.h;
            out.a = this.a;
            return out;
        }

        return new LCHA(this.l, this.c, this.h, this.a);
    }

    asRGBA(out? : RGBA): RGBA {
        const luminance = this.l * 100;
        const a_component = Math.cos(this.h * 6.283185) * this.c * 100;
        const b_component = Math.sin(this.h * 6.283185) * this.c * 100;

        const y = (luminance + 16) / 116;
        const x = a_component / 500 + y;
        const z = y - b_component / 200;

        const cube = (n: number) => n ** 3;
        const xyz_correct = (n: number, scale: number) =>
            cube(n) > 0.008856 ? scale * cube(n) : scale * (n - 16 / 116) / 7.787;

        const X = xyz_correct(x, 0.95047);
        const Y = xyz_correct(y, 1.00000);
        const Z = xyz_correct(z, 1.08883);

        const linear_to_srgb = (n: number) =>
            n > 0.0031308 ? 1.055 * n ** (1 / 2.4) - 0.055 : 12.92 * n;

        const clamp = (n: number) => Math.max(0, Math.min(1, n));

        out ??= new RGBA();

        out.r = clamp(linear_to_srgb( 3.2406 * X - 1.5372 * Y - 0.4986 * Z));
        out.g = clamp(linear_to_srgb(-0.9689 * X + 1.8758 * Y + 0.0415 * Z));
        out.b = clamp(linear_to_srgb( 0.0557 * X - 0.2040 * Y + 1.0570 * Z));
        out.a = this.a;

        return out;
    }
}

export class OKLCHA {
    l : number;
    c : number;
    h : number;
    a : number;

    constructor(l : number = 0, c : number = 0, h : number = 0, a : number = 1) {
        this.l = l;
        this.c = c;
        this.h = h;
        this.a = a;
    }

    public clone(out? : OKLCHA) {
        if (out !== undefined) {
            out.l = this.l;
            out.c = this.c;
            out.h = this.h;
            out.a = this.a;
            return out;
        }

        return new OKLCHA(this.l, this.c, this.h, this.a);
    }

    asRGBA(out? : RGBA): RGBA {
        const angle = this.h * 6.283185;
        const a_component = Math.cos(angle) * this.c;
        const b_component = Math.sin(angle) * this.c;

        const l_ = this.l + 0.3963377774 * a_component + 0.2158037573 * b_component;
        const m_ = this.l - 0.1055613458 * a_component - 0.0638541728 * b_component;
        const s_ = this.l - 0.0894841775 * a_component - 1.2914855480 * b_component;

        const L = l_ ** 3;
        const M = m_ ** 3;
        const S = s_ ** 3;

        const lr =  4.0767416621 * L - 3.3077115913 * M + 0.2309699292 * S;
        const lg = -1.2684380046 * L + 2.6097574011 * M - 0.3413193965 * S;
        const lb = -0.0041960863 * L - 0.7034186147 * M + 1.7076147010 * S;

        const clamp = (n: number) => Math.max(0, Math.min(1, n));
        const linear_to_srgb = (n: number) => {
            n = clamp(n);
            return n > 0.0031308 ? 1.055 * n ** (1 / 2.4) - 0.055 : 12.92 * n;
        };

        out ??= new RGBA();

        out.r = linear_to_srgb(lr);
        out.g = linear_to_srgb(lg);
        out.b = linear_to_srgb(lb);
        out.a = this.a;

        return out;
    }
}

// ### PARSING ###

export function parseRGBA(str: string): RGBA {
    str = str.trim();

    const hex_match = str.match(/^#([a-fA-F0-9]{3,8})$/);
    if (hex_match) {
        const hex = hex_match[1];
        if (hex.length === 3 || hex.length === 4) {
            return new RGBA(
                parseInt(hex[0] + hex[0], 16) / 255,
                parseInt(hex[1] + hex[1], 16) / 255,
                parseInt(hex[2] + hex[2], 16) / 255,
                hex.length === 4 ? parseInt(hex[3] + hex[3], 16) / 255 : 1
            );
        }
        return new RGBA(
            parseInt(hex.slice(0, 2), 16) / 255,
            parseInt(hex.slice(2, 4), 16) / 255,
            parseInt(hex.slice(4, 6), 16) / 255,
            hex.length === 8 ? parseInt(hex.slice(6, 8), 16) / 255 : 1
        );
    }

    const match = str.match(
        /rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*(\d*\.?\d+))?\s*\)|rgba?\(\s*(\d+)\s+(\d+)\s+(\d+)\s*(?:\/\s*(\d*\.?\d+))?\s*\)/
    );

    if (!match) return new RGBA();

    const is_modern = match[5] !== undefined;
    return new RGBA(
        parseInt(is_modern ? match[5] : match[1]) / 255,
        parseInt(is_modern ? match[6] : match[2]) / 255,
        parseInt(is_modern ? match[7] : match[3]) / 255,
        (is_modern ? match[8] : match[4]) !== undefined ? parseFloat(is_modern ? match[8] : match[4]) : 1
    );
}

function parseAngle(val: string): number {
    if (!val || val.toLowerCase() === 'none') return 0;
    val = val.trim();
    if (val.endsWith('deg')) {
        return parseFloat(val) / 360;
    }
    if (val.endsWith('rad')) {
        return parseFloat(val) / (2 * Math.PI);
    }
    if (val.endsWith('grad')) {
        return parseFloat(val) / 400;
    }
    if (val.endsWith('turn')) {
        return parseFloat(val);
    }
    const num = parseFloat(val);
    return isNaN(num) ? 0 : num / 360;
}

function parseNumericChannel(val: string, defaultVal: number = 0, scaleIfGreaterThanOne: boolean = false): number {
    if (!val || val.toLowerCase() === 'none') return defaultVal;
    val = val.trim();
    if (val.endsWith('%')) {
        const num = parseFloat(val);
        return isNaN(num) ? defaultVal : num / 100;
    }
    const num = parseFloat(val);
    if (isNaN(num)) return defaultVal;
    if (scaleIfGreaterThanOne && num > 1) {
        return num / 100;
    }
    return num;
}

function parseAlpha(val: string | undefined): number {
    if (val === undefined) return 1;
    val = val.trim();
    if (val.toLowerCase() === 'none') return 0;
    if (val.endsWith('%')) {
        const num = parseFloat(val);
        return isNaN(num) ? 1 : num / 100;
    }
    const num = parseFloat(val);
    return isNaN(num) ? 1 : num;
}

export function parseHSVA(str: string): HSVA {
    str = str.trim();
    const match = str.match(
        /(?:hsva?|hsla?)\(\s*([^\s,)]+)\s*(?:,\s*|\s+)([^\s,)]+)\s*(?:,\s*|\s+)([^\s,)]+)\s*(?:(?:\/\s*|\s*,\s*)([^\s,)]+))?\s*\)/i
    );
    if (!match) return new HSVA();

    const h = parseAngle(match[1]);
    const is_hsl = str.toLowerCase().startsWith('hsl');

    if (is_hsl) {
        const s_hsl = parseNumericChannel(match[2], 0, true);
        const l = parseNumericChannel(match[3], 0, true);
        const a = parseAlpha(match[4]);

        const v = l + s_hsl * Math.min(l, 1 - l);
        const s_hsv = v === 0 ? 0 : 2 * (1 - l / v);
        return new HSVA(h, s_hsv, v, a);
    } else {
        const s = parseNumericChannel(match[2], 0, true);
        const v = parseNumericChannel(match[3], 0, true);
        const a = parseAlpha(match[4]);
        return new HSVA(h, s, v, a);
    }
}

export function parseOKLCHA(str: string): OKLCHA {
    str = str.trim();
    const match = str.match(
        /oklcha?\(\s*([^\s,)]+)\s*(?:,\s*|\s+)([^\s,)]+)\s*(?:,\s*|\s+)([^\s,)]+)\s*(?:(?:\/\s*|\s*,\s*)([^\s,)]+))?\s*\)/i
    );
    if (!match) return new OKLCHA();

    const l = parseNumericChannel(match[1], 0, true);

    let c_val = match[2].trim();
    let c = 0;
    if (c_val.toLowerCase() !== 'none') {
        if (c_val.endsWith('%')) {
            const num = parseFloat(c_val);
            c = isNaN(num) ? 0 : (num / 100) * 0.4;
        } else {
            const num = parseFloat(c_val);
            c = isNaN(num) ? 0 : num;
        }
    }

    const h = parseAngle(match[3]);
    const a = parseAlpha(match[4]);

    return new OKLCHA(l, c, h, a);
}