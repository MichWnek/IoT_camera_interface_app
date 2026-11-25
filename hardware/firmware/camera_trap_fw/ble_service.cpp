#include "ble_service.h"
#include "config.h"
#include "device_state.h"

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <esp_system.h>
#if __has_include(<esp_mac.h>)
#include <esp_mac.h>  // esp_read_mac w ESP-IDF 5 (arduino-esp32 3.x)
#endif

static BLEServer*         s_server = nullptr;
static BLECharacteristic* s_status = nullptr;
static BLECharacteristic* s_config = nullptr;
static BLECharacteristic* s_command = nullptr;
static BLECharacteristic* s_response = nullptr;
static QueueHandle_t      s_queue = nullptr;
static volatile int       s_connections = 0;
static String             s_name;

static void set_value(BLECharacteristic* c, const String& s) {
  // (uint8_t*, size_t) działa zarówno w arduino-esp32 2.x, jak i 3.x
  c->setValue((uint8_t*)s.c_str(), s.length());
}

static void enqueue(const String& text) {
  BleCommand cmd;
  strlcpy(cmd.text, text.c_str(), sizeof(cmd.text));
  if (xQueueSend(s_queue, &cmd, 0) != pdTRUE) {
    Serial.println("[BLE] kolejka polecen pelna – odrzucono");
  }
}

// ---------------------------------------------------------------------------
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer*) override {
    s_connections++;
    Serial.printf("[BLE] polaczono (aktywne: %d)\n", (int)s_connections);
    // pozwól na kolejne połączenie (np. telefon + PC przy testach)
    BLEDevice::startAdvertising();
  }
  void onDisconnect(BLEServer*) override {
    if (s_connections > 0) s_connections--;
    Serial.printf("[BLE] rozlaczono (aktywne: %d)\n", (int)s_connections);
    BLEDevice::startAdvertising();
  }
};

class CommandCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* c) override {
    String v = String(c->getValue().c_str());  // std::string (2.x) lub String (3.x)
    v.trim();
    if (v.length()) enqueue(v);
  }
};

class ConfigCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* c) override {
    String v = String(c->getValue().c_str());
    v.trim();
    // zapis do CONFIG == polecenie SET_CONFIG
    if (v.length()) enqueue("SET_CONFIG " + v);
  }
  void onRead(BLECharacteristic* c) override {
    set_value(c, state_config_json());
  }
};

class StatusCallbacks : public BLECharacteristicCallbacks {
  void onRead(BLECharacteristic* c) override {
    set_value(c, state_status_json());
  }
};

// ---------------------------------------------------------------------------
void ble_begin() {
  s_queue = xQueueCreate(8, sizeof(BleCommand));

  uint8_t mac[6];
  esp_read_mac(mac, ESP_MAC_BT);
  char name[24];
  snprintf(name, sizeof(name), "%s%02X%02X", BLE_NAME_PREFIX, mac[4], mac[5]);
  s_name = name;

  BLEDevice::init(s_name.c_str());
  BLEDevice::setMTU(BLE_MTU);

  s_server = BLEDevice::createServer();
  s_server->setCallbacks(new ServerCallbacks());

  BLEService* svc = s_server->createService(BLEUUID(SERVICE_UUID), 20);

  s_status = svc->createCharacteristic(
      CHAR_STATUS_UUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  s_status->addDescriptor(new BLE2902());
  s_status->setCallbacks(new StatusCallbacks());
  set_value(s_status, state_status_json());

  s_config = svc->createCharacteristic(
      CHAR_CONFIG_UUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE);
  s_config->setCallbacks(new ConfigCallbacks());
  set_value(s_config, state_config_json());

  s_command = svc->createCharacteristic(
      CHAR_COMMAND_UUID, BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR);
  s_command->setCallbacks(new CommandCallbacks());

  s_response = svc->createCharacteristic(CHAR_RESPONSE_UUID, BLECharacteristic::PROPERTY_NOTIFY);
  s_response->addDescriptor(new BLE2902());

  svc->start();

  BLEAdvertising* adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(SERVICE_UUID);   // aplikacja może filtrować skan po UUID
  adv->setScanResponse(true);
  adv->setMinPreferred(0x06);          // pomaga iOS przy połączeniu
  adv->setMinPreferred(0x12);
  BLEDevice::startAdvertising();

  Serial.printf("[BLE] rozglaszam jako \"%s\" (MAC %s)\n", s_name.c_str(),
                BLEDevice::getAddress().toString().c_str());
}

bool ble_is_connected() { return s_connections > 0; }

bool ble_poll_command(BleCommand& out) {
  return s_queue && xQueueReceive(s_queue, &out, 0) == pdTRUE;
}

void ble_notify_status(const String& json) {
  if (!s_status) return;
  set_value(s_status, json);
  if (s_connections > 0) s_status->notify();
}

void ble_notify_response(const String& json) {
  Serial.printf("[BLE] -> %s\n", json.c_str());
  if (!s_response) return;
  set_value(s_response, json);
  if (s_connections > 0) s_response->notify();
}

void ble_update_config_value(const String& json) {
  if (s_config) set_value(s_config, json);
}

String ble_device_name() { return s_name; }
