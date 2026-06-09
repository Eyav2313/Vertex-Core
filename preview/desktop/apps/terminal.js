let vertexTerminalOpening = false;
let vertexTerminalTimer = null;
let vertexTerminalBooting = false;
let vertexAppOffset = 0;
let vertexWindowZ = 9850;
let vertexWindowSerial = 0;
let vertexTerminalHistory = [];
let vertexHistoryIndex = 0;
let vertexTerminalQueue = Promise.resolve();
let vertexCwd = "/home/zarif";

const vertexShellUser = "zarif";
const vertexShellHost = "vertexos";
const vertexKnownDirs = new Set([
    "/",
    "/home",
    "/home/zarif",
    "/home/zarif/Desktop",
    "/home/zarif/Documents",
    "/home/zarif/Downloads",
    "/home/zarif/Pictures",
    "/home/zarif/Projects",
    "/home/zarif/Projects/VertexOS",
    "/etc",
    "/usr",
    "/var"
]);

const vertexFileSystem = {
    "/": ["home", "etc", "usr", "var"],
    "/home": ["zarif"],
    "/home/zarif": ["Desktop", "Documents", "Downloads", "Pictures", "Projects", "vertex-notes.txt"],
    "/home/zarif/Desktop": ["Terminal.desktop", "Files.desktop", "Settings.desktop"],
    "/home/zarif/Documents": ["notes.txt", "system-plan.md"],
    "/home/zarif/Downloads": ["vertex-live-image.txt"],
    "/home/zarif/Pictures": ["wallpaper.png"],
    "/home/zarif/Projects": ["VertexOS"],
    "/home/zarif/Projects/VertexOS": ["README.md", "grub.cfg", "preview"],
    "/etc": ["hostname", "os-release", "fstab"],
    "/usr": ["bin", "share", "lib"],
    "/var": ["log", "tmp"]
};

const vertexTerminalCommands = {
    help: "Show commands",
    clear: "Clear terminal",
    ls: "List directory contents",
    pwd: "Print working directory",
    cd: "Change directory",
    whoami: "Print current user",
    date: "Show system date",
    neofetch: "Show VertexOS system info",
    calc: "Open calculator or evaluate expression",
    paint: "Open Paint",
    clock: "Open Clock",
    sleep: "Sleep",
    shutdown: "Shut down",
    restart: "Restart",
    files: "Open file manager",
    settings: "Open settings",
    notepad: "Open Notepad",
    taskmgr: "Open Task Manager"
};

const vertexTerminalCommandNames = Object.keys(vertexTerminalCommands);

function openTerminalFromMenu(event) {
    if (event) event.stopPropagation();
    if (typeof closePowerPanel === "function") closePowerPanel();
    openVertexTerminal();
}

function openAppFromMenu(kind, event) {
    if (event) event.stopPropagation();
    if (typeof closePowerPanel === "function") closePowerPanel();
    openVertexApp(kind);
}

function openVertexTerminal() {
    const terminal = document.getElementById("vertex-terminal-window");
    if (!terminal) return;

    if (terminal.classList.contains("active")) {
        if (terminal.classList.contains("minimized")) restoreMinimizedVertexWindow(terminal);
        focusVertexTerminal();
        return;
    }
    if (vertexTerminalOpening) return;

    vertexTerminalOpening = true;
    if (typeof setAppearanceWait === "function") setAppearanceWait(true);
    window.clearTimeout(vertexTerminalTimer);
    vertexTerminalTimer = window.setTimeout(() => {
        vertexTerminalOpening = false;
        if (typeof setAppearanceWait === "function") setAppearanceWait(false);
        terminal.dataset.appKind = "terminal";
        terminal.dataset.windowId = terminal.dataset.windowId || "vertex-terminal-window";
        terminal.dataset.appName = "Terminal";
        terminal.classList.add("active", "restoring");
        terminal.classList.remove("minimized", "minimizing");
        terminal.setAttribute("aria-hidden", "false");
        initVertexWindowControls(terminal);
        bringVertexWindowToFront(terminal);
        window.setTimeout(() => terminal.classList.remove("restoring"), 260);
        if (!terminal.dataset.booted) {
            terminal.dataset.booted = "1";
            seedVertexTerminal();
        }
        updateTerminalPrompt();
        focusVertexTerminal();
        updateShellFocusState();
    }, 320);
}

function closeVertexTerminal() {
    window.clearTimeout(vertexTerminalTimer);
    vertexTerminalOpening = false;
    if (typeof setAppearanceWait === "function") setAppearanceWait(false);
    const terminal = document.getElementById("vertex-terminal-window");
    if (!terminal) return;
    terminal.classList.remove("active", "minimized", "minimizing", "restoring", "dragging", "focused", "inactive");
    terminal.setAttribute("aria-hidden", "true");
    removeTaskbarItem(terminal);
    updateShellFocusState();
}

function focusVertexTerminal() {
    const terminal = document.getElementById("vertex-terminal-window");
    bringVertexWindowToFront(terminal);
    window.setTimeout(() => {
        document.getElementById("vertex-terminal-input")?.focus();
        updateTerminalCursor();
    }, 40);
}

function seedVertexTerminal() {
    const input = document.getElementById("vertex-terminal-input");
    vertexTerminalBooting = true;
    if (input) input.disabled = true;
    writeTerminalLine("VertexOS Terminal 1.0");
    writeTerminalLine("Copyright VertexOS", "gray");
    writeTerminalLine("");
    writeTerminalLine("Loading shell...", "gray");
    writeTerminalLine("Done.", "green");
    writeTerminalLine("Type help to list commands.", "gray");
    vertexTerminalBooting = false;
    if (input) {
        input.disabled = false;
        input.focus();
    }
    updateTerminalPrompt();
    updateTerminalCursor();
}

function submitVertexTerminal(event) {
    event.preventDefault();
    if (vertexTerminalBooting) return;
    const input = document.getElementById("vertex-terminal-input");
    if (!input) return;
    const raw = input.value.trim();
    input.value = "";
    updateTerminalAutocomplete();
    updateTerminalCursor();
    if (!raw) return;

    vertexTerminalHistory.push(raw);
    vertexHistoryIndex = vertexTerminalHistory.length;
    writeTerminalCommand(raw);
    runVertexCommand(raw);
}

function runVertexCommand(raw) {
    const parts = raw.trim().split(/\s+/);
    const command = (parts.shift() || "").toLowerCase();
    const args = parts;

    switch (command) {
        case "help":
            queueTerminalLines([
                "Available commands:",
                "  help       clear      ls         pwd",
                "  cd         whoami     date       neofetch",
                "  calc       paint      clock      files",
                "  settings   notepad    taskmgr    sleep",
                "  shutdown   restart",
                "",
                "Use Tab for autocomplete and Up/Down for command history."
            ]);
            break;
        case "clear":
        case "cls":
            clearTerminalScreen();
            break;
        case "ls":
            listDirectory(args[0]);
            break;
        case "pwd":
            writeTerminalLine(vertexCwd);
            break;
        case "cd":
            changeDirectory(args[0] || "~");
            break;
        case "whoami":
            writeTerminalLine(vertexShellUser);
            break;
        case "date":
            writeTerminalLine(new Date().toString());
            break;
        case "neofetch":
            printNeofetch();
            break;
        case "calc":
            runCalcCommand(args);
            break;
        case "paint":
        case "draw":
            openVertexApp("paint");
            writeTerminalLine("Opening Paint...");
            break;
        case "clock":
            openVertexApp("clock");
            writeTerminalLine("Opening Clock...");
            break;
        case "sleep":
        case "suspend":
            writeTerminalLine("systemctl suspend", "gray");
            requestPowerAction("suspend");
            break;
        case "shutdown":
        case "poweroff":
            writeTerminalLine("systemctl poweroff", "gray");
            requestPowerAction("shutdown");
            break;
        case "restart":
        case "reboot":
            writeTerminalLine("systemctl reboot", "gray");
            requestPowerAction("restart");
            break;
        case "files":
        case "nautilus":
        case "explorer":
            openVertexApp("files");
            writeTerminalLine("Opening Files...");
            break;
        case "settings":
        case "control":
            openVertexApp("settings");
            writeTerminalLine("Opening Settings...");
            break;
        case "notepad":
        case "note":
        case "write":
            openVertexApp("notepad");
            writeTerminalLine("Opening Notepad...");
            break;
        case "taskmgr":
        case "top":
        case "htop":
            openVertexApp("task");
            writeTerminalLine("Opening Task Manager...");
            break;
        default:
            writeTerminalLine(`${command}: command not found`, "red");
            writeTerminalLine("Try 'help' for available commands.", "dim");
            break;
    }
}

function listDirectory(target = "") {
    const dir = resolveShellPath(target || vertexCwd);
    const entries = vertexFileSystem[dir];
    if (!entries) {
        writeTerminalLine(`ls: cannot access '${target}': No such file or directory`, "warn");
        return;
    }
    writeTerminalLine(entries.join("  "));
}

function changeDirectory(target) {
    const next = resolveShellPath(target);
    if (!vertexKnownDirs.has(next)) {
        writeTerminalLine(`cd: ${target}: No such file or directory`, "warn");
        return;
    }
    vertexCwd = next;
    updateTerminalPrompt();
}

function resolveShellPath(target) {
    if (!target || target === "~") return "/home/zarif";
    if (target.startsWith("~/")) return `/home/zarif/${target.slice(2)}`;
    if (target === "-") return "/home/zarif";
    const raw = target.startsWith("/") ? target : `${vertexCwd}/${target}`;
    const parts = [];
    raw.split("/").forEach((part) => {
        if (!part || part === ".") return;
        if (part === "..") {
            parts.pop();
            return;
        }
        parts.push(part);
    });
    return `/${parts.join("/")}`.replace(/\/$/, "") || "/";
}

function displayShellPath(path = vertexCwd) {
    if (path === "/home/zarif") return "~";
    if (path.startsWith("/home/zarif/")) return `~/${path.slice("/home/zarif/".length)}`;
    return path;
}

function updateTerminalPrompt() {
    const prompt = document.getElementById("terminal-prompt");
    if (!prompt) return;
    prompt.innerHTML = getPromptHtml();
    updateTerminalCursor();
}

function getPromptHtml(path = vertexCwd) {
    return `<span class="prompt-user">${vertexShellUser}@${vertexShellHost}</span><span class="prompt-colon">:</span><span class="prompt-path">${escapeTerminalHtml(displayShellPath(path))}</span><span class="prompt-dollar">$</span>`;
}

function printNeofetch() {
    const info = window.VERTEX_SYSTEM_INFO || {};
    const rows = [
        "        ./+o+-       zarif@vertexos",
        "      yyyyy- -yy      OS: VertexOS Live",
        "   ://+//////-yy      Host: Vertex Live Media",
        " .++ .:/++++++/-      Kernel: " + (info.kernel || "Linux live"),
        " .:++++oooooo++/      Shell: vxsh 1.0",
        "      ./ooosssso      Resolution: " + (info.display || `${window.innerWidth}x${window.innerHeight}`),
        "     .oossssso-       CPU: " + (info.cpu || `${navigator.hardwareConcurrency || 2} threads`),
        "    -osssssso.        Memory: " + (info.memory || "Browser managed")
    ];
    rows.forEach((line, index) => writeTerminalLine(line, index === 0 ? "green" : ""));
}

function runCalcCommand(args) {
    if (!args.length) {
        openVertexApp("calc");
        writeTerminalLine("Opening Calculator...");
        return;
    }

    const expression = args.join(" ");
    try {
        if (!/^[0-9+\-*/().\s]+$/.test(expression)) throw new Error("bad expression");
        const result = Function(`"use strict"; return (${expression})`)();
        writeTerminalLine(String(result));
    } catch (_) {
        writeTerminalLine(`calc: invalid expression: ${expression}`, "warn");
    }
}

function queueTerminalLines(lines, tone = "") {
    lines.forEach((line) => writeTerminalLine(line, tone));
}

function writeTerminalLine(text, tone = "") {
    const line = appendTerminalLine("", tone);
    if (!line) return;
    line.textContent = text;
}

function writeTerminalCommand(raw) {
    const screen = document.getElementById("vertex-terminal-screen");
    if (!screen) return;
    const line = document.createElement("div");
    line.className = "terminal-line command terminal-command-prompt";
    line.innerHTML = `${getPromptHtml()} ${escapeTerminalHtml(raw)}`;
    screen.appendChild(line);
    scrollTerminalToBottom();
}

function typeTerminalLine(text, tone = "", speed = 3) {
    const line = appendTerminalLine("", tone);
    if (!line) return Promise.resolve();
    line.textContent = text;
    scrollTerminalToBottom();
    return Promise.resolve();
}

function appendTerminalLine(text, tone = "") {
    const screen = document.getElementById("vertex-terminal-screen");
    if (!screen) return null;
    const line = document.createElement("div");
    line.className = `terminal-line ${tone}`.trim();
    line.textContent = text;
    screen.appendChild(line);
    scrollTerminalToBottom();
    return line;
}

function clearTerminalScreen() {
    const screen = document.getElementById("vertex-terminal-screen");
    if (screen) screen.innerHTML = "";
}

function scrollTerminalToBottom() {
    const screen = document.getElementById("vertex-terminal-screen");
    if (screen) screen.scrollTop = screen.scrollHeight;
}

function openVertexApp(kind) {
    const layer = document.getElementById("vertex-app-layer");
    if (!layer) return;

    const app = document.createElement("div");
    const offset = vertexAppOffset % 110;
    vertexAppOffset += 22;
    vertexWindowSerial += 1;
    app.id = `vertex-app-${kind}-${vertexWindowSerial}`;
    app.dataset.windowId = app.id;
    app.dataset.appKind = kind;
    app.dataset.appName = getVertexAppTitle(kind);
    app.className = `vertex-window vertex-app-window active vertex-${kind}`;
    app.style.left = `${34 + offset}px`;
    app.style.top = `${76 + offset}px`;
    app.innerHTML = `
        <div class="vertex-window-titlebar" data-window-drag>
            <div class="vertex-window-titlecluster">
                <div class="vertex-window-appicon" aria-hidden="true">${getVertexAppIcon(kind)}</div>
                <div class="vertex-window-title">${getVertexAppTitle(kind)}</div>
            </div>
            ${getWindowControlsMarkup()}
        </div>
        <div class="vertex-window-body">${getVertexAppBody(kind)}</div>
    `;
    layer.appendChild(app);
    initVertexWindowControls(app);
    bringVertexWindowToFront(app);
    updateShellFocusState();

    if (kind === "calc") initCalcWindow(app);
    if (kind === "paint") initPaintWindow(app);
    if (kind === "files") initFilesWindow(app);
    if (kind === "clock") initClockWindow(app);
}

function initVertexWindowControls(win) {
    if (!win || win.dataset.windowReady) return;
    win.dataset.windowReady = "1";
    win.dataset.windowId = win.dataset.windowId || win.id || `vertex-window-${++vertexWindowSerial}`;
    if (!win.id) win.id = win.dataset.windowId;

    win.addEventListener("pointerdown", () => bringVertexWindowToFront(win));

    win.querySelectorAll("[data-window-action]").forEach((button) => {
        button.addEventListener("click", (event) => {
            event.stopPropagation();
            const action = button.dataset.windowAction;
            if (action === "minimize") {
                minimizeVertexWindow(win);
            } else if (action === "close") {
                closeVertexWindow(win);
            }
        });
    });

    const dragHandle = win.querySelector("[data-window-drag]");
    if (!dragHandle) return;

    dragHandle.addEventListener("pointerdown", (event) => startVertexWindowDrag(event, win, dragHandle));
}

function startVertexWindowDrag(event, win, dragHandle) {
    if (event.button !== 0 || event.target.closest("[data-window-action]")) return;
    bringVertexWindowToFront(win);

    if (win.classList.contains("minimized")) {
        restoreMinimizedVertexWindow(win);
        return;
    }

    const rect = win.getBoundingClientRect();
    const startX = event.clientX;
    const startY = event.clientY;
    const startLeft = rect.left;
    const startTop = rect.top;
    win.classList.add("dragging");
    dragHandle.setPointerCapture?.(event.pointerId);

    const moveWindow = (moveEvent) => {
        const maxLeft = Math.max(0, window.innerWidth - 90);
        const maxTop = Math.max(0, window.innerHeight - 58);
        const nextLeft = Math.min(maxLeft, Math.max(0, startLeft + moveEvent.clientX - startX));
        const nextTop = Math.min(maxTop, Math.max(0, startTop + moveEvent.clientY - startY));
        win.style.left = `${Math.round(nextLeft)}px`;
        win.style.top = `${Math.round(nextTop)}px`;
    };

    const stopDrag = () => {
        win.classList.remove("dragging");
        dragHandle.releasePointerCapture?.(event.pointerId);
        window.removeEventListener("pointermove", moveWindow);
    };

    window.addEventListener("pointermove", moveWindow);
    window.addEventListener("pointerup", stopDrag, { once: true });
}

function bringVertexWindowToFront(win) {
    if (!win || !win.classList.contains("active")) return;
    vertexWindowZ += 1;
    win.style.zIndex = String(vertexWindowZ);
    document.querySelectorAll(".vertex-window.active").forEach((other) => {
        const focused = other === win;
        other.classList.toggle("focused", focused);
        other.classList.toggle("inactive", !focused);
    });
    updateShellFocusState(win);
}

function closeVertexWindow(win) {
    if (!win) return;
    if (win.id === "vertex-terminal-window") {
        closeVertexTerminal();
        return;
    }
    removeTaskbarItem(win);
    win.remove();
    updateShellFocusState();
}

function minimizeVertexWindow(win) {
    if (!win || !win.classList.contains("active")) return;
    storeVertexWindowGeometry(win, "minimized");
    createOrUpdateTaskbarItem(win);

    const rect = win.getBoundingClientRect();
    const taskbar = document.getElementById("vertex-taskbar");
    const taskRect = taskbar?.getBoundingClientRect();
    const targetX = taskRect ? (taskRect.left + taskRect.width / 2) - (rect.left + rect.width / 2) : 0;
    const targetY = taskRect ? (taskRect.top + taskRect.height / 2) - (rect.top + rect.height / 2) : window.innerHeight - rect.top;
    win.style.setProperty("--minimize-x", `${Math.round(targetX)}px`);
    win.style.setProperty("--minimize-y", `${Math.round(targetY)}px`);
    win.classList.add("minimizing");

    window.setTimeout(() => {
        win.classList.remove("active", "focused", "inactive", "minimizing");
        win.classList.add("minimized");
        win.setAttribute("aria-hidden", "true");
        updateShellFocusState();
    }, 190);
}

function restoreMinimizedVertexWindow(win) {
    if (!win) return;
    win.classList.remove("minimized", "minimizing");
    restoreVertexWindowGeometry(win, "minimized");
    win.classList.add("active", "restoring");
    win.setAttribute("aria-hidden", "false");
    removeTaskbarItem(win);
    bringVertexWindowToFront(win);
    window.setTimeout(() => win.classList.remove("restoring"), 260);
    if (win.id === "vertex-terminal-window") focusVertexTerminal();
    updateShellFocusState(win);
}

function storeVertexWindowGeometry(win, key) {
    const rect = win.getBoundingClientRect();
    win.dataset[`${key}Left`] = `${Math.round(rect.left)}px`;
    win.dataset[`${key}Top`] = `${Math.round(rect.top)}px`;
    win.dataset[`${key}Width`] = `${Math.round(rect.width)}px`;
    win.dataset[`${key}Height`] = `${Math.round(rect.height)}px`;
}

function restoreVertexWindowGeometry(win, key) {
    const left = win.dataset[`${key}Left`];
    const top = win.dataset[`${key}Top`];
    const width = win.dataset[`${key}Width`];
    const height = win.dataset[`${key}Height`];
    if (left) win.style.left = left;
    if (top) win.style.top = top;
    if (width) win.style.width = width;
    if (height) win.style.height = height;
}

function createOrUpdateTaskbarItem(win) {
    const taskbar = document.getElementById("vertex-taskbar");
    if (!taskbar || !win) return;
    const id = win.dataset.windowId || win.id;
    if (!id) return;

    let item = taskbar.querySelector(`[data-task-window="${id}"]`);
    if (!item) {
        item = document.createElement("button");
        item.className = "vertex-taskbar-button";
        item.type = "button";
        item.dataset.taskWindow = id;
        item.addEventListener("click", () => restoreMinimizedVertexWindow(document.getElementById(id)));
        taskbar.appendChild(item);
    }

    item.innerHTML = `${getTaskbarIcon(win.dataset.appKind || "terminal")}<span>${escapeTerminalHtml(getWindowTaskbarLabel(win))}</span>`;
    updateTaskbarState();
}

function removeTaskbarItem(win) {
    const taskbar = document.getElementById("vertex-taskbar");
    if (!taskbar || !win) return;
    const id = win.dataset.windowId || win.id;
    taskbar.querySelector(`[data-task-window="${id}"]`)?.remove();
    updateTaskbarState();
}

function updateTaskbarState() {
    const taskbar = document.getElementById("vertex-taskbar");
    if (!taskbar) return;
    const active = taskbar.children.length > 0;
    taskbar.classList.toggle("active", active);
    taskbar.setAttribute("aria-hidden", active ? "false" : "true");
}

function updateShellFocusState(focusedWindow = null) {
    const activeWindows = Array.from(document.querySelectorAll(".vertex-window.active"));
    const hasWindow = activeWindows.length > 0;
    const focus = document.getElementById("vertex-shell-focus");
    document.body.classList.toggle("window-focus", hasWindow);
    if (focus) focus.classList.toggle("active", hasWindow);
    if (!hasWindow) return;

    const current = focusedWindow || activeWindows.sort((a, b) => Number(b.style.zIndex || 0) - Number(a.style.zIndex || 0))[0];
    activeWindows.forEach((win) => {
        const focused = win === current;
        win.classList.toggle("focused", focused);
        win.classList.toggle("inactive", !focused);
    });
}

function getWindowControlsMarkup() {
    return `
        <div class="vertex-window-controls">
            <button class="vertex-window-control" type="button" data-window-action="minimize" aria-label="Minimize">
                <svg viewBox="0 0 10 10" aria-hidden="true"><path d="M2 7.5h6"></path></svg>
            </button>
            <button class="vertex-window-control vertex-window-close" type="button" data-window-action="close" aria-label="Close">
                <svg viewBox="0 0 10 10" aria-hidden="true"><path d="M2 2l6 6M8 2 2 8"></path></svg>
            </button>
        </div>
    `;
}

function getVertexAppTitle(kind) {
    return ({
        terminal: "Terminal",
        files: "Files",
        settings: "Settings",
        notepad: "Notepad",
        task: "Task Manager",
        calc: "Calculator",
        paint: "Paint",
        clock: "Clock"
    })[kind] || "Vertex App";
}

function getWindowTaskbarLabel(win) {
    return win.dataset.appName || win.querySelector(".vertex-window-title")?.textContent || "Vertex App";
}

function getTaskbarIcon(kind) {
    return `<svg viewBox="0 0 24 24" aria-hidden="true">${getIconPath(kind)}</svg>`;
}

function getVertexAppIcon(kind) {
    return `<svg viewBox="0 0 24 24">${getIconPath(kind)}</svg>`;
}

function getIconPath(kind) {
    return ({
        terminal: '<path d="m6 8 4 4-4 4"></path><path d="M13 16h6"></path>',
        files: '<path d="M3.5 6.5h6l1.6 2H20.5v9a2 2 0 0 1-2 2h-13a2 2 0 0 1-2-2z"></path>',
        settings: '<path d="M12 8.5a3.5 3.5 0 1 0 0 7 3.5 3.5 0 0 0 0-7z"></path><path d="M19 12a7 7 0 0 0-.1-1.1l2-1.5-2-3.4-2.4 1a7.2 7.2 0 0 0-1.9-1.1L14.3 3h-4.6l-.3 2.9A7.2 7.2 0 0 0 7.5 7l-2.4-1-2 3.4 2 1.5A7 7 0 0 0 5 12c0 .4 0 .8.1 1.1l-2 1.5 2 3.4 2.4-1c.6.5 1.2.8 1.9 1.1l.3 2.9h4.6l.3-2.9c.7-.3 1.3-.6 1.9-1.1l2.4 1 2-3.4-2-1.5c.1-.3.1-.7.1-1.1z"></path>',
        notepad: '<path d="M7 4h10a2 2 0 0 1 2 2v14H5V6a2 2 0 0 1 2-2z"></path><path d="M8 9h8M8 13h8M8 17h5"></path>',
        task: '<path d="M5 19V5"></path><path d="M9 19V9"></path><path d="M13 19V7"></path><path d="M17 19v-5"></path>',
        calc: '<rect x="5" y="3" width="14" height="18" rx="2"></rect><path d="M8 7h8"></path><path d="M8 12h.01M12 12h.01M16 12h.01M8 16h.01M12 16h.01M16 16h.01"></path>',
        paint: '<path d="M5 16c2.4 1.8 6.3 2.2 8.5.2l4.8-4.8a2.2 2.2 0 0 0-3.1-3.1l-4.8 4.8C8.3 15.2 6.8 15.8 5 16z"></path><path d="M14 8l3 3"></path>',
        clock: '<circle cx="12" cy="12" r="8"></circle><path d="M12 7v5l3 2"></path>'
    })[kind] || '<rect x="5" y="5" width="14" height="14" rx="3"></rect>';
}

function getVertexAppBody(kind) {
    if (kind === "files") return getFilesBody();
    if (kind === "settings") return getSettingsBody();
    if (kind === "notepad") {
        return `<textarea aria-label="Notepad text">VertexOS note\n\n</textarea>`;
    }
    if (kind === "task") return getTaskManagerBody();
    if (kind === "paint") return getPaintBody();
    if (kind === "clock") return getClockBody();
    if (kind === "calc") {
        const keys = ["7","8","9","/","4","5","6","*","1","2","3","-","0",".","=","+","C"];
        return `
            <div class="calc-display" data-calc-display>0</div>
            <div class="calc-grid">${keys.map((key) => `<button type="button" data-calc-key="${key}">${key}</button>`).join("")}</div>
        `;
    }
    return "";
}

function getPaintBody() {
    return `
        <div class="paint-toolbar">
            <button type="button" data-paint-clear>Clear</button>
            <button class="paint-swatch" type="button" style="--paint-color:#f2f2f2" data-color="#f2f2f2" aria-label="White"></button>
            <button class="paint-swatch" type="button" style="--paint-color:#f66151" data-color="#f66151" aria-label="Red"></button>
            <button class="paint-swatch" type="button" style="--paint-color:#99c1f1" data-color="#99c1f1" aria-label="Blue"></button>
            <button class="paint-swatch" type="button" style="--paint-color:#8ff0a4" data-color="#8ff0a4" aria-label="Green"></button>
            <button class="paint-swatch" type="button" style="--paint-color:#111" data-color="#111" aria-label="Black"></button>
        </div>
        <canvas class="paint-canvas" width="900" height="460"></canvas>
    `;
}

function getClockBody() {
    return `
        <div class="clock-app">
            <div class="clock-time" data-clock-time>00:00:00</div>
            <div class="clock-date" data-clock-date>VertexOS</div>
        </div>
    `;
}

function getFilesBody() {
    const folders = ["Desktop", "Documents", "Downloads", "Pictures", "Projects", "VertexOS"];
    return `
        <aside class="files-sidebar">
            ${["Home", "Desktop", "Documents", "Downloads", "Pictures", "Projects"].map((item, index) => `<div class="files-side-item ${index === 0 ? "active" : ""}">${item}</div>`).join("")}
        </aside>
        <main class="files-main">
            <div class="files-toolbar">
                <div class="files-breadcrumbs">Home / zarif</div>
                <input class="files-search" type="search" placeholder="Search">
            </div>
            <div class="folder-grid">
                ${folders.map((folder) => `
                    <div class="folder-tile">
                        <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3.5 6.5h6l1.7 2h9.3v8.8a2.2 2.2 0 0 1-2.2 2.2H5.7a2.2 2.2 0 0 1-2.2-2.2z"></path></svg>
                        <span>${folder}</span>
                    </div>
                `).join("")}
            </div>
        </main>
    `;
}

function getSettingsBody() {
    const nav = ["System", "Bluetooth", "Network", "Appearance", "Power", "About"];
    const cards = [
        ["Display", "1920 x 1080, 100% scale", "Open"],
        ["Sound", "Output: Default device", "70%"],
        ["Battery", "Balanced power mode", "Auto"],
        ["Updates", "VertexOS live channel", "Ready"]
    ];
    return `
        <aside class="settings-nav">
            ${nav.map((item, index) => `<div class="settings-nav-item ${index === 0 ? "active" : ""}">${item}</div>`).join("")}
        </aside>
        <main class="settings-page">
            <div class="settings-heading">System</div>
            ${cards.map((card) => `
                <div class="settings-card">
                    <div>
                        <div class="settings-card-title">${card[0]}</div>
                        <div class="settings-card-sub">${card[1]}</div>
                    </div>
                    <div class="settings-pill">${card[2]}</div>
                </div>
            `).join("")}
        </main>
    `;
}

function getTaskManagerBody() {
    const rows = [
        ["Vertex Shell", "App", "2.4%", "312 MB", "0%", "0.1 Mbps"],
        ["Chromium", "Renderer", "6.8%", "740 MB", "7%", "0 Mbps"],
        ["System", "Service", "1.2%", "180 MB", "0%", "0 Mbps"],
        ["Network Manager", "Service", "0.4%", "72 MB", "0%", "1.2 Mbps"]
    ];
    return `
        <div class="task-summary">
            <div class="task-card"><strong>11%</strong><span>CPU</span></div>
            <div class="task-card"><strong>2.1 GB</strong><span>RAM</span></div>
            <div class="task-card"><strong>7%</strong><span>GPU</span></div>
            <div class="task-card"><strong>1.3 Mbps</strong><span>Network</span></div>
        </div>
        <table class="task-table">
            <thead><tr><th>Name</th><th>Type</th><th>CPU</th><th>RAM</th><th>GPU</th><th>Network</th></tr></thead>
            <tbody>${rows.map((row) => `<tr>${row.map((cell) => `<td>${escapeTerminalHtml(cell)}</td>`).join("")}</tr>`).join("")}</tbody>
        </table>
    `;
}

function initFilesWindow(app) {
    const search = app.querySelector(".files-search");
    const tiles = Array.from(app.querySelectorAll(".folder-tile"));
    if (!search) return;
    search.addEventListener("input", () => {
        const query = search.value.trim().toLowerCase();
        tiles.forEach((tile) => {
            const visible = tile.textContent.toLowerCase().includes(query);
            tile.style.display = visible ? "" : "none";
        });
    });
}

function initPaintWindow(app) {
    const canvas = app.querySelector(".paint-canvas");
    const ctx = canvas?.getContext("2d");
    if (!canvas || !ctx) return;
    let drawing = false;
    let color = "#f2f2f2";
    ctx.lineWidth = 4;
    ctx.lineCap = "round";
    ctx.strokeStyle = color;

    const point = (event) => {
        const rect = canvas.getBoundingClientRect();
        return {
            x: (event.clientX - rect.left) * (canvas.width / rect.width),
            y: (event.clientY - rect.top) * (canvas.height / rect.height)
        };
    };

    canvas.addEventListener("pointerdown", (event) => {
        drawing = true;
        const p = point(event);
        ctx.beginPath();
        ctx.moveTo(p.x, p.y);
        canvas.setPointerCapture(event.pointerId);
    });
    canvas.addEventListener("pointermove", (event) => {
        if (!drawing) return;
        const p = point(event);
        ctx.strokeStyle = color;
        ctx.lineTo(p.x, p.y);
        ctx.stroke();
    });
    canvas.addEventListener("pointerup", () => drawing = false);
    canvas.addEventListener("pointercancel", () => drawing = false);
    app.querySelector("[data-paint-clear]")?.addEventListener("click", () => ctx.clearRect(0, 0, canvas.width, canvas.height));
    app.querySelectorAll("[data-color]").forEach((button) => {
        button.addEventListener("click", () => color = button.dataset.color || "#f2f2f2");
    });
}

function initClockWindow(app) {
    const timeEl = app.querySelector("[data-clock-time]");
    const dateEl = app.querySelector("[data-clock-date]");
    if (!timeEl || !dateEl) return;
    const render = () => {
        const now = new Date();
        timeEl.textContent = now.toLocaleTimeString([], { hour12: false });
        dateEl.textContent = now.toLocaleDateString([], { weekday: "long", year: "numeric", month: "long", day: "numeric" });
    };
    render();
    const timer = window.setInterval(() => {
        if (!document.body.contains(app)) {
            window.clearInterval(timer);
            return;
        }
        render();
    }, 1000);
}

function initCalcWindow(app) {
    const display = app.querySelector("[data-calc-display]");
    let expression = "";
    const setDisplay = (value) => display.textContent = value || "0";
    app.querySelectorAll("[data-calc-key]").forEach((button) => {
        button.addEventListener("click", () => {
            const key = button.dataset.calcKey;
            if (key === "C") {
                expression = "";
                setDisplay("0");
                return;
            }
            if (key === "=") {
                try {
                    if (!/^[0-9+\-*/().\s]+$/.test(expression)) throw new Error("bad expression");
                    expression = String(Function(`"use strict"; return (${expression || "0"})`)());
                    setDisplay(expression);
                } catch (_) {
                    expression = "";
                    setDisplay("Error");
                }
                return;
            }
            expression += key;
            setDisplay(expression);
        });
    });
}

function initTerminalInput() {
    const input = document.getElementById("vertex-terminal-input");
    if (!input || input.dataset.terminalReady) return;
    input.dataset.terminalReady = "1";
    input.addEventListener("input", () => {
        updateTerminalAutocomplete();
        updateTerminalCursor();
    });
    input.addEventListener("keydown", handleTerminalKeydown);
    input.addEventListener("keyup", updateTerminalCursor);
    input.addEventListener("click", updateTerminalCursor);
    window.addEventListener("resize", updateTerminalCursor);
}

function handleTerminalKeydown(event) {
    const input = event.currentTarget;
    if (!input) return;

    if (event.key === "Tab") {
        const suggestion = getTerminalAutocomplete(input.value);
        if (suggestion) {
            event.preventDefault();
            input.value = suggestion;
            updateTerminalAutocomplete();
            updateTerminalCursor();
        }
        return;
    }

    if (event.key === "ArrowUp") {
        event.preventDefault();
        if (!vertexTerminalHistory.length) return;
        vertexHistoryIndex = Math.max(0, vertexHistoryIndex - 1);
        input.value = vertexTerminalHistory[vertexHistoryIndex] || "";
        updateTerminalAutocomplete();
        updateTerminalCursor();
        return;
    }

    if (event.key === "ArrowDown") {
        event.preventDefault();
        if (!vertexTerminalHistory.length) return;
        vertexHistoryIndex = Math.min(vertexTerminalHistory.length, vertexHistoryIndex + 1);
        input.value = vertexTerminalHistory[vertexHistoryIndex] || "";
        updateTerminalAutocomplete();
        updateTerminalCursor();
        return;
    }

    if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "l") {
        event.preventDefault();
        clearTerminalScreen();
    }
}

function updateTerminalAutocomplete() {
    const input = document.getElementById("vertex-terminal-input");
    const ghost = document.getElementById("terminal-autocomplete");
    if (!input || !ghost) return;
    const value = input.value.trimStart().toLowerCase();
    const suggestion = getTerminalAutocomplete(value);
    ghost.textContent = suggestion && suggestion !== value ? suggestion : "";
}

function getTerminalAutocomplete(value) {
    if (!value) return "";
    return vertexTerminalCommandNames.find((name) => name.startsWith(value)) || "";
}

function updateTerminalCursor() {
    const input = document.getElementById("vertex-terminal-input");
    const prompt = document.getElementById("terminal-prompt");
    const row = input?.closest(".terminal-input-row");
    if (!input || !prompt || !row) return;
    const rowRect = row.getBoundingClientRect();
    const promptRect = prompt.getBoundingClientRect();
    const style = window.getComputedStyle(input);
    const beforeCaret = input.value.slice(0, input.selectionStart || input.value.length);
    const textWidth = measureTerminalText(beforeCaret, style.font);
    const inputLeft = Math.round(promptRect.right - rowRect.left + 7);
    const cursorLeft = inputLeft + Math.round(textWidth);
    row.style.setProperty("--terminal-input-left", `${inputLeft}px`);
    row.style.setProperty("--terminal-cursor-left", `${cursorLeft}px`);
}

function measureTerminalText(text, font) {
    const canvas = measureTerminalText.canvas || (measureTerminalText.canvas = document.createElement("canvas"));
    const ctx = canvas.getContext("2d");
    ctx.font = font || "14px monospace";
    return ctx.measureText(text).width;
}

function escapeTerminalHtml(value) {
    return String(value).replace(/[&<>"']/g, (char) => ({
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        '"': "&quot;",
        "'": "&#39;"
    }[char]));
}

initTerminalInput();
initVertexWindowControls(document.getElementById("vertex-terminal-window"));
