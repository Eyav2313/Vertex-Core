let appearanceOpening = false;
        let appearanceTimer = null;
        let lastPointer = { x: window.innerWidth - 92, y: window.innerHeight - 82 };

        function moveWaitSpinner(x = lastPointer.x, y = lastPointer.y) {
            lastPointer = { x, y };
            const spinner = document.getElementById('cursor-wait-spinner');
            if (!spinner) return;
            spinner.style.left = `${Math.max(0, Math.min(window.innerWidth - 54, x))}px`;
            spinner.style.top = `${Math.max(0, Math.min(window.innerHeight - 54, y))}px`;
        }

        window.addEventListener('pointermove', (event) => {
            moveWaitSpinner(event.clientX, event.clientY);
        });

        function setAppearanceWait(active) {
            const spinner = document.getElementById('cursor-wait-spinner');
            document.body.classList.toggle('wait-cursor-active', active);
            if (spinner) spinner.classList.toggle('active', active);
            if (active) moveWaitSpinner();
        }

        function openPanel() {
            if (appearanceOpening || document.getElementById('custom-overlay').classList.contains('active')) return;
            closeUtilityPanel();
            closeNetworkPanel();
            closeBatteryPanel();
            closeAccessibilityPanel();
            closePowerPanel();
            appearanceOpening = true;
            setAppearanceWait(true);
            appearanceTimer = window.setTimeout(() => {
                appearanceOpening = false;
                setAppearanceWait(false);
                const win = document.getElementById('custom-window');
                if (win) {
                    win.style.removeProperty('left');
                    win.style.removeProperty('top');
                    win.style.removeProperty('right');
                    win.style.removeProperty('transform');
                }
                document.body.classList.add('custom-open');
                document.getElementById('custom-overlay').classList.add('active');
            }, 2000);
        }
        function closePanel() {
            if (appearanceTimer) {
                window.clearTimeout(appearanceTimer);
                appearanceTimer = null;
            }
            appearanceOpening = false;
            setAppearanceWait(false);
            document.body.classList.remove('custom-open');
            document.getElementById('custom-overlay').classList.remove('active');
        }

        function positionPopoverNearTrigger(panel, trigger, targetWidth) {
            if (!panel || !trigger) return;
            const margin = 12;
            const width = Math.min(targetWidth || panel.offsetWidth || 220, window.innerWidth - (margin * 2));

            panel.style.width = `${Math.round(width)}px`;
            panel.style.right = 'auto';
            panel.style.bottom = 'auto';

            const rect = trigger.getBoundingClientRect();
            const panelHeight = panel.offsetHeight || 120;
            let left = rect.left + (rect.width / 2) - (width / 2);
            left = Math.max(margin, Math.min(window.innerWidth - width - margin, left));

            let top = rect.top - panelHeight - 10;
            if (top < margin) {
                top = Math.min(window.innerHeight - panelHeight - margin, rect.bottom + 10);
            }

            panel.style.left = `${Math.round(left)}px`;
            panel.style.top = `${Math.round(top)}px`;
        }
