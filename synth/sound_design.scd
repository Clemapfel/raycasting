var server = Server.default;
var volume = Volume.new(server);
var midi = MIDIInterface.new(server);

var prefix = thisProcess.nowExecutingPath.dirname;

~transpose = { arg freq, n;
    (freq.cpsmidi + n).midicps;
};
volume.volume = -20; // db offset

~bubble_pop;

server.waitForBoot({
	~bubble_pop.();
});

~bubble_pop = {
	 var def = SynthDef(\bubble_pop, { arg out = 0, base_start, base_end, above_start, above_end, sweep_duration;
        var attack = 0.05;
        var delay = 0.1 * sweep_duration;

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

		var snap_duration = 0.032;
		var noise = EnvGen.ar(Env.perc(0.001, snap_duration)) * LPF.ar(
            WhiteNoise.ar(1.0),
			freq: XLine.ar(8000, 10, snap_duration - 0.001)
        );

        var signal = noise + sweep_above + sweep_base;
        Out.ar(out, signal.dup);
    });

    var clock = TempoClock.new(tempo: 2);
	var scale = Scale.chromatic;

	var pattern = Pbind(
		\instrument, \bubble_pop,
		\key, Pseq(scale.degrees + 60, 1),
		\base_start,  Pfunc { |ev| (ev[\key] +  0).midicps }, // convert midi key to hertz
		\base_end,    Pfunc { |ev| (ev[\key] + 12).midicps },
		\above_start, Pfunc { |ev| (ev[\key] -  3).midicps },
		\above_end,   Pfunc { |ev| (ev[\key] +  5).midicps },
		\sweep_duration, 0.1
	);

	var n_beats = 1;
	var out_filename = "bubble_pop.wav";
	var server_options;
	var osc_file_name = PathName.tmp +/+ "bubble_score.osc";
	var score;
	var export_dir = (thisProcess.nowExecutingPath.dirname +/+ "export").standardizePath;
	var out_path = (export_dir +/+ out_filename).standardizePath;

	// add manualy s_new id
	pattern = Pbindf(pattern,
		\id, Pseries(1000, 1)
	);

	score = pattern.asScore(n_beats);
	score.add([0.0, ['/g_new', 1, 0, 0]]);
	score.add([0.0, ['/d_recv', def.asBytes]]);
	score.score.sort({ arg a, b; a[0] < b[0]; });

	server_options = ServerOptions.new;
	server_options.numOutputBusChannels = 1;
	server_options.numInputBusChannels = 1;
	server_options.memSize = 8192;
	server_options.verbosity = 0;

	if (File.exists(export_dir).not) { File.mkdir(export_dir) };

	score.recordNRT(
		outputFilePath: out_path,
		headerFormat: "WAV",
		sampleFormat: "int16",
		oscFilePath: osc_file_name,
		options: server_options,
		duration: n_beats * TempoClock.beatDur,
		action: {
			File.delete(osc_file_name);
			if (File.exists(out_path)) {
				"Wrote file to `%`".format(out_path).postln;
			} {
				"Failed to write file to `%`".format(out_path).postln;
			}
		}
	);
}