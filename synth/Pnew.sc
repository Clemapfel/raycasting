Pnew : Pbind {
    *new { |name ...pairs|
        ^super.new(*([\instrument, name] ++ pairs))
    }
}

Psynth : Pbind {
	*new { |synth ... pairs|
		if (synth.isKindOf(Synth).not) {
			Error("In Psynth: argument #1 is not a synth node").throw;
		};

        ^super.new(*([
			\type, \set,
			\id, synth.nodeID

		] ++ pairs))
	}
}