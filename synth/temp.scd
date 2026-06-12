~oscillators = { arg v;
	{ [FSinOsc.ar(440), SinOsc.ar(440.0 * v)] }
};

Server.default.waitForBoot({
	var buf, window, scope;
	var window_w = 800, window_h = 600;

	buf = Buffer.alloc(Server.default, 1024, 2);
	SynthDef(\scopeOut, {
		var ratio = SinOsc.kr(0.05).range(1 - 1 / 12, 1 + 1 / 12);
		var sig = ~oscillators.value(ratio).value;
		ScopeOut2.ar(sig, buf.bufnum);
		Out.ar(0, sig);
	}).play;

	window = Window("Scope", Rect(0, 0, window_w, window_h));
	scope = ScopeView(window, Rect(0, 0, window_w, window_h));
	scope.style = 2;
	scope.yZoom = 1.0;
	scope.xZoom = 1.0;
	scope.bufnum = buf.bufnum;
	scope.server = Server.default;
	scope.start;
	window.front;
});