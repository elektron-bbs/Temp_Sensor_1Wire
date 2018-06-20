# Funk-Temperatur-Sensor mit 1-Wire-Sensoren
Dieser Funk-Temperatursensor übertraegt die Temperaturwerte von maximal 8 Stueck 1-Wire-Sensoren.
Verwendet wird ein Funkprotokoll der WS2000/WS7000-Serie. Dieses Protokoll kann vom SIGNALduino empfangen und in FHEM dekodiert werden.
Zum Einsatz kommt ein ATtiny44. Die Software wurde unter BASCOM programmiert. Es koennen folgende Typen von 1-Wire-Sensoren verwendet werden:

- DS1820 / DS18S20 1–Wire Digital Thermometer
- DS1822 Econo 1-Wire Digital Thermometer
- DS18B20 Programmable Resolution 1-Wire Digital Thermometer

Eine individuelle Adresse für den ersten Sensor kann im Bereich von 0 bis 7 mittels Jumpern eingestellt werden.
Weitere 1-Wire-Sensoren belegen automatisch die darauf folgenden Adressen.
Als Zusatz wird, wenn Adresse 7 noch nicht belegt ist, die Batteriespannung des Funk-Sensors mit der naechsten freien Adresse uebertragen.
Dieser Wert muss in FHEM z.B. mit folgenden Attribut umgerechnet werden, um plausible Spannungsanzeigen zu erhalten:

```attr CUL_WS_02 userReadings voltage {(ReadingsVal("CUL_WS_02","temperature",0) / 10.0)}```

Die durchschnittliche Stromaufnahme mit unterschiedlicher Anzahl von Sensoren wurde gemessen.
Daraus ergibt sich eine errechnete theoretische Laufzeit mit einem Batteriesatz von 3 Zellen Typ AA.
Ausgegangen wurde dabei von einer Kapazitaet der Zellen von 2 Ah.

| Anzahl Sensoren | Stromaufnahme (µA) | Laufzeit in Jahren |
| ------------- | ------------- | ------------- |
| 2 | 15 | 15 |
| 4 | 30 | 7 |
| 6 | 50 | 4 |
| 7 | 60 | 3 |
| 8 | 63 | 3 |

