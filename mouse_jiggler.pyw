"""
Mouse Jiggler — keeps the PC awake by moving the mouse
after 60 seconds of inactivity.

• Monitors mouse position every 500 ms.
• When the mouse stops, a 60-second idle timer starts.
• If the mouse stays still for 60 s, it jiggles randomly.
• Any real mouse movement resets the timer.
• Runs as a small tkinter window with Start / Stop / Quit.
"""

import ctypes
import ctypes.wintypes
import random
import time
import tkinter as tk
from threading import Thread, Event

# ── Windows API helpers ──────────────────────────────────────────────
class POINT(ctypes.Structure):
    _fields_ = [("x", ctypes.c_long), ("y", ctypes.c_long)]

def get_cursor_pos():
    pt = POINT()
    ctypes.windll.user32.GetCursorPos(ctypes.byref(pt))
    return pt.x, pt.y

def set_cursor_pos(x, y):
    ctypes.windll.user32.SetCursorPos(x, y)

# ── Core logic ───────────────────────────────────────────────────────
IDLE_TIMEOUT = 60          # seconds before jiggle
POLL_INTERVAL = 0.5        # seconds between position checks
JIGGLE_RANGE = 1           # max pixels to move in each direction

class MouseJiggler:
    def __init__(self, status_var, timer_var):
        self._stop_event = Event()
        self._thread = None
        self._status_var = status_var
        self._timer_var = timer_var

    def start(self):
        if self._thread and self._thread.is_alive():
            return
        self._stop_event.clear()
        self._thread = Thread(target=self._run, daemon=True)
        self._thread.start()
        self._status_var.set("Running")

    def stop(self):
        self._stop_event.set()
        self._status_var.set("Stopped")
        self._timer_var.set("Idle: —")

    def _run(self):
        last_x, last_y = get_cursor_pos()
        last_move_time = time.monotonic()

        while not self._stop_event.is_set():
            x, y = get_cursor_pos()

            if (x, y) != (last_x, last_y):
                # Mouse moved — reset timer
                last_x, last_y = x, y
                last_move_time = time.monotonic()

            idle = time.monotonic() - last_move_time

            # Update the UI timer
            remaining = max(0, IDLE_TIMEOUT - idle)
            self._timer_var.set(f"Idle: {remaining:.0f}s left")

            if idle >= IDLE_TIMEOUT:
                # Jiggle the mouse
                dx = random.randint(-JIGGLE_RANGE, JIGGLE_RANGE)
                dy = random.randint(-JIGGLE_RANGE, JIGGLE_RANGE)
                new_x = max(0, x + dx)
                new_y = max(0, y + dy)
                set_cursor_pos(new_x, new_y)

                last_x, last_y = new_x, new_y
                last_move_time = time.monotonic()

            self._stop_event.wait(POLL_INTERVAL)

# ── GUI ──────────────────────────────────────────────────────────────
def main():
    root = tk.Tk()
    root.title("Mouse Jiggler")
    root.resizable(False, False)
    root.attributes("-topmost", True)

    status_var = tk.StringVar(value="Stopped")
    timer_var = tk.StringVar(value="Idle: —")

    jiggler = MouseJiggler(status_var, timer_var)

    frame = tk.Frame(root, padx=16, pady=12)
    frame.pack()

    tk.Label(frame, textvariable=status_var, font=("Segoe UI", 14, "bold")).pack(pady=(0, 4))
    tk.Label(frame, textvariable=timer_var, font=("Segoe UI", 11)).pack(pady=(0, 10))

    btn_frame = tk.Frame(frame)
    btn_frame.pack()

    tk.Button(btn_frame, text="Start", width=8, command=jiggler.start).pack(side=tk.LEFT, padx=4)
    tk.Button(btn_frame, text="Stop",  width=8, command=jiggler.stop).pack(side=tk.LEFT, padx=4)
    tk.Button(btn_frame, text="Quit",  width=8, command=root.destroy).pack(side=tk.LEFT, padx=4)

    # Auto-refresh the timer label from the background thread
    def refresh_ui():
        root.after(500, refresh_ui)
    root.after(500, refresh_ui)

    root.protocol("WM_DELETE_WINDOW", lambda: (jiggler.stop(), root.destroy()))
    root.mainloop()

if __name__ == "__main__":
    main()
