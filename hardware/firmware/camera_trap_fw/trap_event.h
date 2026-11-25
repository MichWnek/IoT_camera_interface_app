// Logika fotopułapki: PIR -> klasyfikacja kilku klatek -> nagrywanie lub nic.
#pragma once
#include <Arduino.h>
#include "device_state.h"

void      trap_storage_begin();   // karta SD po stronie ESP32 (tylko RECORD_TARGET_ESP_SD)
// Wykonuje pełne zdarzenie. Zasilanie kamery: włącza na początku; wyłącza na
// końcu, jeśli keepCameraOn == false.
TrapEvent trap_run_event(bool keepCameraOn);
