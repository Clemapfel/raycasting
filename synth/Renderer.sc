Renderer {
    classvar <headerFormat = "WAV";
    classvar <sampleFormat = "int16";
    classvar <sampleRate = 48000;
	classvar <numChannels = 2;
    classvar <serverOptions;
    classvar <>exportPrefix = "export";

    *new {
        ^super.new.init();
    }

    init {} // noop

    initClass {
        serverOptions = ServerOptions.new;
        serverOptions.sampleRate = sampleRate;
        serverOptions.memSize = 8192;
        serverOptions.verbosity = 0;
    }

	*pr_assert { arg got, expected, scope, argIndex, optional = false;
		if (optional and: { got.isNil }) { ^this };
		if (got.isKindOf(expected).not) {
			Error("In Renderer.%: wrong type for argument #%: expected `%`, got `%`".format(scope, argIndex, expected, got.class)).throw;
		};
	}

    *render { arg synthdef, pattern, duration, filename, doneAction;
        var export_dir, osc_file, out_file, score, eps, synthdefPath, currentPath;

		Renderer.pr_assert(synthdef, SynthDef, "render", 1);
        Renderer.pr_assert(pattern, Pattern, "render", 2);
		Renderer.pr_assert(duration, Number, "render", 3, optional: true);
		Renderer.pr_assert(filename, String, "render", 4);
		Renderer.pr_assert(doneAction, Function, "render", 5, optional: true);

        if (duration.isNil) {
            duration = this.measureDuration(pattern);
        } {
            if (duration <= 0) {
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
        pattern = Pbindf(pattern,
			\id, Pseries(1000, 1),
			\instrument, synthdef.name
		);

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

	*record { arg server, pattern, filename, doneAction;
        var export_dir, out_file;
		var group, bus, recorder, bootCondition;
		var startListener, endListener;
		var synthSet, patternDone, recordCondition;

		Renderer.pr_assert(server, Server, "record", 1);
        Renderer.pr_assert(pattern, Pattern, "record", 2);
		Renderer.pr_assert(filename, String, "record", 3);
		Renderer.pr_assert(doneAction, Function, "record", 4, optional: true);

        if (filename.endsWith(".wav").not) {
            Error("In Renderer.record: when recording `%`: for argument #4: expected string of the form `<filename>.wav`, got `%`".format(filename, filename)).throw;
        };

		export_dir = Renderer.getExportDir();
        if (File.exists(export_dir).not) { File.mkdir(export_dir) };

        out_file = export_dir +/+ filename;

		fork {
			// allocate custom bus for this recording
			bus = Bus.audio(server, Renderer.numChannels);

			// init recorder
			recorder = Recorder(server);
			recorder.recHeaderFormat = Renderer.headerFormat;
			recorder.recSampleFormat = Renderer.sampleFormat;

			// allocate group on server if not yet present
			group = server.defaultGroupID;// server.nextNodeID;
			server.sendMsg('/g_new', group, Node.addActions[\addToTail], 0);

			// overwrite the patterns synth, group, and instrument
			pattern = Pbindf(pattern, *[
				out: bus,
				group: group
			]);

			synthSet = IdentitySet.new;
			patternDone = false;
			recordCondition = Condition.new;

			server.queryAllNodes;

			// append a function to the pattern that notifies recorder and condition
			pattern = Pseq([
				Pfuncn({ |env|
					if (env[\instrument].isNil) { "In Renderer.record: pattern does not have the `instrument` key set, it will target the default synth.".warn; };

					recorder.record(out_file, bus, Renderer.numChannels);
					(type: \rest, dur: 0);
				}, 1),

				pattern,

				Pfuncn({
					patternDone = true;
					recordCondition.test = patternDone && synthSet.size == 0;
					recordCondition.signal;
					(type: \rest, dur: 0);
				}, 1),
			]);

			// register listeners
			startListener = OSCdef.new(\start_listener, { arg msg, time, addr, recvPort;
				case
				{ msg[1] == group } {
					// group start
				}
				{ msg[2] == group } {
					// synth in group start: add to set
					synthSet.add(msg[1]);
					recordCondition.test = patternDone && synthSet.size == 0
				};
			}, '/n_go');

			endListener = OSCdef.new(\end_listener, { arg msg, time, addr, recvPort;
				case
				{ msg[1] == group } {
					// group end
				}
				{ msg[2] == group } {
					// synth end: remove from set
					synthSet.remove(msg[1]);

					// update condition
					recordCondition.test = patternDone && synthSet.size == 0;
					recordCondition.signal;
				};
			}, '/n_end');

			// start recording
			pattern.play;

			// wait for pattern to be done
			recordCondition.hang;

			// exit
			recorder.stopRecording;
			if (File.exists(out_file)) {
				"In Renderer.record: Wrote file to `%`".format(out_file).postln;
			} {
				"In Renderer.record: Failed to write file to `%`".format(out_file).postln;
			};

			// unregister listeners
			startListener.free;
		    endListener.free;

			// free synths
			server.sendMsg('/g_deepFree', group);
		} // fork
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
		var stream, inEvent = Event.default;
		var totalSecs = 0.0;
		var count = 0;
		var currentTempo;
		var ev;

		Renderer.pr_assert(pattern, Pattern, "measureDuration", 1);
		Renderer.pr_assert(maxEvents, Integer, "measureDuration", 2);
		Renderer.pr_assert(initialTempo, Number, "measureDuration", 3, optional: true);

		stream = pattern.asStream;
		currentTempo = initialTempo ?? { TempoClock.default.tempo };

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
		var result;

		Renderer.pr_assert(duration, Number, "formatDuration", 1);

		result = duration.asTimeString;

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

		var out;

		Renderer.pr_assert(midiNote, Integer, "degreeToID", 1);
		Renderer.pr_assert(useSharps, Boolean, "degreeToID", 2);

		out = (midiNote - 60).asString;
		while { out.size < 2 } { out = "0" ++ out; };
		^out;
	}

	*tmpFileID {
		^(".tmp_" ++ UniqueID.next ++ ".wav");
	}

    *patternToScore { arg pattern, maxTime;
        var time = 0, bundleList = [];
        var event, proto, stream, ev;
        var clock;

        Renderer.pr_assert(pattern, Pattern, "patternToScore", 1);
        Renderer.pr_assert(maxTime, Number, "patternToScore", 2);

        clock = TempoClock(TempoClock.default.tempo);

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

	*allocBufferFromDuration { arg server, duration, numChannels = 1, doneAction;
		var buffer, numFrames;

		Renderer.pr_assert(server, Server, "allocBufferFromDuration", 1);
		Renderer.pr_assert(duration, Number, "allocBufferFromDuration", 2);
		Renderer.pr_assert(numChannels, Integer, "allocBufferFromDuration", 3);
		Renderer.pr_assert(doneAction, Function, "allocBufferFromDuration", 4, optional: true);

		numFrames = (duration * Renderer.sampleRate).ceil.asInteger;
		^Renderer.allocBuffer(server, numFrames, numChannels, doneAction)
	}

	*allocBuffer { arg server, numFrames, numChannels, doneAction;
		var buffer;

		if (numFrames.isKindOf(Number)) { numFrames = numFrames.ceil.asInteger; };

		Renderer.pr_assert(server, Server, "allocBuffer", 1);
		Renderer.pr_assert(numFrames, Integer, "allocBuffer", 2);
		Renderer.pr_assert(numChannels, Integer, "allocBuffer", 3);
		Renderer.pr_assert(doneAction, Function, "allocBuffer", 4, optional: true);

		^Buffer.alloc(server,
			numFrames: numFrames,
			numChannels: numChannels,
			sampleRate: Renderer.sampleRate,
			completionMessage: {
				if (doneAction.notNil) {
					doneAction.();
				};
			}
		);
	}

	*readBuffer { arg server, filepath, doneAction;
		var buffer;

		Renderer.pr_assert(server, Server, "readBuffer", 1);
		Renderer.pr_assert(filepath, String, "readBuffer", 2);
		Renderer.pr_assert(doneAction, Function, "readBuffer", 3, optional: true);

		^Buffer.read(server, filepath,
			action: {
				if (doneAction.notNil) {
					doneAction.();
				};
			}
		);
	}

	*writeBuffer { arg buffer, filepath, leaveOpen, doneAction;
		Renderer.pr_assert(buffer, Buffer, "writeBuffer", 1);
		Renderer.pr_assert(filepath, String, "writeBuffer", 2);
		Renderer.pr_assert(leaveOpen, Boolean, "writeBuffer", 3, optional: true);
		Renderer.pr_assert(doneAction, Function, "writeBuffer", 4, optional: true);

		doneAction.class.postln;

		buffer.write(filepath,
			headerFormat: Renderer.headerFormat,
			sampleFormat: Renderer.sampleFormat,
			leaveOpen: leaveOpen,
			completionMessage: {
				if (doneAction.notNil) {
					doneAction.();
				};
			}
		);

		^buffer;
	}

	*allocRecorder { arg server, duration, numChannels = 1, doneAction;
		^Renderer.allocBuffer(server,
			duration * Renderer.sampleRate,
			numChannels,
			doneAction
		);
	}
}