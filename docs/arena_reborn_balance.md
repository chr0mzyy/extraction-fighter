# Arena Reborn — authoritative balance baseline

MVP 0.6.0 rozdziela rodzinę gameplayową od wyglądu. Źródłem prawdy jest `ArenaEquipmentResolver`; `WeaponCosmeticDefinition` przechowuje wyłącznie identyfikację i prezentację skórki. Standardowa Arena ma 100 HP, nie używa affixów, efektów Mythic, durability ani premii gearu.

## Broń

| Rodzina | Body / light | Head / heavy | Tempo | Magazynek | Reload | Dodatkowe strojenie |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| Katana | 28 | 45 | melee | — | — | blok 70%, deflect 0.18 s, recovery 0.48/0.92 s |
| Nodachi | 38 | 58 | melee | — | — | blok 55%, recovery 0.72/1.24 s, dłuższy lunge |
| Sniper Rifle | 58 | 90 | 1.05/s | 4 | 1.80 s | 1.15° hip spread; brak one-shota 100 HP |
| Assault Rifle | 17 | 26 | 8.50/s | 30 | 2.05 s | hip 1.0°, ADS 0.22° |
| Burst Rifle | 18 | 29 | 6.25/s | 24 | 1.95 s | 0.58 s między burstami; ADS 0.20° |
| Battle Rifle | 34 | 52 | 2.70/s | 14 | 2.30 s | mocny odrzut; hip 1.45°, ADS 0.25° |
| Knight Sword | 32 | 50 | melee | — | — | blok 78%, deflect 0.15 s, windup heavy 0.30 s |
| Magic Wand | 30 | — | 2.00/s | — | — | widoczny pocisk 31 m/s |
| Glock | 20 | 30 | 6.25/s | 17 | 1.35 s | hip 0.90° |
| Akimbo Glock | 14 | 21 | 9.20/s | 34 | 2.30 s | hip 1.85°, bez ADS |

Są to wartości startowe, nie obietnica finalnego balansu. Celem jest typowy TTK około 1.5–2.5 s w realistycznym starciu. Rodziny pozostają mechanicznie różne, ale wszystkie skórki jednej rodziny muszą generować identyczny fingerprint gameplayowy.

## Umiejętności

| Skill | Power | Bazowy cel cooldownu |
| --- | ---: | ---: |
| Dash | 60 | 6 s |
| Double Jump | 70 | 4 s |
| Wallrun | 70 | 7 s |
| Smoke Veil | 70 | 14 s |
| Air Dash | 80 | 8 s |
| Launch | 85 | 10 s |
| Grapple | 90 | 9 s |
| Ground Slam | 90 | 11 s |
| Blink | 110 | 11 s |
| Invisibility | 120 | 20 s |

Maksymalna suma dwóch slotów wynosi 200 Power. Power jest kosztem konstrukcji builda, a nie statystyką powiększaną przez konto.

## Progresja

- Account XP: 90 za ukończenie, 50 za zwycięstwo, do 120 za kille, do 180 za damage i do 50 za headshoty.
- Style Tokens: 12 za ukończenie, 8 za zwycięstwo i do 20 za kille.
- Mastery rodziny: bazowo 20 po użyciu w ukończonym meczu, następnie ograniczone bonusy za real damage, hity i kille tej rodziny.
- Mastery level: `1 + floor(xp / 400)`, maksymalnie 20. Poziom 5 odblokowuje drugą istniejącą skórkę rodziny, poziom 15 trzecią.
- Account level i mastery nie zmieniają HP, damage, recoil, cooldownów ani Skill Power.

Każdy wynik ma unikatowy `result_id`. Nagroda może zostać zatwierdzona tylko raz, a Training nie wywołuje trwałego serwisu progresji.

## Inwarianty uczciwości

1. `ArenaWeaponGameplayDefinition.apply_to()` zawsze usuwa affixy, `special_effect_id` i durability.
2. Wybrany `skin_id` może zmienić nazwę, ikonę/model, rarity i flavor text — nic więcej.
3. Standardowa Arena czyści gameplayowe efekty gearu i ustawia 100 HP.
4. Casual pozwala na FPP/TPP; przyszłe Ranked jest FPP-only i pozostaje wyłączone do powstania prawdziwej infrastruktury sieciowej.
5. Legacy affix/Mythic runtime pozostaje testowalny poza standardową Areną, ale nie może zostać włączony przez kosmetyk.
