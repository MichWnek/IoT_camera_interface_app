// Wi-Fi (AP lub sieć domowa) + serwery HTTP: strona testowa i strumień MJPEG.
#pragma once
#include <Arduino.h>

struct WifiInfo {
  bool   on;
  String mode;       // "ap" / "sta"
  String ssid;
  String password;   // tylko w trybie AP
  String ip;
  String streamUrl;  // http://<ip>:81/stream
};

bool     wifi_enable(String& error);   // uruchamia Wi-Fi + serwery HTTP
void     wifi_disable();
bool     wifi_is_on();
WifiInfo wifi_info();
void     wifi_loop();                  // auto-wyłączenie po bezczynności
