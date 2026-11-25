# Integracja aplikacji z fotopułapką (BLE + Wi-Fi)

Lista funkcji, które aplikacja Flutter musi obsłużyć, żeby współpracować z firmware ESP32
(`hardware/firmware/camera_trap_fw`). Szczegóły protokołu: [`hardware/README.md`](../hardware/README.md).

> Firmware nie był jeszcze kompilowany ani testowany na sprzęcie – protokół może wymagać drobnych poprawek.

## 1. Bluetooth – połączenie

- **Uprawnienia:** `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, lokalizacja (Android). Prośba o włączenie Bluetooth.
- **Skanowanie** po UUID serwisu `6e400000-c0de-4a1b-9f5e-ca3e7a000001`, nazwa `CT-XXXX`; pokazać RSSI.
  - Urządzenie zwykle śpi. Skan musi trwać do kilku minut (aż przyjdzie okresowe wybudzenie `adv`)
    albo użytkownik macha przed PIR. W UI warto o tym napisać.
- **Połączenie:**
  - zwiększyć MTU (np. 247),
  - zasubskrybować STATUS i RESPONSE,
  - od razu wysłać `SET_TIME <epoch>` i `WAKE_UP`, żeby urządzenie nie zasnęło w trakcie obsługi.
- **Rozłączenie / utrata zasięgu:** wykrycie, komunikat, ewentualnie ponowne łączenie.
- **Parowanie z listą kamer:** zapisanie MAC i nazwy jako `CameraTrap`.

| Charakterystyka | UUID | Właściwości |
|---|---|---|
| STATUS | `6e400001-c0de-4a1b-9f5e-ca3e7a000001` | READ, NOTIFY |
| CONFIG | `6e400002-c0de-4a1b-9f5e-ca3e7a000001` | READ, WRITE |
| COMMAND | `6e400003-c0de-4a1b-9f5e-ca3e7a000001` | WRITE |
| RESPONSE | `6e400004-c0de-4a1b-9f5e-ca3e7a000001` | NOTIFY |

## 2. Status (charakterystyka STATUS)

- Odczyt przy połączeniu i powiadomienia co 5 s.
- Przykład: `{"bat":-1,"sd":-1.00,"wifi":0,"cli":0,"cam":1,"awake":0,"err":0,"up":12,"ev":3,"pir":0,"wake":"pir","time":1764000000}`

| Pole | Znaczenie |
|---|---|
| `bat` | bateria w %, `-1` = nieznana |
| `sd` | wolne GB, `-1` = nieznane |
| `wifi`, `cli` | Wi-Fi włączone, liczba klientów streamu |
| `cam` | kamera odpowiada |
| `awake` | tryb serwisowy |
| `err` | maska błędów: 1 kamera, 2 SD, 4 bateria, 8 Wi-Fi, 16 PIR |
| `up` | czas działania [s] |
| `ev` | liczba nagrań |
| `pir` | aktualny stan PIR |
| `wake` | co obudziło urządzenie: `boot` / `pir` / `adv` |
| `time` | zegar urządzenia (epoch), `0` = nieustawiony |

- **Zmiana modelu:** `DeviceStatus` musi przyjmować `-1` dla baterii i SD (dziś `assert` wymaga ≥ 0).

## 3. Konfiguracja (charakterystyka CONFIG)

- Odczyt i zapis JSON `{"ai","frames","hits","rec","cool","adv","win"}`. Zapis idzie do CONFIG
  albo przez `SET_CONFIG {json}`.
- Przy zapisie trzeba odczytać odpowiedź: przy błędzie przychodzi `ok:0` z opisem.
- **Zmiana modelu:** `CameraConfig` zamiast `pirThreshold` (V) dostaje poniższe pola
  (czułość HC-SR501 ustawia się potencjometrem, nie programowo):

| Pole | Zakres | Znaczenie |
|---|---|---|
| `ai` | 0–1 | minimalna pewność „zwierzęcia” |
| `frames` | 1–10 | klatki do klasyfikacji po PIR |
| `hits` | 1–frames | ile klatek musi pokazać zwierzę |
| `rec` | 1–60 s | długość nagrania |
| `cool` | 0–3600 s | po zdarzeniu PIR nie budzi |
| `adv` | 0–1440 min | co ile wstać i rozgłaszać BLE (0 = nigdy) |
| `win` | 2–120 s | jak długo rozgłaszać BLE po wybudzeniu |

## 4. Polecenia (COMMAND → odpowiedź w RESPONSE)

| Polecenie | W aplikacji |
|---|---|
| `PING` | przycisk Test (jest już `TODO` w `configuration_screen.dart`) |
| `WAKE_UP` | przycisk wybudzania / wejście w tryb serwisowy |
| `SLEEP` | „Uśpij teraz” przy kończeniu pracy z kamerą |
| `TRIGGER` | „Testuj detekcję”, czyli symulacja PIR |
| `GET_STATUS` / `GET_CONFIG` / `GET_EVENT` | odświeżenie danych |
| `SET_CONFIG {json}` | zapis konfiguracji |
| `SET_TIME <epoch>` | automatycznie po połączeniu |
| `ENABLE_WIFI` / `DISABLE_WIFI` / `WIFI_INFO` | ekran wideo |
| `REBOOT` | ustawienia zaawansowane |

- Odpowiedź: `{"cmd":"…","ok":1,…}` lub `{"cmd":"…","ok":0,"error":"…"}`. Dopasowywać po polu `cmd`,
  z limitem czasu na brak odpowiedzi.
- **Asynchroniczne `EVENT`:** po wykryciu ruchu przychodzi
  `{"cmd":"EVENT","ok":1,"id":…,"animal":…,"score":…,"cls":"…","hits":…,"checked":…,"frames":…,"ms":…,"t":…}`.
  Pokazać jako powiadomienie lub wpis w historii.

## 5. Wi-Fi i wideo

1. Wysłać `ENABLE_WIFI` i z odpowiedzi odczytać `ssid`, `pass`, `ip`, `url`.
2. Pokazać SSID i hasło (z kopiowaniem) oraz instrukcję ręcznego przełączenia Wi-Fi w telefonie, jak przewiduje HLD.
   - Opcjonalnie połączenie automatyczne pakietem `wifi_iot` na Androidzie.
3. Odtwarzacz MJPEG pod `http://<ip>:81/stream`: `flutter_vlc_player` albo własny widżet MJPEG na pakiecie `http`.
   - Obsługa błędów: odpowiedź 503 (brak kamery) i zerwany strumień.
4. Opcjonalnie odpytywać `/detections` co 2 s i nakładać ramki na obraz. Pojedyncze zdjęcie jest pod `/capture`.
5. Wymagane uprawnienie `INTERNET` i zezwolenie na `http://` (cleartext) dla `192.168.4.1`.
6. Na wyjściu z ekranu `DISABLE_WIFI` (ESP i tak wyłączy Wi-Fi po 10 min bez klientów).

## 6. Dane lokalne i stan aplikacji

- Lista kamer: nazwa, MAC, ostatni status, ostatnie zdarzenie, data ostatniego połączenia (Hive / sqflite).
- Zarządzanie stanem (provider / bloc): stan połączenia, status, konfiguracja, oczekujące odpowiedzi.

## 7. Poza zakresem tej części (opcjonalne z HLD)

- Nawigacja GPS do kamery: zapis lokalizacji przy dodawaniu kamery, kompas, azymut.
- Tryb ciepło-zimno po RSSI Bluetooth.
