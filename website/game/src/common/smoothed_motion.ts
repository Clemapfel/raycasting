import { Time } from "./time.ts";

/** fmod that returns a value in [0, m) **/
function pmod(x: number, m: number): number {
    return ((x % m) + m) % m;
}

/** **/
export class SmoothedMotion {
    private attack_speed: number;
    private decay_speed: number;
    private ramp: number;
    private current_value: number;
    private target_value: number;

    private is_periodic: boolean = false;
    private lower_bound: number = 0;
    private upper_bound: number = 1;

    /** **/
    constructor(
        value: number,
        speed: number = 1,
        ramp: number = Math.log(1000) // 1s lag time
    ) {
        this.attack_speed = speed;
        this.decay_speed = speed;
        this.ramp = ramp;
        this.current_value = value;
        this.target_value = value;
    }

    /** **/
    public getValue(): number {
        return this.current_value;
    }

    /** **/
    public getTargetValue(): number {
        return this.target_value;
    }

    /** **/
    public setTargetValue(x: number) {
        this.target_value = x;
    }

    /** **/
    public setValue(x: number) {
        this.current_value = x;
    }

    /** **/
    public skip() {
        this.setValue(this.target_value);
    }

    /** **/
    public setSpeed(attack_speed: number, decay_speed: number = attack_speed) {
        this.attack_speed = attack_speed;
        this.decay_speed = decay_speed;
    }

    /** **/
    public setAttackSpeed(speed: number) {
        this.attack_speed = speed;
    }

    /** **/
    public setDecaySpeed(speed: number) {
        this.decay_speed = speed;
    }

    /** **/
    public setIsPeriodic(b: boolean, lower?: number, upper?: number) {
        this.is_periodic = b;

        if (lower !== undefined)
            this.lower_bound = lower;

        if (upper !== undefined)
            this.upper_bound = upper;
    }

    /** **/
    public update(delta: Time): number {
        let distance: number;

        if (this.is_periodic) {
            const range = this.upper_bound - this.lower_bound;
            const direct_distance = this.target_value - this.current_value;
            distance = direct_distance - range * Math.floor((direct_distance + range * 0.5) / range);
        }
        else {
            distance = this.target_value - this.current_value;
        }

        const speed = distance > 0 ? this.attack_speed : this.decay_speed;
        const step = this.ramp * distance * speed * delta.asSeconds();

        this.current_value += step;

        if (this.is_periodic) {
            const range = this.upper_bound - this.lower_bound;
            this.current_value = this.lower_bound + pmod(this.current_value - this.lower_bound, range);

            const final_distance = this.target_value - this.current_value;
            const wrapped_final_distance = final_distance - range * Math.floor((final_distance + range * 0.5) / range);
            if (Math.abs(wrapped_final_distance) < Math.abs(step))
                this.current_value = this.target_value;
        }
        else {
            // clamp overshoot
            if ((distance > 0 && this.current_value > this.target_value)
                || (distance < 0 && this.current_value < this.target_value)
            ) this.current_value = this.target_value;
        }

        return this.current_value;
    }
}