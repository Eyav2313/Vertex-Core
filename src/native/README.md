# Native Components

Use this area for C and C++ components that sit close to the session, device, boot, or installer boundary.

Initial candidates:

- `vertex-sessiond`: session readiness and diagnostics helper.
- `vertex-powerd`: policy bridge for battery, thermal, and performance modes.
- `vertex-greeter-bridge`: optional display manager integration helper.

Native components should build with CMake or Meson, use C++20 where C++ is needed, and keep privileged operations isolated.
