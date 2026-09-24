# Ritterland: Panduan Kode

Panduan ini merangkum semua file `.gd` yang dibuat atau diubah selama pengerjaan, apa fungsi tiap bagiannya, dan cara menambah variabel atau isi baru. Semua path relatif terhadap folder project (`res://`).

Ringkasan cepat alur game:

```
Dialogic (.dtl)  ->  Cutscene.gd  ->  CombatZone  ->  CombatManager / TurnManager
                                                          |
                     PlayerInputHandler (input)  +  CombatHUD (tombol/bar)
                                                          |
                     SkillDB / SkillData (data skill)  +  EntityBase (stat unit)
                                                          |
                     Global / CharacterProgress (level, loadout, save)  +  PauseMenu (menu)
```

---

## 1. Dialog dan Cutscene

### `Dialog/S1/*.dtl` (timeline Dialogic)

Satu file per chapter (`ch00_prologue` sampai `ch15_*`). Cerita mengikuti novel persis. Pilihan jawaban hanya mengubah nada Lan dan meter kedekatan, bukan alur.

- Variabel yang boleh berubah: `aff_*` (kedekatan karakter), `stat_*`, flag event kanon, dan `combat_won`. Rank tetap 67.
- Pause dan kecepatan teks: `[pause=0.35]` dan `[lspeed=0.25!]...[lspeed]`. Titik-titik `...` dibuat lambat satu kali.
- Baris dialog **tidak boleh diawali kata kunci Dialogic** (`if`, `elif`, `else`, `jump`, `label`, `join`, `leave`, `set`). Baris seperti itu dibaca sebagai perintah.
- Memicu cutscene atau battle dari dialog memakai event Signal:

```
[signal arg="combat:tutorial"]
if {combat_won}:
    Lan: Menang.
else:
    Lan: Kalah.
```

**Menambah variabel dialog baru:** buka `project.godot`, bagian `[dialogic]` → `variables`, tambahkan entri baru (misal `aff_rin`). Di dialog pakai `{aff_rin}` atau `set {aff_rin} += 1`. Variabel lama yang tidak terpakai (exposure, rank_points, dan lain-lain) masih ada di file itu dan aman dihapus.

### `Scripts/core/Cutscene.gd` (autoload `Cutscene`)

Penghubung antara Dialogic, sprite di dunia, dan combat. Autoload sudah terdaftar di Project Settings.

| Bagian | Fungsi |
|---|---|
| `play(timeline, label)` | Memulai timeline: `Cutscene.play("ch00_prologue")`. |
| `get_actor(id)` | Mengembalikan node aktor: Lan (`Global.player`), NPC asli di `Y-sort` (`<id>Npc` atau `<id>`), atau menduplikat `IliaNpc.tscn` sebagai placeholder dengan warna berbeda. |
| `_on_speaker` | Otomatis memastikan pembicara ada di layar. |
| `_on_signal(arg)` | Membaca perintah dari event Signal di `.dtl`. |
| `_busy(job)` | Menjeda Dialogic selama sebuah aksi (gerak atau battle) berjalan. |
| `_move` | Menjalankan animasi jalan lalu idle. |
| `_combat` | Menyembunyikan textbox, membekukan pemain, menjalankan `CombatZone.start_training()`, menunggu `combat_ended`, mengisi `Dialogic.VAR.combat_won` (1 atau 0), lalu menampilkan dialog lagi. |
| `_freeze(on)` | Membekukan atau melepas pemain saat cutscene. |

Perintah Signal yang tersedia: `enter:Nama:x:y`, `move:Nama:x:y[:detik]`, `leave:Nama`, `combat:<apa pun>`.

**Menambah perintah baru:** tambahkan cabang di `match p[0]` pada `_on_signal`, misalnya `"shake": _shake()`. **Mengganti sprite placeholder:** ubah `const ACTOR := preload(...)`. **Menambah nama yang dianggap pemain:** edit `PLAYER_NAMES`.

Catatan: fitur lompat (`hop`) sudah dihapus atas permintaanmu.

### `addons/dialogic/Modules/Character/DefaultAnimations/stardew_cross.gd`

Animasi pergantian potret (crossfade) bergaya Stardew Valley. Potret lama memudar cepat, potret baru muncul dengan kilatan putih yang memudar ke normal.

- `HOP := 0.0` (tinggi lompatan, 0 = tidak melompat). Ubah ke angka piksel lain kalau mau melompat lagi.
- `FLASH := 3.0` (kecerahan kilatan, di atas 1 lebih terang dari putih).
- File animasi Dialogic **harus** berada di folder `DefaultAnimations` supaya terbaca.
- Diaktifkan lewat `project.godot`: `animations/cross_fade_default="Stardew Cross"` dan `cross_fade_default_length=0.35`.

---

## 2. Data skill

### `Scripts/resources/SkillData.gd`

Satu resource = satu skill. Field yang bisa diatur:

| Field | Arti |
|---|---|
| `id`, `display_name`, `description` | Identitas dan teks tampilan. |
| `category` | `PHYSICAL` atau `MAGIC`. |
| `shape` | `SINGLE` (satu tile pilihan), `AREA` (kotak `(2*radius+1)²` di sekitar tile pilihan; `cast_range` 0 = berpusat di pemakai), `PROJECTILE` (terbang lurus, mengenai target valid pertama). |
| `target_side` | `ENEMIES` atau `ALLIES`. |
| `min_level` | Level minimal untuk membuka skill. |
| `sp_cost`, `ap_cost` | Biaya SP dan AP (AP per giliran = SPD). |
| `power` | Pengali damage terhadap ATK. 0 = tanpa damage (buff/debuff). |
| `spd_scale` | Damage tambahan = SPD pemakai × nilai ini (skill berbasis SPD). |
| `hits` | Jumlah serangan; damage total dibagi rata per hit. |
| `cast_range`, `radius` | Jarak bidik dan radius area. |
| `def_pierce` | Persentase DEF target yang diabaikan (0 sampai 1). |
| `effect` | `StatusEffect` yang dikenakan ke tiap target. |
| `weapon` | `""` = bebas senjata (magic), atau `"longsword"` / `"montante"`. |
| `pull` | Setelah damage, target ditarik sekian tile ke pusat skill. |
| `charge_gain`, `is_ultimate` | Pengisi bar ultimate dan penanda ultimate (memakai satu bar penuh). |

Fungsi: `shape_name()` dan `summary()` menghasilkan teks ringkas untuk tooltip dan menu.

### `Scripts/core/SkillDB.gd`

Database skill, loadout, dan basic attack. Semua fungsi `static`, bisa dipanggil sebagai `SkillDB.xxx()`.

**Konstanta penting**

- `CHARACTER_SKILLS`: daftar id skill yang bisa dipelajari tiap karakter (key `"player"` untuk Lan, `member_id` untuk anggota party).
- `BASIC`: definisi basic attack per karakter (atau `"karakter:senjata"`). Key yang dipakai: `name`, `reach`, `power`, `spd`, `hits`, `shape` (`single` / `area` / `proj`), `radius`, `splash`.
- `START_WEAPON`: senjata awal untuk karakter yang bisa ganti senjata. `SWAP`: pasangan senjata yang saling ditukar.
- `MAX_LOADOUT := 4`: jumlah slot per bar.

**Fungsi**

| Fungsi | Kegunaan |
|---|---|
| `_build()` | Tempat semua `_add({...})` skill ditulis. |
| `get_skill(id)` | Mengambil satu skill. |
| `skills_for_character(id)` | Semua skill karakter, diurutkan per level. |
| `unlocked_skills(id, level)` | Skill biasa yang sudah terbuka. |
| `get_ultimate(id, level)` | Ultimate yang terbuka. |
| `get_loadout(id, weapon)` | Bar skill aktif. Untuk pengguna senjata, memakai bar milik senjata itu; magic masuk ke kedua bar. |
| `ensure_customized(id)` | Mengubah bar otomatis menjadi bar yang bisa diedit (juga membuat bar per senjata untuk Lan). |
| `on_level_up(...)` | Mengisi slot kosong dengan skill baru saat naik level. |
| `weapon_of(actor)` | Senjata aktif sebuah unit (diisi otomatis dari `START_WEAPON`). |
| `basic_for(actor)` | Data basic attack unit itu. |
| `basic_skill(actor)` | Basic attack dalam bentuk `SkillData` (0 SP, 1 AP) agar memakai sistem bidik dan highlight grid yang sama (tombol Q). |
| `basic_damage(actor)` | ATK × power + SPD × spd. |
| `basic_in_reach(actor, from, to)` | Cek jangkauan basic attack (jarak 2 atau lebih harus satu garis lurus). |

**Cara menambah skill baru**

1. Di `_build()`, tambahkan:

```gdscript
_add({"id": "contoh", "display_name": "Contoh", "category": P, "shape": AREA,
	"weapon": "montante",          # kosongkan untuk magic / bebas senjata
	"min_level": 5, "sp_cost": 6, "ap_cost": 2, "power": 1.5,
	"cast_range": 3, "radius": 1, "description": "..."})
```

2. Daftarkan id-nya di `CHARACTER_SKILLS["player"]` (atau karakter lain).
3. Selesai. Skill otomatis muncul di menu dan di battle. Untuk skill berbasis SPD tambahkan `"spd_scale": 1.0`. Untuk debuff tambahkan `"effect": _effect("id", "Nama", StatusEffect.StatType.SPD, -2, 3)` (stat, jumlah, durasi giliran).

**Cara menambah karakter baru (Rin, Leonora, dan lainnya):** buat entri di `CHARACTER_SKILLS["id_member"]` dan entri di `BASIC["id_member"]` (`reach`, `power`, `shape`, dan seterusnya). Kalau karakter itu bisa ganti senjata, tambahkan juga ke `START_WEAPON` dan `BASIC["id:senjata"]`.

---

## 3. Combat

### `Scripts/core/TurnManager.gd`

Mesin giliran: fase Planning (pemain menyusun aksi) lalu Execution (semua aksi berjalan berurutan, FIFO).

Bagian yang diubah atau ditambah selama chat ini:

| Fungsi | Kegunaan |
|---|---|
| Penanganan `ATTACK_MELEE` | Cek jangkauan lewat `SkillDB.basic_in_reach`, damage lewat `SkillDB.basic_damage`, mendukung multi-hit dan `splash`. Dipakai juga oleh musuh. |
| `get_skill_cells(...)` | Semua tile yang terkena skill. |
| `is_skill_target_valid(...)` | Cek target bidikan valid atau tidak. |
| `_execute_skill(actor, action)` | Membayar biaya, mencari target, menghitung damage (ATK × power + SPD × spd_scale, dibagi per hit), memberi efek, menjalankan tarikan, lalu mengisi bar ultimate. |
| `_pull_toward(t, center, steps)` | Menggeser target ke pusat skill, hanya masuk tile kosong (tidak menumpuk). Mencoba sumbu terjauh dulu, lalu sumbu lain, lalu berhenti. |
| `clear_remaining_actions_for_unit(unit)` | Membatalkan sisa aksi sebuah unit. Dipakai saat musuh tertarik: rutenya sudah tidak valid, jadi dia kehilangan giliran. |
| `unit_at_cell`, `is_opponent`, `_cell_open`, `_check_combat_end` | Fungsi bantu yang sudah ada. |

Aturan tarikan: musuh yang `is_boss = true` tidak bisa ditarik.

### `Scripts/ui/PlayerInputHandler.gd`

Input pemain saat fase Planning.

| Bagian | Kegunaan |
|---|---|
| Tombol 1 sampai 4 | Skill di bar. Tombol 5 = ultimate. |
| Tombol **Q** | Basic attack dengan highlight grid (`toggle_skill(SkillDB.basic_skill(unit))`). |
| Tombol **E** | Slot spesial: `do_special()`. Untuk Lan menukar longsword dan montante, 0 AP, langsung berlaku. |
| `queue_melee_attack(target)` | Klik musuh langsung = basic attack, memakai jangkauan dari `SkillDB.basic_in_reach`. |
| `toggle_skill`, `queue_skill_at`, `can_use_skill` | Alur bidik, antre, dan validasi skill. |

**Menambah tombol hotkey baru:** tambahkan cabang di blok `if event is InputEventKey` di `_unhandled_input`, contohnya:

```gdscript
if event.keycode == KEY_R:
	mau_diapakan()
	return
```

### `Scripts/ui/CombatHUD.gd`

HUD battle. Bagian skill bar (`_update_skill_bar`, `_rebuild_skill_buttons`, `_add_skill_button`):

- Menampilkan tombol **Q** (basic) dan **E** (swap weapon, hanya untuk unit yang punya senjata), lalu skill 1 sampai 4, lalu ultimate.
- Bar dibangun ulang otomatis kalau senjata atau isi loadout berubah.
- Ikon tombol Q dan E kosong dulu. Isi lewat Inspector node HUD: `basic_icon` dan `special_icon` (tipe `Texture2D`).

### `Scripts/entities/EntityBase.gd`

Base class semua unit (pemain, party, musuh). Bagian yang ditambah:

- `var weapon: String` (senjata aktif; diisi malas oleh `SkillDB.weapon_of`).
- `get_battle_skills()` sekarang memanggil `SkillDB.get_loadout(character_id, weapon)`.
- Sudah ada: `character_id`, `spd`, `get_effective_stat(...)`, `move_to_grid_target(pos)`, `take_damage`, `spend_sp`, `gain_charge`.

### `Scripts/entities/EnemyNPC.gd`

- `@export var is_boss: bool = false`: centang di Inspector untuk bos. Bos kebal efek tarik.

---

## 4. Progres, menu, dan save

### `Scripts/core/CharacterProgress.gd`

Data satu karakter yang bertahan antar battle dan masuk save: level, xp, poin stat, equipment, dan loadout.

- `skill_loadout`: 4 id skill untuk karakter biasa.
- `weapon_loadout`: untuk Lan, `{ "longsword": [4 id], "montante": [4 id] }`.
- `to_dict()` / `from_dict()` sudah menyimpan dan memuat `weapon_loadout`.

**Menambah data karakter baru yang perlu disimpan:** tambahkan variabel, lalu tambahkan ke `to_dict()` dan `from_dict()`.

### `Scripts/core/Global.gd`

Autoload global. Bagian yang diubah:

- `get_progress(id)`: kalau karakter berbasis senjata belum punya bar per senjata, bendera "customized" dimatikan sehingga bar dibangun ulang otomatis.
- `set_skill_slot(id, slot, skill_id, weapon := "")`: memasang skill ke slot. Aturan Lan: skill fisik hanya di bar senjatanya; skill magic (`weapon == ""`) menempati slot yang sama di kedua bar; mengganti slot yang berisi magic dengan skill fisik menghapus magic itu dari bar satunya juga.

Contoh: `Global.set_skill_slot("player", 1, "vortex", "longsword")` memasang Vortex di slot 2 kedua bar.

### `Scripts/ui/PauseMenu.gd`

Bagian Skills di menu karakter. Untuk karakter berbasis senjata (Lan) ditampilkan dua bar (Longsword dan Montante) masing-masing 4 slot; skill magic diberi tanda `[shared]`. Karakter lain tetap satu bar. Perubahan dropdown memanggil `Global.set_skill_slot`.

---

## 5. Cara kerja skill Lan (ringkas)

- Longsword (single target): Zornhau (Lv 1), Half-Sword Thrust (Lv 3), Krumphau (Lv 6), Zwerchhau (Lv 9).
- Montante (area): Montante Cross (Lv 1), Montante Crash (Lv 3), Montante Sweep (Lv 6), Montante Storm (Lv 9).
- Wind shir (magic, bebas senjata, slot dipakai bersama): Wind Blade (Lv 2), Vortex (Lv 3, menarik musuh, 10 SP 2 AP), Tailwind (Lv 5), Gale Cleave (Lv 9), Cyclone Prison (Lv 11, tarik 3 tile lalu slow, 14 SP 2 AP).
- Basic attack: Longsword Cut (satu target) dan Montante Swing (area 3x3 di sekitar tile sebelah Lan).
- Ilia: basic Rapier Thrust (jangkauan 2 lurus, ATK + SPD), skill rapier berbasis SPD (Fleche, Double Thrust, Dancing Blades) dan illusion shir (Mirage Veil, Phantom Step, Illusion Snare, Hundred Faces).

## 6. Catatan penting

- **Godot menimpa file yang terbuka.** Kalau file `.gd` terbuka di editor saat saya mengubahnya dari luar, Godot bisa menyimpan versi lama. Tutup tab script sebelum perubahan datang, atau pilih Reload / Don't Save.
- Angka balance (damage, biaya, level) adalah tebakan awal. Ubah langsung di `SkillDB._build()`.
- Belum diuji langsung di Godot: cek Output/Debugger setelah menjalankan dan kirim errornya kalau ada.
