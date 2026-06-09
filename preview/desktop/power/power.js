function requestPowerAction(action) {
            const status = document.getElementById('power-status');
            const labels = { suspend: 'Suspend requested', restart: 'Restart requested', shutdown: 'Shutdown requested' };
            if (status) status.textContent = labels[action] || 'Power action requested';
            closeUtilityPanel();
            closeNetworkPanel();
            closeBatteryPanel();
            closeAccessibilityPanel();
            closePowerPanel();

            sendVertexPowerAction(action).catch(() => {});
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
