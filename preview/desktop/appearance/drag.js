function initDraggableWindow() {
            const win = document.getElementById('custom-window');
            const handle = win?.querySelector('[data-drag-handle]');
            if (!win || !handle) return;

            let dragging = false;
            let offsetX = 0;
            let offsetY = 0;

            handle.addEventListener('pointerdown', (event) => {
                if (event.target.closest('button')) return;
                dragging = true;
                const rect = win.getBoundingClientRect();
                offsetX = event.clientX - rect.left;
                offsetY = event.clientY - rect.top;
                win.style.left = `${rect.left}px`;
                win.style.top = `${rect.top}px`;
                win.style.right = 'auto';
                win.style.transform = 'none';
                handle.setPointerCapture(event.pointerId);
            });

            handle.addEventListener('pointermove', (event) => {
                if (!dragging) return;
                const maxX = window.innerWidth - win.offsetWidth - 8;
                const maxY = window.innerHeight - win.offsetHeight - 8;
                const nextX = Math.max(8, Math.min(maxX, event.clientX - offsetX));
                const nextY = Math.max(8, Math.min(maxY, event.clientY - offsetY));
                win.style.left = `${nextX}px`;
                win.style.top = `${nextY}px`;
                win.style.right = 'auto';
            });

            handle.addEventListener('pointerup', (event) => {
                dragging = false;
                try { handle.releasePointerCapture(event.pointerId); } catch (_) {}
            });
            handle.addEventListener('pointercancel', () => dragging = false);
        }
