# MaxPS4 loading diagnostics

The upstream iOS loading overlay uses a synthetic progress value when console logging is disabled. It approaches 90% asymptotically, so the integer display can remain at 89% even though 89% is not a real engine completion value.

The MaxPS4 build patch now tails only the last 8 KiB of the emulator log while the full console is disabled and displays the latest recognized boot stage below the percentage. This keeps the lightweight UI while making stalls diagnosable on-device.
