// Grove Vision AI V2 (OV5647) przez I2C: zasilanie, klasyfikacja, obraz, zapis na SD modułu.
#pragma once
#include <Arduino.h>
#include <vector>

struct Detection {
  int16_t x, y, w, h;   // współrzędne modelu (środek + rozmiar); 0 dla klasyfikatora
  uint8_t score;        // 0–100
  uint8_t target;       // indeks klasy
};

struct Classification {
  bool    animal;       // jakaś klasa zwierzęcia powyżej progu AI
  uint8_t score;        // najlepszy wynik klasy zwierzęcia (0–100)
  uint8_t target;
  String  name;         // nazwa klasy z modelu (jeśli znana)
};

bool   camera_power_on();       // włącza zasilanie (jeśli sterowane) i czeka na moduł
void   camera_power_off();      // zwalnia I2C i odcina zasilanie (jeśli sterowane)
bool   camera_ready();

// Jedno wnioskowanie BEZ obrazu (szybkie) – do decyzji "czy jest zwierzę".
bool   camera_classify(Classification& out);
// Jedno wnioskowanie Z obrazem JPEG – stream / zapis na SD po stronie ESP32.
bool   camera_grab(std::vector<uint8_t>& jpg);
// Nagrywanie na kartę SD modułu Grove: włącza/wyłącza akcję save_jpeg()
// i wykonuje jedną klatkę (moduł sam zapisuje plik).
bool   camera_grove_sd_save(bool on);
bool   camera_record_frame_on_grove();

String camera_last_detections_json();
