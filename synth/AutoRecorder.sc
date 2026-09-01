AutoRecorder {
    classvar <headerFormat = "WAV";
    classvar <sampleFormat = "int16";
    classvar <sampleRate = 48000;

	var <>idToEntry = Dictionary.new();

	var <>recordStartOSC;
	var <>recordEndOSC;
	var <>recorder;
	var <>recordStartOSCdef;
	var <>recordEndOSCdef;

	*new { arg server;
		^super.new.init(server);
	}

	init { arg server;
		var id = UniqueID.next;

		recorder = Recorder(server);
		recorder.recHeaderFormat = AutoRecorder.headerFormat;
		recorder.recSampleFormat = AutoRecorder.sampleFormat;

		recordStartOSC = ("/recordStart" ++ id).asSymbol;
		recordEndOSC = ("/recordEnd" ++ id).asSymbol;

		recordStartOSCdef = OSCdef(("recordStartOSCdef" ++ id).asSymbol, { arg msg;
			var filename = msg[1].asString;
			var bus = msg[2];
			var numChannels = msg[3];

			recorder.record(filename, bus: bus, numChannels: numChannels);
		}, recordStartOSC);

		recordEndOSCdef = OSCdef(("recordEndOSCdef" ++ id).asSymbol, { arg msg;
			recorder.stopRecording;
		}, recordEndOSC);

		^this;
	}

	start { arg filename, bus = 0, numChannels = 1;
		var symbol;

		if (filename.isKindOf(PathName)) { filename = filename.fullPath; };
		symbol = filename.asSymbol;

		NetAddr.localAddr.sendMsg(recordStartOSC, filename, bus, numChannels);

		^this;
	}

	ar { arg signal;
		^SendReply.ar(DetectSilence.ar(signal), recordEndOSC);
	}

	kr { arg signal;
		^SendReply.kr(DetectSilence.kr(signal), recordEndOSC);
	}

	free {
		if (recordStartOSCdef.isNil.not) { recordStartOSCdef.free; };
		if (recordEndOSCdef.isNil.not) { recordEndOSCdef.free; };
	}
}


    