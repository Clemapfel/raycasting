PeakSentinel {
    // Dictionary to hold all active sentinels
    classvar <allSentinels;

    var <server, <bus;
    var <synth, <oscFunc;
    var <replyID;
    var isPlaying = false;
    var <defName;
    var <key;

    // Initializes the classvar when SuperCollider compiles the class library
    *initClass {
        allSentinels = Dictionary.new;
    }

    *new { |server, bus|
        var resolvedServer, instanceKey;

        resolvedServer = server ?? { Server.default };

        if(bus.isNil or: { bus.isKindOf(Bus).not }) {
            Error("PeakSentinel requires a valid Bus object.").throw;
        };

        // Create a unique key for this specific server/rate/index combination.
        // This ensures that even if two separate Bus objects point to the same
        // underlying hardware index, they share the same Sentinel.
        instanceKey = "%_%_%".format(resolvedServer.name, bus.rate, bus.index);

        // Enforce Singleton per bus: Return existing instance if it already exists
        if(allSentinels.at(instanceKey).notNil) {
            // Optional: notify the user that an existing instance is being reused
            ("PeakSentinel: Watcher already exists for " ++ instanceKey ++ ". Returning existing instance.").postln;
            ^allSentinels.at(instanceKey);
        };

        // Otherwise, create and return a new instance
        ^super.new.init(resolvedServer, bus, instanceKey);
    }

    // Static helper method to clean up all active sentinels at once
    *freeAll {
        allSentinels.copy.do { |sentinel| sentinel.free };
    }

    init { |argServer, argBus, argKey|
        server = argServer;
        bus = argBus;
        key = argKey;

        if(bus.rate != \audio) {
            "PeakSentinel: Warning - designed primarily for audio rate buses.".warn;
        };

        // Store this new instance in the class dictionary
        allSentinels.put(key, this);

        replyID = UniqueID.next;
        defName = "peak_sentinel_ar_" ++ bus.numChannels;

        oscFunc = OSCFunc({ |msg|
            var peakVal = msg[3];
            var busIndex = msg[4];
            "WARNING (PeakSentinel): Clipping detected on Bus % (Peak value: %)".format(
                busIndex,
                peakVal.round(0.001)
            ).warn;
        }, '/peak_sentinel_clip', server.addr, argTemplate: [nil, replyID]).fix;

        isPlaying = true;

        ServerTree.add(this, server);
        if(server.serverRunning) {
            this.doOnServerTree(server);
        };
    }

    doOnServerTree { |srv|
        if(isPlaying and: { srv == server }) {
            Routine {
                this.startSynth;
            }.play(SystemClock);
        }
    }

    startSynth {
        var def = SynthDef(defName, { |busIndex = 0, replyID = -1|
            var sig = In.ar(busIndex, bus.numChannels);
            var maxAmp = sig.asArray.collect(_.abs).reduce('max');
            var isClipping = maxAmp >= 1.0;
            var trig = isClipping > Delay1.ar(isClipping);
            var debouncedTrig = trig * (1.0 - Delay1.ar(Trig1.ar(trig, 0.5)));

            SendReply.ar(debouncedTrig, '/peak_sentinel_clip', [maxAmp, busIndex], replyID);
        });

        def.add;
        server.sync;

        if(isPlaying) {
            synth = Synth.tail(server.defaultGroup, defName, [
                \busIndex, bus.index,
                \replyID, replyID
            ]);
        }
    }

    free {
        isPlaying = false;
        synth !? { synth.free; synth = nil; };
        oscFunc !? { oscFunc.free; oscFunc = nil; };
        ServerTree.remove(this, server);

        // Remove from the dictionary so a new one can be created later if needed
        allSentinels.removeAt(key);
    }
}