var server = Server.default;
var volume = Volume.new(server);
var midi = MIDIInterface.new(server);
~transpose = { arg freq, n;
    (freq.cpsmidi + n).midicps;
};
volume.volume = -20; // db offset

server.waitForBoot({
    var bubble = SynthDef(\bubble, { arg out = 0, base_start, base_end, above_start, above_end, sweep_duration;
        var attack = 0.05;
        var delay = 0.1 * sweep_duration;
        // single envelope, single EnvGen instance, sole doneAction owner
        var env = Env.perc(
            attackTime: sweep_duration * attack,
            releaseTime: sweep_duration * (1 - attack)
        );
        var amplitude = EnvGen.ar(env, doneAction: 2);

        var sweep_base = amplitude * SinOsc.ar(
            freq: XLine.kr(base_start, base_end, dur: sweep_duration),
            phase: Rand(0, 2pi)
        );

		var sweep_above = amplitude * Line.ar(0, 1, delay) *
            SinOsc.ar(
                freq: XLine.kr(above_start, above_end, dur: sweep_duration - delay),
                phase: Rand(0, 2pi)
            );

		var noise = EnvGen.ar(Env.perc(0.001, 0.005)) * BPF.ar(
            WhiteNoise.ar(1),
            freq: 0.05 * XLine.kr(above_end, above_start, sweep_duration)
        );

        var signal = noise + sweep_above + sweep_base;
        Out.ar(out, signal.dup);
    }).add;

    var rep = inf;
    var clock = TempoClock.new(tempo: 2);
	var scale = Scale.chromatic;

	var pattern = Pbind(
		\instrument, \bubble,
		\key, Prand((scale.degrees + 60), inf), // random key in scale
		\base_start,  Pfunc { |ev| (ev[\key] +  0).midicps }, // convert midi key to hertz
		\base_end,    Pfunc { |ev| (ev[\key] + 12).midicps },
		\above_start, Pfunc { |ev| (ev[\key] -  3).midicps },
		\above_end,   Pfunc { |ev| (ev[\key] +  5).midicps },
		\sweep_duration, 0.1
	);

    server.sync;
    pattern.play(clock);
});