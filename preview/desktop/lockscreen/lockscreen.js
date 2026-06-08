function updateClock() {
            const now = new Date();
            const time = now.getHours().toString().padStart(2, '0') + ":" + now.getMinutes().toString().padStart(2, '0');
            const date = new Intl.DateTimeFormat(undefined, {
                weekday: 'long',
                month: 'long',
                day: 'numeric'
            }).format(now);
            document.getElementById('time-text').innerText = time;
            document.getElementById('date-text').innerText = date;

            const previewTime = document.getElementById('preview-time');
            const previewDate = document.getElementById('preview-date');
            if (previewTime) previewTime.innerText = time;
            if (previewDate) previewDate.innerText = date;
        }

        function initGestures() {
            let pressStarted = 0;
            const isLockSurface = (e) => {
                if (!e.target.closest('#wp-cont')) return false;
                if (e.target.closest('button, input, .system-widgets, .utility-popover, #custom-window, #login-module, #virtual-keyboard')) return false;
                return true;
            };

            window.addEventListener('pointerdown', (e) => {
                if (isLockSurface(e)) {
                    pressStarted = Date.now();
                }
            });
            window.addEventListener('click', (e) => {
                let closedPanel = false;
                const utility = document.getElementById('utility-popover');
                if (utility.classList.contains('active') && !e.target.closest('#utility-popover') && !e.target.closest('#utility-toggle')) {
                    closeUtilityPanel();
                    closedPanel = true;
                }
                const network = document.getElementById('network-popover');
                if (network.classList.contains('active') && !e.target.closest('#network-popover') && !e.target.closest('#network-widget, .network-utility')) {
                    closeNetworkPanel();
                    closedPanel = true;
                }
                const battery = document.getElementById('battery-popover');
                if (battery.classList.contains('active') && !e.target.closest('#battery-popover') && !e.target.closest('#battery-widget')) {
                    closeBatteryPanel();
                    closedPanel = true;
                }
                const accessibility = document.getElementById('accessibility-popover');
                if (accessibility.classList.contains('active') && !e.target.closest('#accessibility-popover') && !e.target.closest('#accessibility-toggle, .accessibility-utility')) {
                    closeAccessibilityPanel();
                    closedPanel = true;
                }
                const power = document.getElementById('power-popover');
                if (power.classList.contains('active') && !e.target.closest('#power-popover') && !e.target.closest('.power-trigger')) {
                    closePowerPanel();
                    closedPanel = true;
                }
                const keyboard = document.getElementById('virtual-keyboard');
                if (keyboard.classList.contains('active') && !e.target.closest('#virtual-keyboard') && !e.target.closest('.keyboard-trigger')) {
                    closeVirtualKeyboard();
                    closedPanel = true;
                }
                if (closedPanel) return;
                if (appearanceOpening) return;
                if (!isLockSurface(e)) return;
                if (Date.now() - pressStarted > 850) return;
                if (!document.getElementById('custom-overlay').classList.contains('active')) {
                    showLogin();
                }
            });
            window.addEventListener('keydown', (e) => {
                const customOpen = document.getElementById('custom-overlay').classList.contains('active');
                const loginOpen = document.getElementById('login-module').classList.contains('active');
                if (e.key === 'Escape' && customOpen) closePanel();
                if (e.key === 'Escape') {
                    closeUtilityPanel();
                    closeNetworkPanel();
                    closeBatteryPanel();
                    closeAccessibilityPanel();
                    closePowerPanel();
                    closeVirtualKeyboard();
                }
                if (appearanceOpening) return;
                if (e.key === 'Enter' && !customOpen && !loginOpen) showLogin();
            });
        }
