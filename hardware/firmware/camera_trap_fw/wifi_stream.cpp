#include "wifi_stream.h"
#include "camera_grove.h"
#include "config.h"
#include "device_state.h"

#include <WiFi.h>
#include <esp_http_server.h>
#include <vector>

#define PART_BOUNDARY "camtrapframe"
static const char* STREAM_CONTENT_TYPE = "multipart/x-mixed-replace;boundary=" PART_BOUNDARY;
static const char* STREAM_BOUNDARY     = "\r\n--" PART_BOUNDARY "\r\n";
static const char* STREAM_PART         = "Content-Type: image/jpeg\r\nContent-Length: %u\r\n\r\n";

static httpd_handle_t s_httpd = nullptr;
static httpd_handle_t s_streamd = nullptr;
static volatile bool  s_stopping = false;
static bool           s_on = false;
static WifiInfo       s_info;
static uint32_t       s_lastActivityMs = 0;
static volatile int   s_clients = 0;       // aktywni klienci streamu

// ---------------------------------------------------------------------------
//  Strona testowa (otwórz http://192.168.4.1 w przeglądarce)
// ---------------------------------------------------------------------------
static const char INDEX_HTML[] PROGMEM = R"HTML(<!doctype html>
<html lang="pl"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Fotopułapka – podgląd</title>
<style>
 body{margin:0;font-family:system-ui,sans-serif;background:#111;color:#eee;padding:16px}
 img{width:100%;max-width:640px;background:#000;border:2px solid #444;display:block}
 pre{background:#222;padding:8px;max-width:624px;overflow:auto;font-size:13px}
 a{color:#8cf}
</style></head><body>
<h2>Podgląd na żywo</h2>
<img id="v" alt="brak obrazu">
<p>Strumień: <a id="u"></a> (np. VLC → Media → Otwórz strumień sieciowy)</p>
<h3>Status</h3><pre id="s">…</pre>
<h3>Detekcje (powyżej progu AI)</h3><pre id="d">…</pre>
<script>
const url = location.protocol + '//' + location.hostname + ':81/stream';
document.getElementById('v').src = url;
const a = document.getElementById('u'); a.href = url; a.textContent = url;
async function tick(){
  try{
    document.getElementById('s').textContent = JSON.stringify(await (await fetch('/status')).json(), null, 1);
    document.getElementById('d').textContent = JSON.stringify(await (await fetch('/detections')).json(), null, 1);
  }catch(e){}
}
setInterval(tick, 2000); tick();
</script></body></html>)HTML";

static void touch() { s_lastActivityMs = millis(); }

static esp_err_t send_json(httpd_req_t* req, const String& json) {
  httpd_resp_set_type(req, "application/json");
  httpd_resp_set_hdr(req, "Access-Control-Allow-Origin", "*");
  return httpd_resp_send(req, json.c_str(), json.length());
}

static esp_err_t index_handler(httpd_req_t* req) {
  touch();
  httpd_resp_set_type(req, "text/html; charset=utf-8");
  return httpd_resp_send(req, INDEX_HTML, strlen(INDEX_HTML));
}

static esp_err_t status_handler(httpd_req_t* req) {
  touch();
  return send_json(req, state_status_json());
}

static esp_err_t detections_handler(httpd_req_t* req) {
  return send_json(req, camera_last_detections_json());
}

static esp_err_t capture_handler(httpd_req_t* req) {
  touch();
  std::vector<uint8_t> jpg;
  if (!camera_grab(jpg)) {
    httpd_resp_send_err(req, HTTPD_500_INTERNAL_SERVER_ERROR, "camera not available");
    return ESP_FAIL;
  }
  httpd_resp_set_type(req, "image/jpeg");
  httpd_resp_set_hdr(req, "Content-Disposition", "inline; filename=capture.jpg");
  httpd_resp_set_hdr(req, "Access-Control-Allow-Origin", "*");
  return httpd_resp_send(req, (const char*)jpg.data(), jpg.size());
}

// MJPEG – każdy klient działa w tasku serwera na porcie 81 aż do rozłączenia.
static esp_err_t stream_handler(httpd_req_t* req) {
  if (!camera_ready()) {
    httpd_resp_set_status(req, "503 Service Unavailable");
    httpd_resp_sendstr(req, "camera not available (send WAKE_UP or check wiring)");
    return ESP_OK;
  }
  httpd_resp_set_type(req, STREAM_CONTENT_TYPE);
  httpd_resp_set_hdr(req, "Access-Control-Allow-Origin", "*");
  httpd_resp_set_hdr(req, "Cache-Control", "no-cache");

  state_set_stream_clients(+1);
  s_clients++;
  Serial.println("[WIFI] klient streamu polaczony");

  std::vector<uint8_t> jpg;
  char part[64];
  int failures = 0;
  uint32_t frames = 0, t0 = millis();
  esp_err_t res = ESP_OK;

  while (!s_stopping) {
    touch();
    if (!camera_grab(jpg)) {
      if (++failures > 20) { res = ESP_FAIL; break; }
      vTaskDelay(pdMS_TO_TICKS(100));
      continue;
    }
    failures = 0;
    size_t n = snprintf(part, sizeof(part), STREAM_PART, (unsigned)jpg.size());
    res = httpd_resp_send_chunk(req, STREAM_BOUNDARY, strlen(STREAM_BOUNDARY));
    if (res == ESP_OK) res = httpd_resp_send_chunk(req, part, n);
    if (res == ESP_OK) res = httpd_resp_send_chunk(req, (const char*)jpg.data(), jpg.size());
    if (res != ESP_OK) break;  // klient się rozłączył

    if (++frames % 20 == 0) {
      Serial.printf("[WIFI] stream: %.1f fps, ramka %u B\n",
                    frames * 1000.0f / (millis() - t0), (unsigned)jpg.size());
    }
  }

  state_set_stream_clients(-1);
  s_clients--;
  Serial.println("[WIFI] klient streamu rozlaczony");
  return res;
}

// ---------------------------------------------------------------------------
static bool start_servers() {
  httpd_config_t cfg = HTTPD_DEFAULT_CONFIG();
  cfg.server_port = HTTP_PORT;
  cfg.ctrl_port = 32768;
  cfg.max_uri_handlers = 8;

  httpd_uri_t index_uri      = {"/",           HTTP_GET, index_handler,      nullptr};
  httpd_uri_t status_uri     = {"/status",     HTTP_GET, status_handler,     nullptr};
  httpd_uri_t detections_uri = {"/detections", HTTP_GET, detections_handler, nullptr};
  httpd_uri_t capture_uri    = {"/capture",    HTTP_GET, capture_handler,    nullptr};
  httpd_uri_t stream_uri     = {"/stream",     HTTP_GET, stream_handler,     nullptr};

  if (httpd_start(&s_httpd, &cfg) != ESP_OK) return false;
  httpd_register_uri_handler(s_httpd, &index_uri);
  httpd_register_uri_handler(s_httpd, &status_uri);
  httpd_register_uri_handler(s_httpd, &detections_uri);
  httpd_register_uri_handler(s_httpd, &capture_uri);

  // Osobny serwer dla streamu, żeby /status działał w trakcie oglądania.
  cfg.server_port = STREAM_PORT;
  cfg.ctrl_port = 32769;
  if (httpd_start(&s_streamd, &cfg) != ESP_OK) {
    httpd_stop(s_httpd);
    s_httpd = nullptr;
    return false;
  }
  httpd_register_uri_handler(s_streamd, &stream_uri);
  return true;
}

static void stop_servers() {
  s_stopping = true;              // pętle streamu kończą się po bieżącej klatce
  vTaskDelay(pdMS_TO_TICKS(500));
  if (s_streamd) { httpd_stop(s_streamd); s_streamd = nullptr; }
  if (s_httpd)   { httpd_stop(s_httpd);   s_httpd = nullptr; }
  s_stopping = false;
}

bool wifi_enable(String& error) {
  if (s_on) return true;

#if WIFI_USE_HOME_NETWORK
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(true);  // wymagane przy współpracy Wi-Fi + BLE
  WiFi.begin(HOME_WIFI_SSID, HOME_WIFI_PASSWORD);
  Serial.printf("[WIFI] lacze z \"%s\"...\n", HOME_WIFI_SSID);
  uint32_t t0 = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - t0 < HOME_WIFI_TIMEOUT_MS) delay(200);
  if (WiFi.status() != WL_CONNECTED) {
    WiFi.disconnect(true);
    WiFi.mode(WIFI_OFF);
    error = "home wifi connect timeout";
    state_set_flag(ERR_WIFI, true);
    return false;
  }
  s_info.mode = "sta";
  s_info.ssid = HOME_WIFI_SSID;
  s_info.password = "";
  s_info.ip = WiFi.localIP().toString();
#else
  uint8_t mac[6];
  WiFi.mode(WIFI_AP);
  WiFi.softAPmacAddress(mac);
  char ssid[32];
  snprintf(ssid, sizeof(ssid), "%s%02X%02X", AP_SSID_PREFIX, mac[4], mac[5]);
  if (!WiFi.softAP(ssid, AP_PASSWORD, AP_CHANNEL, 0, 2)) {
    WiFi.mode(WIFI_OFF);
    error = "softAP start failed";
    state_set_flag(ERR_WIFI, true);
    return false;
  }
  s_info.mode = "ap";
  s_info.ssid = ssid;
  s_info.password = AP_PASSWORD;
  s_info.ip = WiFi.softAPIP().toString();
#endif

  if (!start_servers()) {
    WiFi.mode(WIFI_OFF);
    error = "http server start failed";
    state_set_flag(ERR_WIFI, true);
    return false;
  }

  s_info.on = true;
  s_info.streamUrl = "http://" + s_info.ip + ":" + String(STREAM_PORT) + "/stream";
  s_on = true;
  touch();
  state_set_flag(ERR_WIFI, false);
  state_set_wifi(true);
  Serial.printf("[WIFI] ON (%s) SSID=%s IP=%s stream=%s\n", s_info.mode.c_str(),
                s_info.ssid.c_str(), s_info.ip.c_str(), s_info.streamUrl.c_str());
  return true;
}

void wifi_disable() {
  if (!s_on) return;
  stop_servers();
#if WIFI_USE_HOME_NETWORK
  WiFi.disconnect(true);
#else
  WiFi.softAPdisconnect(true);
#endif
  WiFi.mode(WIFI_OFF);
  s_on = false;
  s_info = WifiInfo();
  state_set_wifi(false);
  Serial.println("[WIFI] OFF");
}

bool wifi_is_on() { return s_on; }

WifiInfo wifi_info() { return s_info; }

void wifi_loop() {
#if WIFI_IDLE_TIMEOUT_MS > 0
  if (!s_on) return;
  if (s_clients > 0) return;
#if !WIFI_USE_HOME_NETWORK
  if (WiFi.softAPgetStationNum() > 0) return;  // ktoś jest podłączony do AP
#endif
  if (millis() - s_lastActivityMs > WIFI_IDLE_TIMEOUT_MS) {
    Serial.println("[WIFI] bezczynnosc – wylaczam Wi-Fi");
    wifi_disable();
  }
#endif
}
