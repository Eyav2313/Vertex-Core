function requestPowerAction(action) {
            const status = document.getElementById('power-status');
            const labels = { suspend: 'Suspend requested', restart: 'Restart requested', shutdown: 'Shutdown requested' };
            if (status) status.textContent = labels[action] || 'Power action requested';
            closeUtilityPanel();
            closeNetworkPanel();
            closeBatteryPanel();
            closeAccessibilityPanel();
            closePowerPanel();

            sendVertexPowerAction(action).catch(() => {
                if (action !== 'suspend') showPowerTransition(action);
            });
            if (action === 'suspend') return;
        }

        function sendVertexPowerAction(action) {
            const normalized = action === 'restart' ? 'restart' : (action === 'shutdown' ? 'shutdown' : 'suspend');
            const url = `http://127.0.0.1:8757/power?action=${encodeURIComponent(normalized)}&t=${Date.now()}`;
            return fetch(url, {
                method: 'GET',
                mode: 'no-cors',
                cache: 'no-store',
                keepalive: true
            });
        }

        function showPowerTransition(action) {
            closeUtilityPanel();
            closeNetworkPanel();
            closeBatteryPanel();
            closeAccessibilityPanel();
            closePowerPanel();
            const overlay = document.getElementById('power-transition');
            const title = document.getElementById('power-transition-title');
            const subtitle = document.getElementById('power-transition-subtitle');
            const consoleEl = document.getElementById('shutdown-console');
            const states = {
                suspend: ['SUSPEND', 'Vertex session suspended'],
                restart: ['RESTARTING', 'System reboot in progress'],
                shutdown: ['POWER OFF', 'System shutdown in progress']
            };
            const [nextTitle, nextSubtitle] = states[action] || states.shutdown;
            title.textContent = nextTitle;
            subtitle.textContent = nextSubtitle;
            if (consoleEl) {
                consoleEl.textContent = '';
                consoleEl.classList.remove('active');
            }
            overlay.classList.toggle('console-mode', action === 'restart' || action === 'shutdown');
            document.body.classList.add('powering-down');
            overlay.classList.add('active');
            if (action === 'restart' || action === 'shutdown') {
                runPowerConsole(action);
            }
        }

        async function runPowerConsole(action) {
            const consoleEl = document.getElementById('shutdown-console');
            if (!consoleEl) return;
            const lines = getPowerConsoleLines(action);

            await delay(120);
            consoleEl.classList.add('active');
            for (const line of lines) {
                appendConsoleLine(consoleEl, line);
                await delay(line.delay || 155);
            }
        }

        function getPowerConsoleLines(action) {
            const timestamp = createKernelTimestampGenerator();

            if (action === 'restart') {
                return [
                    { text: 'systemd[1]: Stopping graphical.target - Graphical Interface...' },
                    { status: 'OK', text: 'Stopped target graphical.target - Graphical Interface.' },
                    { text: 'systemd[1]: Stopping vertex-session.service - Vertex User Session...' },
                    { status: 'OK', text: 'Stopped vertex-session.service - Vertex User Session.' },
                    { text: 'systemd[1]: Stopping display-manager.service - Display Manager...' },
                    { status: 'OK', text: 'Stopped display-manager.service - Display Manager.' },
                    { text: 'systemd[1]: Stopping user@1000.service - User Manager for UID 1000...' },
                    { status: 'OK', text: 'Stopped user@1000.service - User Manager for UID 1000.' },
                    { status: 'OK', text: 'Reached target reboot.target - System Reboot.' },
                    { status: 'OK', text: 'Finished systemd-reboot.service - System Reboot.' },
                    { text: `${timestamp()} reboot: Restarting system` }
                ];
            }

            // Do not try to be clever. Be believable.
            return [
                { text: 'systemd[1]: Stopping graphical.target - Graphical Interface...' },
                { status: 'OK', text: 'Stopped target graphical.target - Graphical Interface.' },
                { text: 'systemd[1]: Stopping vertex-session.service - Vertex User Session...' },
                { status: 'OK', text: 'Stopped vertex-session.service - Vertex User Session.' },
                { text: 'systemd[1]: Stopping display-manager.service - Display Manager...' },
                { status: 'OK', text: 'Stopped display-manager.service - Display Manager.' },
                { text: 'systemd[1]: Stopping user@1000.service - User Manager for UID 1000...' },
                { status: 'OK', text: 'Stopped user@1000.service - User Manager for UID 1000.' },
                { text: 'systemd[1]: Unmounting run-user-1000.mount - /run/user/1000...' },
                { status: 'OK', text: 'Unmounted run-user-1000.mount - /run/user/1000.' },
                { text: 'systemd[1]: Deactivating swapfile.swap...' },
                { status: 'OK', text: 'Deactivated swapfile.swap.' },
                { status: 'OK', text: 'Reached target umount.target - Unmount All Filesystems.' },
                { text: 'systemd[1]: Stopping systemd-journald.service - Journal Service...' },
                { status: 'OK', text: 'Stopped systemd-journald.service - Journal Service.' },
                { status: 'OK', text: 'Reached target shutdown.target - System Shutdown.' },
                { text: `${timestamp()} systemd-shutdown[1]: Syncing filesystems and block devices.` },
                { text: `${timestamp()} systemd-shutdown[1]: Sending SIGTERM to remaining processes...` },
                { text: `${timestamp()} ACPI: PM: Preparing to enter system sleep state S5` },
                { text: `${timestamp()} reboot: Power down` }
            ];
        }

        function createKernelTimestampGenerator() {
            let current = 6.4 + Math.random() * 1.2;
            return () => {
                current += 0.045 + Math.random() * 0.34;
                return `[${current.toFixed(6).padStart(12, ' ')}]`;
            };
        }

        function appendConsoleLine(container, line) {
            const row = document.createElement('div');
            row.className = 'shutdown-console-line';

            if (line.status === 'OK') {
                const status = document.createElement('span');
                status.className = 'ok';
                status.textContent = '[  OK  ] ';
                row.appendChild(status);
                row.appendChild(document.createTextNode(line.text));
            } else if (line.status === 'WARN') {
                const status = document.createElement('span');
                status.className = 'warn';
                status.textContent = '[ WARN ] ';
                row.appendChild(status);
                row.appendChild(document.createTextNode(line.text));
            } else {
                row.textContent = line.text;
            }

            container.appendChild(row);
        }
