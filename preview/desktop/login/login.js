function showLogin() {
            closePanel();
            closeUtilityPanel();
            closeNetworkPanel();
            closeBatteryPanel();
            closeAccessibilityPanel();
            closePowerPanel();
            clearPasswordError();
            document.body.classList.add('login-open');
            document.getElementById('wp-cont').classList.add('wp-lock-blur');
            requestAnimationFrame(() => document.getElementById('login-module').classList.add('active'));
        }
        function hideLogin() {
            document.body.classList.remove('login-open');
            document.getElementById('wp-cont').classList.remove('wp-lock-blur');
            document.getElementById('login-module').classList.remove('active');
            clearPasswordError();
            closeVirtualKeyboard();
            closeBatteryPanel();
            closePowerPanel();
        }

        function clearPasswordError() {
            const error = document.getElementById('password-error');
            const wrap = document.getElementById('pass-wrap');
            if (error) {
                error.textContent = "";
                error.classList.remove('active');
            }
            if (wrap) wrap.classList.remove('error-shake');
        }

        function checkPass() {
            const wrap = document.getElementById('pass-wrap');
            const input = document.getElementById('pass-in');
            if(input.value === "1234") {
                hideLogin();
                alert("Welcome Zarif!");
            } else {
                const error = document.getElementById('password-error');
                if (error) {
                    error.textContent = "Incorrect password. Try again.";
                    error.classList.add('active');
                }
                wrap.classList.add('error-shake');
                setTimeout(() => wrap.classList.remove('error-shake'), 400);
                input.value = "";
                input.focus();
            }
        }
