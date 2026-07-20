Renderer {
    classvar <headerFormat = "WAV";
    classvar <sampleFormat = "int16";
    classvar <sampleRate = 48000;
    classvar <serverOptions;
    classvar <>exportPrefix = "export";

    *new {
        ^super.new.init();
    }

    init {} // noop

    initClass {
        serverOptions = ServerOptions.new;
        serverOptions.sampleRate = sampleRate;
        serverOptions.numOutputBusChannels = 1;
        serverOptions.numInputBusChannels = 1;
        serverOptions.memSize = 8192;
        serverOptions.verbosity = -2;
    }

    *render { arg synthdef, pattern, filename, duration;
        var export_dir, osc_file, out_file, score, eps, synthdef_path, currentPath;

        if (filename.isKindOf(String).not) {
            Error("In Renderer.render: when rendering an unknown file: for argument #3: expected `String`, got `%`".format(filename.class)).throw;
        };

        if (synthdef.isKindOf(SynthDef).not) {
            Error("In Renderer.render: when rendering `%`: for argument #1: expected `SynthDef`, got `%`".format(filename, synthdef.class)).throw;
        };

        if (pattern.isKindOf(Pattern).not) {
            Error("In Renderer.render: when rendering `%`: for argument #2: expected `Pattern`, got `%`".format(filename, pattern.class)).throw;
        };

        if (filename.endsWith(".wav").not) {
            Error("In Renderer.render: when rendering `%`: for argument #3: expected string of the form `<filename>.wav`, got `%`".format(filename, filename)).throw;
        };

        if (duration.isNil) {
            duration = this.measureDuration(pattern);
        } {
            if (duration.isKindOf(Number).not or: { duration <= 0 }) {
                Error("In Renderer.render: when rendering `%`: for argument #4: expected a positive `Number` or `nil`, got `%`".format(filename, duration)).throw;
            };
        };

        if (duration == inf) {
            Error("In Renderer.render: when rendering `%` duration is infinite".format(filename)).throw;
        };

        currentPath = thisProcess.nowExecutingPath;
        if (currentPath.isNil) {
            export_dir = (File.getcwd +/+ Renderer.exportPrefix).standardizePath;
        } {
            export_dir = (currentPath.dirname +/+ Renderer.exportPrefix).standardizePath;
        };
        if (File.exists(export_dir).not) { File.mkdir(export_dir) };

        osc_file = PathName.tmp +/+ UniqueID.next ++ ".osc";
        out_file = export_dir +/+ filename;

        // write synthedef as file to disk, this allows usage of very large synthdefs
        synthdef_path = PathName.tmp +/+ (SystemSynthDefs.generateTempName ++ ".scsyndef");
        File.use(synthdef_path, "wb", { arg f; f.write(synthdef.asBytes) });

        // make sure pattern allocates s_new ids manually
        pattern = Pbindf(pattern, \id, Pseries(1000, 1));

        // Generate the score bounded by the duration limit
        score = this.patternToScore(pattern, duration);

        // add a pause so 0.0 score events are at the start
        eps = 2 / sampleRate;
        duration = duration + eps;

        score.score.do({ arg e; e[0] = e[0] + eps; });

        // allocate synthdef
        score.add([0.0, ['/d_load', synthdef_path.absolutePath]]);
        score.sort();
        score.recordNRT(
            outputFilePath: out_file,
            headerFormat: headerFormat,
            sampleFormat: sampleFormat,
            oscFilePath: osc_file,
            duration: duration,
            options: serverOptions,
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

	*measureDuration { arg pattern, maxEvents = 100000, initialTempo;
		var stream = pattern.asStream;
		var inEvent = Event.default;
		var totalSecs = 0.0;
		var count = 0;
		// Fallback to the current global tempo (in beats per second) if none is provided
		var currentTempo = initialTempo ?? { TempoClock.default.tempo };
		var ev;

		// Evaluate the stream until it ends, or until we hit the maxEvents safeguard
		while {
			ev = stream.next(inEvent.copy);
			ev.notNil and: { count < maxEvents }
		} {
			var delta = 0;

			// Handle Event patterns (e.g., Pbind)
			if(ev.isKindOf(Event)) {
				// If the event dictates a tempo change, update our tracker
				if(ev[\tempo].notNil) {
					currentTempo = ev[\tempo];
				};
				// Calculate the beat delta (handles \dur, \stretch, \delta, etc.)
				delta = ev.delta ?? 0;
			} {
				// Handle Value patterns (e.g., Pseq([1, 2, 3]))
				if(ev.isNumber) {
					delta = ev;
				}
			};

			// Tempo in SC is beats-per-second. (Beats) / (Beats/Sec) = Seconds
			totalSecs = totalSecs + (delta / currentTempo);
			count = count + 1;
		};

		// Heuristic: If we hit our maximum event limit, the pattern is infinite
		if(count >= maxEvents) {
			^inf
		};

		^totalSecs;
	}

    *patternToScore { arg pattern, maxTime;
        var time = 0, bundleList = [];
        var event, proto, stream, ev;
        var clock = TempoClock(TempoClock.default.tempo);

        proto = (
            schedBundle: { |lag, offset, server ... bundle|
                var timeOffsetSecs = (offset ? 0) / clock.tempo;
                bundleList = bundleList.add([time + timeOffsetSecs + (lag ? 0)] ++ bundle);
            },
            schedBundleArray: { |lag, offset, server, bundle|
                var timeOffsetSecs = (offset ? 0) / clock.tempo;
                bundleList = bundleList.add([time + timeOffsetSecs + (lag ? 0)] ++ bundle);
            }
        );

        event = Event.default.copy.putAll(proto);
        stream = pattern.asStream;

        Routine {
            thisThread.clock = clock;
            while {
                ev = stream.next(event.copy);
                ev.notNil and: { time <= maxTime }
            } {
				// update tempo mid-pattern
                if (ev[\tempo].notNil) { clock.tempo = ev[\tempo] };

                ev.putAll(proto);
                ev.play;

                time = time + (ev.delta / clock.tempo);
            };
        }.value;

        clock.stop;

        bundleList = bundleList.sort { |a, b| a[0] < b[0] };
        ^Score(bundleList);
    }
}