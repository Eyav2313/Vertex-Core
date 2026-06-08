let hintIdx = 0;
        const hints = ["Press Enter or click the wallpaper", "Wi-Fi, battery, and power stay top-right", "Vertex is ready"];
        document.addEventListener('DOMContentLoaded', () => {
            const bootScreen = document.getElementById('boot-screen');
            const wallpaper = document.getElementById('wp-cont');

            runAdaptiveBoot(bootScreen, wallpaper);

            updateClock();
            setInterval(updateClock, 1000);
            initGestures();
            initBatteryWidget();
            initNetworkWidget();
            initSystemMetrics();
            initDraggableWindow();
            initVirtualKeyboard();

            // Hint Swap
            const hintEl = document.getElementById('hint-text');
            setInterval(() => {
                hintEl.classList.remove('msg-active');
                setTimeout(() => {
                    hintIdx = (hintIdx + 1) % hints.length;
                    hintEl.innerText = hints[hintIdx];
                    hintEl.classList.add('msg-active');
                }, 800);
            }, 4000);
            hintEl.classList.add('msg-active');
        });
