# Extraction Fighter — MVP 0.6.0 Arena Reborn

Lokalna gra Movement Arena Fighter w Godot 4.7.2: szybki movement, broń palna i biała, dwie aktywne umiejętności oraz krótkie mecze rundowe przeciw botom. Poziom konta, mastery i kosmetyki nie zwiększają siły postaci.

## Instalacja i uruchomienie

Projekt nie wymaga wtyczek ani dodatkowych bibliotek. Potrzebna jest standardowa wersja Godot 4.7.2 (bez .NET/Mono).

```bash
git clone https://github.com/chr0mzyy/extraction-fighter.git
cd extraction-fighter
godot --path .
```

Jeśli Godot nie jest w `PATH`, użyj pełnej ścieżki do pliku wykonywalnego. Możesz też zaimportować `project.godot` w Project Managerze i nacisnąć `F5`. Na CachyOS/Arch pobrany plik może wymagać `chmod +x Godot_v4.7.2-stable_linux.x86_64`.

## Sterowanie

| Klawisz | Działanie |
| --- | --- |
| `W` `A` `S` `D` | Ruch na ziemi |
| `Mysz` | Widok; z `A`/`D` steruje torem bunny hopu |
| `Spacja` | Skok; przytrzymanie łączy bunny hopy |
| `Shift`, `C` lub `Ctrl` | Kucanie / momentum slide |
| `1` / `2` | Broń 1 / broń 2 |
| `LPM` | Strzał / lekki atak |
| `PPM` | ADS / blok |
| `F` | Ciężki atak bronią białą |
| `R` | Przeładowanie; restart trasy w Movement Training |
| `Q` / `E` | Umiejętność w slocie Q / E |
| `3` / `4` | Wychylenie w lewo / prawo |
| `V` | Przełączenie FPP / TPP w Casual |
| `Esc` | Pauza |
| `F3` | Diagnostyka |

Bindy można zmienić w **SETTINGS > KEYBINDS**. Double Jump zajmuje slot umiejętności, ale uruchamia się drugim naciśnięciem `Spacji` w powietrzu. W locie puszczenie `W` nie kasuje pędu; air-strafe/bhop wymaga trzymanej `Spacji`, zgodnego `A`/`D` i ruchu myszy.

## Główna pętla

**LOBBY → BUILD → ARENA → RESULTS → XP / MASTERY / COSMETICS → NEXT MATCH**

- **PLAY:** Casual 1v1 (pierwszy do 4) albo Casual 2v2 (pierwszy do 3). To wyłącznie lokalna gra z botami; matchmaking i multiplayer nie są zaimplementowane.
- **LOADOUT:** dwie rodziny broni, dwa skille i maksymalnie 200 Skill Power. Wszystkie 10 rodzin oraz wszystkie 10 działających skilli są dostępne od początku.
- **CUSTOMIZATION:** wybór skórki niezależny od broni gameplayowej. Common/Rare/Mythic opisuje wyłącznie kosmetyk.
- **PROFILE:** poziom konta, XP, Style Tokens, statystyki i mastery każdej rodziny.
- **TRAINING:** 10-mechanikowa trasa movementu z checkpointami, restartem i personal best; nie daje trwałego mastery ani waluty.

Ranked pozostaje widocznym, wyłączonym placeholderem **COMING SOON**. Jego gotowa polityka kamery wymusza FPP; Casual pozwala płynnie zmieniać FPP/TPP.

## Arsenał i umiejętności

Rodziny gameplayowe: Katana, Nodachi, Sniper Rifle, Assault Rifle, Burst Rifle, Battle Rifle, Knight Sword, Magic Wand, Glock i Akimbo Glock. Każda ma własną rolę i jedną autorytatywną konfigurację statystyk. Rusty/Ronin/Phantom i pozostałe warianty są skórkami tej samej rodziny: nie zmieniają obrażeń, tempa, odrzutu, amunicji, zasięgu, hitboxu ani efektów.

Skille: Dash 60, Double Jump 70, Wallrun 70, Smoke Veil 70, Air Dash 80, Launch 85, Grapple 90, Ground Slam 90, Blink 110 i Invisibility 120. Suma slotów Q+E nie może przekroczyć 200. Invisibility kończy się przy ataku, Blink sprawdza kolizję, Grapple zachowuje pęd, a Wallrun wymaga kontaktu ze ścianą.

Pełne wartości broni, role i założenia TTK są w [docs/arena_reborn_balance.md](docs/arena_reborn_balance.md).

## Uczciwość i progresja kosmetyczna

Standardowa Arena zawsze używa 100 HP i `ArenaEquipmentResolver`. Affixy, efekty Mythic, statystyki rarity, durability, pancerz z gearu i poziom konta są odłączone od obliczeń walki. Sniper zadaje 90 w głowę, więc pełne 100 HP nie ginie od jednego standardowego trafienia.

Po ukończonym meczu prawdziwe statystyki wydarzeń naliczają jeden raz:

- Account XP za ukończenie, wynik i aktywną grę,
- mastery XP tylko rodzinom faktycznie użytym w walce,
- Style Tokens na kosmetyki.

Identyfikator wyniku zapobiega ponownemu odebraniu nagrody po rematchu lub ponownym otwarciu ekranu. Mastery 5 i 15 może odblokować kolejne istniejące skórki; żaden poziom nie zmienia gameplayu. Poprzednia wymiana/przejmowanie przedmiotów po Arenie jest nieaktywna.

Damage liczy wyłącznie faktycznie odebrane HP, bez obrażeń ponad pozostałe zdrowie celu. Bezczynne bronie nie zdobywają mastery. Jeśli zapis nagrody zawiedzie, profil jest przywracany do wcześniejszego stanu, a wyniki pokazują **RETRY REWARD SAVE**. Ponowienie nie duplikuje nagrody; wyjście do lobby przed udanym zapisem oznacza rezygnację z nagrody za ten mecz.

Perfect parry Katany wymaga 0,6 s przed ponownym otwarciem okna; zwykły blok działa także w tym czasie. Peek animuje górną część sylwetki i zachowuje stabilne nogi.

## Zapis i migracja

Profil v7 pozostaje w `user://player_profile.json` i korzysta z zapisu tymczasowego, weryfikacji oraz backupu. Migracja z v6:

- zachowuje stare item instances, stash, affixy, durability, Gold, Scrap i historię extraction,
- mapuje tylko zweryfikowane posiadane warianty broni na kosmetyki,
- dodaje domyślne skórki, Arena loadout, account XP, mastery, Style Tokens i statystyki,
- jest idempotentna i nie przelicza starego majątku na przewagę ani walutę kosmetyczną.

Legacy Dungeon/Extraction nie jest dostępny w głównym menu. Kod pozostaje zachowany dla kompatybilności i można odzyskać stan sprzed migracji z referencji Git `backup/pre-arena-reborn` (commit `19404239cb5414f154892d26bf2443135d4148aa`).

## Testy na Linuxie

Najważniejsze testy można uruchomić z katalogu repozytorium:

```bash
/sciezka/do/godot --headless --editor --path . --quit
/sciezka/do/godot --headless --path . -- --arena-reborn-test
/sciezka/do/godot --headless --path . -- --arena-round-test
/sciezka/do/godot --headless --path . -- --arena-mode=2v2 --arena-round-test
/sciezka/do/godot --headless --path . -- --arena-acceptance-test
/sciezka/do/godot --headless --path . -- --arena-mode=2v2 --arena-acceptance-test
/sciezka/do/godot --headless --path . -- --arena-reward-test
/sciezka/do/godot --headless --path . -- --loadout-integration-test
/sciezka/do/godot --headless --path . -- --self-test
/sciezka/do/godot --headless --path . -- --training-self-test
/sciezka/do/godot --headless --path . -- --lobby-layout-test
/sciezka/do/godot --headless --path . -- --pause-flow-test
```

`--arena-reborn-test` sprawdza dostęp nowego profilu, identyczne statystyki wszystkich skórek w rodzinie, brak przecieków affix/Mythic, limit 200 Power, bezpieczną migrację v6→v7, jednorazowe XP/mastery/Style Tokens, odblokowanie kosmetyki i politykę kamery. `--arena-reward-test` potwierdza, że stary item swap jest wyłączony i ekran wyników pokazuje progresję. Testy używają izolowanych profili; zwykłe uruchomienie korzysta z normalnego profilu użytkownika.

## Powtarzalna weryfikacja

Przy uruchamianiu testów ustaw osobny katalog `XDG_DATA_HOME`, aby startowe ładowanie profilu nie dotykało Twoich normalnych danych:

```bash
XDG_DATA_HOME=/tmp/extraction-fighter-tests godot --headless --path . -- --arena-acceptance-test
XDG_DATA_HOME=/tmp/extraction-fighter-visual godot --path . --rendering-method gl_compatibility -- --arena-visual-test
```

Test akceptacyjny prowadzi faktyczne postacie przez countdown, eliminacje, reset rund, wyniki, zapis/reload nagród i rematch. Test graficzny wymaga wyświetlacza i zapisuje 27 obrazów do `user://arena_visual_validation`: lobby, loadout, kosmetyki, profil, FPP, TPP, pauza, wyniki i błąd zapisu w 1280×720, 1920×1080 oraz 2560×1440. Szczegóły w [raporcie weryfikacji](docs/arena_reborn_validation.md).

## Stan projektu

MVP 0.6.0 jest grywalnym lokalnym vertical slice’em Arena Reborn. Zachowano zaawansowany movement, melee/parry, 10 skilli, AI, rundy, FPP/TPP, audio, HUD, ustawienia, pauzę i trening. Nie ma jeszcze sieci, Ranked, nowych modeli postaci, bannerów/emote ani pełnego zestawu nagród mastery 10/20. Dungeon i jego ekonomia istnieją wyłącznie jako nieaktywna warstwa legacy.
