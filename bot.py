import undetected_chromedriver as uc
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import time
import random
import requests

# ============================================================
# 1. KONFIGURASI GREEN API (DAPATKAN DARI DASHBOARD)
# ============================================================
ID_INSTANCE = "7107484514"       # Contoh: 1101234567
API_TOKEN = "2a555fb6b17a41029e35f8f663cb5b530a14864803a84e3194"    # Contoh: d3e4f5g6h7i8j9k0...
DEST_PHONE = "6288223749303"      # Nomor tujuan notifikasi (format 62)

# ============================================================
# 2. KONFIGURASI TARGET ANTREAN
# ============================================================
URL_TARGET = "https://antrean.logammulia.com/"

def kirim_wa_green(pesan):
    """Fungsi kirim WhatsApp menggunakan Green API"""
    url = f"https://api.green-api.com/waInstance{ID_INSTANCE}/sendMessage/{API_TOKEN}"
    payload = {
        "chatId": f"{DEST_PHONE}@c.us",
        "message": pesan
    }
    headers = {'Content-Type': 'application/json'}
    try:
        response = requests.post(url, json=payload, headers=headers)
        if response.status_code == 200:
            print("✅ Notifikasi WhatsApp (Green API) terkirim!")
        else:
            print(f"❌ Gagal kirim WA: {response.text}")
    except Exception as e:
        print(f"⚠️ Error API: {e}")

def jalankan_bot():
    print("🚀 Memulai Bot Antrean Antam dengan Green API...")
    
    options = uc.ChromeOptions()
    # Aktifkan baris di bawah jika ingin pakai profil Chrome agar tidak login ulang
    # options.add_argument(f"--user-data-dir=C:\\Users\\NAMA_USER\\AppData\\Local\\Google\\Chrome\\User Data")

    driver = uc.Chrome(options=options)

    try:
        driver.get(URL_TARGET)
        print("🔎 Monitoring dimulai. Mengecek tombol 'Ambil Antrean'...")

        while True:
            try:
                driver.refresh()
                timestamp = time.strftime('%H:%M:%S')

                # XPath untuk tombol pendaftaran (Bisa disesuaikan jika teks berubah)
                xpath_tombol = "//a[contains(text(), 'Ambil')] | //button[contains(text(), 'Booking')]"
                
                try:
                    wait = WebDriverWait(driver, 6)
                    tombol = wait.until(EC.element_to_be_clickable((By.XPATH, xpath_tombol)))
                    
                    if tombol:
                        print(f"[{timestamp}] !!! ANTREAN TERBUKA !!!")
                        tombol.click()
                        
                        # Kirim notifikasi via Green API
                        pesan_wa = f"🔥 ALERT ANTAM: Antrean sudah dibuka pada {timestamp}! Bot telah mencoba klik. Segera selesaikan di laptop!"
                        kirim_wa_green(pesan_wa)
                        
                        # Berhenti agar user bisa ambil alih
                        print("🚨 Segera selesaikan pendaftaran secara manual!")
                        break 
                except:
                    print(f"[{timestamp}] Slot belum ada. Mencoba lagi...")

                # Jeda refresh 15-25 detik (Aman dari blokir IP)
                time.sleep(random.uniform(15, 25))

            except Exception as e:
                print(f"⚠️ Gangguan pada browser: {e}")
                time.sleep(10)

    except KeyboardInterrupt:
        print("\n🛑 Bot dihentikan.")
    finally:
        print("🖥️ Browser tetap terbuka untuk pengisian data.")

if __name__ == "__main__":
    jalankan_bot()
