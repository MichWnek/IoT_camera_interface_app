# Specyfikacja Interfejsu Użytkownika i Architektury Aplikacji: Fotopułapka AI

## 1. Docelowe Funkcje

### Funkcje podstawowe (Core features):
* **Zdalna konfiguracja:** Komendy Bluetooth (regulacja progów detekcji false positives, czułości PIR, włączenie strumieniowania wideo poprzez Wi-Fi, informacje o statusie).
* **Strumieniowanie wideo:** Podgląd na żywo z kamery poprzez Wi-Fi (opcjonalne nałożenie obszaru czułości PIR na obraz w celu łatwiejszej konfiguracji).
* **Zarządzanie statusami:** Przetwarzanie i wysyłanie podstawowych informacji o statusie urządzenia poprzez Bluetooth (poziom baterii, wolna pamięć karty SD, komunikaty o błędach).

### Dodatkowa funkcjonalność (Nice-to-haves):
* **Makro-nawigacja:** Zapisywanie lokalizacji GPS oraz nawigacja na azymut w celu odnalezienia kamery w terenie.
* **Mikro-nawigacja:** Tryb nawigacji ciepło-zimno oparty o RSSI sygnału Bluetooth (BLE Beacon) do precyzyjnej lokalizacji urządzenia w bliskim otoczeniu.

## 2. Stos Technologiczny (Tech Stack)

| Moduł | Funkcjonalność | Rekomendowane pakiety Flutter |
| :-- | :-- | :-- |
| **Dane i Stan** | Lokalne przechowywanie punktów trasy, profili kamer i logów | `hive` lub `sqflite`, `provider` lub `flutter_bloc` |
| **Makro-Nawigacja** | Współrzędne GPS, obliczanie dystansu, azymut kompasu | `geolocator`, `flutter_compass` |
| **Mikro-Nawigacja** | Skanowanie BLE, komenda wybudzenia, filtrowanie sygnału RSSI | `flutter_blue_plus`, `permission_handler` |
| **Konfiguracja (BLE)** | Operacje zapisu GATT | `flutter_blue_plus` |
| **Strumieniowanie wideo** | Strumień wideo na żywo (RTSP lub MJPEG) | `flutter_vlc_player` lub `webview_flutter` |

## 3. Kluczowe Widoki UI i Wymagania Terenowe (Field-Ready UX)

* **Panel Konfiguracyjny (Configuration Panel):** Suwaki i przełączniki do regulacji czułości PIR, progów AI oraz przycisk wybudzania (`WAKE_UP`).
* **Odtwarzacz Wideo (VLC Wrapper):** Strumień RTSP/MJPEG na żywo z opcjonalną nakładką detekcji PIR.
* **Ergonomia terenowa:** Wysoki kontrast, czytelność w pełnym słońcu oraz opcjonalny tryb nocny chroniący wzrok badacza.
---
**Opcjonalne:**
* **Pulpit i Widok Mapy (Dashboard & Map View):** Główny panel zarządzania listą fotopułapek, podgląd stanu baterii, pamięci SD oraz szybki dostęp do lokalizacji.
* **Widok Kompasu GPS (Macro-Navigation View):** Tarcza kompasu, wskaźnik azymutu w stopniach oraz aktualizowany dystans w metrach do celu.
* **Widok Poszukiwania Hot-Cold (Micro-Navigation View):** Dynamiczny wskaźnik siły sygnału BLE RSSI do precyzyjnego namierzania urządzenia w najbliższym otoczeniu.

## Szacunkowa pracochłonność (Effort Estimate)

| Moduł / Faza | Opis zakresu prac | Szacowany czas (godziny) |
| :--- | :--- | :--- |
| **1. Architektura i Baza Danych** | Konfiguracja projektu Flutter, lokalna baza danych (Hive/SQLite), ekrany główne (Dashboard). | 24–40 godz. |
| **2. Konfiguracja i Status (BLE)** | Implementacja GATT Writes dla ustawień PIR, pobieranie statusu baterii i pamięci SD. | 32–48 godz. |
| **3. Strumieniowanie Wideo (Wi-Fi)** | Ręczny przełącznik sieci, obsługa odtwarzacza VLC/RTSP, stabilizacja strumienia. | 48–72 godz. |
| **4. Mikro-Nawigacja (BLE) Opcjonalnie** | Skanowanie BLE, obsługa beaconów, filtracja sygnału RSSI (Hot-Cold UI). | 40–64 godz. |
| **5. Makro-Nawigacja (GPS) Opcjonalnie** | Integracja geolokalizacji, kompasu, obliczanie azymutu i dystansu do fotopułapki. | 32–48 godz. |
| **Całkowity szacowany czas:** | *Rekomendowane przydzielenie jeszcze co najmniej 1 osoby (roboczogodziny)* | **~216–328 roboczogodzin** |

## Diagram interakcji (Funkcje podstawowe)
```mermaid
graph TD
    %% Define main logical blocks
    subgraph RESEARCHER_ENV [Środowisko Badań terenowych]
        USER((Naukowiec w terenie))
        PHONE_HW[Hardware telefonu]
    end

    subgraph FLUTTER_APP [Architektura Aplikacji mobilnej]
        %% UI Layer
        subgraph UI [Interfejs Użytkownika]
            CONF_PANEL[Panel konfiguracyjny]
            VLC["Odtwarzacz wideo"]
        end

        %% State & Data Management Layer
        STATE["Zarządzanie stanem (Bloc/Provider)"]
        LOCAL_DB[("Lokalna Baza danych")]

        %% Logical Services Layer
        subgraph SERVICES [Serwisy]
            BLE_MGR["BLE Manager (GATT)"]
        end
    end

    subgraph CAMERA_TRAP ["Fotopułapka (ESP32)"]
        subgraph PHYSICAL [Podzespoły komunikacyjne]
            ESP_BLE["BLE (GATT)"]
            ESP_WIFI["Wi-Fi AP"]
        end

        subgraph LOGICAL [Serwisy]
            RTSP["Serwer RTSP"]
        end
    end

    %% Define Interactions

    %% 1. User & App Internal Flows
    USER --Interacts--> UI
    UI --Trigger Events--> STATE
    STATE --Update UI--> UI
    STATE <--> LOCAL_DB
    
    BLE_MGR ==GATT Write: WAKE_UP==> ESP_BLE
    ESP_BLE ==GATT Read/Notification: STATUS_UPDATE ==>BLE_MGR
    BLE_MGR ==GATT Write: SET_CONFIG==> ESP_BLE

    %% 3. Configuration & Streaming Flow via Wi-Fi (Direct Connection)
    USER -.-> |Manual Wi-Fi Switch| PHONE_HW
    
    ESP_BLE ==>|ENABLE_WIFI command| ESP_WIFI
    RTSP ==>|Stream live video| ESP_WIFI

    VLC -..-> |Fetch RTSP/MJPEG Stream| ESP_WIFI

    %% Styling for clarity
    classDef ui_component color:#000000,fill:#e3f2fd,stroke:#1565c0,stroke-width:2px;
    classDef db_component color:#000000,fill:#ffe0b2,stroke:#f57c00,stroke-width:2px,stroke-dasharray: 5 5;
    classDef logic_component color:#000000,fill:#c8e6c9,stroke:#2e7d32,stroke-width:2px;
    classDef hw_component color:#000000,fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px;
    
    %% Assign styles
    class DASH,CONF_PANEL,VLC ui_component;
    class LOCAL_DB,SD_CARD db_component;
    class STATE,BLE_MGR,RTSP, logic_component;
    class PHONE_HW,ESP_BLE,ESP_WIFI, hw_component;

```

## Diagram Interakcji (Pełny feature set):
```mermaid
graph TD
    %% Define main logical blocks
    subgraph RESEARCHER_ENV [Środowisko badań terenowych]
        USER((Biolog w terenie))
        PHONE_HW[Hardware telefonu]
        GPS_SENS[Sygnał GPS]
    end

    subgraph FLUTTER_APP [Architektura aplikacji mobilnej]
        %% UI Layer
        subgraph UI [Interfejs użytkownika]
            DASH[Panel informacyjny / Mapa]
            NAV_COMPASS[Widok kompasu GPS]
            HOT_COLD[Widok nawigacji RSSI BLE]
            CONF_PANEL[Panel Konfiguracyjny]
            VLC["Odtwarzacz wideo"]
        end

        %% State & Data Management Layer
        STATE["Zarządzanie stanem (Bloc/Provider)"]
        LOCAL_DB[("Lokalna Baza danych")]

        %% Logical Services Layer
        subgraph SERVICES [Usługi]
            NAV_SERV["Nawigacja (Odległość/Azymut)"]
            BLE_MGR["BLE Manager (SKanowanie Beacon/GATT)"]
        end
    end

    subgraph CAMERA_TRAP ["Fotopułapka"]
        subgraph COMMS["Podzespoły komunikacyjne"]
            ESP_BLE["BLE (GATT & Beacon)"]
            ESP_WIFI["Wi-Fi AP"]
        end

        subgraph SERVICES_L ["Usługi"]
            ESP_BEACON["Usługa BLE Beacon"]
            RSTP["Serwer RSTP"]
        end
    end

    %% Define Interactions

    %% 1. User & App Internal Flows
    USER --Interacts--> UI
    UI --Trigger Events--> STATE
    STATE --Update UI--> UI
    STATE <--> LOCAL_DB
    
    %% Navigation Flow (Macro)
    PHONE_HW --Provides Heading--> NAV_COMPASS
    GPS_SENS -.-> PHONE_HW
    PHONE_HW --Provides Location--> NAV_SERV
    NAV_SERV --Calculates Distance/Bearing--> STATE
    LOCAL_DB --Provides Saved Target Coords--> NAV_SERV

    %% 2. Proximity & Wake-Up Flow (Micro-Navigation) via BLE
    STATE --Start BLE Hunt--> BLE_MGR
    BLE_MGR --Filter by Target MAC--> STATE
    BLE_MGR --Read Raw RSSI--> STATE
    STATE --Update RSSI UI--> HOT_COLD
    
    BLE_MGR ==GATT Write: WAKE_UP==> ESP_BLE
    BLE_MGR ==GATT Write: SET_CONFIG==> ESP_BLE
    ESP_BEACON ==BLE Beacon==> ESP_BLE
    ESP_BLE ==Beacon Broadcast==> BLE_MGR

    %% 3. Configuration & Streaming Flow via Wi-Fi (Direct Connection)
    USER -.-> |Manual Wi-Fi Switch| PHONE_HW
    
    BLE_MGR ==>|ENABLE_WIFI command| ESP_BLE

    VLC -..-> |Fetch RTSP/MJPEG Stream| ESP_WIFI

    RSTP ==> |Stream video| ESP_WIFI

    %% Styling for clarity
    classDef ui_component color:#000000,fill:#e3f2fd,stroke:#1565c0,stroke-width:2px;
    classDef db_component color:#000000,fill:#ffe0b2,stroke:#f57c00,stroke-width:2px,stroke-dasharray: 5 5;
    classDef logic_component color:#000000,fill:#c8e6c9,stroke:#2e7d32,stroke-width:2px;
    classDef hw_component color:#000000,fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px;
    
    %% Assign styles
    class DASH,NAV_COMPASS,HOT_COLD,CONF_PANEL,VLC ui_component;
    class LOCAL_DB,SD_CARD db_component;
    class STATE,NAV_SERV,BLE_MGR,RSTP,ESP_BEACON, logic_component;
    class PHONE_HW,GPS_SENS,ESP_BLE,ESP_WIFI, hw_component;
```