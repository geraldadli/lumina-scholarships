package com.lumina.hybrid_ai_example

import android.os.Bundle
import android.util.Log
import com.google.firebase.Firebase
import com.google.firebase.appcheck.appCheck
import com.google.firebase.appcheck.debug.DebugAppCheckProviderFactory
import com.google.firebase.initialize
import io.flutter.embedding.android.FlutterActivity

/**
 * App contoh untuk menguji paket hybrid_ai (bukan aplikasi produksi).
 *
 * Memasang App Check *debug provider*. Saat pertama kali dijalankan, Firebase SDK
 * mencetak debug token ke logcat dengan teks "Enter this debug secret into the allow list".
 * Token itu didaftarkan manual di Firebase Console → App Check → Manage debug tokens.
 * Kode ini sendiri TIDAK pernah mencetak token.
 */
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val app = Firebase.initialize(this)
        if (app == null) {
            Log.w(TAG, "Firebase belum dikonfigurasi: google-services.json belum ditaruh di example/android/app/.")
            return
        }

        Firebase.appCheck.installAppCheckProviderFactory(DebugAppCheckProviderFactory.getInstance())

        // Meminta token sekali: memicu SDK mencetak debug secret, sekaligus menguji pendaftarannya.
        Firebase.appCheck.getAppCheckToken(false).addOnCompleteListener { task ->
            if (task.isSuccessful) {
                Log.i(TAG, "App Check OK: debug token sudah terdaftar di Firebase Console.")
            } else {
                Log.w(TAG, "App Check belum lolos (normal sebelum token didaftarkan): ${task.exception?.javaClass?.simpleName}")
            }
        }
    }

    private companion object {
        const val TAG = "LuminaAppCheck"
    }
}
