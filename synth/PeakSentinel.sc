PeakSentinel {
	classvar <allSentinels; // static list of all active sentinels

	var <monitoredBus;
	var <oscFunc, <oscID;
	var <>synth, <synthDef;

	*initClass {
		allSentinels = Dictionary.new;
	}

	init { arg server, bus, hash;
		var genSynthDef = { arg numChannels;
			var name = ("peakSentinelMonitor_" ++ numChannels.asString).asSymbol;
			SynthDef(name, { arg bus = 0, oscID = -1;
				var signal = In.ar(bus, numChannels);

				// send an OSC message anytime a new all-time peaked is encountered
				var reduced = signal.reduce('max').abs;
				var runningMax = RunningMax.ar(
					reduced,
					DetectSilence.ar(reduced)
				);
				var newPeak = (HPZ1.ar(runningMax) > 0) * (runningMax >= 1.0);

				SendReply.ar(
					Changed.ar(newPeak),
					'/peak_sentinel_print_warning',
					[ bus, runningMax ],
					oscID
				);
			});
		};

		synthDef = genSynthDef.(bus.numChannels);
		synthDef.add;

		if (bus.rate != \audio) {
			Error("In PeakSentinel.init: bus is not an audio bus").throw;
		};

		oscID = UniqueID.next;
		oscFunc = OSCdef.new(("peakSentinelWarn_" ++ hash).asSymbol, { arg msg, time, addr, recvPort;
			var bus = msg[3].asInteger;
			var peakValue = msg[4];
			"In PeakSentinel: Clipping detected on Bus `%` (Peak Value: `%`)".format(
				bus,
				peakValue
			).warn;
		}, '/peak_sentinel_print_warning', server.addr);

		// add to singleton instance list
		allSentinels.put(hash, this);

		// register with the server tree so it stays global
		ServerTree.add(this, server);

		monitoredBus = bus;
	}

	*new { arg server, bus;
		var hash;

		server = server ?? Server.default;
		bus = bus ?? server.outputBus;

		if (server.isKindOf(Server).not) {
			Error("In PeakSentinel.new: expected `Server` for argument #1, got `%`".format(bus.class)).throw;
		};

		if (bus.isKindOf(Bus).not) {
			Error("In PeakSentinel.new: expected `Bus` for argument #2, got `%`".format(bus.class)).throw;
		};

		// generate unique hash for this server/bus combination
		hash = "%_%".format(server.hash, bus.hash);

		// if a sentinel already exists for this bus, do not create a new one
		if (allSentinels.at(hash).notNil) {
			^allSentinels.at(hash);
		};

		^super.new.init(server, bus, hash);
	}

	doOnServerTree { arg server;
		if (synth.isNil.not) {
			synth.free;
		};

		synth = Synth.tail(
			RootNode(server), // add to the end of all groups
			synthDef.name,
			[
				\bus, monitoredBus,
				\oscID, oscID,
				\numChannels, monitoredBus.numChannels
			]
		);
	}
}