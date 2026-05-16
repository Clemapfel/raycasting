/** **/
export enum TimeUnit {
    HOURS,
    MINUTES,
    SECONDS,
    MILLISECONDS,
    MICROSECONDS
}

/** **/
export class Time {
    private value : number;

    /** **/
    constructor(value : number = 0, unit : TimeUnit = TimeUnit.SECONDS) {
        this.from(value, unit);
    }

    /** **/
    clone() : Time {
        return new Time(this.value);
    }

    /** **/
    add(other : Time, out? : Time) : Time {
        const target = out ?? this;
        target.value = this.value + other.value;
        return target;
    }

    /** **/
    subtract(other : Time, out? : Time) : Time {
        const target = out ?? this;
        target.value = this.value - other.value;
        return target;
    }

    /** **/
    as(unit : TimeUnit): number {
        switch (unit) {
            case TimeUnit.HOURS:
                return this.value / 3600;
            case TimeUnit.MINUTES:
                return this.value / 60;
            case TimeUnit.SECONDS:
                return this.value;
            case TimeUnit.MILLISECONDS:
                return this.value * 1000;
            case TimeUnit.MICROSECONDS:
                return this.value * 1000000;
            default:
                throw new Error(`In Time.as: unhandled time unit ${unit}`);
        }
    }

    /** **/
    asHours() { return this.as(TimeUnit.HOURS); }

    /** **/
    asMinutes() { return this.as(TimeUnit.MINUTES); }

    /** **/
    asSeconds() { return this.as(TimeUnit.SECONDS); }

    /** **/
    asMilliseconds() { return this.as(TimeUnit.MILLISECONDS); }

    /** **/
    asMicroseconds() { return this.as(TimeUnit.MICROSECONDS); }

    /** **/
    from(value: number, unit : TimeUnit) : Time {
        switch (unit) {
            case TimeUnit.HOURS:
                this.value = value * 3600;
                break;
            case TimeUnit.MINUTES:
                this.value = value * 60;
                break;
            case TimeUnit.SECONDS:
                this.value = value;
                break;
            case TimeUnit.MILLISECONDS:
                this.value = value / 1000;
                break;
            case TimeUnit.MICROSECONDS:
                this.value = value / 1000 / 1000;
                break;
            default:
                throw new Error(`In Time.from: unhandled time unit ${unit}`);
        }

        return this;
    }

    /** **/
    fromHours(x : number) { return this.from(x, TimeUnit.HOURS); }

    /** **/
    fromMinutes(x : number) { return this.from(x, TimeUnit.MINUTES); }

    /** **/
    fromSeconds(x : number) { return this.from(x, TimeUnit.SECONDS); }

    /** **/
    fromMilliseconds(x : number) { return this.from(x, TimeUnit.MILLISECONDS); }

    /** **/
    fromMicroseconds(x : number) { return this.from(x, TimeUnit.MICROSECONDS); }
}

/** **/
export function Hours(x : number) { return new Time(x, TimeUnit.HOURS); }

/** **/
export function Minutes(x : number) { return new Time(x, TimeUnit.MINUTES); }

/** **/
export function Seconds(x : number) { return new Time(x, TimeUnit.SECONDS); }

/** **/
export function Milliseconds(x : number) { return new Time(x, TimeUnit.MILLISECONDS); }

/** **/
export function Microseconds(x : number) { return new Time(x, TimeUnit.MICROSECONDS); }
