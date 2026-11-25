// Serwis BLE GATT: STATUS (read/notify), CONFIG (read/write),
// COMMAND (write), RESPONSE (notify).
#pragma once
#include <Arduino.h>

// Polecenie odebrane przez BLE – przekazywane do loop() przez kolejkę,
// żeby ciężkie operacje (start Wi-Fi, NVS, I2C) nie działały w tasku BT.
struct BleCommand {
  char text[244];
};

void   ble_begin();
bool   ble_is_connected();
// Pobiera kolejne polecenie (nieblokująco). Zwraca false, gdy kolejka pusta.
bool   ble_poll_command(BleCommand& out);
void   ble_notify_status(const String& json);
void   ble_notify_response(const String& json);
void   ble_update_config_value(const String& json);
String ble_device_name();
