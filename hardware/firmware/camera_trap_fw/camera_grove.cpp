#include "camera_grove.h"
#include "config.h"
#include "device_state.h"

#include <ArduinoJson.h>
#include <Wire.h>
#include <mbedtls/base64.h>

#if USE_GROVE_VISION_AI
#include <Seeed_Arduino_SSCMA.h>
static SSCMA s_ai;
#else
#include <img_converters.h>  // fmt2jpg – koder JPEG wbudowany w arduino-esp32
#endif

static SemaphoreHandle_t      s_lock = nullptr;  // jedno wywołanie modułu naraz (loop + HTTP)
static bool                   s_ready = false;
static std::vector<String>    s_classNames;      // z AI.info(), małe litery
static std::vector<Detection> s_lastDet;
static uint32_t               s_lastDetMs = 0;

static void lock()   { if (!s_lock) s_lock = xSemaphoreCreateMutex(); xSemaphoreTake(s_lock, portMAX_DELAY); }
static void unlock() { xSemaphoreGive(s_lock); }

// ---------------------------------------------------------------------------
//  Które klasy to "zwierzę"
// ---------------------------------------------------------------------------
static bool list_contains(const char* csv, const String& item) {
  String list = String(",") + csv + ",";
  list.toLowerCase();
  return list.indexOf("," + item + ",") >= 0;
}

static String class_name(uint8_t target) {
  return target < s_classNames.size() ? s_classNames[target] : String();
}

static bool is_animal_class(uint8_t target) {
  String name = class_name(target);
  if (name.length()) return list_contains(ANIMAL_CLASS_NAMES, name);
  if (String(ANIMAL_CLASS_IDS) == "*") return true;
  return list_contains(ANIMAL_CLASS_IDS, String(target));
}

// ---------------------------------------------------------------------------
#if USE_GROVE_VISION_AI

// AI.info() zwraca JSON modelu zakodowany w base64; wyciągamy "classes".
static void load_class_names() {
  s_classNames.clear();
  String b64 = s_ai.info(false);
  if (!b64.length()) return;
  std::vector<uint8_t> raw((b64.length() * 3) / 4 + 4);
  size_t len = 0;
  if (mbedtls_base64_decode(raw.data(), raw.size(), &len, (const uint8_t*)b64.c_str(), b64.length()) != 0) return;
  JsonDocument doc;
  if (deserializeJson(doc, (const char*)raw.data(), len)) return;
  for (JsonVariant c : doc["classes"].as<JsonArray>()) {
    String n = c.as<String>();
    n.trim();
    n.toLowerCase();
    s_classNames.push_back(n);
  }
}

static void collect_detections() {
  const float thr = state_get_config().aiThreshold * 100.0f;
  s_lastDet.clear();
  for (auto& b : s_ai.boxes())
    if (b.score >= thr) s_lastDet.push_back({(int16_t)b.x, (int16_t)b.y, (int16_t)b.w, (int16_t)b.h, b.score, b.target});
  for (auto& c : s_ai.classes())
    if (c.score >= thr) s_lastDet.push_back({0, 0, 0, 0, c.score, c.target});
  s_lastDetMs = millis();
}

bool camera_power_on() {
  lock();
  if (!s_ready) {
#if GROVE_POWER_PIN >= 0
    pinMode(GROVE_POWER_PIN, OUTPUT);
    digitalWrite(GROVE_POWER_PIN, GROVE_POWER_ON_LEVEL);
    delay(300);
#endif
    uint32_t t0 = millis();
    while (!s_ready && millis() - t0 < GROVE_BOOT_TIMEOUT_MS) {
      s_ready = s_ai.begin(&Wire);  // biblioteka sama robi Wire.begin(); bez resetu – szybko
      if (!s_ready) delay(250);
    }
#if GROVE_RESET_PIN >= 0
    if (!s_ready) {
      // Moduł się zawiesił – twardy reset przez pin RST i jeszcze jedna próba
      Serial.println("[CAM] brak odpowiedzi – reset modulu");
      s_ready = s_ai.begin(&Wire, GROVE_RESET_PIN);
      for (int i = 0; !s_ready && i < 8; i++) { delay(250); s_ready = s_ai.begin(&Wire); }
    }
#endif
    if (s_ready) {
      s_ai.clean_actions();         // na wypadek pozostawionego save_jpeg()
      load_class_names();
      Serial.printf("[CAM] Grove OK (%u ms), klasy modelu: %u\n", (unsigned)(millis() - t0),
                    (unsigned)s_classNames.size());
      for (size_t i = 0; i < s_classNames.size(); i++)
        Serial.printf("      %u: %s%s\n", (unsigned)i, s_classNames[i].c_str(),
                      is_animal_class(i) ? "  <- zwierze" : "");
    } else {
      Serial.println("[CAM] Grove Vision AI NIE ODPOWIADA");
    }
  }
  unlock();
  state_set_flag(ERR_CAMERA, !s_ready);
  return s_ready;
}

void camera_power_off() {
#if GROVE_POWER_PIN >= 0
  lock();
  Wire.end();
  pinMode(SDA, INPUT);  // nie zasilaj modułu przez linie I2C
  pinMode(SCL, INPUT);
  digitalWrite(GROVE_POWER_PIN, !GROVE_POWER_ON_LEVEL);
  s_ready = false;
  unlock();
  Serial.println("[CAM] Grove wylaczony");
#endif
  // bez sterowania zasilaniem moduł zostaje włączony i gotowy
}

bool camera_classify(Classification& out) {
  out = {false, 0, 0, ""};
  if (!s_ready) return false;
  lock();
  // invoke(times, filter=true) -> moduł odsyła same wyniki, bez obrazu
  bool ok = s_ai.invoke(1, true, false) == CMD_OK;
  if (ok) {
    collect_detections();
    for (const Detection& d : s_lastDet) {
      if (!is_animal_class(d.target)) continue;
      if (d.score > out.score) {
        out.score = d.score;
        out.target = d.target;
        out.name = class_name(d.target);
      }
    }
    out.animal = out.score > 0;  // s_lastDet zawiera już tylko wyniki >= progu AI
  }
  unlock();
  state_set_flag(ERR_CAMERA, !ok);
  return ok;
}

bool camera_grab(std::vector<uint8_t>& jpg) {
  if (!s_ready) return false;
  lock();
  bool ok = s_ai.invoke(1, false, true) == CMD_OK;  // z obrazem (base64)
  String b64;
  if (ok) {
    b64 = s_ai.last_image();
    collect_detections();
  }
  unlock();
  if (!ok || !b64.length()) return false;

  size_t outLen = 0;
  jpg.resize((b64.length() * 3) / 4 + 4);
  if (mbedtls_base64_decode(jpg.data(), jpg.size(), &outLen, (const uint8_t*)b64.c_str(), b64.length()) != 0)
    return false;
  jpg.resize(outLen);
  return true;
}

bool camera_grove_sd_save(bool on) {
  if (!s_ready) return false;
  lock();
  bool ok = (on ? s_ai.save_jpeg() : s_ai.clean_actions()) == CMD_OK;
  unlock();
  Serial.printf("[CAM] zapis na SD Grove: %s %s\n", on ? "ON" : "OFF", ok ? "" : "(BLAD)");
  return ok;
}

bool camera_record_frame_on_grove() {
  if (!s_ready) return false;
  lock();
  bool ok = s_ai.invoke(1, !GROVE_SD_FETCH_IMAGE, GROVE_SD_FETCH_IMAGE) == CMD_OK;
  if (ok) collect_detections();
  unlock();
  return ok;
}

// ---------------------------------------------------------------------------
#else  // ======================= SYMULACJA (bez Grove) ========================

static uint8_t s_mockScore = 0;

bool camera_power_on() {
  if (!s_ready) {
    Serial.println("[CAM] SYMULACJA – brak Grove Vision AI");
    s_classNames = {"background", "animal"};
    s_ready = true;
  }
  state_set_flag(ERR_CAMERA, false);
  return true;
}

void camera_power_off() {}

bool camera_classify(Classification& out) {
  delay(150);  // mniej więcej czas wnioskowania modułu
  bool animal = (int)random(100) < MOCK_ANIMAL_CHANCE;
  uint8_t score = animal ? random(70, 100) : random(5, 40);
  lock();
  s_lastDet.clear();
  if (score >= state_get_config().aiThreshold * 100.0f) s_lastDet.push_back({0, 0, 0, 0, score, 1});
  s_lastDetMs = millis();
  unlock();
  out = {!s_lastDet.empty(), (uint8_t)(s_lastDet.empty() ? 0 : score), 1, "animal"};
  return true;
}

// Obraz testowy: gradient + odbijający się kwadrat + pasek postępu
bool camera_grab(std::vector<uint8_t>& jpg) {
  static uint8_t* frame = nullptr;
  static uint32_t n = 0, lastMs = 0;
  static int bx = 10, by = 10, dx = 3, dy = 2;
  const int W = MOCK_FRAME_W, H = MOCK_FRAME_H, B = 28;

  lock();
  uint32_t wait = 1000 / MOCK_FPS, el = millis() - lastMs;
  if (el < wait) vTaskDelay(pdMS_TO_TICKS(wait - el));
  lastMs = millis();
  if (!frame) frame = (uint8_t*)malloc(W * H);
  if (!frame) { unlock(); return false; }

  n++;
  bx += dx; by += dy;
  if (bx < 0 || bx + B >= W) { dx = -dx; bx += 2 * dx; }
  if (by < 0 || by + B >= H) { dy = -dy; by += 2 * dy; }
  for (int y = 0; y < H; y++)
    for (int x = 0; x < W; x++) {
      uint8_t v = (uint8_t)(((x + n * 2) & 0x7F) + 40);
      if (x >= bx && x < bx + B && y >= by && y < by + B) v = 250;
      if (x < 4 || y < 4 || x >= W - 4 || y >= H - 4) v = 0;
      frame[y * W + x] = v;
    }
  for (int x = 4; x < 4 + (int)(n % (W - 8)); x++)
    for (int y = H - 8; y < H - 5; y++) frame[y * W + x] = 255;

  s_mockScore = 40 + (n % 60);
  s_lastDet.clear();
  if (s_mockScore >= state_get_config().aiThreshold * 100.0f)
    s_lastDet.push_back({(int16_t)(bx + B / 2), (int16_t)(by + B / 2), B, B, s_mockScore, 1});
  s_lastDetMs = millis();

  uint8_t* out = nullptr;
  size_t outLen = 0;
  bool ok = fmt2jpg(frame, W * H, W, H, PIXFORMAT_GRAYSCALE, 70, &out, &outLen);
  unlock();
  if (!ok || !out) return false;
  jpg.assign(out, out + outLen);
  free(out);
  return true;
}

bool camera_grove_sd_save(bool) { return true; }

bool camera_record_frame_on_grove() {
  delay(1000 / MOCK_FPS);
  return true;
}
#endif

// ---------------------------------------------------------------------------
bool camera_ready() { return s_ready; }

String camera_last_detections_json() {
  String out = "{\"age_ms\":";
  lock();
  out += s_lastDetMs ? String(millis() - s_lastDetMs) : String(-1);
  out += ",\"boxes\":[";
  for (size_t i = 0; i < s_lastDet.size(); i++) {
    const Detection& d = s_lastDet[i];
    char buf[128];
    snprintf(buf, sizeof(buf), "%s{\"x\":%d,\"y\":%d,\"w\":%d,\"h\":%d,\"score\":%u,\"target\":%u,\"name\":\"%s\"}",
             i ? "," : "", d.x, d.y, d.w, d.h, d.score, d.target, class_name(d.target).c_str());
    out += buf;
  }
  unlock();
  out += "]}";
  return out;
}
