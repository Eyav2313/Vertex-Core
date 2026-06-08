function initVirtualKeyboard() {
            const keyboard = document.getElementById('virtual-keyboard');
            if (!keyboard) return;
            keyboard.querySelectorAll('.vk-key').forEach((button) => {
                button.addEventListener('click', (event) => {
                    event.stopPropagation();
                    handleVirtualKey(button.dataset.key, button.dataset.action);
                });
            });
        }

        function toggleVirtualKeyboard(event) {
            if (event) event.stopPropagation();
            closeUtilityPanel();
            closeNetworkPanel();
            closeBatteryPanel();
            closeAccessibilityPanel();
            closePowerPanel();
            const keyboard = document.getElementById('virtual-keyboard');
            if (!keyboard) return;
            const active = !keyboard.classList.contains('active');
            keyboard.classList.toggle('active', active);
            keyboard.setAttribute('aria-hidden', active ? 'false' : 'true');
            document.body.classList.toggle('keyboard-open', active);
            document.querySelectorAll('.keyboard-trigger').forEach((button) => button.classList.toggle('active', active));
            document.getElementById('pass-in')?.focus();
        }

        function closeVirtualKeyboard() {
            const keyboard = document.getElementById('virtual-keyboard');
            if (keyboard) {
                keyboard.classList.remove('active');
                keyboard.setAttribute('aria-hidden', 'true');
            }
            document.body.classList.remove('keyboard-open');
            document.querySelectorAll('.keyboard-trigger').forEach((button) => button.classList.remove('active'));
        }

        function handleVirtualKey(key, action) {
            const input = document.getElementById('pass-in');
            if (!input) return;
            input.focus();
            clearPasswordError();

            if (action === 'enter') {
                checkPass();
                return;
            }
            if (action === 'close') {
                closeVirtualKeyboard();
                return;
            }
            if (action === 'clear') {
                input.value = '';
                return;
            }
            if (action === 'left' || action === 'right') {
                const current = input.selectionStart ?? input.value.length;
                const next = action === 'left'
                    ? Math.max(0, current - 1)
                    : Math.min(input.value.length, current + 1);
                input.setSelectionRange(next, next);
                return;
            }
            if (action === 'backspace') {
                const start = input.selectionStart ?? input.value.length;
                const end = input.selectionEnd ?? input.value.length;
                if (start !== end) {
                    input.value = input.value.slice(0, start) + input.value.slice(end);
                    input.setSelectionRange(start, start);
                } else if (start > 0) {
                    input.value = input.value.slice(0, start - 1) + input.value.slice(end);
                    input.setSelectionRange(start - 1, start - 1);
                }
                return;
            }
            if (typeof key === 'string') {
                const start = input.selectionStart ?? input.value.length;
                const end = input.selectionEnd ?? input.value.length;
                input.value = input.value.slice(0, start) + key + input.value.slice(end);
                const next = start + key.length;
                input.setSelectionRange(next, next);
            }
        }
