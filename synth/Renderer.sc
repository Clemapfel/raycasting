Renderer {
	var <headerFormat = "WAV";
	var <sampleFormat = "int16";
	var <clock = TempoClock(1);
	var serverOptions;

	classvar nextNodeID = Pseries(1000, 1);

	*new {
		^super.new.init();
	}

	init {
		serverOptions = ServerOptions.new;
		serverOptions.numOutputBusChannels = 1;
		serverOptions.numInputBusChannels = 1;
		serverOptions.memSize = 8192;
		serverOptions.verbosity = -1;
	}

	render { arg synthdef, pattern, filename, n_beats = 1, clock = TempoClock.default;
		var export_dir, osc_file, out_file, score;

		if (synthdef.isKindOf(SynthDef).not) {
			Error("In Renderer.render: for argument #1: expected `SynthDef`, got `%`".format(synthdef.class)).throw;
		};

		if (pattern.isKindOf(Pattern).not) {
			Error("In Renderer.render: for argument #2: expected `Pattern`, got `%`".format(pattern.class)).throw;
		};

		if (n_beats.isKindOf(Integer).not) {
			Error("In Renderer.render: for argument #3: expected `Integer`, got `%`".format(n_beats.class)).throw;
		};

		if (filename.isKindOf(filename).not) {
			Error("In Renderer.render: for argument #4: expected `String`, got `%`".format(filename.class)).throw;
		};

		if (filename.findRegexp("(.*)%\\.wav").isNil) {
			Error("In Renderer.render: for argument #4: expected string of the form `<filename>.wav`, got `%`".format(filename)).throw;
		};

		export_dir = (thisProcess.nowExecutingPath.dirname +/+ "export").standardizePath;
		if (File.exists(export_dir).not) { File.mkdir(export_dir) };

		osc_file = PathName.tmp +/+ UniqueID.next ++ ".osc";
		out_file = export_dir +/+ filename;

		// add pattern that manually decides the s_new ids
		pattern = Pbindf(pattern,
			\id, Renderer.nextNodeID
		);

		// add a small pause so 0.0 osc message are at the start
		pattern = Pseq([Rest(1 / 60), pattern]);

		score = pattern.asScore(n_beats);
		score.add([0.0, ['/d_recv', def.asBytes]]); // allocate synthdef
		score.add([0.0, ['/g_new', 1, 0, 0]]); // allocate group 1

		// sort score so group and synth allocation are in front of pattern
		score.sort();

		// render to disk
		score.recordNRT(
			outputFilePath: export_dir +/+ filename,
			headerFormat: Renderer.headerFormat,
			sampleFormat: Renderer.sampleFormat,
			oscFilePath: osc_file,
			options: this.serverOptions,
			duration: n_beats * clock.beatDur,
			action: {
				File.delete(osc_file);
				if (File.exists(out_path)) {
					"Wrote file to `%`".format(out_path).postln;
				} {
					"Failed to write file to `%`".format(out_path).postln;
				}
			}
		);

	}
};