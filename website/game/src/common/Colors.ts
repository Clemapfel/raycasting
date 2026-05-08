export class RGBA {
    r : number; // in [0, 1]
    g : number; // in [0, 1]
    b : number; // in [0, 1]
    a : number; // in [0, 1]

    constructor(r : number = 0, g : number = 0, b : number = 0, a : number = 1) {
        this.r = r;
        this.g = g;
        this.b = b;
        this.a = a;
    }
}

export class HSVA {
    h : number; // in [0, 1]
    s : number; // in [0, 1]
    v : number; // in [0, 1]
    a : number; // in [0, 1]

    constructor(h : number = 0, s : number = 0, v : number = 0, a : number = 1) {
        this.h = h;
        this.s = s;
        this.v = v;
        this.a = a;
    }
    
    public toRGBA(): RGBA {
        let hue = this.h;
        let value = this.v;
        let saturation = this.s;
        let alpha = this.a;

        const chroma = value * saturation;
        const hue_sector = hue * 360 / 60;
        const x = chroma * (1 - Math.abs(hue_sector % 2 - 1));
        const m = value - chroma;

        if (hue_sector < 1) return new RGBA(chroma + m, x + m, m, alpha);
        if (hue_sector < 2) return new RGBA(x + m, chroma + m, m, alpha);
        if (hue_sector < 3) return new RGBA(m, chroma + m, x + m, alpha);
        if (hue_sector < 4) return new RGBA(m, x + m, chroma + m, alpha);
        if (hue_sector < 5) return new RGBA(x + m, m, chroma + m, alpha);
        return new RGBA(chroma + m,  m, x + m, alpha);
    }
}

export class LCHA {
    l : number; // in [0, 1]
    c : number; // in [0, 1]
    h : number; // in [0, 1]
    a : number; // in [0, 1]

    constructor(l : number = 0, c : number = 0, h : number = 0, a : number = 1) {
        this.l = l;
        this.c = c;
        this.h = h;
        this.a = a;
    }

    to_rgba(): RGBA {
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

        return new RGBA(
            clamp(linear_to_srgb( 3.2406 * X - 1.5372 * Y - 0.4986 * Z)),
            clamp(linear_to_srgb(-0.9689 * X + 1.8758 * Y + 0.0415 * Z)),
            clamp(linear_to_srgb( 0.0557 * X - 0.2040 * Y + 1.0570 * Z)),
            this.a,
        );
    }
}