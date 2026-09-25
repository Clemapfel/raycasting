AutoRecorder {
    classvar <>headerFormat = "wav";
    classvar <>sampleFormat = "int16";
    classvar <>sampleRate = 48000;

    var <>path;
    var <>defID;
    var <>server;

    var <>recordEndOSC;
    var <>recordEndOSCdef;
    var <>recordStartOSC;
    var <>recordStartOSCdef;

    var <>doneCondition;
    var <>buffer;
    var <>synth;
    var <>bus;
	var <>shouldTrimSilence;
    var <state = \idle; // states: \idle, \armed, \recording, \stopping

    *new { arg server;
        ^super.new.init(server);
    }

    init { arg inServer, numChannels = 1;
        var id = UniqueID.next;
        server = inServer;

        doneCondition = Condition.new(true);
        recordEndOSC = ("/recordEnd" ++ id).asSymbol;
        recordStartOSC = ("/recordStart" ++ id).asSymbol;
        defID = ("autoRecorder_Disk" ++ id).asSymbol;

        SynthDef(defID, { arg bufnum, bus;
			DiskOut.ar(bufnum, In.ar(bus, numChannels));
        }).add;

		recordStartOSCdef = OSCdef(("recordStartOSCdef" ++ id).asSymbol, {
			server.bind { this.start(); }
		}, recordStartOSC);

		recordEndOSCdef = OSCdef(("recordEndOSCdef" ++ id).asSymbol, {
			server.bind { this.stop(); }
		}, recordEndOSC);

        ^this;
    }

    record { arg filename, f, startAutomatically = true, trimSilence = true, inBus = 0, numChannels = 1;
        if (f.isKindOf(Function).not && f.respondsTo(\play).not) {
            Error("In AutoRecorder.record: argument #2 is not callable").throw
        };

        if (filename.isKindOf(PathName)) {
            filename = filename.fullPath
        };

        if (state != \idle) {
            ^this;
        };

        bus = inBus;
        state = \armed;
        doneCondition.test = false;
		shouldTrimSilence = trimSilence;

        fork {
            buffer = Buffer.alloc(server,
				sampleRate.nextPowerOfTwo,
                numChannels
            );

            server.sync;

            // prepare for writing, synth is started on `start`
            buffer.write(filename, headerFormat, sampleFormat,
                0, 0, true // disk out config
            );

            server.sync;

            path = PathName.new(filename);
			"In AutoRecorder: preparing recording `%`".format(
                path.fileNameWithoutExtension
            ).postln;

			startAutomatically.if { this.start() };

			if (f.isKindOf(Function)) {
				f.value;
			} {
				f.play;
			};
        }

        ^this;
    }

	start { arg group = server.defaultGroup;
		if (state == \armed) {
			state = \recording;

			synth = Synth.tail(group, defID, [
				\bufnum, buffer,
				\bus, bus
			]);

			"In AutoRecorder: recording `%` to `%`".format(
				path.fileNameWithoutExtension,
				path.fullPath
			).postln;
		}
	}

    stop {
        var stateBefore = state;
        var bufToClose;
        var currentPath;

        if (state != \recording) {
            ^this;
        };

        state = \stopping;

        bufToClose = buffer;
        buffer = nil;
        currentPath = path;

        fork {
            if (bufToClose.notNil) {
                bufToClose.close { arg buf;
                    if (synth.notNil and: { synth.isPlaying }) {
                        synth.free;
                    };

                    buf.free;

                    "In AutoRecorder: done recording `%` to `%`".format(
                        currentPath.fileNameWithoutExtension,
                        currentPath.fullPath
                    ).postln;

                    if (shouldTrimSilence) {
                        AutoRecorder.trimSilence(currentPath.fullPath);
                    };

                    state = \idle;
                    doneCondition.test = true;
                    doneCondition.unhang;
                };
            } {
                if (synth.notNil and: { synth.isPlaying }) {
                    synth.free;
                };

                state = \idle;
                doneCondition.test = true;
                doneCondition.unhang;
            };
        }
    }

    begin { arg trig;
		// triggers after recording started are ignored
		^SendReply.ar(trig, recordStartOSC);
    }

	end { arg trig, doneAction = Done.freeSelfToTail;
        var method = if (trig.rate == \audio) { \ar } { \kr };

        var reply = SendReply.perform(method, trig, recordEndOSC);

        DetectSilence.perform(method,
            in: 1 - (trig > 0),
            amp: 0.5,
            time: server.latency,
            doneAction: doneAction
        );

        ^reply;
    }

    wait {
        doneCondition.hang;
    }

    free {
        if (recordStartOSCdef.notNil) { recordStartOSCdef.free; };
        if (recordEndOSCdef.notNil) { recordEndOSCdef.free; };
        if (buffer.notNil) { buffer.free; };
    }

	*trimSilence { arg pathIn;
		var path = PathName.new(pathIn.standardizePath);

		var inFile = SoundFile.openRead(path.fullPath);
		var numChannels = inFile.numChannels;
		var numFrames = inFile.numFrames;
		var data = FloatArray.newClear(numFrames * numChannels);

		var isNonZeroFrame = { |i|
			var result = false;
			numChannels.do { |j|
				if (data[(i * numChannels) + j] != 0.0) { result = true };
			};
			result;
		};

		var startFrame = nil, endFrame = nil;

		inFile.readData(data);
		inFile.close;

		block { |break|
			forBy (0, numFrames - 1, 1) { |i|
				if (isNonZeroFrame.value(i)) {
					startFrame = i;
					break.value;
				};
			};
		};

		block { |break|
			forBy (numFrames - 1, 0, -1) { |i|
				if (isNonZeroFrame.value(i)) {
					endFrame = i;
					break.value;
				};
			};
		};

		if (startFrame.isNil || endFrame.isNil) {
			"In AutoRecorder: file at `%` only silence".format(path.fullPath).postln;
		} {
			var outData = data.copyRange(
				startFrame * numChannels,
				(endFrame * numChannels) + (numChannels - 1)
			);

			var outFile = SoundFile.new()
			    .headerFormat_(inFile.headerFormat)
			    .sampleFormat_(inFile.sampleFormat)
			    .numChannels_(inFile.numChannels)
			    .sampleRate_(inFile.sampleRate)
			;

			if (outFile.openWrite(path.fullPath)) {
				outFile.writeData(outData);
				outFile.close;
				"In AutoRecorder: exported recording `%`".format(
					path.fullPath
				).postln;
			} {
				"In AutoRecorder.trimSilence: failed to open file at `%`".format(
					path.fullPath
				).postln;
			};
		};
	}
}