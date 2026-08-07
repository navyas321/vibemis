# BL-2629 microphone validation

The client microphone path is opt-in. Open Settings -> Streaming, select the
input device, enable **Enable microphone streaming**, and confirm the live input
meter moves before starting a stream.

## BL-2633: stock-host graceful degradation

Use the same client build and paired, unmodified Apollo/Vibepollo host for both
runs. Record the parent SHA, common-c SHA, AppImage SHA-256, `selftest --json`,
and host application list in separate evidence directories.

```bash
export APP=/path/to/Vibemis.AppImage HOST=paired-stock-host APPNAME=test-app DURATION=90
export MODE=off RUN="$PWD/evidence/bl2633-off"
scripts/run-microphone-evidence.sh

# Turn the client setting ON; keep the stock host unchanged.
export MODE=on RUN="$PWD/evidence/bl2633-on" EXPECT_MIC=0
scripts/run-microphone-evidence.sh
```

The ON log must contain the exact no-support line printed by common-c and no
`streamid=mic`. Video/audio must stay alive for the evidence window with no
unexpected reconnect or teardown. Preserve performance-overlay captures for
OFF and ON as a control comparison.

## BL-2634: mic-enabled host

Use a host build that explicitly contains the microphone receiver, recording its
repository branch and commit, Steam Streaming Microphone driver, encryption
support, and a fresh host log.

```bash
export MODE=on RUN="$PWD/evidence/bl2634-client" EXPECT_MIC=1
scripts/run-microphone-evidence.sh
```

The client log must show the capture device, negotiated mic stream active,
`Microphone stream encryption: enabled`, and the first microphone packet. The
host log must show positive `streamid=mic` setup.
Speak a known phrase and retain host-side receive-meter or WAV evidence with
synchronized UTC timestamps. Client logs alone cannot prove host receipt.

## Current status

The code checkpoint is `228f845d` with common-c `ee67c928`. Static shell,
submodule, and audio invariants pass. Runtime validation remains open until a
Qt/AppImage artifact, target SteamOS client, mic-enabled host branch, and
host-side receive capture are available.
