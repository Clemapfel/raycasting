DoneSentinel {
	// convenience wrapper to free synth from within SynthDef

	*duration { arg duration, doneAction = Done.freeSelf;
		^EnvGen.ar(Env.new([1, 1], [duration], curve: \hold), doneAction: Done.freeSelf)
	}

	*ar { arg ugen, doneAction = Done.freeSelf;
		^DetectSilence.ar(ugen, doneAction: doneAction);
	}

	*kr { arg ugen, doneAction = Done.freeSelf;
		^DetectSilence.kr(ugen, doneAction: doneAction);
	}
}