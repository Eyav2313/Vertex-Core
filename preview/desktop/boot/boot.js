function getBootProfile() {
            const cores = navigator.hardwareConcurrency || 2;
            const memory = navigator.deviceMemory || 4;
            const score = (cores * 0.62) + (memory * 0.72);
            const fast = score >= 8;
            const slow = score < 4.5;

            return {
                consoleMs: fast ? 1450 : slow ? 2350 : 1850,
                logoMs: fast ? 3600 : slow ? 5600 : 4400,
                spinnerMs: fast ? 1450 : slow ? 2500 : 1850,
                cores,
                memory
            };
        }

        function preloadImage(src) {
            return new Promise((resolve) => {
                const image = new Image();
                image.onload = resolve;
                image.onerror = resolve;
                image.src = src;
            });
        }

        async function runAdaptiveBoot(bootScreen, wallpaper) {
            const profile = getBootProfile();

            bootScreen.classList.add('logo-phase');
            const assetWait = Promise.all([
                preloadImage('../../assets/branding/vertex-logo.png'),
                preloadImage('../../assets/wallpapers/vertex-lock-background.png')
            ]);
            const start = performance.now();
            await Promise.race([assetWait, delay(1400)]);
            await delay(Math.max(0, profile.logoMs - (performance.now() - start)));

            bootScreen.classList.remove('logo-phase');
            bootScreen.classList.add('spinner-phase');
            await delay(profile.spinnerMs);

            bootScreen.classList.add('boot-exit');
            wallpaper.classList.add('wp-ready');
            document.body.classList.add('lock-ready');
            setTimeout(playBootRevealSound, 160);
            setTimeout(() => bootScreen.style.display = 'none', 900);
        }

        function playBootRevealSound() {
            if (window.__vertexBootRevealSoundPlayed) return;
            window.__vertexBootRevealSoundPlayed = true;

            if (typeof playVertexSound === 'function') {
                playVertexSound('start', 0.82).catch(() => playBootRevealToneFallback());
                return;
            }

            playBootRevealToneFallback();
        }

        function playBootRevealToneFallback() {
            const AudioEngine = window.AudioContext || window.webkitAudioContext;
            if (!AudioEngine) return;

            try {
                const ctx = new AudioEngine({ latencyHint: 'interactive' });
                const start = ctx.currentTime + 0.02;
                const master = ctx.createGain();
                const filter = ctx.createBiquadFilter();

                filter.type = 'lowpass';
                filter.frequency.setValueAtTime(6400, start);
                filter.Q.setValueAtTime(0.42, start);
                master.gain.setValueAtTime(0.0001, start);
                master.gain.exponentialRampToValueAtTime(0.085, start + 0.035);
                master.gain.exponentialRampToValueAtTime(0.0001, start + 1.05);
                filter.connect(master);
                master.connect(ctx.destination);

                [
                    { frequency: 523.25, delay: 0.00, duration: 0.38, gain: 0.22, type: 'triangle' },
                    { frequency: 659.25, delay: 0.055, duration: 0.52, gain: 0.17, type: 'sine' },
                    { frequency: 987.77, delay: 0.18, duration: 0.58, gain: 0.11, type: 'sine' },
                    { frequency: 1318.51, delay: 0.28, duration: 0.46, gain: 0.055, type: 'sine' }
                ].forEach((voice) => {
                    const osc = ctx.createOscillator();
                    const gain = ctx.createGain();
                    const t = start + voice.delay;

                    osc.type = voice.type || 'sine';
                    osc.frequency.setValueAtTime(voice.frequency, t);
                    osc.frequency.exponentialRampToValueAtTime(voice.frequency * 1.006, t + voice.duration);
                    gain.gain.setValueAtTime(0.0001, t);
                    gain.gain.exponentialRampToValueAtTime(voice.gain, t + 0.028);
                    gain.gain.exponentialRampToValueAtTime(0.0001, t + voice.duration);
                    osc.connect(gain);
                    gain.connect(filter);
                    osc.start(t);
                    osc.stop(t + voice.duration + 0.05);
                });

                if (ctx.state === 'suspended') {
                    ctx.resume().catch(() => {});
                }
                setTimeout(() => ctx.close().catch(() => {}), 1200);
            } catch (_) {
                window.__vertexBootRevealSoundPlayed = false;
            }
        }
