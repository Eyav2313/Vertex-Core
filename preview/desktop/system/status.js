function initBatteryWidget() {
            const widget = document.getElementById('battery-widget');
            const fill = document.getElementById('battery-fill');
            const meterFill = document.getElementById('battery-meter-fill');
            const percentText = document.getElementById('battery-percent');
            const caption = document.getElementById('battery-caption');
            if (!fill) return;
            let lastChargingState = null;

            const isFastCharging = (level, battery) => {
                const info = window.VERTEX_SYSTEM_INFO || {};
                if (/fast|quick|turbo/i.test(info.battery || '')) return true;
                if (!battery || !battery.charging || !Number.isFinite(battery.chargingTime)) return false;
                return level < 0.8 && battery.chargingTime > 0 && battery.chargingTime <= 3600;
            };

            const setLevel = (level, charging = false, options = {}) => {
                const percent = Math.max(0, Math.min(100, Math.round(level * 100)));
                const visualPercent = Math.max(8, percent);
                const fastCharging = charging && (options.fastCharging || isFastCharging(level, options.battery));
                if (widget) {
                    widget.classList.remove('unknown');
                    widget.classList.toggle('charging', charging);
                    widget.title = fastCharging ? `Battery ${percent}%, fast charging` : (charging ? `Battery ${percent}%, charging` : `Battery ${percent}%`);
                    widget.setAttribute('aria-label', widget.title);
                }
                fill.style.setProperty('--battery-level', `${visualPercent}%`);
                fill.style.setProperty('--battery-level-scale', `${visualPercent / 100}`);
                if (meterFill) {
                    meterFill.style.setProperty('--battery-level', `${percent}%`);
                    meterFill.classList.toggle('charging', charging);
                }
                if (percentText) percentText.textContent = `${percent}%`;
                if (caption) caption.textContent = fastCharging ? 'Fast charging from AC power' : (charging ? 'Charging from AC power' : (percent <= 20 ? 'Low battery' : 'Battery available'));

                if (options.announce && lastChargingState !== null && charging !== lastChargingState) {
                    playBatteryPowerSound(charging ? 'plug-in' : 'plug-out');
                    showChargingAura({
                        charging,
                        fastCharging,
                        percent
                    });
                }
                lastChargingState = charging;
            };

            const setUnknown = () => {
                if (widget) {
                    widget.classList.add('unknown');
                    widget.classList.remove('charging');
                    widget.title = 'Battery unavailable';
                    widget.setAttribute('aria-label', 'Battery status unavailable');
                }
                fill.style.setProperty('--battery-level-scale', '0');
                if (meterFill) {
                    meterFill.style.setProperty('--battery-level', '0%');
                    meterFill.classList.remove('charging');
                }
                if (percentText) percentText.textContent = 'Unknown';
                if (caption) caption.textContent = 'Battery status unavailable';
                lastChargingState = null;
            };

            const info = window.VERTEX_SYSTEM_INFO || {};
            window.vertexUpdateBatteryState = (detail = {}) => {
                if (typeof detail.percent !== 'number') return;
                setLevel(detail.percent / 100, Boolean(detail.charging), {
                    announce: true,
                    fastCharging: Boolean(detail.fastCharging)
                });
            };
            window.addEventListener('vertex:battery', (event) => {
                window.vertexUpdateBatteryState(event.detail || {});
            });

            if (typeof info.batteryPercent === 'number') {
                setLevel(info.batteryPercent / 100, /charging|ac power|adapter|plugged|external/i.test(info.battery || ''));
                return;
            }
            if (!navigator.getBattery) {
                setUnknown();
                return;
            }

            navigator.getBattery().then((battery) => {
                const update = (announce = false) => setLevel(battery.level, battery.charging, { battery, announce });
                update();
                battery.addEventListener('levelchange', update);
                battery.addEventListener('chargingchange', () => update(true));
            }).catch(() => setUnknown());
        }

        function playBatteryPowerSound(kind) {
            if (typeof playVertexSound === 'function') {
                const volume = kind === 'plug-out' ? 0.72 : 0.82;
                playVertexSound(kind, volume).catch(() => playBatteryPowerToneFallback(kind));
                return;
            }

            playBatteryPowerToneFallback(kind);
        }

        function playBatteryPowerToneFallback(kind) {
            const AudioEngine = window.AudioContext || window.webkitAudioContext;
            if (!AudioEngine) return;

            try {
                const ctx = new AudioEngine({ latencyHint: 'interactive' });
                const start = ctx.currentTime + 0.015;
                const master = ctx.createGain();
                const filter = ctx.createBiquadFilter();
                const voices = kind === 'plug-out'
                    ? [
                        { frequency: 659.25, delay: 0, duration: 0.18, gain: 0.09, type: 'triangle' },
                        { frequency: 493.88, delay: 0.08, duration: 0.24, gain: 0.07, type: 'sine' }
                    ]
                    : [
                        { frequency: 523.25, delay: 0, duration: 0.18, gain: 0.1, type: 'triangle' },
                        { frequency: 783.99, delay: 0.07, duration: 0.28, gain: 0.085, type: 'sine' },
                        { frequency: 1046.5, delay: 0.16, duration: 0.32, gain: 0.055, type: 'sine' }
                    ];

                filter.type = 'lowpass';
                filter.frequency.setValueAtTime(kind === 'plug-out' ? 4600 : 6200, start);
                filter.Q.setValueAtTime(0.38, start);
                master.gain.setValueAtTime(0.0001, start);
                master.gain.exponentialRampToValueAtTime(kind === 'plug-out' ? 0.075 : 0.095, start + 0.025);
                master.gain.exponentialRampToValueAtTime(0.0001, start + 0.68);
                filter.connect(master);
                master.connect(ctx.destination);

                voices.forEach((voice) => {
                    const osc = ctx.createOscillator();
                    const gain = ctx.createGain();
                    const t = start + voice.delay;
                    osc.type = voice.type || 'sine';
                    osc.frequency.setValueAtTime(voice.frequency, t);
                    if (kind === 'plug-out') {
                        osc.frequency.exponentialRampToValueAtTime(voice.frequency * 0.985, t + voice.duration);
                    }
                    gain.gain.setValueAtTime(0.0001, t);
                    gain.gain.exponentialRampToValueAtTime(voice.gain, t + 0.018);
                    gain.gain.exponentialRampToValueAtTime(0.0001, t + voice.duration);
                    osc.connect(gain);
                    gain.connect(filter);
                    osc.start(t);
                    osc.stop(t + voice.duration + 0.05);
                });

                if (ctx.state === 'suspended') {
                    ctx.resume().catch(() => {});
                }
                setTimeout(() => ctx.close().catch(() => {}), 900);
            } catch (_) {}
        }

        function showChargingAura({ charging, fastCharging, percent }) {
            const aura = document.getElementById('charge-aura');
            const frost = document.getElementById('charge-frost');
            const icon = document.getElementById('charge-aura-icon');
            const title = document.getElementById('charge-aura-title');
            const subtitle = document.getElementById('charge-aura-subtitle');
            if (!aura || !icon || !title || !subtitle) return;

            window.clearTimeout(window.__vertexChargeAuraTimer);
            aura.classList.toggle('unplugged', !charging);
            icon.textContent = charging ? 'ϟ' : 'AC';
            title.textContent = charging ? (fastCharging ? 'Fast Charging' : 'Charging') : 'Power Disconnected';
            subtitle.textContent = charging ? `${percent}% battery` : `${percent}% remaining`;
            icon.textContent = charging ? 'AC' : '--';
            aura.setAttribute('aria-hidden', 'false');
            aura.classList.add('active');
            if (frost) {
                frost.setAttribute('aria-hidden', 'false');
                frost.classList.add('active');
            }

            window.__vertexChargeAuraTimer = window.setTimeout(() => {
                aura.classList.remove('active');
                if (frost) frost.classList.remove('active');
                window.setTimeout(() => aura.setAttribute('aria-hidden', 'true'), 520);
                window.setTimeout(() => frost?.setAttribute('aria-hidden', 'true'), 520);
            }, charging ? 2200 : 1800);
        }

        function initNetworkWidget() {
            const network = document.getElementById('network-widget');
            if (!network) return;

            const update = () => {
                const info = window.VERTEX_SYSTEM_INFO || {};
                const connected = info.network?.connected ?? navigator.onLine;
                network.style.opacity = connected ? '1' : '0.46';
                network.title = connected ? (info.network?.name ? `Connected: ${info.network.name}` : 'Network connected') : 'Network offline';
                network.setAttribute('aria-label', network.title);
                const menuNetwork = document.getElementById('system-menu-network-label');
                if (menuNetwork) menuNetwork.textContent = connected ? (info.network?.name || 'Network Connected') : 'Network Offline';
                const metric = document.getElementById('metric-network');
                if (metric) metric.textContent = connected ? (info.network?.name || 'Online') : 'Offline';
            };

            update();
            window.addEventListener('online', update);
            window.addEventListener('offline', update);
        }

        function renderNetworkList() {
            const list = document.getElementById('network-list');
            if (!list) return;

            const info = window.VERTEX_SYSTEM_INFO || {};
            const networks = Array.isArray(info.networks) ? info.networks : [];
            const connected = info.network?.connected ?? navigator.onLine;
            const currentName = info.network?.name || (connected ? 'Current network' : 'No connection');
            const currentStatus = connected ? 'Connected, secured' : 'Offline';
            const available = networks;

            const connectedSection = `
                <div class="panel-label">Connected</div>
                <div class="panel-row network-row">
                    <div class="row-text">
                        <span class="row-title">${escapeHtml(currentName)}</span>
                        <span class="row-subtitle">${escapeHtml(currentStatus)}</span>
                    </div>
                    <span class="row-status">${connected ? 'On' : 'Off'}</span>
                </div>
            `;

            const availableSection = available.length ? available.map((item) => {
                const name = item.name || 'Unknown network';
                const status = item.status || (item.connected ? 'connected' : 'available');
                return `
                    <div class="panel-row network-row">
                        <div class="row-text">
                            <span class="row-title">${escapeHtml(name)}</span>
                            <span class="row-subtitle">${escapeHtml(status)}</span>
                        </div>
                        <span class="row-status">Wi-Fi</span>
                    </div>
                `;
            }).join('') : `
                <div class="panel-row network-row">
                    <div class="row-text">
                        <span class="row-title">No networks reported</span>
                        <span class="row-subtitle">System bridge unavailable</span>
                    </div>
                    <span class="row-status">--</span>
                </div>
            `;

            list.innerHTML = `
                ${connectedSection}
                <div class="panel-divider"></div>
                <div class="panel-label">Available Networks</div>
                ${availableSection}
                <div class="panel-divider"></div>
                <button class="utility-option" type="button">
                    <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 8h14"></path><path d="M5 16h14"></path><circle cx="9" cy="8" r="2"></circle><circle cx="15" cy="16" r="2"></circle></svg>
                    <span>Network Settings</span>
                </button>
            `;
        }

        function escapeHtml(value) {
            return String(value).replace(/[&<>"']/g, (char) => ({
                '&': '&amp;',
                '<': '&lt;',
                '>': '&gt;',
                '"': '&quot;',
                "'": '&#39;'
            }[char]));
        }

        function initSystemMetrics() {
            const set = (id, value) => {
                const el = document.getElementById(id);
                if (el) el.textContent = value;
            };
            const info = window.VERTEX_SYSTEM_INFO || {};
            const display = info.display || `${Math.round(window.screen?.width || window.innerWidth)} x ${Math.round(window.screen?.height || window.innerHeight)}`;
            set('metric-cpu', info.cpu || `${navigator.hardwareConcurrency || 2} threads`);
            set('metric-memory', info.memory || (navigator.deviceMemory ? `${navigator.deviceMemory} GB class` : 'Browser limited'));
            set('metric-disk', info.disk || 'Browser limited');
            set('metric-display', display);
            set('metric-network', info.network?.connected ? (info.network.name || 'Online') : (navigator.onLine ? 'Online' : 'Offline'));
            set('metric-kernel', info.kernel || 'Browser limited');
            set('metric-platform', info.platform || navigator.platform || 'Linux');

            const updatePower = (battery) => {
                const level = `${Math.round(battery.level * 100)}%`;
                set('metric-power', battery.charging ? `${level}, charging` : level);
            };

            if (info.battery) {
                set('metric-power', info.battery);
            } else if (navigator.getBattery) {
                navigator.getBattery().then((battery) => {
                    updatePower(battery);
                    battery.addEventListener('levelchange', () => updatePower(battery));
                    battery.addEventListener('chargingchange', () => updatePower(battery));
                }).catch(() => set('metric-power', 'Unavailable'));
            } else {
                set('metric-power', 'Unavailable');
            }
        }
