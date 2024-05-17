# Characteristics

Reusable implementations of standardized Bluetooth Characteristics.

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

SpeziBluetooth provides a collection of Bluetooth characteristics already out of the box.
This includes generic characteristics like
``DateTime`` and a collection of characteristics from the health domain.

Below is a list of already implemented characteristics.
Encoding and decoding is handled using [`ByteCodable`](https://swiftpackageindex.com/StanfordSpezi/SpeziFileFormats/documentation/bytecoding)
which natively integrates with SpeziBluetooth-defined services.

## Topics

### Device Information

- ``PnPID``
- ``VendorIDSource``

### Time

- ``DateTime``
- ``DayOfWeek``
- ``DayDateTime``
- ``ExactTime256``
- ``CurrentTime``

### Blood Pressure

- ``BloodPressureMeasurement``
- ``BloodPressureFeature``
- ``IntermediateCuffPressure``

### Temperature Measurement

- ``TemperatureMeasurement``
- ``TemperatureType``
- ``MeasurementInterval``

### Weight Measurement

- ``WeightMeasurement``
- ``WeightScaleFeature``
