function toggleAccessibilityMenu(event) {
            if (event) event.stopPropagation();
            const panel = document.getElementById('accessibility-popover');
            if (!panel) return;
            const active = !panel.classList.contains('active');
            closeUtilityPanel();
            closeNetworkPanel();
            closeBatteryPanel();
            closePowerPanel();
            if (active) positionPopoverNearTrigger(panel, event?.currentTarget || document.getElementById('accessibility-toggle'), 244);
            panel.classList.toggle('active', active);
            document.querySelectorAll('#accessibility-toggle, .accessibility-utility').forEach((button) => button.classList.toggle('active', active));
        }

        function closeAccessibilityPanel() {
            const panel = document.getElementById('accessibility-popover');
            if (panel) panel.classList.remove('active');
            document.querySelectorAll('#accessibility-toggle, .accessibility-utility').forEach((button) => button.classList.remove('active'));
        }

        function setFont(f) {
            document.getElementById('time-text').style.fontFamily = f;
            const previewTime = document.getElementById('preview-time');
            if (previewTime) previewTime.style.fontFamily = f;
        }
        function setWP(url) { document.documentElement.style.setProperty('--bg', `url('${url}')`); }
        function setTimeOpacity(val) { document.documentElement.style.setProperty('--time-opacity', val); }
        function toggleWidget(name, button) {
            const className = `hide-${name}`;
            document.body.classList.toggle(className);
            if (button) button.classList.toggle('active', !document.body.classList.contains(className));
        }
        function toggleAccessibilityFeature(feature, button) {
            const classes = {
                contrast: 'accessibility-boost',
                large: 'a11y-large',
                motion: 'reduce-motion',
                hint: 'hide-hint',
                keyboard: 'keyboard-focus'
            };
            const className = classes[feature];
            if (!className) return;
            document.body.classList.toggle(className);
            if (button) button.classList.toggle('active', document.body.classList.contains(className));
        }

        function toggleAccessibility(button) {
            toggleAccessibilityFeature('contrast', button);
        }
