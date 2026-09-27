AutoRecorder {
	classvar <>headerFormat = "wav";
    classvar <>sampleFormat = "int16";
    classvar <>sampleRate = 48000;

	classvar <>oscMessageID = '/autoRecorderEnd';

	classvar <>exportPathName = "export";
	classvar <>assetPathName = "assets";

	*record { arg recordbuf, sig;
		DiskOut.ar(recordbuf, sig);
	}

	*end { arg trig;
		var method = if (trig.rate == \audio) { \ar } { \kr };
		SendReply.perform(method, trig, cmdName: AutoRecorder.oscMessageID);
	}

	*start { arg filename, f;
		if (f.isKindOf(Function).not) {
			Error("In AutoRecorder.record: argument #2 is not a function").throw;
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
			File.mkdir(~export_path +/+ prefix)
		};

		if (degree.isNil) {
			res = exportPath +/+ prefix +/+ name ++ "." ++ AutoRecorder.headerFormat;
		} {
			res = exportPath +/+ prefix +/+ name ++ "_%".format(degree + 1) ++ "." ++ AutoRecorder.headerFormat;
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
		^((t1 - t0) * 1.5).max(server.latency); // safety margin
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
			"In AutoRecorder.trimSilence: file at `%` only silence".format(path.fullPath).postln;
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
				"In AutoRecorder.trimSilence: exported recording `%`".format(
					path.fullPath
				).postln;
				^true;
			} {
				"In AutoRecorder.trimSilence: failed to open file at `%`".format(
					path.fullPath
				).postln;
				^false;
			};
		};
	}


}