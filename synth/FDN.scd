~reverb = {
    var server = Server.default;
    var sampleRate = server.sampleRate;

	var n = 8;

	var minDelay = 0.03;
	var maxDelay = 0.1;

	// choose delay amounts
    var delayAmounts = {
		var numDelays = n;

		// pick n logarithmically distributed
		var baseTimes = numDelays.collect { |i|
			minDelay * (maxDelay / minDelay) ** (i / n)
		};

		// then nudge to nearest prime number of samples
		// this ensures delay amounts are coprime
		var isPrime = { |x|
			var prime = true;
			case
			{ x < 2 } { prime = false }
			{ x == 2 } { prime = true }
			{ x.even } { prime = false }
			{
				prime = true;
				(3, 5..x.sqrt.floor).do { |i|
					if (x % i == 0) { prime = false }
				};
			};
			prime;
		};

		var nearestPrime = { |candidate|
			var offset = 0;
			var found = false;
			var result;

			while ({ found.not }, {
				if (isPrime.(candidate + offset)) {
					result = candidate + offset;
					found = true;
				} {
					if ((candidate - offset > 1) && isPrime.(candidate - offset)) {
						result = candidate - offset;
						found = true;
					}
				};
				offset = offset + 1;
			});

			result;
		};

		baseTimes.collect { |t|
			var candidate = (t * sampleRate).round.asInteger;
			nearestPrime.(candidate) / sampleRate;
		};
	}.value;

	// generate nxn orthonormal hadamard matrix using sylvester construction
    var mixingMatrix = { |n|
		var h = [[1]];
		while ({ h.size < n }, {
			var size = h.size;
			var newH = Array.fill(size * 2, { |i|
				Array.fill(size * 2, { |j|
					var r = i % size, c = j % size;
					if (i < size or: { j < size }) {
						h[r][c]
					} {
						h[r][c].neg
					};
				});
			});
			h = newH;
		});

		h / n.sqrt;
	}.value(n);

	// signal * gain -> delay
	var inputGain = 1 ! n;

	// delay -> output * gain
    var outputGain = 1 ! n;

	// feedback weight
	var t60 = 3.0;
	var feedbackGain = delayAmounts.collect { |d|
		10 ** (-3 * d / t60);
	};

    var reverbDef = SynthDef.new(\reverbFDN, { arg out, in, gate = 1, mix = 0.5;
		var dry = In.ar(in);

		var feedbackIn = LocalIn.ar(n);
        var expansion = dry ! n;
        var delays = n.collect { |i|
            DelayC.ar(
                in: (expansion[i] * inputGain[i]) + feedbackIn[i],
                maxdelaytime: delayAmounts[i],
                delaytime: delayAmounts[i] - ControlDur.ir
            );
        };

        var mixed = mixingMatrix.collect { |row, i|
            row.sum { |x, j| x * delays[j] };
        };

        var wet = Mix.ar(delays * outputGain);

		LocalOut.ar(mixed * feedbackGain);

		Out.ar(out, ~amp * ((mix * dry) + (1 - mix) * wet).dup);
		DetectSilence.ar(wet, doneAction: Done.freeSelf);
    }).add;

	var buf = Buffer.read(s, ExampleFiles.apollo11);
	var playDef = SynthDef.new(\playbackFDN, { arg out = 0,  1.0, gate = 1, bufnum;
		Out.ar(out, ~amp * PlayBuf.ar(1,
			bufnum: bufnum,
			trigger: gate,
			doneAction: Done.freeSelf
		).dup);
    }).add;

	var group = Group.new;
	var bus = Bus.audio(server, 1);

    server.sync;

	Synth.new(playDef.name, [
		\out, bus,
		\bufnum, buf.bufnum
	], group, addAction: \addToHead);

	Synth.new(reverbDef.name, [
		\out, 0,
		\in, bus
	], group, addAction: \addToTail);

	/*
    PmonoArtic(def.name, *[
        degree: 0,
        mix: 0.5,
		bufnum: Pn(buf, 1)
    ]).play;
	*/
};