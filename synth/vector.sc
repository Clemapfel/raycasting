Vec2 {
    var <>x, <>y;

    *new { arg x = 0, y = 0;
        ^super.newCopyArgs(x, y);
    }

    clone {
        ^Vec2.new(x, y);
    }

    dot { arg other;
        ^(x * other.x) + (y * other.y);
    }

    cross { arg other;
        ^(x * other.y) - (y * other.x);
    }

    distance { arg other;
        ^((x - other.x).squared + (y - other.y).squared).sqrt;
    }

    squared_distance { arg other;
        var dx, dy;
        dx = x - other.x;
        dy = y - other.y;
        ^(dx.squared + dy.squared);
    }

    magnitude {
        ^(x.squared + y.squared).sqrt;
    }

    angle {
        ^y.atan2(x);
    }

    flip {
        ^Vec2.new(x.neg, y.neg);
    }

    turn_left {
        ^Vec2.new(y, x.neg);
    }

    turn_right {
        ^Vec2.new(y.neg, x);
    }

    normalize {
        var length;
        length = this.magnitude();

        if (length <= 1e-7) {
            ^Vec2.new(0, 0);
        } {
            ^Vec2.new(x / length, y / length);
        };
    }

    rotate { arg angle;
        var cosA, sinA;
        cosA = angle.cos;
        sinA = angle.sin;
        ^Vec2.new(
            (cosA * x) - (sinA * y),
            (sinA * x) + (cosA * y)
        );
    }

    add { arg other;
        if (other.isKindOf(Number)) {
            ^Vec2.new(x + other, y + other);
        };

        if (other.isKindOf(SequenceableCollection)) {
            ^Vec2.new(x + (other[0] ? 0), y + (other[1] ? 0));
        };

        ^Vec2.new(x + other.x, y + other.y);
    }

    subtract { arg other;
        if (other.isKindOf(Number)) {
            ^Vec2.new(x - other, y - other);
        };

        if (other.isKindOf(SequenceableCollection)) {
            ^Vec2.new(x - (other[0] ? 0), y - (other[1] ? 0));
        };

        ^Vec2.new(x - other.x, y - other.y);
    }

    reverse_subtract { arg other;
        if (other.isKindOf(Number)) {
            ^Vec2.new(other - x, other - y);
        };

        if (other.isKindOf(SequenceableCollection)) {
            ^Vec2.new((other[0] ? 0) - x, (other[1] ? 0) - y);
        };

        ^Vec2.new(other.x - x, other.y - y);
    }

    multiply { arg other;
        if (other.isKindOf(Number)) {
            ^Vec2.new(x * other, y * other);
        };

        if (other.isKindOf(SequenceableCollection)) {
            ^Vec2.new(x * (other[0] ? 0), y * (other[1] ? 0));
        };

        ^Vec2.new(x * other.x, y * other.y);
    }

    divide { arg other;
        if (other.isKindOf(Number)) {
            ^Vec2.new(x / other, y / other);
        };

        if (other.isKindOf(SequenceableCollection)) {
            ^Vec2.new(x / (other[0] ? 0), y / (other[1] ? 0));
        };

        ^Vec2.new(x / other.x, y / other.y);
    }

    + { arg other; ^this.add(other); }
    - { arg other; ^this.subtract(other); }
    * { arg other; ^this.multiply(other); }
    / { arg other; ^this.divide(other); }

    performBinaryOpOnSomeArray { arg aSelector, thisArray;
        ^thisArray.collect({ |item| item.perform(aSelector, this) });
    }

    performBinaryOpOnSimpleNumber { arg aSelector, aNumber;
        ^this.perform(aSelector, aNumber);
    }

    at { arg index;
		// required for destructuring
        ^this.asArray.at(index);
    }

    size { ^2; }

    do { arg function;
        this.asArray.do(function);
    }

    asArray {
        ^[x, y];
    }

    *newArray { arg ... args;
        ^args.clump(2).collect { |pair|
            Vec2.new(pair[0], pair[1] ? 0);
        };
    }
}

Vec3 {
    var <>x, <>y, <>z;

    *new { arg x = 0, y = 0, z = 0;
        ^super.newCopyArgs(x, y, z);
    }

    assign { arg ax, ay, az;
        x = ax;
        y = ay;
        z = az;
    }

    clone {
        ^Vec3.new(x, y, z);
    }

    dot { arg other;
        ^((x * other.x) + (y * other.y) + (z * other.z));
    }

    cross { arg other;
        ^Vec3.new(
            (y * other.z) - (z * other.y),
            (z * other.x) - (x * other.z),
            (x * other.y) - (y * other.x)
        );
    }

    distance { arg other;
        ^((x - other.x).squared + (y - other.y).squared + (z - other.z).squared).sqrt;
    }

    squared_distance { arg other;
        var dx, dy, dz;
        dx = x - other.x;
        dy = y - other.y;
        dz = z - other.z;
        ^(dx.squared + dy.squared + dz.squared);
    }

    magnitude {
        ^(x.squared + y.squared + z.squared).sqrt;
    }

    normalize {
        var length;
        length = this.magnitude();

        if (length <= 1e-7) {
            ^Vec3.new(0, 0, 0);
        } {
            ^Vec3.new(x / length, y / length, z / length);
        };
    }

    add { arg other;
        if (other.isKindOf(Number)) {
            ^Vec3.new(x + other, y + other, z + other);
        };

        if (other.isKindOf(SequenceableCollection)) {
            ^Vec3.new(x + (other[0] ? 0), y + (other[1] ? 0), z + (other[2] ? 0));
        };

        ^Vec3.new(x + other.x, y + other.y, z + other.z);
    }

    subtract { arg other;
        if (other.isKindOf(Number)) {
            ^Vec3.new(x - other, y - other, z - other);
        };

        if (other.isKindOf(SequenceableCollection)) {
            ^Vec3.new(x - (other[0] ? 0), y - (other[1] ? 0), z - (other[2] ? 0));
        };

        ^Vec3.new(x - other.x, y - other.y, z - other.z);
    }

    reverse_subtract { arg other;
        if (other.isKindOf(Number)) {
            ^Vec3.new(other - x, other - y, other - z);
        };

        if (other.isKindOf(SequenceableCollection)) {
            ^Vec3.new((other[0] ? 0) - x, (other[1] ? 0) - y, (other[2] ? 0) - z);
        };

        ^Vec3.new(other.x - x, other.y - y, other.z - z);
    }

    multiply { arg other;
        if (other.isKindOf(Number)) {
            ^Vec3.new(x * other, y * other, z * other);
        };

        if (other.isKindOf(SequenceableCollection)) {
            ^Vec3.new(x * (other[0] ? 0), y * (other[1] ? 0), z * (other[2] ? 0));
        };

        ^Vec3.new(x * other.x, y * other.y, z * other.z);
    }

    divide { arg other;
        if (other.isKindOf(Number)) {
            ^Vec3.new(x / other, y / other, z / other);
        };

        if (other.isKindOf(SequenceableCollection)) {
            ^Vec3.new(x / (other[0] ? 0), y / (other[1] ? 0), z / (other[2] ? 0));
        };

        ^Vec3.new(x / other.x, y / other.y, z / other.z);
    }

    + { arg other; ^this.add(other); }
    - { arg other; ^this.subtract(other); }
    * { arg other; ^this.multiply(other); }
    / { arg other; ^this.divide(other); }

    performBinaryOpOnSomeArray { arg aSelector, thisArray;
        ^thisArray.collect({ |item| item.perform(aSelector, this) });
    }

    performBinaryOpOnSimpleNumber { arg aSelector, aNumber;
        ^this.perform(aSelector, aNumber);
    }

    at { arg index;
        ^this.asArray.at(index);
    }

    size { ^3; }

    do { arg function;
        this.asArray.do(function);
    }

    asArray {
        ^[x, y, z];
    }

    *newArray { arg ... args;
        ^args.clump(3).collect { |trio|
            Vec3.new(trio[0], trio[1] ? 0, trio[2] ? 0);
        };
    }
}

Vec4 {
    var <>x, <>y, <>z, <>w;

    *new { arg x = 0, y = 0, z = 0, w = 0;
        ^super.newCopyArgs(x, y, z, w);
    }

    assign { arg ax, ay, az, aw;
        x = ax;
        y = ay;
        z = az;
        w = aw;
    }

    clone {
        ^Vec4.new(x, y, z, w);
    }

    distance { arg other;
        ^((x - other.x).squared + (y - other.y).squared + (z - other.z).squared + (w - other.w).squared).sqrt;
    }

    squared_distance { arg other;
        var dx, dy, dz, dw;
        dx = x - other.x;
        dy = y - other.y;
        dz = z - other.z;
        dw = w - other.w;
        ^(dx.squared + dy.squared + dz.squared + dw.squared);
    }

    magnitude {
        ^(x.squared + y.squared + z.squared + w.squared).sqrt;
    }

    normalize {
        var length;
        length = this.magnitude();

        if (length <= 1e-7) {
            ^Vec4.new(0, 0, 0, 0);
        } {
            ^Vec4.new(x / length, y / length, z / length, w / length);
        };
    }

    add { arg other;
        if (other.isKindOf(Number)) {
            ^Vec4.new(x + other, y + other, z + other, w + other);
        };

        if (other.isKindOf(SequenceableCollection)) {
            ^Vec4.new(x + (other[0] ? 0), y + (other[1] ? 0), z + (other[2] ? 0), w + (other[3] ? 0));
        };

        ^Vec4.new(x + other.x, y + other.y, z + other.z, w + other.w);
    }

    subtract { arg other;
        if (other.isKindOf(Number)) {
            ^Vec4.new(x - other, y - other, z - other, w - other);
        };

        if (other.isKindOf(SequenceableCollection)) {
            ^Vec4.new(x - (other[0] ? 0), y - (other[1] ? 0), z - (other[2] ? 0), w - (other[3] ? 0));
        };

        ^Vec4.new(x - other.x, y - other.y, z - other.z, w - other.w);
    }

    reverse_subtract { arg other;
        if (other.isKindOf(Number)) {
            ^Vec4.new(other - x, other - y, other - z, other - w);
        };

        if (other.isKindOf(SequenceableCollection)) {
            ^Vec4.new((other[0] ? 0) - x, (other[1] ? 0) - y, (other[2] ? 0) - z, (other[3] ? 0) - w);
        };

        ^Vec4.new(other.x - x, other.y - y, other.z - z, other.w - w);
    }

    multiply { arg other;
        if (other.isKindOf(Number)) {
            ^Vec4.new(x * other, y * other, z * other, w * other);
        };

        if (other.isKindOf(SequenceableCollection)) {
            ^Vec4.new(x * (other[0] ? 0), y * (other[1] ? 0), z * (other[2] ? 0), w * (other[3] ? 0));
        };

        ^Vec4.new(x * other.x, y * other.y, z * other.z, w * other.w);
    }

    divide { arg other;
        if (other.isKindOf(Number)) {
            ^Vec4.new(x / other, y / other, z / other, w / other);
        };

        if (other.isKindOf(SequenceableCollection)) {
            ^Vec4.new(x / (other[0] ? 0), y / (other[1] ? 0), z / (other[2] ? 0), w / (other[3] ? 0));
        };

        ^Vec4.new(x / other.x, y / other.y, z / other.z, w / other.w);
    }

    + { arg other; ^this.add(other); }
    - { arg other; ^this.subtract(other); }
    * { arg other; ^this.multiply(other); }
    / { arg other; ^this.divide(other); }

    performBinaryOpOnSomeArray { arg aSelector, thisArray;
        ^thisArray.collect({ |item| item.perform(aSelector, this) });
    }

    performBinaryOpOnSimpleNumber { arg aSelector, aNumber;
        ^this.perform(aSelector, aNumber);
    }

    at { arg index;
        ^this.asArray.at(index);
    }

    size { ^4; }

    do { arg function;
        this.asArray.do(function);
    }

    asArray {
        ^[x, y, z, w];
    }

    *newArray { arg ... args;
        ^args.clump(4).collect { |quad|
            Vec4.new(quad[0], quad[1] ? 0, quad[2] ? 0, quad[3] ? 0);
        };
    }
}