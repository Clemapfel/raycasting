var server = Server.default;
var recorder;

// midi mapping
var sliders = Pseq.new((110 .. 117)).asStream;
var knobs = Pseq.new((102 .. 109)).asStream;
var pads = Pseq.new([3, 4, 5, 6]).asStream;
var notes = (12 .. 120);

var volume_knob_id = sliders.next;
var max_volume = 1.0;

var record_pad_id = pads.next;

// server
server.options.memSize = 2**18;
server.options.blockSize = 128;

// recorder
thisProcess.platform.recordingsDir = "C:/Users/cleme/Workspace/raycasting/synth/export";
recorder = Recorder.new(server);
recorder.recHeaderFormat = "wav";
recorder.filePrefix = "recording_" ++ Date.localtime.format("%H_%M_%S_%d_%m_%Y_");

if (server.serverRunning.not) {
    server.boot;
} {
    server.reboot;
};

MIDIClient.init;
MIDIIn.connectAll;

server.waitForBoot({
    var active_notes = Array.newClear(128);

    // Load the meow buffer from the directory where this script is saved
    var meow_path = thisProcess.nowExecutingPath.dirname +/+ "meow.wav";
    var meow_buffer = Buffer.read(server, meow_path);

    // record start / end
    var record_start_midi_def = MIDIdef.cc(\record_on, { arg value, id, channel, source;
        if (value > 0 && recorder.isRecording.not) {
            server.prepareForRecord;
            recorder.record;
        };

        if (value == 0 && recorder.isRecording) {
            recorder.stopRecording;
        };
    }, record_pad_id);

    // volume slider (Global control)
    var volume_bus = Bus.control(server, 1);
    var volume_midi_def = MIDIdef.cc(\volume_handler, { arg value, id, channel, source;
        volume_bus.set(value.linlin(0, 2**7, 0, max_volume));
    }, volume_knob_id);

    // midi bend (Global control)
    var bend_bus = Bus.control(server, 1);
    var bend_midi_def = MIDIdef.bend(\bend_handler, { arg value, channel, source;
        bend_bus.set(value.linlin(0, 2**14, -1, 1));
    });

    // synth
    var pitch_synth_def_id = \pitch_synth_def;
    var pitch_synth_def = SynthDef(pitch_synth_def_id, {
        arg out = 0, frequency = 440, gate = 1, attack = 0.000, decay = 0.05, bufnum;

        var bend, volume, envelope, pitch_ratio;
        var sine_signal, meow_signal, final_signal;

        bend = In.kr(bend_bus.index, bend_bus.numChannels);
        bend = Lag2.kr(bend.linlin(-1, 1, 0, 1));

        frequency = bend.linlin(0, 1, 0.5, 1.5) * frequency;
        pitch_ratio = frequency / 880; // reference pitch

        volume = Lag2.kr(In.kr(volume_bus.index, volume_bus.numChannels));
        envelope = EnvGen.kr(Env.asr(attack, 1.0, decay), gate, doneAction: Done.freeSelf);

        sine_signal = SinOsc.ar(frequency,
			0, // phase
			volume
		);
        meow_signal = PlayBuf.ar(2, bufnum, BufRateScale.kr(bufnum), loop: 0);
        meow_signal = PitchShift.ar(meow_signal,
			0.1,    // window size
			pitch_ratio,
			0.0,   // pitch dispersion
			0.004  // time dispersion
		);

		final_signal = (blend(sine_signal, meow_signal, 0.75)) * volume * envelope;
        Out.ar(out, [final_signal, final_signal]); // dupe for stereo out
    }).add;


    var note_on_midi_def = MIDIdef.noteOn(\note_on, { arg value, id, channel, source;
        if(active_notes[id].notNil) {
            active_notes[id].set(\gate, 0);
        };

        active_notes[id] = Synth(pitch_synth_def_id, [
            \frequency, id.midicps, // convert midi to hz
            \gate, 1,
            \bufnum, meow_buffer.bufnum
        ]);
    }, notes);

    var note_off_midi_def = MIDIdef.noteOff(\note_off, { arg value, id, channel, source;
        if(active_notes[id].notNil) {
            active_notes[id].set(\gate, 0);
            active_notes[id] = nil;
        };
    }, notes);

	   server.sync;

    // main setup
    volume_bus.setSynchronous(0.05);
    bend_bus.setSynchronous(0.0);


});