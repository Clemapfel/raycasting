Renderer {
	classvar <headerFormat = "WAV";
	classvar <sampleFormat = "int16";
	classvar <sampleRate = 48000;
	classvar <serverOptions;

	*new {
		^super.new.init();
	}

	init {}

	initClass {
		serverOptions = ServerOptions.new;
		serverOptions.sampleRate = Renderer.sampleRate;
		serverOptions.numOutputBusChannels = 1;
		serverOptions.numInputBusChannels = 1;
		serverOptions.memSize = 8192;
		serverOptions.verbosity = -1;
	}

	/*
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
	*/

	render { arg synthdef, pattern, filename, duration;
		var export_dir, osc_file, out_file, score, eps, synthdef_path;

		if (synthdef.isKindOf(SynthDef).not) {
			Error("In Renderer.render: for argument #1: expected `SynthDef`, got `%`".format(synthdef.class)).throw;
		};

		if (pattern.isKindOf(Pattern).not) {
			Error("In Renderer.render: for argument #2: expected `Pattern`, got `%`".format(pattern.class)).throw;
		};

		if (duration.isKindOf(Number).not) {
			Error("In Renderer.render: for argument #3: expected `Numebr`, got `%`".format(duration.class)).throw;
		};

		if (filename.isKindOf(String).not) {
			Error("In Renderer.render: for argument #4: expected `String`, got `%`".format(filename.class)).throw;
		};

		if (filename.findRegexp("(.*)%\\.wav").isNil) {
			Error("In Renderer.render: for argument #4: expected string of the form `<filename>.wav`, got `%`".format(filename)).throw;
		};

		export_dir = (thisProcess.nowExecutingPath.dirname +/+ "export").standardizePath;
		if (File.exists(export_dir).not) { File.mkdir(export_dir) };

		osc_file = PathName.tmp +/+ UniqueID.next ++ ".osc";
		out_file = export_dir +/+ filename;

		// write synthedef as file to disk, this allows usage of very large synthdefs
		synthdef_path = PathName.tmp +/+ (SystemSynthDefs.generateTempName ++ ".scsyndef");
		File.use(synthdef_path, "wb", { arg f; f.write(synthdef.asBytes) });

		// make sure pattern allocates s_new ids manually
		pattern = Pbindf(pattern,
			\id, Pseries(1000, 1),
			\tempo, 20
		);

		score = pattern.asScore(12);

		// add a pause so 0.0 score events are at the start
		eps = 2 / Renderer.sampleRate;
		duration = duration + eps;
		duration.postln;

		score.score.collect({ arg e; e[0] = e[0] + eps; });

		// allocate synthdef
		score.add([0.0, ['/d_load', synthdef_path.absolutePath]]);

		score.sort();

		score.score.do({ arg e; e.postln; });

		score.recordNRT(
			outputFilePath: export_dir +/+ filename,
			headerFormat: Renderer.headerFormat,
			sampleFormat: Renderer.sampleFormat,
			oscFilePath: osc_file,
			options: Renderer.serverOptions,
			duration: duration,
			action: {
				File.delete(osc_file);
				File.delete(synthdef_path);

				if (File.exists(out_file)) {
					"In Renderer.render: Wrote file to `%`".format(out_file).postln;
				} {
					"In Renderer.render: Failed to write file to `%`".format(out_file).postln;
				}
			}
		);
	}
}