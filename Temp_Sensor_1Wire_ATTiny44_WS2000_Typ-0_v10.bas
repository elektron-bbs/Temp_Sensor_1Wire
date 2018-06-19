'*******************************************************************************
'* Description   : Sensor Temperaturen mit max. 8 Stueck 1-Wire Sensoren       *
'* RF-Protokoll  : WS2000                                                      *
'* Revision      : 1.0                                                         *
'* Controller    : ATtiny44                                                    *
'* Stromaufnahme : ca. 30 µA mit 2 x DS18B20 + Aurel TX-SAW-MID 5V Transmitter *
'* Compiler      : BASCOM-AVR  2.0.8.1                                         *
'* Author        : UB , 2018                                                   *
'* Web           : HTTP://www.Elektron-BBS.de                                  *
'*******************************************************************************
$regfile = "attiny44.dat"
$crystal = 1000000
$hwstack = 32
$swstack = 10
$framesize = 40
$noramclear                                                 ' Variablen nicht zurück setzen
Stop Ac                                                     ' Strom sparen
Stop Adc                                                    ' Strom sparen

'************************* ports for connection ********************************
Led_bl Alias Portb.0 : Config Led_bl = Output               ' LED blau
Tx433 Alias Portb.1 : Config Tx433 = Output                 ' Data Sendemodul 433 MHz

'******************************* 1-Wire ****************************************
Config 1wire = Porta.3                                      ' 1-Wire Datenanschluss
Dim Sensor_anzahl As Word                                   ' Anzahl Sensoren, the 1wirecount function returns a word/integer
Dim Sensor_id(64) As Byte                                   ' 1-Wire ID: 8 Sensoren je 8 Byte
Dim Sensor_nr As Byte                                       ' Sensornummer
Dim Sensor_start_adr As Byte                                ' Sensor Startadresse im Array
Dim Temp_raw As Integer                                     ' Temperatur
Dim Ubatt As Word                                           ' Temperatur

'************************* Variablen TX 433 MHz ********************************
Dim Tx_dbl As Double                                        ' 64 Bit Sendepuffer
Dim Tx_bit_nr As Byte                                       ' Nummer zu sendendes Bit
Dim Tx_byte As Byte                                         ' zu sendendes Byte
Dim Tx_byte_nr As Byte                                      ' Nummer zu sendendes Byte
Dim Check As Byte                                           ' Prüfsumme XOR Typ bis Check muss 0 ergeben
Dim Ersumme As Byte                                         ' Prüfsumme errechnet
Dim S_adresse_temp As Byte                                  ' Sensoradresse Temperatur

'***************************** Watchdog ****************************************
Dim Wd_count As Byte                                        ' Zähler für Watchdog-Starts

'***************************** Temporär ****************************************
Dim X As Byte
Dim Barray(9) As Byte                                       ' Byte Array
Dim I As Integer , I1 As Integer
Dim L As Long                                               ' 4 Bytes, -2.147.483.648 to 2.147.483.647

'*************************** H A U P T P R O G R A M M *************************
X = Mcusr                                                   ' MCUSR – MCU Status Register
If X = 1 Or X = 2 Then                                      ' Power-on Reset or External Reset
   Wd_count = 0
End If
If Wd_count >= 22 Then : Wd_count = 0 : End If              ' alle 22 * 8 = 176 Sekunden
'If Wd_count >= 8 Then : Wd_count = 0 : End If               ' alle 8 * 8 = 64 Sekunden
Incr Wd_count

If Wd_count = 1 Then
   'Sensor-Adresse von Jumperstellung übernehmen
   Config Porta.0 = Input : Porta.0 = 1                     ' Port als Eingänge, Pullups einschalten
   Config Porta.1 = Input : Porta.1 = 1                     ' Port als Eingänge, Pullups einschalten
   Config Porta.2 = Input : Porta.2 = 1                     ' Port als Eingänge, Pullups einschalten
   Nop                                                      ' kurz warten (SYNC LATCH)
   X = Pina                                                 ' Jumperstellung übernehmen
   'Jumper gegen GND, gesteckt = Bit auf 0, offen = Bit auf 1
   'Pina.0 - Jumper 1 (K1) Adresse Temperatur Bit 0
   'Pina.1 - Jumper 2 (K2) Adresse Temperatur Bit 1
   'Pina.2 - Jumper 3 (K3) Adresse Temperatur Bit 2
   S_adresse_temp = X And &B00000111                        ' Adresse Temp-/Feuchtesensor (untere 3 Bit) übernehmen
   Porta.0 = 0                                              ' Pullups ausschalten
   Porta.1 = 0                                              ' Pullups ausschalten
   Porta.2 = 0                                              ' Pullups ausschalten
   'Sensor-Anzahl ermitteln
   Sensor_anzahl = 1wirecount()                             ' the 1wirecount function returns a word/integer
   'Sensor-Adressen ermitteln
   If Sensor_anzahl >= 1 Then
      For Sensor_nr = 1 To Sensor_anzahl
         Sensor_start_adr = Sensor_nr - 1                   ' 0 bis Anzahl Sensoren - 1
         Sensor_start_adr = Sensor_start_adr * 8            ' Adresse sind 8 Byte
         Incr Sensor_start_adr                              ' Startadresse im Array ist 1, 9, 17 ...
         If Sensor_nr = 1 Then
            Sensor_id(sensor_start_adr) = 1wsearchfirst()   ' search for the first device on the bus
         Else
            Sensor_id(sensor_start_adr) = 1wsearchnext()    ' search for the next device on the bus
         End If
      Next Sensor_nr
   End If
   'Prüfung Sensoradresse + Anzahl Sensoren
   X = S_adresse_temp + Sensor_anzahl                       ' 0-7 + 1-8 = 1-15
   If X >= 8 Then                                           ' zu hohe Adresse
      S_adresse_temp = 8 - Sensor_anzahl
   End If
Else                                                        ' Wd_count >= 2
   X = Sensor_anzahl * 2                                    ' Anzahl Sensoren * 2
   Incr X                                                   ' 2 Counts pro Sensor
   If Wd_count <= X Then                                    ' wenn Wd_count <= Anzahl * 2
      If Wd_count.0 = 0 Then
         'Start Temperaturmessung
         Sensor_nr = Wd_count / 2
         Sensor_start_adr = Sensor_nr - 1                   ' 0 bis Anzahl Sensoren - 1
         Sensor_start_adr = Sensor_start_adr * 8            ' Adresse sind 8 Byte
         Incr Sensor_start_adr                              ' Startadresse im Array
         1wverify Sensor_id(sensor_start_adr)               ' Issues the "Match ROM"
         If Err = 0 Then
            1wwrite &H44                                    ' CONVERT T [44h]
         End If
      Else
         'Sensorwerte auslesen
         1wverify Sensor_id(sensor_start_adr)               ' Issues the "Match ROM"
         If Err = 0 Then
            1wwrite &HBE                                    ' READ SCRATCHPAD [BEh]
            Barray(1) = 1wread(9)                           ' read bytes into array
            If Barray(9) = Crc8(barray(1) , 8) Then         ' CRC-Prüfung
               Select Case Sensor_id(sensor_start_adr)      ' 1-Wire family code
                  Case &H10                                 ' DS1820 / DS18S20 1–Wire Digital Thermometer
                     I = Makeint(barray(1) , Barray(2))     ' Byte 1 und 2 zusammenfügen
                     'I = I * 50                             ' Auflösung 9 Bit, 0,5 °C
                     'genauere Umrechnung braucht 222 Byte mehr
                     I.0 = 0                                ' truncating the 0.5°C bit (bit 0)
                     I = I * 100 : I = I - 25
                     I1 = Barray(8) - Barray(7)
                     I1 = I1 * 100
                     I1 = I1 / Barray(8)
                     I = I + I1
                     'I = I / 2
                     Temp_raw = I / 2                       ' Temperatur übernehmen
                  Case &H22                                 ' DS1822 Econo 1-Wire Digital Thermometer
                     I = Makeint(barray(1) , Barray(2))     ' Byte 1 und 2 zusammenfügen
                     L = I * 100
                     Shift L , Right , 4 , Signed           ' /16
                     Temp_raw = L                           ' Integer Temperatur übernehmen
                  Case &H28                                 ' DS18B20 Programmable Resolution 1-Wire Digital Thermometer
                     I = Makeint(barray(1) , Barray(2))     ' Byte 1 und 2 zusammenfügen
                     L = I * 100
                     Shift L , Right , 4 , Signed           ' /16
                     Temp_raw = L                           ' Integer Temperatur übernehmen
               End Select

               Temp_raw = Temp_raw / 10

               Barray(1) = 0                                ' Sensortyp 0 - Thermo (AS3)
               X = Sensor_nr - 1                            ' Sensornummer (0-7) Temperatur übernehmen
               Barray(2) = S_adresse_temp + X               ' Sensoradresse (0-7) Temperatur übernehmen
               If Temp_raw < 0 Then
                  Barray(2).3 = 1                           ' Bit 20 Vorzeichen negativ
                  Temp_raw = Temp_raw * -1                  ' Temperaturwert umkehren
               End If

               Gosub Temp_in_array                          ' Temperatur in Array übernehmen
               Gosub Tx_433_send                            ' Daten senden
            End If
         End If
      End If
   Else                                                     ' Sensoranzahl * 2 + 2
      X = Sensor_anzahl * 2                                 ' Anzahl Sensoren * 2
      X = X + 2                                             ' 2 Counts pro Sensor
      If Wd_count = X Then                                  ' wenn Wd_count = Anzahl * 2 + 2
         X = S_adresse_temp + Sensor_anzahl
         If X <= 7 Then
            Config Adc = Single , Prescaler = Auto , Reference = Internal_1.1
            Set Led_bl                                      ' LED ein (Spannungsteiler für Messung ein)
            Temp_raw = Getadc(7)                            ' Batteriespannung messen
            Reset Led_bl                                    ' LED aus (Spannungsteiler für Messung aus)
            Stop Adc                                        ' A/D-Wandler ausschalten

            L = Temp_raw * 1048576
            Shift L , Right , 21                            ' / 2097152
            Temp_raw = L                                    ' Wert übernehmen

            Barray(1) = 0                                   ' Sensortyp 0 - Thermo (AS3)
            Barray(2) = S_adresse_temp + Sensor_anzahl      ' Sensoradresse (0-7) übernehmen
            Gosub Temp_in_array                             ' Temperatur in Array übernehmen
            Gosub Tx_433_send                               ' Daten senden
         End If
      End If
   End If
End If

Mcusr = 0                                                   ' clear MCUSR – MCU Status Register
Config Watchdog = 8192                                      ' 8 Sekunden
Start Watchdog
Config Powermode = Powerdown

End

'************************** U N T E R P R O G R A M M E ************************
Temp_in_array:                                              ' Temperatur in Array übernehmen
   X = 0
   While Temp_raw >= 100                                    ' solange Wert größer X
      Temp_raw = Temp_raw - 100                             ' Zehnerpotenz subtrahieren
      Incr X                                                ' dann Zaehler erhöhen
   Wend
   Barray(5) = X                                            ' Hunderter
   X = 0
   While Temp_raw >= 10                                     ' solange Wert größer X
      Temp_raw = Temp_raw - 10                              ' Zehnerpotenz subtrahieren
      Incr X                                                ' dann Zaehler erhöhen
   Wend
   Barray(4) = X                                            ' Zehner
   Barray(3) = Low(temp_raw)                                ' Einer
Return

'senden dauert: 57,55 mS (Thermo, AS3)
Tx_433_send:
   Tx_dbl = 0                                               ' alle Bits auf 0 setzen
   X = 10                                                   ' 10 Bit Präambel
   Do                                                       ' Bit 10 bis Anzahl Step 5 muß 1 sein
      Tx_dbl.x = 1                                          ' Bit auf 1 setzen
      X = X + 5                                             ' Array beginnt bei 1
   Loop Until X >= 46                                       ' Ende mit gesetzter Anzahl Bits 45 (Thermo, AS3)
   'Bits übernehmen
   Check = 0                                                ' Checksumme zurück setzen
   Ersumme = 0                                              ' Prüfsumme zurück setzen
   Tx_byte_nr = 0
   Do                                                       ' Sensortyp, Adresse und Werte aus Array übernehmen
      Incr Tx_byte_nr                                       ' beginnt mit 1
      Tx_byte = Barray(tx_byte_nr)                          ' Byte übernehmen
      Gosub Tx_433_byte                                     ' Bit 0-3 übernehmen
   Loop Until Tx_byte_nr >= 5                               ' fertig
   Incr Tx_byte_nr                                          ' nächstes Byte
   Tx_byte = Check                                          ' Checkbyte übernehmen
   Gosub Tx_433_byte                                        ' Byte übernehmen
   Ersumme = Ersumme + 5                                    ' Prüfsumme errechnen
   Tx_byte = Ersumme And &B00001111                         ' obere 4 Bit auf 0 setzen
   Incr Tx_byte_nr                                          ' nächstes Byte
   Gosub Tx_433_byte                                        ' Byte übernehmen
   'Bits senden
   Set Led_bl                                               ' LED ein
   X = 0                                                    ' Beginne mit Bit 0
   Do
      If Tx_dbl.x = 1 Then                                  ' 1 senden
         Set Tx433                                          ' Ausgang high
         Waitus 366                                         ' 366 µS warten
         Reset Tx433                                        ' Ausgang low
'         Waitus 854                                         ' 854 µS warten (OK bei 8 MHz Takt)
         Waitus 780                                         ' 854 µS warten, Rest braucht Programm
      Else                                                  ' 0 senden
         Set Tx433                                          ' Ausgang high
         Waitus 854                                         ' 854 µS warten
         Reset Tx433                                        ' Ausgang low
'         Waitus 366                                         ' 366 µS warten (OK bei 8 MHz Takt)
         Waitus 304                                         ' 366 µS warten, Rest braucht Programm
      End If
      Incr X                                                ' nächstes Bit
   Loop Until X >= 46                                       ' Ende mit gesetzter Anzahl Bits 45 (Thermo, AS3)
   Reset Led_bl                                             ' LED aus
Return

Tx_433_byte:
   Tx_bit_nr = Tx_byte_nr * 5                               ' Bit 5, 10, 15...
   Tx_bit_nr = Tx_bit_nr + 6                                ' Bit 11, 16, 21...
   X = 0
   Do
      Tx_dbl.tx_bit_nr = Tx_byte.x                          ' Bit aus Byte übernehmen
      Incr Tx_bit_nr : Incr X                               ' nächstes Bit
   Loop Until X >= 4                                        ' 4 Bit
   Check = Check Xor Tx_byte                                ' Check
   Ersumme = Ersumme + Tx_byte                              ' Prüfsumme bilden
Return
