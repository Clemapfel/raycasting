var server = Server.default;
//var midi = MIDIInterface.new(server);
var volume = Volume.new(server);
	volume.volume = 0;

thisThread.randSeed = Date.new.rawSeconds;


server.waitForBoot({
    SynthDef(\trigger, { arg out = 0, freq = 440, amp = 0.2, gate = 1;
    var env = EnvGen.ar(
        Env.asr(
            attackTime: 0.01,
            sustainLevel: 1.0,
            releaseTime: 0.1
        ),
        gate: gate,
        doneAction: 2
    );

	var signal = env * SinOsc.ar(freq: freq) * amp;
	signal = Rotate2.ar(
			SinOsc.ar(1.0, phase: 0 * pi),
			DC.ar(0), //SinOsc.ar(20, phase: 1 * pi),
			signal
		);

	Out.ar(out, signal.dup);
}).add;

    server.sync;

    ~clock = TempoClock.new(tempo: 1);

    // 2. Play the pattern using legato to stretch/shrink the notes
    ~pattern = Pbind(
        \instrument, \trigger,
	    \freq, Pbinop('*', 440, Pwhite(1, 4, 12)),
        \dur, 1
    ).play(~clock);
});
