AutoRecorder {
    classvar <>headerFormat = "WAV";
    classvar <>sampleFormat = "int16";
    classvar <>sampleRate = 48000;

    classvar <>recordEndMessage = '/autoRecorderEnd';
    classvar <>warnMessage = '/autoRecorderWarn';

    classvar <>exportPathName = "export";
    classvar <>assetPathName = "assets";
    classvar <>postfixPattern = "_%";

	classvar <>isRecording = false; // switch on to disable recording

    *ar { arg recordbuf, sig;
		if (AutoRecorder.isRecording) {
			SendReply.kr((recordbuf <= 0) * Impulse.kr(0), cmdName: AutoRecorder.warnMessage);
			DiskOut.ar(recordbuf, sig);
		}
	}

    *end { arg trig;
        var method = if (trig.rate == \audio) { \ar } { \kr };
        SendReply.perform(method, trig, cmdName: AutoRecorder.recordEndMessage);
    }

    *record { arg server, filename, f, numChannels = 1, trimStart = true, trimEnd = true, normalize = false;
        var condition, latency, pathname, swap, bus, dummyBuf;
        var endDef, warnDef;

        if (server.isKindOf(Server).not) {
            Error("In AutoRecorder.record: argument #1 `server` is not a `Server`").throw;
        };

        if (filename.isKindOf(String).not) {
            Error("In AutoRecorder.record: argument #2 `filename` is not a `String`").throw;
        };

        if (f.isKindOf(Function).not) {
            Error("In AutoRecorder.record: argument #3 `f` is not a `Function`").throw;
        };

		protect {
			latency = AutoRecorder.measureLatency(server);
			condition = Condition.new(false);
			pathname = PathName.new(filename.standardizePath);

			endDef = OSCdef(("autoRecorderEnd" ++ UniqueID.next).asSymbol, {
				condition.test = true;
				condition.signal;
			}, AutoRecorder.recordEndMessage).oneShot;

			if (AutoRecorder.isRecording) {
				warnDef = OSCdef(("autoRecorderWarn" ++ UniqueID.next).asSymbol, {
					"In AutoRecorder.ar: `recordbufnum` is `0`. Was the synthdef argument assigned correctly?".warn;
				}, AutoRecorder.warnMessage).oneShot;

				server.bind {
					dummyBuf = Buffer.alloc(server, 1, 1); // dummy to avoid bufnum 0 for warnDef
					swap = Buffer.alloc(server, AutoRecorder.sampleRate.nextPowerOfTwo, numChannels);
					bus = Bus.audio(server, numChannels);
					server.sync;
				};

				swap.write(filename,
					AutoRecorder.headerFormat,
					AutoRecorder.sampleFormat,
					0, 0, true
				);
				server.sync;

				"In AutoRecorder: recording `%` ...".format(
					pathname.fileNameWithoutExtension
				).postln;
			} {
				swap = 0;
				bus = Bus.audio(server, numChannels);

				"In AutoRecorder: playing `%` ...".format(
					pathname.fileNameWithoutExtension
				).postln;
			};

			latency.wait;

			f.value(swap, bus);
			condition.wait;
			latency.wait;
		} {
			endDef !? _.free;
			warnDef !? _.free;

			swap !? {
				try { swap.close };
				try { swap.free };
			};

			dummyBuf !? { try { dummyBuf.free } };
			bus !? { try { bus.free } };

			if (AutoRecorder.isRecording and: { File.exists(pathname.fullPath) }) {
				if (AutoRecorder.postprocess(pathname, trimStart, trimEnd, normalize) == false) {
					"In AutoRecorder: file contains only silence or failed to postprocess.".postln;
				} {
					"In AutoRecorder: wrote `%`".format(
						pathname.fullPath
					).postln;
				};
			} {
				"In AutoRecorder: done playing `%`".format(
					pathname.fileNameWithoutExtension
				).postln;
			};
		};
    }

    *filename { arg prefix, name, degree;
        var exportPath = thisProcess.nowExecutingPath.dirname +/+ AutoRecorder.exportPathName;
        var res;

        if (prefix.isNil || name.isNil) {
            Error("In AutoRecorder.filename: expected string for argument #1 and #2").throw
        };

        if (File.exists(exportPath).not) {
            File.mkdir(exportPath)
        };

        if (File.exists(exportPath +/+ prefix).not) {
            File.mkdir(exportPath +/+ prefix)
        };

        if (degree.isNil) {
            res = exportPath +/+ prefix +/+ name ++ "." ++ AutoRecorder.headerFormat.toLower;
        } {
            res = exportPath +/+ prefix +/+ name ++ (AutoRecorder.postfixPattern ++ "%").format(degree + 1) ++ "." ++ AutoRecorder.headerFormat.toLower;
        };

        ^res.standardizePath;
    }

    *measureLatency { arg server;
        var condition = Condition.new(false);
        var id = UniqueID.next;
        var t0, t1;

        server.sync;

        OSCdef(("ping_" ++ id).asSymbol, { |msg|
            if (msg[1] == id) {
                t1 = Main.elapsedTime;
                condition.test = true;
                condition.signal;
            };
        }, '/synced').oneShot;

        t0 = Main.elapsedTime;
        server.sendMsg('/sync', id);
        condition.wait;

        ^(t1 - t0) * 1.5;
    }

    *postprocess { arg path, trimStart = true, trimEnd = true, normalize = true;
        var inFile = SoundFile.openRead(path.fullPath);
        var numChannels, numFrames, data, isNonZeroFrame;
        var startFrame = nil, endFrame = nil;
        var maxVal = 0.0;

        if (inFile.isNil) { ^false };

        numChannels = inFile.numChannels;
        numFrames = inFile.numFrames;

        if (numFrames <= 0) {
            inFile.close;
            ^false;
        };

        data = FloatArray.newClear(numFrames * numChannels);

        isNonZeroFrame = { |i|
            var result = false;
            numChannels.do { |j|
                if (data[(i * numChannels) + j] != 0.0) { result = true };
            };
            result;
        };

        inFile.readData(data);
        inFile.close;

		if (trimStart) {
			block { |break|
				forBy (0, numFrames - 1, 1) { |i|
					if (isNonZeroFrame.value(i)) {
						startFrame = i;
						break.value;
					};
				};
			};
		} {
			startFrame = 0
		};

		if (trimEnd) {
			block { |break|
				forBy (numFrames - 1, 0, -1) { |i|
					if (isNonZeroFrame.value(i)) {
						endFrame = i;
						break.value;
					};
				};
			};
		} {
			endFrame = numFrames;
		};

        if (startFrame.isNil || endFrame.isNil) {
            ^false;
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

			if (normalize) {
				// normalize magnitudes
				var peak = outData.abs.maxItem;
				if (maxVal > 0.0) {
					outData = outData / maxVal;
				};
			};

            if (outFile.openWrite(path.fullPath)) {
                outFile.writeData(outData);
                outFile.close;
                ^true;
            } {
                "In AutoRecorder.postprocess: failed to open file at `%`".format(
                    path.fullPath
                ).postln;
                ^false;
            };
        };
	}
}