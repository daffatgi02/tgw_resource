blueprint TGW Multi-1v1 versi satu lokasi fisik, banyak arena pakai routing bucket, tanpa voice. Komunikasi pakai chat per arena. Tetap hybrid 70 persen ESX dan 30 persen standalone. Best practice.

Tujuan
• Semua arena berada di koordinat yang sama.
• Isolasi arena memakai routing bucket unik.
• Voice dimatikan. Chat dibatasi per arena.
• Tetap dukung antre, matchmaking, ronde, ladder, rating, spectate.

Porsi 70 persen ESX
• Identitas pemain dan identifier via xPlayer.
• Spawn dan teleport dasar via ESX.Game.
• Callback client server via ESX.TriggerServerCallback.
• Notifikasi via ESX.ShowNotification.
• HUD dasar via esx_hud.
• Menu via esx_menu_default.
• Uang cash untuk reward atau biaya masuk.

Porsi 30 persen standalone
• Queue Manager. Status lobi, waiting, paired, spectate.
• Matchmaker. Cocokkan rating dan preferensi ronde.
• Arena Manager. Satu set spawn A/B yang sama. Banyak arena dibedakan oleh bucket.
• Round Controller. Freeze, equip, start, end, cleanup, sudden death, AFK forfeit.
• Loadout Manager. Rifle, pistol, sniper. Aturan armor dan helm per tipe.
• Preference Manager. Ban pistol atau sniper. Favorit senjata.
• Ladder Manager. Naik turun level per hasil.
• Rating. ELO K-factor tetap. Simpan win, loss, recent rounds.
• Integrity Guard. Whitelist senjata, batas radius, anti godmode, anti teleport.
• Spectator Controller. Queue bisa spectate pemain yang sedang bertarung.
• Chat Router. Chat hanya ke pemain dalam bucket arena yang sama.

Dependensi wajib
• es_extended
• oxmysql
• esx_menu_default
• esx_hud

Konfigurasi server.cfg di path "D:fivem-server-roottxDataFiveMBasicServerCFXDefault_D1353C.baseserver.cfg"
• ensure oxmysql
• ensure es_extended
• ensure esx_menu_default
• ensure esx_hud
• ensure tgw_core
• ensure tgw_queue
• ensure tgw_matchmaker
• ensure tgw_arena
• ensure tgw_round
• ensure tgw_loadout
• ensure tgw_preference
• ensure tgw_ladder
• ensure tgw_rating
• ensure tgw_integrity
• ensure tgw_chat
• ensure tgw_ui

Skema database inti
• users
identifier varchar64 pk. nickname varchar24. money int.
• tgw_players
identifier pk. rating int default 1500. wins int. losses int. ladder_level int. last_seen timestamp.
• tgw_preferences
identifier pk. allow_pistol tinyint. allow_sniper tinyint. preferred_round enum rifle pistol sniper. fav_rifle varchar32. fav_pistol varchar32.
• tgw_arenas
id pk. name varchar32. bucket_id int unique. spawn_ax float. spawn_ay float. spawn_az float. spawn_bx float. spawn_by float. spawn_bz float. heading_a float. heading_b float. radius float. level int.
• tgw_matches
id pk. arena_id fk. player_a identifier. player_b identifier. round_type enum rifle pistol sniper. start_time ts. end_time ts. winner enum a b draw. status enum running ended.
• tgw_round_events
id pk. match_id fk. type varchar32 start end kill afk sd warn. actor identifier null. target identifier null. value int null. created_at ts.
• tgw_ladder_logs
id pk. identifier. before_level int. after_level int. match_id fk. created_at ts.
• tgw_rating_logs
id pk. identifier. before_rating int. after_rating int. delta int. match_id fk. created_at ts.
• tgw_queue
identifier pk. queued_at ts. state enum waiting spectate paired. preferred_round cached. rating_snapshot int.

Catatan seed arena
• Simpan satu set koordinat spawn A/B dan radius untuk “template”.
• Saat start, seed N baris tgw_arenas dengan bucket_id berbeda. Semua mengambil koordinat template yang sama.

Alur pemain dan spectate
• Pemain join. Sistem muat users dan tgw_players. Buat rating 1500 jika baru.
• Pemain pilih Join Queue di menu. Masuk tgw_queue state waiting.
• Jika semua arena terpakai, ubah state spectate. Pilih match running acak. Pindahkan pemain ke bucket arena target. Aktifkan spectator mode. Nonaktifkan collision dan input selain Next/Prev dan Leave.
• Saat ada slot, hentikan spectate. Teleport ke lobi kecil. Tarik pairing. Pindahkan ke bucket arena yang ditetapkan. Masuk freeze.

Matchmaker best practice
• Jalan tiap 1 detik. Ambil batch antrean teratas.
• Kelompokkan berdasar preferensi. Cocokkan selisih rating terdekat.
• Jika preferensi tidak cocok, pakai prioritas server: rifle, pistol, sniper.
• Simpan pairing ke tgw_matches status running. Hapus dari tgw_queue.

Arena Manager best practice
• Satu koordinat spawn A dan B untuk semua arena.
• Bedakan arena dengan bucket_id unik. Semua entitas dan pemain di-assign ke bucket arena.
• Pastikan set bucket saat masuk arena, respawn, dan setiap transisi ronde.
• Semua props yang di-spawn server wajib SetEntityRoutingBucket ke bucket arena.

Round Controller best practice
• Freeze 3–5 detik. Kunci gerak dan senjata. Tampilkan HUD lawan dan hitung mundur.
• Equip loadout sesuai round_type dan preferensi. Terapkan armor dan helm sesuai kebijakan.
• Start ronde 60–90 detik. Tandai AFK pada detik 15 jika tanpa input gerak atau tembakan.
• Sudden death 20–30 detik bila masih seri. Tambah damage atau beri damage di luar radius.
• End. Tentukan pemenang. Update ladder dan rating. Cleanup senjata dan status. Kembalikan ke antrean atau keluar mode.

Loadout Manager best practice
• Rifle. Primary dari fav_rifle. Secondary pistol default. Armor 50. Helm aktif.
• Pistol. Pistol saja dari fav_pistol. Armor 25. Helm nonaktif.
• Sniper. Sniper default. Pistol default. Armor 50. Helm aktif.
• Peluru pas untuk satu ronde. Tidak ada heal.

Preference Manager best practice
• Simpan preferensi ke tgw_preferences.
• Rifle selalu tersedia. Ban pistol atau sniper diperbolehkan.
• Validasi input agar tidak kosong semua.

Ladder Manager best practice
• Tentukan jumlah level misal 32. Level awal di tengah.
• Menang naik satu level. Kalah turun satu level.
• Simpan ke tgw_players.ladder_level. Catat ke tgw_ladder_logs.

Rating Manager best practice
• ELO K-factor 24. Hitung sekali saat ronde berakhir.
• Simpan before dan after ke tgw_rating_logs.

Integrity Guard best practice
• Scan whitelist senjata tiap 500 ms. Hapus yang ilegal.
• Cek radius. Beri peringatan 3 detik. Pelanggaran ulang → forfeit.
• Tes godmode ringan di luar freeze. Jika curang, keluarkan dari mode.
• Nonaktifkan reward saat spectate. Nonaktifkan interaksi.

Chat per arena
• Nonaktifkan broadcast chat global untuk pemain yang berada dalam mode TGW.
• Tangkap event chat server. Dapatkan bucket pengirim. Relay pesan hanya ke pemain dengan bucket yang sama.
• Tambahkan perintah “/a” untuk arena chat. Format nama: nickname#ladderLevel atau nickname#rating singkat.
• Saat spectate, pesan tetap masuk ke bucket arena yang ditonton. Hindari kirim ke semua arena.
• Saat keluar mode, kembalikan pemain ke chat global.

UI dan UX
• Menu tgw_ui via esx_menu_default. Isi Join, Leave, Preferences, Spectate Next, Spectate Prev.
• HUD ronde tampilkan nama lawan, sisa waktu, tipe ronde, kecil skor. Gunakan esx_hud untuk ammo. Tambahkan overlay freeze dan sudden death.
• Notifikasi wajib. Antre, pairing, teleport, countdown, start, win, lose, naik level, turun level, rating berubah.
• Chat indicator kecil di HUD agar jelas berada di channel arena.

Parameter konfigurasi
• freeze_time 4 detik. round_time 75 detik. sudden_death_time 25 detik.
• arenas_count misal 24. radius 30 meter.
• AFK threshold 15 detik. K_factor 24. rating awal 1500. level awal tengah.
• Urutan tipe ronde: rifle, pistol, sniper.
• ChatArenaCommand “/a”. Prefix nama chat: “[Arena N]”.

API event dan callback utama
• Client ke server
tgw:queue:join
tgw:queue:leave
tgw:pref:save
tgw:round:reportHit
tgw:spectate:next
tgw:spectate:prev
tgw:chat:sendArena
• Server ke client
tgw:queue:status waiting spectate paired
tgw:match:teleport arena_id spawn_side
tgw:round:freeze start countdown
tgw:round:equip loadout
tgw:round:begin timer
tgw:round:result winner rating_delta ladder_delta
tgw:spectate:start target_id
tgw:spectate:stop
tgw:chat:receiveArena message payload
• Callback ESX
tgw:ui:getStatus
tgw:ui:getPreferences
tgw:ui:getLeaderboard
• Exports antar modul
tgw_matchmaker:PairNow(identifier)
tgw_arena:GetFreeArena()
tgw_round:ForceEnd(match_id)
tgw_integrity:IsInArena(source)
tgw_chat:IsArenaChatEnabled(source)

Jadwal eksekusi loop
• Matchmaker tiap 1 detik.
• Spectator validasi target tiap 0.5 detik. Ganti target jika mati.
• Integrity scan tiap 0.5 detik.
• Round timer tick tiap 250 ms.
• Chat queue flush per tick untuk hindari spam.


Alur gamemode:
Siap. Berikut blueprint alur lengkap gamemode TGW Multi-1v1 satu lokasi, banyak arena via routing bucket, tanpa voice, chat per arena. Fokus ke UX dan flow. Tanpa opsi. Best practice.

1. Pra-game dan identitas

* Server cek data pemain saat connect.
* Jika belum punya nickname, tampilkan modal set nickname.
* Aturan nickname: 3–16 karakter. Huruf, angka, garis bawah. Unik. Saring kata terlarang.
* Simpan nickname ke DB. Kunci semua tombol selain simpan dan batal sampai beres.
* Jika sudah punya nickname, langsung ke Lobi.

2. Lobi

* Lokasi lobi di bucket 0. Tak ada senjata. Chat global aktif.
* HUD ringkas: tombol Join Queue. Tombol Preferences.
* Preferensi wajib: ban pistol atau sniper. Pilih rifle favorit dan pistol favorit.
* Setelah set, pemain menekan Join Queue. Status berubah menjadi Waiting.

3. Antrian dan spectate saat menunggu

* Sistem pairing jalan tiap 1 detik.
* Jika belum dapat lawan karena slot arena penuh, pemain langsung spectate.
* Server pilih satu match yang sedang berjalan. Pindahkan pemain ke bucket arena target.
* Mode spectate: tidak terlihat, tidak bisa interaksi, bisa ganti target.
* Indikator HUD menampilkan Spectate dan [Arena N].
* Saat ada slot dan pairing siap, server hentikan spectate. Pindahkan ke lobi kecil 2 detik. Lalu masuk arena.

4. Pairing

* Cocokkan berdasar selisih rating terdekat.
* Cek preferensi. Jika cocok, pakai tipe ronde yang cocok. Jika tidak, pakai urutan server: rifle, lalu pistol, lalu sniper.
* Tetapkan arena kosong. Set bucket pemain ke bucket arena.
* Teleport ke Spawn A atau Spawn B. Tampilkan nama lawan di HUD.

5. Ronde 1v1

* Freeze 4 detik. Kunci gerak dan senjata. Tampilkan countdown 3 2 1 dengan bunyi bip.
* Equip otomatis sesuai tipe ronde dan preferensi. Armor dan helm sesuai aturan tipe ronde.
* Ronde berjalan 75 detik. Ini 1 menit 15 detik. HUD menampilkan timer, nama lawan, tipe ronde.
* AFK forfeit jika 15 detik tanpa input gerak dan tembak.
* Keluar radius arena memicu peringatan 3 detik. Ulangi pelanggaran → forfeit.

6. Sudden death

* Jika 75 detik habis dan belum ada pemenang, jalankan sudden death 25 detik.
* Tambah tekanan: shrink radius bertahap atau damage di luar radius. Headshot bonus 25 persen.
* Jika tetap tidak ada kill sampai 25 detik habis, tentukan pemenang dengan urutan berikut.

  1. HP tersisa tertinggi menang.
  2. Jika HP sama, hit terbanyak menang.
  3. Jika tetap sama, hasil draw.

7. Hasil ronde

* Kalah karena mati, forfeit, AFK, atau keluar radius.
* Menang jika lawan mati, forfeit, AFK, disconnect, atau timeout kalah kriteria di sudden death.
* Draw jika kriteria di sudden death sama persis.

8. Pasca ronde

* Tampilkan ringkasan 5 detik di tengah layar. Win atau Lose atau Draw. Rating ±. Level ±. Durasi. Tipe ronde.
* Update ladder: menang naik 1 level. Kalah turun 1 level. Batas bawah 1. Puncak tetap saat menang.
* Update rating ELO K-factor 24. Hitung sekali. Simpan before dan after.
* Bersihkan senjata dan status. Kembalikan ke Waiting secara default.

9. Spectate setelah selesai

* Setelah panel hasil hilang, pemain bisa:

  1. Re-queue otomatis. Tetap di Waiting.
  2. Masuk Spectate match lain. Tombol di HUD. Server memindahkan ke bucket arena target.
  3. Keluar ke Lobi. Kembali ke bucket 0 dan chat global.

10. Kematian di tengah ronde

* Pemain yang mati langsung masuk Spectate lawan di arena yang sama.
* HUD ganti ke mode Spectate. Tampilkan sisa waktu.
* Tidak ada respawn di ronde itu.
* Setelah hasil diumumkan, ikuti alur Pasca ronde.

11. AFK, timeout, disconnect

* AFK 15 detik di ronde → forfeit. Lawan menang.
* Keluar radius berulang → forfeit. Lawan menang.
* Disconnect saat ronde → lawan menang. HUD lawan menampilkan “Menang. Lawan disconnect.”
* Saat pemain reconnect, status dikembalikan ke Lobi.

12. Chat per arena

* Saat di arena atau spectate, chat hanya untuk pemain di bucket arena yang sama.
* Indikator HUD menampilkan [Arena N] atau [Arena N • Spectate].
* Saat di Lobi, chat kembali global dengan indikator [Global].

13. Waktu dan siklus

* Freeze 4 detik.
* Ronde 75 detik.
* Sudden death 25 detik.
* Total maksimum satu match 104 detik termasuk transisi singkat.
* Matchmaker berjalan paralel. Target antrean tidak lebih dari 1 detik untuk evaluasi.

14. Alur lengkap end-to-end

* Pemain baru masuk. Jika belum punya nickname, set nickname. Lanjut ke Lobi.
* Set preferensi. Join Queue. Status Waiting.
* Jika slot penuh, masuk Spectate match aktif. Bisa ganti target. Menunggu pairing.
* Pairing terjadi. Server pilih arena dan bucket. Teleport ke Spawn A atau B.
* Freeze 4 detik dengan countdown 3 2 1. Lalu start.
* Ronde 75 detik. Sistem pantau AFK, radius, senjata legal.
* Jika belum selesai, sudden death 25 detik.
* Server tentukan hasil. Kirim rating ± dan level ±. Tampilkan ringkasan 5 detik.
* Setelah ringkasan, pemain otomatis Waiting. Bisa pilih Spectate match lain atau keluar ke Lobi.

15. Aturan tegas pemain

* Tidak ada heal item. Tidak ada loot. Semua loadout dari server.
* Tidak ada voice. Hanya chat per arena.
* Tidak bisa pindah arena manual saat bertanding.
* Tidak bisa ganti nickname saat antre atau bertanding.

16. Sinyal UX penting

* Forfeit reason selalu muncul 4 detik: “Forfeit. AFK 15 dtk.” atau “Forfeit. Keluar zona.”
* Countdown besar di tengah. Bip 3 kali. “GO” singkat.
* Ringkasan kemenangan dan kekalahan singkat. Ada angka rating dan level yang jelas.
* Badge chat menunjukkan channel aktif. “Global”, “[Arena 7]”, atau “[Arena 7 • Spectate]”.

17. Tanggung jawab server

* Server satu-satunya sumber kebenaran hasil ronde.
* Server yang menetapkan bucket, equip, start, end, dan spectate.
* Server yang memutus AFK, radius, disconnect, dan forfeit.

18. Batasan teknis yang wajib

* OneSync aktif. Routing bucket aktif.
* Set bucket ulang pada setiap transisi: enter arena, respawn, end, spectate start/stop.
* Semua entitas arena yang di-spawn server memakai bucket arena. Hindari kebocoran stream.

19. Jalur pilihan pemain setelah hasil

* Re-queue langsung. Tidak ada konfirmasi. Cepat.
* Spectate match lain. Tombol khusus di HUD hasil. Server pilih match rating berdekatan.
* Keluar ke Lobi. Tombol Back. Kembali chat global.

20. Nilai default yang dipakai

* Ronde 75 detik. Sudden death 25 detik. Freeze 4 detik.
* AFK threshold 15 detik.
* Ladder 32 level. Start di level 16.
* Rating start 1500. K-factor 24.
* Radius arena 30 meter.

Rencana struktur folder dan file
• resources
[esx]
es_extended
esx_menu_default
esx_hud
[standalone]
oxmysql
[tgw]
tgw_core
fxmanifest.lua
server/main.lua        init DB, ambil ESX, helpers, rate limit
client/main.lua        binding dasar, wrapper notif ESX
config/shared.lua      konstanta global dan keybind
tgw_queue
fxmanifest.lua
server/queue.lua       antre, state waiting, spectate
client/ui.lua          menu Join, Leave, Preferences, Spectate
tgw_matchmaker
fxmanifest.lua
server/matchmaker.lua  pairing rating dan preferensi, tulis tgw_matches
tgw_arena
fxmanifest.lua
server/arena.lua       assign bucket, enter/leave arena, entity bucket
client/zone.lua        cek radius satu lokasi, warning out-of-bounds
tgw_round
fxmanifest.lua
server/round.lua       state machine freeze, equip, start, end, cleanup
client/round.lua       countdown, HUD, freeze control, sudden death
tgw_loadout
fxmanifest.lua
server/loadout.lua     rifle pistol sniper, armor, helm, ammo
tgw_preference
fxmanifest.lua
server/prefs.lua       simpan dan ambil tgw_preferences
client/menu.lua        esx_menu_default untuk pengaturan
tgw_ladder
fxmanifest.lua
server/ladder.lua      naik turun level, log
tgw_rating
fxmanifest.lua
server/elo.lua         ELO, simpan rating dan log
tgw_integrity
fxmanifest.lua
server/guard.lua       whitelist senjata, anti cheat, forfeit
client/guard.lua       scan senjata dan radius, disable controls
tgw_chat
fxmanifest.lua
server/chat.lua        filter chat ke bucket arena, perintah “/a”
client/chat.lua        UI kecil status channel chat
tgw_ui
fxmanifest.lua
client/hud.lua         overlay timer, lawan, tipe ronde, indikator chat
client/spectate.lua    mode spectate, ganti target, kamera

Kekurangan dan improvisasi
• Semua berada di satu lokasi. Kamu wajib disiplin set bucket pada setiap transisi. Kalau lupa, pemain bisa saling terlihat antar arena. Alasan: routing bucket adalah satu-satunya isolasi.
• Chat per arena butuh override chat bawaan. Kamu perlu intercept event chat di server agar tidak broadcast global. Alasan: cegah cross-arena intel dan spam.
• Tanpa voice. Fokus gameplay jadi bersih. Jika nanti butuh turnamen, kamu bisa tambahkan voice khusus panitia via bucket khusus. Alasan: kontrol koms sederhana dan aman.

blueprint UI UX

Status HUD dan Alur State

* State yang ditangani: Lobby. Queue. Spectate. Freeze. In-Round. Sudden-Death. End-Summary.
* Render HUD hanya pada state aktif. Matikan saat Lobby.
* Target performa draw loop di 0.02 ms. Update teks timer di 10 Hz. Animasi pakai fade 150 ms.

1. Alasan Forfeit di HUD
   Tujuan

* Pemain paham kenapa kalah tanpa bingung.

Desain

* Posisi kanan atas di bawah timer ronde.
* Chip kecil dengan ikon. Teks pendek 2 kata.
* Warna merah untuk keluar zona. Kuning untuk AFK.

Konten

* Keluar zona. “Forfeit. Keluar zona.”
* AFK. “Forfeit. AFK 15 dtk.”

Interaksi

* Muncul saat pelanggaran diputus server.
* Tampil 4 detik. Fade in 150 ms. Fade out 200 ms.
* Sembunyikan jika ronde berakhir.

Teknis

* Client memegang state forfeitReason string.
* Server kirim event tgw:round:forfeitReason payload reason dan ttl.
* Jangan pakai NUI berat. Gambar rect dan teks via native draw. Gunakan safezone scaling.

2. Countdown 3 2 1 dengan bunyi bip
   Tujuan

* Start yang jelas. Semua siap menembak di detik 0.

Desain

* Posisi tengah layar. Angka besar.
* Ukuran 1080p. 220 px tinggi. Skala adaptif safezone.
* Warna putih 80 persen opacity. Efek pop scale kecil.

Audio

* Bunyi bip tiga kali. Nada meningkat. Bunyi “GO” pendek di akhir.

Teknis

* Kirim event tgw:round:freezeStart dengan duration.
* Client jalankan counter lokal 3 2 1 0. Tampilkan angka. Hilang saat 0.
* Audio. Gunakan tiga file ogg 40–60 ms di NUI audio tag. Play via SendNUIMessage agar konsisten lintas build. Hindari nama soundset game yang berubah.
* Kunci input saat freeze. Lepas kunci pada 0. Aktifkan senjata pada frame yang sama.

3. Ringkasan Akhir Ronde
   Tujuan

* Pemain melihat hasil singkat. Tahu perubahan rating dan level.

Desain

* Panel tengah atas. Lebar 560 px. Tinggi 180 px.
* Judul besar Win atau Lose. Warna hijau untuk Win. Merah untuk Lose. Oranye untuk Draw.
* Baris detail: Rating ±XX. Level ±1. Waktu ronde. Tipe ronde.

Konten contoh

* “Win”
* “Rating +18”
* “Level +1”
* “Rifle 01:08”

Interaksi

* Tampil 5 detik. Bisa tutup cepat dengan tombol Enter.
* Setelah panel hilang. Notifikasi kecil “Masuk antre lagi” di kanan atas 2 detik.

Teknis

* Server kirim event tgw:round:end payload winner ratingDelta ladderDelta roundType duration.
* Client render panel via native draw atau NUI ringan tanpa DOM berat.
* Jangan ambil rating ulang dari DB. Percaya payload server. Hindari race.

4. Indikator Channel Chat Aktif
   Tujuan

* Pemain tahu sedang chat arena. Tidak spam global.

Desain

* Badge kecil di dekat minimap kiri bawah.
* Format “[Arena 5]”. Tambah ikon balon chat kecil.
* Warna biru tegas. Kontras dengan minimap.

Konten

* Arena N saat di bucket arena.
* “Global” saat di lobi.
* Tambah “Spectate” saat menonton.

Interaksi

* Klik keybind Y untuk fokus chat arena. Chat global dimatikan saat mode TGW jika disetel RestrictGlobalInMode.
* Saat spectate. Badge menampilkan “[Arena 5 • Spectate]”.

Teknis

* Server chat router hanya relay ke bucket pengirim.
* Client tampilkan badge berdasarkan state lokal arenaId dan role spectate.
* Rate limit input chat 4 pesan per 6 detik. Tampilkan “Cooldown chat 1 dtk” jika melampaui.

Spesifikasi Visual
Palet warna

* Win hijau 31B36B. Lose merah E33C3C. Draw oranye F2A900.
* Timer putih FFFFFF 80 persen. Forfeit merah E33C3C. AFK kuning FFC400.
* Badge arena biru 1F8BED.

Tipografi

* Heading medium. Skala 0.8–1.0 GTA text scale.
* Body kecil. Skala 0.4–0.5.
* Jarak huruf standar. Teks semua huruf kapital untuk angka countdown.

Aksesibilitas

* Kontras minimal 4.5. Tambah ikon untuk buta warna. Petir untuk sudden death. Timer jam untuk waktu.
* Semua informasi warna wajib ada teksnya.

Audio

* Volume bip 35 persen. Jangan lebih keras dari senjata.
* Matikan audio di spectate jika ingin diam. Tampilkan indikator visual saja.

Kontrol dan Keybind

* Buka menu preferensi F5.
* Spectate next RIGHT. Spectate prev LEFT.
* Tutup panel end Enter.

Kontrak Event HUD
Client mendengar

* tgw:round:freezeStart duration
* tgw:round:countdown t sisa detik jika server ingin sinkron ulang
* tgw:round:forfeitReason reason ttl
* tgw:round:end winner ratingDelta ladderDelta roundType duration
* tgw:chat:channel arenaId role

Client mengirim

* tgw:ui:ackEndPanel closed true saat panel ditutup
* tgw:chat:sendArena text

Fallback tanpa NUI

* Countdown dan forfeit tetap jalan dengan native draw.
* Panel end pakai native draw sederhana. Hanya NUI yang menangani audio bip.
* Jika NUI gagal load. Diamkan audio. Jangan hentikan flow ronde.

Perf budget

* HUD draw 0.02 ms. Countdown update 10 Hz.
* Panel end 0.03 ms maksimum saat tampil.
* Tidak ada loop berat di setiap frame. Pakai state change trigger.

Urutan Render HUD

* Atas. Timer ronde dan chip forfeit.
* Tengah. Countdown atau panel end.
* Kiri bawah. Badge chat arena.
* Jangan tumpuk dengan notifikasi ESX. Geser 20 px bila overlap.

Validasi QA

* Baca timer dari 3 meter dan 720p. Jelas.
* Forfeit selalu muncul maksimal 150 ms setelah server putuskan.
* Panel end tidak menutupi crosshair jika pemain masih bisa bergerak.
* Badge chat berubah instan saat pindah bucket.

String Lokal Indonesia

* “Forfeit. Keluar zona.”
* “Forfeit. AFK 15 dtk.”
* “Sudden Death”
* “Win”
* “Lose”
* “Draw”
* “Rating +%d”
* “Rating %s%d”
* “Level %s%d”
* “[Arena %d]”
* “[Global]”
* “[Arena %d • Spectate]”
* “Masuk antre lagi”


Ini set konfigurasi untuk blueprint config tgw: satu lokasi fisik, banyak arena lewat routing bucket, tanpa voice, chat per arena. Semua file format Lua. Letakkan di folder masing-masing.

tgw_core/config/shared.lua

```lua
Config = {}

-- kerangka
Config.Framework = 'esx'
Config.UseVoice = false                 -- voice dimatikan
Config.EnableSpectateQueue = true
Config.Locale = 'id'

-- kapasitas
Config.MaxArenas = 24                   -- jumlah arena paralel
Config.LobbyBucket = 0                  -- bucket lobi

-- timing global
Config.TickRate = 250                   -- ms
Config.DBWait = 50

-- ekonomi (opsional)
Config.UseCashAsCredits = true
Config.CreditsOnWin = 100
Config.CreditsOnLose = 0
```

tgw_arena/config/arena.lua

```lua
Config = {}

-- model satu lokasi, banyak arena via bucket
Config.UseInstance = true
Config.BaseBucket = 1000                -- bucket awal arena
Config.ArenasCount = 24                 -- jumlah arena aktif
Config.AutoSeedArenas = true            -- auto-seed tgw_arenas saat start

-- template lokasi untuk SEMUA arena
Config.Template = {
  name      = 'Depot One',
  radius    = 30.0,
  spawnA    = vector3(169.5, -1005.2, 29.4),
  headingA  = 90.0,
  spawnB    = vector3(145.8, -1012.9, 29.4),
  headingB  = 270.0
}

-- batas arena (untuk warning / sudden death)
Config.OutOfBoundsWarnSec = 3.0
```

tgw_chat/config/chat.lua

```lua
Config = {}

-- chat per arena
Config.EnableArenaChat = true
Config.ArenaCommand = 'a'               -- /a <pesan> kirim ke arena (bucket) yang sama
Config.GlobalCommand = 'g'              -- /g <pesan> kirim global bila diizinkan

-- batasi chat global saat dalam mode
Config.RestrictGlobalInMode = true      -- blok chat global default saat player di mode TGW

-- format
Config.ShowBucketInPrefix = true        -- [Arena 5]
Config.ShowLadderOrRating = 'rating'    -- 'rating' atau 'ladder' atau 'none'
Config.PrefixMaxName = 18

-- rate limit
Config.RateLimitPerArena = { msgs = 4, window = 6 }  -- 4 pesan per 6 detik
```

tgw_queue/config/queue.lua

```lua
Config = {}

-- antre dan spectate
Config.MinEloDiff = 100
Config.EloDiffGrow = 25
Config.EloDiffGrowStep = 10
Config.MaxEloDiff = 400

Config.SpectateSwitchCooldown = 2.0
Config.SpectateHud = true

-- preferensi ronde dan fallback
Config.MatchPreferredFirst = true
Config.ServerRoundPriority = { 'rifle', 'pistol', 'sniper' }
Config.FallbackAfterSec = 30
```

tgw_matchmaker/config/matchmaker.lua

```lua
Config = {}

Config.TickPairingSec = 1
Config.MaxPairsPerTick = 12
Config.ReuseEmptyArenaFirst = true
```

tgw_round/config/round.lua

```lua
Config = {}

-- waktu
Config.FreezeTime   = 4.0
Config.RoundTime    = 75.0
Config.SuddenDeath  = 25.0
Config.AFKThreshold = 15.0

-- sudden death
Config.SuddenDeathShrink = true
Config.SuddenDeathShrinkStep = 3.0
Config.SuddenDeathTick = 5.0

-- out of bounds
Config.OutOfBoundsDamagePerSec = 25

-- tipe ronde
Config.RoundTypes = {
  rifle = {
    armor = 50, helmet = true,
    weapons = { 'WEAPON_CARBINERIFLE','WEAPON_ASSAULTRIFLE','WEAPON_BULLPUPRIFLE' },
    pistol = 'WEAPON_PISTOL',
    ammo = { primary = 120, secondary = 36 }
  },
  pistol = {
    armor = 25, helmet = false,
    weapons = { 'WEAPON_PISTOL','WEAPON_PISTOL_MK2','WEAPON_PISTOL50' },
    pistol = nil,
    ammo = { primary = 60, secondary = 0 }
  },
  sniper = {
    armor = 50, helmet = true,
    weapons = { 'WEAPON_SNIPERRIFLE','WEAPON_MARKSMANRIFLE','WEAPON_HEAVYSNIPER' },
    pistol = 'WEAPON_SNSPISTOL',
    ammo = { primary = 30, secondary = 24 }
  }
}

-- kontrol
Config.DisableMelee = true
Config.BlockHealthItems = true
Config.BlockArmorItems  = true
```

tgw_loadout/config/loadout.lua

```lua
Config = {}

-- favorit default
Config.DefaultFav = {
  rifle  = 'WEAPON_CARBINERIFLE',
  pistol = 'WEAPON_PISTOL'
}

-- attachments
Config.Attachments = {
  WEAPON_CARBINERIFLE  = { 'COMPONENT_AT_AR_FLSH','COMPONENT_AT_AR_AFGRIP' },
  WEAPON_ASSAULTRIFLE  = { 'COMPONENT_AT_AR_FLSH' },
  WEAPON_MARKSMANRIFLE = {},
  WEAPON_SNIPERRIFLE   = {},
  WEAPON_PISTOL        = { 'COMPONENT_AT_PI_FLSH' },
  WEAPON_PISTOL50      = {}
}

-- ammo map
Config.AmmoType = {
  primary = 'AMMO_RIFLE',
  pistol  = 'AMMO_PISTOL',
  sniper  = 'AMMO_SNIPER'
}
```

tgw_preference/config/preferences.lua

```lua
Config = {}

Config.AllowBanPistol = true
Config.AllowBanSniper = true
Config.RifleAlwaysAvailable = true

Config.MaxNameLen = 20
```

tgw_ladder/config/ladder.lua

```lua
Config = {}

Config.Levels = 32
Config.StartLevel = 16
Config.StepWin = 1
Config.StepLose = 1
Config.StayOnTopIfWin = true
Config.BottomFloor = 1
```

tgw_rating/config/rating.lua

```lua
Config = {}

Config.StartRating = 1500
Config.KFactor = 24
Config.SeasonalReset = false
Config.SeasonalFloor = 1200
Config.DrawMargin = 0.10

Config.LogEveryMatch = true
```

tgw_integrity/config/integrity.lua

```lua
Config = {}

-- whitelist per tipe
Config.Whitelist = {
  rifle  = { 'WEAPON_CARBINERIFLE','WEAPON_ASSAULTRIFLE','WEAPON_BULLPUPRIFLE','WEAPON_PISTOL' },
  pistol = { 'WEAPON_PISTOL','WEAPON_PISTOL_MK2','WEAPON_PISTOL50' },
  sniper = { 'WEAPON_SNIPERRIFLE','WEAPON_MARKSMANRIFLE','WEAPON_HEAVYSNIPER','WEAPON_SNSPISTOL' }
}

-- scan
Config.ScanIntervalMs = 500
Config.BoundaryWarnSec = 3.0
Config.BoundaryMaxViolations = 2

-- anti-godmode ringan
Config.HealthProbe = true
Config.HealthProbeInterval = 7.5
Config.HealthProbeDamage = 1
```

tgw_ui/config/ui.lua

```lua
Config = {}

-- keybind
Config.OpenMenuKey = 'F5'
Config.SpectateNextKey = 'RIGHT'
Config.SpectatePrevKey = 'LEFT'
Config.LeaveQueueKey = 'BACK'

-- HUD
Config.ShowRoundHUD = true
Config.ShowTimer = true
Config.ShowOpponentName = true
Config.ShowRoundType = true

-- indikator chat
Config.ShowChatChannel = true     -- tampilkan [Arena N] di HUD kecil
```

server.cfg minimal

```cfg
ensure oxmysql
ensure es_extended
ensure esx_menu_default
ensure esx_hud

ensure tgw_core
ensure tgw_queue
ensure tgw_matchmaker
ensure tgw_arena
ensure tgw_round
ensure tgw_loadout
ensure tgw_preference
ensure tgw_ladder
ensure tgw_rating
ensure tgw_integrity
ensure tgw_chat
ensure tgw_ui
```

Catatan penting
• Semua arena pakai koordinat Template yang sama. Isolasi terjadi di bucket BaseBucket..BaseBucket+ArenasCount-1.
• Matikan pma-voice. Komunikasi hanya lewat tgw_chat.
• Intercept chat default di tgw_chat. Pakai /a untuk chat per arena.
• Set ulang bucket pada setiap transisi: enter arena, respawn, end, spectate start/stop.
• Jika nanti ingin ganti lokasi, cukup ubah Template. Tidak perlu ubah jumlah arena.
