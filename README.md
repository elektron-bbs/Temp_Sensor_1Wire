# Funk-Temperatur-Sensor mit 1-Wire-Sensoren
Dieser Funk-Temperatursensor übertraegt die Temperaturwerte von maximal 8 Stueck 1-Wire-Sensoren.
Verwendet wird ein Funkprotokoll der WS2000/WS7000-Serie. Dieses Protokoll kann vom SIGNALduino empfangen und in FHEM dekodiert werden.
Zum Einsatz kommt ein ATtiny44. Die Software wurde unter BASCOM programmiert.
Eine individuelle Adresse für den ersten Sensor kann im Bereich von 0 bis 7 mittels Jumpern eingestellt werden.
Weitere Sensoren belegen automatisch die darauf folgenden Adressen. Als Zusatz wird, wenn Adresse 7 noch nicht belegt ist, die Batteriespannung des Sensors mit der naechsten freien Adresse uebertragen.
Dieser Wert muss in FHEM z.B. mit folgenden Attribut umgerechnet werden.

```attr CUL_WS_02 userReadings voltage {(ReadingsVal("CUL_WS_02","temperature",0) / 10.0)}```

| Anzahl Sensoren | durchschnittliche Stromaufnahme (µA) | ungefaehre Laufzeit in Jahren mit 3 Zellen Typ AA |
| ------------- | ----------- | ------------------- |
| 2 | 15 | 15 |

