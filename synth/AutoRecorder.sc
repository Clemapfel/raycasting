AutoRecorder {
	classvar <>headerFormat = "WAV";
    classvar <>sampleFormat = "int16";
    classvar <>sampleRate = 48000;

	classvar <>recordEndMessage = '/autoRecorderEnd';
	classvar <>warnMessage = '/autoRecorderWarn';

	classvar <>exportPathName = "export";
	classvar <>assetPathName = "assets";
	classvar <>postfixPattern = "_%";

	classvar <>isSilenced = false;

	/*
	// ### EXAMPLE USAGE ###

	// client side

	AutoRecorder.record(
        server,
        AutoRecorder.filename("folder", "file", postfix),
        { |recordbuf|
            Synth.new(def.name, [
                \freq, 440,
                \recordbuf, recordbuf.bufnum
            ]
		}
	);


	// in synth def

	AutoRecorder.ar(recordbuf, sig);

	// where
	// recordbuf: argument given to f in AutoRecorder.reorc
	// sig: signal to be recorded

	AutoRecorder.end(trig);

	// where
    // trig: trigger that signals end of recording
    //       usually Done.kr, DetectSilence, or DelayN.kr(Impulse.kr(0), t, t)

	*/

	*ar { arg recordbuf, sig;
		if (AutoRecorder.isSilenced.not) {
			// warn if recordbuf == 0
		    SendReply.kr((recordbuf <= 0) * Impulse.kr(0), cmdName: AutoRecorder.warnMessage);
		};

		// write to disk
		DiskOut.ar(recordbuf, sig);
	}

	*end { arg trig;
		// notify recording is done
		var method = if (trig.rate == \audio) { \ar } { \kr };
		SendReply.perform(method, trig, cmdName: AutoRecorder.recordEndMessage);
	}

	*record { arg server, filename, f, numChannels = 1;
		var condition, latency, pathname, swap, bus;
		var aborted = false, endDef, warnDef;

		if (server.isKindOf(Server).not) {
			Error("In AutoRecorder.record: argument #1 `server` is not a `Server`").throw;
		};

		if (filename.isKindOf(String).not) {
			Error("In AutoRecorder.record: argument #2 `filename` is not a `String`").throw;
		};

		if (f.isKindOf(Function).not) {
			Error("In AutoRecorder.record: argument #3 `f` is not a `Function`").throw;
		};

		// manually measure latency to keep start/end safety buffer as small as possible
		latency = AutoRecorder.measureLatency(server);

		condition = Condition.new(false);
		pathname = PathName.new(filename.standardizePath);

		// oscdef that unhangs condition after `SendReply` in `end`
		endDef = OSCdef(("autoRecorderEnd" ++ UniqueID.next).asSymbol, {
			condition.test = true;
			condition.signal;
		}, AutoRecorder.recordEndMessage).oneShot;

		// oscdef that warns if ar gets an unassigned bufnum
		warnDef = OSCdef(("autoRecorderWarn" ++ UniqueID.next).asSymbol, {
			"In AutoRecorder.ar: `recordbufnum` is `0`. Was the synthdef argument assigned correctly?".warn;
		}, AutoRecorder.warnMessage).oneShot;

		// alloc buffer
		server.bind {
			Buffer.alloc(server, 1, 1); // alloc dummy buffer so swap can never have bufnum 0 for `ar` warning
			swap = Buffer.alloc(server, AutoRecorder.sampleRate.nextPowerOfTwo, 1);
			bus = Bus.audio(server, numChannels);
			server.sync;
		};

		// open file on disk
		swap.write(filename,
			AutoRecorder.headerFormat,
			AutoRecorder.sampleFormat,
			0, 0, true // DiskOut config
		);
		server.sync;

		"In AutoRecorder: starting recording...".postln;

		// buffer at start and end of recording, will be trimmed on export
		latency.wait;

		// invoke callback, provides local swap, to be handed to `ar`
		f.value(swap, bus);

		// wait for `end` to fire (or for the server to quit)
		condition.wait;

		latency.wait;

		swap.close {
			swap.free {
				latency.wait;
				if (AutoRecorder.postprocess(pathname) == false) {
					"In AutoRecorder: file contains only silence. Was `AutoRecorder.ar` used?".postln;
				};
				"In AutoRecorder: done. Wrote `%` to `%`".format(
					pathname.fileNameWithoutExtension,
					pathname.fullPath
				).postln;
			}
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

		server.sync; // flush pending messages

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

		^(t1 - t0) * 1.5; // safety margin
	}

	*postprocess { arg path;
		var inFile = SoundFile.openRead(path.fullPath);
		var numChannels = inFile.numChannels;
		var numFrames = inFile.numFrames;
		var data = FloatArray.newClear(numFrames * numChannels);

		// trim silence at start and end
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