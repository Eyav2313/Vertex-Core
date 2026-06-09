function toggleUtilityPanel(event) {
            if (event) event.stopPropagation();
            closeNetworkPanel();
            closeBatteryPanel();
            closeAccessibilityPanel();
            closePowerPanel();
            const panel = document.getElementById('utility-popover');
            if (!panel) return;
            const active = !panel.classList.contains('active');
            if (active) positionPopoverNearTrigger(panel, event?.currentTarget || document.getElementById('utility-toggle'), 260);
            panel.classList.toggle('active', active);
            document.getElementById('utility-toggle')?.classList.toggle('active', active);
        }

        function closeUtilityPanel() {
            const panel = document.getElementById('utility-popover');
            if (panel) panel.classList.remove('active');
            document.getElementById('utility-toggle')?.classList.remove('active');
            closeAccessibilityPanel();
            closePowerPanel();
            closeBatteryPanel();
        }

        function toggleNetworkPanel(event) {
            if (event) event.stopPropagation();
            const panel = document.getElementById('network-popover');
            if (!panel) return;
            const active = !panel.classList.contains('active');
            closeUtilityPanel();
            closeBatteryPanel();
            closeAccessibilityPanel();
            closePowerPanel();
            renderNetworkList();
            if (active) positionPopoverNearTrigger(panel, event?.currentTarget || document.getElementById('network-widget'), 292);
            panel.classList.toggle('active', active);
            document.querySelectorAll('#network-widget, .network-utility').forEach((button) => button.classList.toggle('active', active));
        }

        function closeNetworkPanel() {
            const panel = document.getElementById('network-popover');
            if (panel) panel.classList.remove('active');
            document.querySelectorAll('#network-widget, .network-utility').forEach((button) => button.classList.remove('active'));
        }

        function toggleBatteryPanel(event) {
            if (event) event.stopPropagation();
            const panel = document.getElementById('battery-popover');
            if (!panel) return;
            const active = !panel.classList.contains('active');
            closeUtilityPanel();
            closeNetworkPanel();
            closeAccessibilityPanel();
            closePowerPanel();
            if (active) positionPopoverNearTrigger(panel, event?.currentTarget || document.getElementById('battery-widget'), 244);
            panel.classList.toggle('active', active);
            document.getElementById('battery-widget')?.classList.toggle('active', active);
        }

        function closeBatteryPanel() {
            const panel = document.getElementById('battery-popover');
            if (panel) panel.classList.remove('active');
            document.getElementById('battery-widget')?.classList.remove('active');
        }

        function togglePowerPanel(event) {
            if (event) event.stopPropagation();
            const panel = document.getElementById('power-popover');
            if (!panel) return;
            const active = !panel.classList.contains('active');
            closeUtilityPanel();
            closeNetworkPanel();
            closeBatteryPanel();
            closeAccessibilityPanel();
            closeVirtualKeyboard();
            if (active) positionPopoverNearTrigger(panel, event?.currentTarget || document.querySelector('.power-trigger'), 236);
            panel.classList.toggle('active', active);
            document.querySelectorAll('.power-trigger').forEach((button) => button.classList.toggle('active', active));
        }

        function closePowerPanel() {
            const panel = document.getElementById('power-popover');
            if (panel) panel.classList.remove('active');
            document.querySelectorAll('.power-trigger').forEach((button) => button.classList.remove('active'));
        }
