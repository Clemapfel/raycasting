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
        serverOptions.verbosity = -1;
    }

    *render { arg synthdef, pattern, duration, filename, doneAction;
        var export_dir, osc_file, out_file, score, eps, synthdefPath, currentPath;

        if (filename.isKindOf(String).not) {
            Error("In Renderer.render: when rendering an unknown file: for argument #3: expected `String`, got `%`".format(filename.class)).throw;
        };

        if (synthdef.isKindOf(SynthDef).not) {
            Error("In Renderer.render: when rendering `%`: for argument #1: expected `SynthDef`, got `%`".format(filename, synthdef.class)).throw;
        };

        if (pattern.isKindOf(Pattern).not) {
            Error("In Renderer.render: when rendering `%`: for argument #2: expected `Pattern`, got `%`".format(filename, pattern.class)).throw;
        };

		if (duration.isNil) {
            duration = this.measureDuration(pattern);
        } {
            if (duration.isKindOf(Number).not or: { duration <= 0 }) {
                Error("In Renderer.render: when rendering `%`: for argument #3: expected a positive `Number` or `nil`, got `%`".format(filename, duration)).throw;
            };
        };

        if (filename.endsWith(".wav").not) {
            Error("In Renderer.render: when rendering `%`: for argument #4: expected string of the form `<filename>.wav`, got `%`".format(filename, filename)).throw;
        };

        if (duration == inf) {
            Error("In Renderer.render: when rendering `%` duration is infinite".format(filename)).throw;
        };

		export_dir = Renderer.getExportDir();
        if (File.exists(export_dir).not) { File.mkdir(export_dir) };

        osc_file = PathName.tmp +/+ UniqueID.next ++ ".osc";
        out_file = export_dir +/+ filename;

        // write synthedef as file to disk, this allows usage of very large synthdefs
        synthdefPath = PathName.tmp +/+ (SystemSynthDefs.generateTempName ++ ".scsyndef");

		// write as bytes instead of writeDefFile to ensure path and naming
        File.use(synthdefPath, "wb", { arg f; f.write(synthdef.asBytes) });

        // make sure pattern allocates s_new ids manually
        pattern = Pbindf(pattern, \id, Pseries(1000, 1));

        // Generate the score bounded by the duration limit
        score = this.patternToScore(pattern, duration);

        // add a pause so 0.0 score events are at the start
        eps = 2 / sampleRate;
        duration = duration + eps;

        score.score.do({ arg e; e[0] = e[0] + eps; });

        // allocate synthdef
        score.add([0.0, ['/d_load', synthdefPath.absolutePath]]);
        score.sort();

		"In Renderer.render: rendering % (%s)".format(filename, Renderer.formatDuration(duration)).postln;

        score.recordNRT(
            outputFilePath: out_file,
            headerFormat: headerFormat,
            sampleFormat: sampleFormat,
            oscFilePath: osc_file,
            duration: duration,
            options: serverOptions,
            action: {
                File.delete(osc_file);
				File.delete(synthdefPath);
                if (File.exists(out_file)) {
                    "In Renderer.render: Wrote file to `%`".format(out_file).postln;
                } {
                    "In Renderer.render: Failed to write file to `%`".format(out_file).postln;
                };

				if (doneAction.notNil) {
					doneAction.value(out_file);
				};
            }
        );
    }

	*getExportDir {
		var export_dir;
		var currentPath = thisProcess.nowExecutingPath;
        if (currentPath.isNil) {
            export_dir = (File.getcwd +/+ Renderer.exportPrefix).standardizePath;
        } {
            export_dir = (currentPath.dirname +/+ Renderer.exportPrefix).standardizePath;
        };

		^export_dir;
	}

	*measureDuration { arg pattern, maxEvents = 10000, initialTempo;
		var stream = pattern.asStream;
		var inEvent = Event.default;
		var totalSecs = 0.0;
		var count = 0;
		var currentTempo = initialTempo ?? { TempoClock.default.tempo };
		var ev;

		while {
			ev = stream.next(inEvent.copy);
			ev.notNil and: { count < maxEvents }
		} {
			var delta = 0;

			if(ev.isKindOf(Event)) {
				// handle tempo changing mid-pattern
				if(ev[\tempo].notNil) {
					currentTempo = ev[\tempo];
				};
				delta = ev.delta ?? 0;
			} {
				if(ev.isNumber) {
					delta = ev;
				}
			};

			totalSecs = totalSecs + (delta / currentTempo);
			count = count + 1;
		};

		if(count >= maxEvents) {
			^inf
		};

		^totalSecs;
	}

	*formatDuration { arg duration;
		var result = duration.asTimeString;

		^result;
	}

	*degreeToID { arg midiNote = 60, useSharps = false;
		/*
		var octave = midiNote.div(12) - 1; // 60 is C4
		var pitchClass = midiNote % 12;
		var noteData;

		var sharpsMap = [
			["C",  ""], ["C", "s"], ["D",  ""], ["D", "s"],
			["E",  ""], ["F",  ""], ["F", "s"], ["G",  ""],
			["G", "s"], ["A",  ""], ["A", "s"], ["B",  ""]
		];

		var flatsMap = [
			["C",  ""], ["D", "b"], ["D",  ""], ["E", "b"],
			["E",  ""], ["F",  ""], ["G", "b"], ["G",  ""],
			["A", "b"], ["A",  ""], ["B", "b"], ["B",  ""]
		];

		useSharps.if({
			noteData = sharpsMap[pitchClass];
		}, {
			noteData = flatsMap[pitchClass];
		});

		^noteData[0] ++ noteData[1] ++ octave.asString;
		*/

		var out = (midiNote - 60).asString;
		while { out.size < 2 } { out = "0" ++ out; };
		^out;
	}

	*tmpFileID {
		^(".tmp_" ++ UniqueID.next ++ ".wav");
	}

    *patternToScore { arg pattern, maxTime;
        var time = 0, bundleList = [];
        var event, proto, stream, ev;
        var clock = TempoClock(TempoClock.default.tempo);

        proto = (
            schedBundle: { arg lag, offset, server ... bundle;
                var timeOffsetSecs = (offset ? 0) / clock.tempo;
                bundleList = bundleList.add([time + timeOffsetSecs + (lag ? 0)] ++ bundle);
            },
            schedBundleArray: { arg lag, offset, server, bundle;
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