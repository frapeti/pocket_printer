package com.example.pax_printer_app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import java.io.File
import java.io.FileOutputStream
import android.net.Uri
import android.content.ContentResolver
import android.webkit.MimeTypeMap
import android.util.Log

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.pax_printer_app/shared_image"
    private var sharedImagePath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Configurar el canal para comunicarse con Flutter
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getSharedImagePath") {
                result.success(sharedImagePath)
                // Reset después de enviar para evitar reutilizar la misma imagen
                sharedImagePath = null
            } else {
                result.notImplemented()
            }
        }
        
        // Procesar el intent si ya existe
        handleIntent(intent)
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }
    
    private fun handleIntent(intent: Intent) {
        // Verificar si el intent es de tipo SEND (compartir)
        val action = intent.action
        val type = intent.type
        
        if (Intent.ACTION_SEND == action && type?.startsWith("image/") == true) {
            try {
                // Obtener la URI de la imagen compartida
                val imageUri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                
                if (imageUri != null) {
                    // Crear una copia local de la imagen para acceder a ella después
                    val copiedFile = copyImageToLocal(imageUri)
                    sharedImagePath = copiedFile.absolutePath
                    Log.d("MainActivity", "Imagen recibida: $sharedImagePath")
                }
            } catch (e: Exception) {
                Log.e("MainActivity", "Error procesando imagen compartida", e)
            }
        }
    }
    
    private fun copyImageToLocal(uri: Uri): File {
        val contentResolver = contentResolver
        val inputStream = contentResolver.openInputStream(uri)
        
        // Obtener extensión del archivo
        val extension = getExtension(contentResolver, uri)
        
        // Crear archivo temporal en la caché de la app
        val outputDir = cacheDir
        val outputFile = File.createTempFile("shared_image_", ".$extension", outputDir)
        
        // Copiar contenido
        val outputStream = FileOutputStream(outputFile)
        inputStream?.use { input ->
            outputStream.use { output ->
                input.copyTo(output)
            }
        }
        
        return outputFile
    }
    
    private fun getExtension(contentResolver: ContentResolver, uri: Uri): String {
        // Intentar obtener extensión del MimeType
        val mimeType = contentResolver.getType(uri)
        return if (mimeType != null) {
            MimeTypeMap.getSingleton().getExtensionFromMimeType(mimeType) ?: "jpg"
        } else {
            // Default a jpg si no se puede determinar
            "jpg"
        }
    }
}
