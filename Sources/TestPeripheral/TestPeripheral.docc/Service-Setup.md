# Running as a Service

Setting up the Test Peripheral as a launchd service.

<!--
#
# This source file is part of the Stanford Spezi open source project
#
# SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
#
# SPDX-License-Identifier: MIT
#
-->

## Overview

This guides provides an overview on how to deploy the test peripheral as a launchd launch agent on macOS.

> Tip: For more information on `launchd` refer to the [Creating Launch Daemons and Agents](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html)
    guide or other resources like [What is launchd?](https://launchd.info).

### Build the TestPeripheral

1. Clone the repository and open it in Xcode.
2. Select the `TestPeripheral` scheme and `Any Mac` as the destination.
3. Run `Product > Archive` to build and archive a release build.
4. Open the Xcode Organizer and distribute the build products of the archive from the previous step.
5. Move the `TestPeripheral` binary into the `/Applications` folder. 


### Setup as a Service

We provide a small script to run the test peripheral as a service using `launchd` on macOS.#
Follow the following steps to install and run the service.
We assume that you placed the `TestPeripheral` binary in the `/Applications` folder as per the previous steps.

#### Install Service

To install the launchd service run the following command in the root folder of the SpeziBluetooth project:

```
./bin/service-launchd.sh install
```

#### Start Service

To load the service into launchd run the following command:

```
./bin/service-launchd.sh start
```

#### Stop Service

To unload the service from launchd run the following command:

```
./bin/service-launchd.sh stop
```

#### Status

You can get the current status of the launch agent using the following command:
```
./bin/service-launchd.sh status
```

If the service is running, you will get output similar to the one below.
The first column is the PID of the application (or `-` if not running) and the second column is the last exit code.

```
Started:
9314    0       edu.stanford.spezi.bluetooth.testperipheral´
```

#### Uninstall Service

To completely uninstall the launchd launch agent, run the following command:

```
./bin/service-launchd.sh uninstall
```
